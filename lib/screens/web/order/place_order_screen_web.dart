import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:mynt_plus/utils/custom_navigator.dart';
import 'package:mynt_plus/provider/profile_all_details_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/web_colors.dart';
import 'package:mynt_plus/res/global_font_web.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import '../market_watch/tv_chart/chart_iframe_guard.dart';
import 'margin_details_dialog_web.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/models/marketwatch_model/scrip_info.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/order_book_model/order_margin_model.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:mynt_plus/models/order_book_model/sip_place_order.dart';
import 'package:mynt_plus/provider/auth_provider.dart';
import 'package:mynt_plus/provider/chart_provider.dart';
import 'package:mynt_plus/provider/market_watch_provider.dart';
import 'package:mynt_plus/provider/network_state_provider.dart';
import 'package:mynt_plus/provider/order_input_provider.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/shocase_provider.dart';
import 'package:mynt_plus/provider/sip_order_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/transcation_provider.dart';
import 'package:mynt_plus/provider/user_profile_provider.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/screens/web/funds/fund_screen_web.dart';
import 'orderscreen_header_web.dart';
import 'slice_order_sheet_web.dart';
import 'package:mynt_plus/sharedWidget/common_text_fields_web.dart';
import 'package:mynt_plus/sharedWidget/custom_widget_button.dart';
import 'package:mynt_plus/sharedWidget/enums.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';
import 'package:mynt_plus/sharedWidget/no_internet_widget.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/utils/rupee_convert_format.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/provider/fund_provider.dart';
import 'package:mynt_plus/res/res.dart';
import '../../../models/order_book_model/place_gtt_order.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/utils/url_utils.dart';
import 'package:mynt_plus/utils/safe_parse.dart';
import 'package:mynt_plus/models/marketwatch_model/linked_scrips.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:mynt_plus/utils/overlay_manager.dart';
import 'package:mynt_plus/utils/custom_navigator.dart';
import 'package:mynt_plus/routes/route_names.dart';

// InheritedWidget to pass close callback to child widgets
class _PlaceOrderDialogCloseNotifier extends InheritedWidget {
  final VoidCallback onClose;

  const _PlaceOrderDialogCloseNotifier({
    required this.onClose,
    required super.child,
  });

  static _PlaceOrderDialogCloseNotifier? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_PlaceOrderDialogCloseNotifier>();
  }

  @override
  bool updateShouldNotify(_PlaceOrderDialogCloseNotifier oldWidget) {
    return onClose != oldWidget.onClose;
  }
}

// InheritedWidget to pass drag handlers to child widgets
class _PlaceOrderDialogDragNotifier extends InheritedWidget {
  final void Function(DragStartDetails) onPanStart;
  final void Function(DragUpdateDetails) onPanUpdate;
  final void Function(DragEndDetails) onPanEnd;
  final bool isDragging;

  const _PlaceOrderDialogDragNotifier({
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.isDragging,
    required super.child,
  });

  static _PlaceOrderDialogDragNotifier? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_PlaceOrderDialogDragNotifier>();
  }

  @override
  bool updateShouldNotify(_PlaceOrderDialogDragNotifier oldWidget) {
    return onPanStart != oldWidget.onPanStart ||
        onPanUpdate != oldWidget.onPanUpdate ||
        onPanEnd != oldWidget.onPanEnd ||
        isDragging != oldWidget.isDragging;
  }
}

class PlaceOrderScreenWeb extends ConsumerStatefulWidget {
  final OrderScreenArgs orderArg;
  final ScripInfoModel scripInfo;
  final String isBasket;
  final bool fromChart;
  const PlaceOrderScreenWeb(
      {super.key,
      required this.scripInfo,
      required this.orderArg,
      required this.isBasket,
      this.fromChart = false});

  @override
  ConsumerState<PlaceOrderScreenWeb> createState() =>
      _PlaceOrderScreenWebState();

  // Static variable to track the current overlay entry
  static OverlayEntry? _currentOverlayEntry;

  // Static variable to track inner dialog overlay entries
  static OverlayEntry? _currentDialogOverlayEntry;

  // Static variable to remember the last position of the dialog
  static Offset? _lastSavedPosition;

  /// Static method to show a dialog on top of the place order overlay
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

  /// Static method to show PlaceOrderScreenWeb as a draggable dialog
  static void showDraggable({
    required BuildContext context,
    required OrderScreenArgs orderArg,
    required ScripInfoModel scripInfo,
    required String isBasket,
    bool fromChart = false,
    Offset? initialPosition,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    
    // Close existing order screen if one is already open
    if (_currentOverlayEntry != null) {
      try {
        _currentOverlayEntry!.remove();
      } catch (e) {
        // Entry might already be removed, ignore error
      }
      _currentOverlayEntry = null;
    }

    // Dialog dimensions for centering calculation
    const dialogWidth = 450.0;
    const dialogHeight = 500.0;
    // Use saved position, then initialPosition parameter, then center of screen
    final position = _lastSavedPosition ??
        initialPosition ??
        Offset(
          (MediaQuery.of(context).size.width - dialogWidth) / 2,
          (MediaQuery.of(context).size.height - dialogHeight) / 2,
        );

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _DraggablePlaceOrderScreenDialog(
        orderArg: orderArg,
        scripInfo: scripInfo,
        isBasket: isBasket,
        fromChart: fromChart,
        initialPosition: position,
        onPositionChanged: (newPosition) {
          // Save the position for next time
          _lastSavedPosition = newPosition;
        },
        onClose: () {
          overlayEntry.remove();
          _currentOverlayEntry = null;
          // Unregister from overlay manager
          OverlayManager.unregister(overlayEntry);
        },
      ),
    );

    // Store the current overlay entry
    _currentOverlayEntry = overlayEntry;
    overlay.insert(overlayEntry);

    // Register with overlay manager for global control
    OverlayManager.register(overlayEntry);
  }
}

class _PlaceOrderScreenWebState extends ConsumerState<PlaceOrderScreenWeb>
    with TickerProviderStateMixin {
  bool? isBuy;
//   bool addStoploss = false;
  bool isAgree = false;
  String quotemsg = "";
//   bool addValidity = false;
//   bool isAmo = false;
  // bool isAvbSecu = false;
  bool isSecu = false;
  Future<void> Function()? _pendingSurveillanceAction;

  // Stock exchange selection variables
  List<Equls> _stockExchangesList = [];
  Equls stockExchangeSelected = Equls();
  OrderScreenArgs selectedStockSubscribe = OrderScreenArgs(exchange:"",token:"",tSym:"",prd:"",transType:true,perChange:"",lotSize:"",ltp:"",isExit:false,orderTpye:"",isModify:false,raw:{},holdQty:"");

  late AnimationController anibuildctrl;
  // late Animation<double> _shakeAnimation;
  TextEditingController priceCtrl = TextEditingController();
  TextEditingController mktProtCtrl = TextEditingController();
  TextEditingController qtyCtrl = TextEditingController();
  TextEditingController discQtyCtrl = TextEditingController();
  TextEditingController triggerPriceCtrl = TextEditingController();
  TextEditingController stopLossCtrl = TextEditingController();
  TextEditingController targetCtrl = TextEditingController();
  TextEditingController trailingTicksCtrl = TextEditingController();

  TextEditingController sipLtpctrl = TextEditingController();
  TextEditingController sipname = TextEditingController();
  TextEditingController sipqtyctrl = TextEditingController();

  final Preferences pref = locator<Preferences>();

  DateTime now = DateTime.now();
  String formattedDate = "";
  String selectedValue = 'Daily';
  double resultsip = 0.0;

  String mktProtErrorText = "";
  TextEditingController mktProtDialogCtrl = TextEditingController();

  // Debounce timer for validation warnings
  Timer? _warningDebounceTimer;

  // Debounce timer for margin and brokerage API calls
  Timer? _marginUpdateDebounceTimer;

  int frezQty = 0;
  int reminder = 0;
  int maxQty = 0;
  int quantity = 0;
  List orderTypes = ["Delivery", "Intraday", "CO - BO"];

  List priceTypes = ["Limit", "Market", "SL Limit", "SL MKT"];
  List<String> validityTypes = ["DAY", "IOC", "EOS"];
  List<String> sipDropdown = ['Daily', 'Weekly', 'Fortnightly', 'Monthly'];
  bool isOco = false;
  bool isGtt = true;

  // List<String> validityTypesGTT = ["DAY", "GTT"];
  bool _isStock = true;
  int lotSize = 0;
  int multiplayer = 0;
  String ordPrice = "0.00";
  String validityType = "GTT";
  String orderType = "Delivery";
  String priceType = "Limit";
  // String validityTypeGTT = "DAY";
  double tik = 0.00;
  double roundOffWithInterval(double input, double interval) {
    return ((input / interval).round() * interval);
  }

  /// Handles keyboard up/down arrow to increment/decrement a price field by tick size.
  /// Returns [KeyEventResult.handled] if the key was consumed, [KeyEventResult.ignored] otherwise.
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
    // Round to tick size to avoid floating point drift
    newVal = roundOffWithInterval(newVal, tik);
    final formatted = newVal.toStringAsFixed(2);
    ctrl.text = formatted;
    ctrl.selection = TextSelection.collapsed(offset: formatted.length);
    setState(() {
      if (ctrl == priceCtrl) {
        ordPrice = formatted;
      }
      if (ctrl == priceCtrl || ctrl == triggerPriceCtrl) {
        _debouncedMarginUpdate();
      }
    });
    return KeyEventResult.handled;
  }

  /// Handles keyboard up/down arrow on the qty field.
  /// - Stocks: step by 1.
  /// - F&O Qty mode (`isLotMode == false`): step by lot size, snap non-multiples.
  /// - F&O Lot mode (`isLotMode == true`): step by 1 lot.
  ///
  /// `isLotMode` differs per call site:
  ///   - main qty   → `!_isStock && !_isLotToQty`
  ///   - GTT/OCO qty → `!_isStock && !_isGTTLotToQty`
  KeyEventResult _handleQtyArrowKey(
      KeyEvent event, TextEditingController ctrl, bool isLotMode) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    final isUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final isDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!isUp && !isDown) return KeyEventResult.ignored;

    final int step = (_isStock || isLotMode)
        ? 1
        : (multiplayer > 0 ? multiplayer : 1);
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
      _debouncedMarginUpdate();
    });
    return KeyEventResult.handled;
  }

  /// Freeze-cap warning text. In Lot mode the cap is shown in lots
  /// to match the field's display; otherwise the original Qty-mode text.
  String _freezeCapMessage() {
    final int frezQtyOrderSliceMaxLimit =
        ref.read(orderProvider).frezQtyOrderSliceMaxLimit;
    if (!_isStock && !_isLotToQty && lotSize > 0) {
      final int maxLots = (frezQtyOrderSliceMaxLimit * frezQty) ~/ lotSize;
      return "Maximum Allowed Lots: $maxLots";
    }
    return "Maximum Allowed Quantity $frezQty x $frezQtyOrderSliceMaxLimit = ${frezQtyOrderSliceMaxLimit * frezQty}";
  }

  Map userOrderPreference = {};
  bool isUserOrderPreferenceAvailable = false;
  final GlobalKey<TooltipState> tooltipKey = GlobalKey<TooltipState>();

  bool isAdvancedOptionClicked = false;
  bool _isMarketOrder = false;
  bool _isQtyToAmount = false;
  bool _isLotToQty = true;
  bool _isGTTLotToQty = true;
  bool _isStoplossOrder = false;
  bool _afterMarketOrder = false;
  bool _savedAfterMarketOrder = false; // Stores AMO state when switching to CO-BO
  bool _wasInCOBOMode = false; // Tracks if previous order type was CO-BO
  bool _addValidityAndDisclosedQty = false;
  bool _isCoverOrderEnabled = true;
  bool _isBracketOrderEnabled = false;
  bool _isMTFEnabled = false;
  // bool _GTTPriceTypeIsMarket = false;
  // bool _GTTOCOPriceTypeIsMarket = false;

  bool _hasValidCircuitBreakerValues = false;
  bool _isMarketClosed = false;

  @override
  void initState() {
    // Clear stale GTT/OCO state from any previous order session so the
    // trigger price, qty, and price fields don't carry over old values.
    ref.read(ordInputProvider).clearTextField();

    ref.read(fundProvider).fetchFunds(context);
    _stockExchangesList = ref.read(marketWatchProvider).equls ?? [];

    userOrderPreference = ref.read(authProvider).savedOrderPreference;
    if (userOrderPreference.isNotEmpty && !widget.orderArg.isModify) {
      isUserOrderPreferenceAvailable = true;
    }

    tik = double.tryParse(widget.scripInfo.ti.toString())?? 0.00;
    bool checkRawValue = widget.orderArg.raw.isNotEmpty;
    Map orderRawValue = widget.orderArg.raw;
    bool prdcheck = widget.orderArg.prd?.isNotEmpty ?? false;

    _isStock = widget.scripInfo.exch == "NSE" || widget.scripInfo.exch == "BSE";
    if(_isStock){
      // Check if equls list matches the current symbol (by checking if any token matches)
      final bool equlsMatchesCurrentSymbol = _stockExchangesList.isNotEmpty &&
          _stockExchangesList.any((eq) => eq.token == widget.scripInfo.token);

      if (equlsMatchesCurrentSymbol) {
        // Use equls list for exchange switching (NSE/BSE toggle)
        final matchingExchange = _stockExchangesList.firstWhere(
          (exchange) => exchange.exch == widget.scripInfo.exch,
          orElse: () => _stockExchangesList[0],
        );
        stockExchangeSelected = matchingExchange;
      } else {
        // equls has stale data - create a temporary entry from widget data
        stockExchangeSelected = Equls(
          exch: widget.scripInfo.exch,
          token: widget.scripInfo.token,
          tsym: widget.orderArg.tSym,
        );
        // Clear stale list to avoid showing wrong exchange options
        _stockExchangesList = [];
      }

      // Always use widget data for selectedStockSubscribe to ensure correct values
      selectedStockSubscribe.exchange = widget.scripInfo.exch ?? "";
      selectedStockSubscribe.token = widget.scripInfo.token ?? "";
      selectedStockSubscribe.tSym = widget.orderArg.tSym;
      selectedStockSubscribe.ltp = widget.orderArg.ltp ?? "";
      selectedStockSubscribe.perChange = widget.orderArg.perChange ?? "";

      // Subscribe to websocket for initial stock exchange
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _subscribeSelectedStock(context);
      });
    }

    orderType = prdcheck // ① honour prd
        ? {"C": "Delivery", "I": "Intraday", "F": "MTF"}[widget.orderArg.prd] ??
            "Delivery"
        : checkRawValue // ② old logic
            ? {
                  "B": "CO - BO",
                  "H": "CO - BO",
                  "I": "Intraday",
                  "F": "MTF"
                }[orderRawValue['prd']] ??
                "Delivery"
            : isUserOrderPreferenceAvailable
                ? (["Delivery", "Intraday", "MTF", "CO - BO"]
                        .contains(userOrderPreference['prd'])
                    ? userOrderPreference['prd']
                    : "Delivery")
                : "Delivery";

    orderTypes = [
      {"type": "Delivery"},
      {"type": "Intraday"}
    ];

    if (widget.isBasket != "Basket" &&
        widget.isBasket != "BasketEdit" &&
        widget.isBasket != "BasketMode") {
      if (widget.scripInfo.exch == "NSE" || widget.scripInfo.exch == "BSE") {
        // if (widget.scripInfo.instname == "EQ") {
        orderTypes.add({"type": "MTF"});
        // }
        if (ref.read(userProfileProvider).userDetailModel != null &&
            ref.read(userProfileProvider).userDetailModel!.stat == "Ok") {
          for (var element
              in ref.read(userProfileProvider).userDetailModel!.prarr!) {
            if (element.sPrdtAli == "MTF") {
              // orderTypes.add({"type": "MTF"});
              _isMTFEnabled = true;
            }
          }
        }
      }

      // SIP is now handled via dedicated SIP creation dialog
      // if (widget.scripInfo.instname == "EQ") {
      //   orderTypes.add({
      //     "type": "SIP",
      //     "key": ref.read(showcaseProvide).sip,
      //     "case": "Click here to view SIP order details."
      //   });
      // }
    }
    orderTypes.add({"type": "CO - BO"});

    if (widget.isBasket != "Basket" &&
        widget.isBasket != "BasketEdit" &&
        widget.isBasket != "BasketMode") {
      if (widget.scripInfo.instname != "UNDIND" &&
          widget.scripInfo.instname != "COM") {
        orderTypes.add({
          "type": "GTT",
          "key": ref.read(showcaseProvide).orderscreenBracketcase,
          "case": "Click here to view GTT order details."
        });
      }
    }
    // print("object ${res['prctyp']} ${res['prctyp'] == "SL-LMT"} ${priceType}");

    priceType = widget.orderArg.isExit &&
            ["Limit", "Market"].contains(userOrderPreference['expos'])
        ? (userOrderPreference['expos'] ?? 'Limit')
        : checkRawValue
            ? {
                  "MKT": "Market",
                  "SL-LMT": "SL Limit",
                  "SL-MKT": "SL MKT"
                }[orderRawValue['prctyp'] ?? orderRawValue['prctype']] ??
                "Limit"
            : isUserOrderPreferenceAvailable
                ? (["Limit", "Market"].contains(userOrderPreference['prc'])
                    ? (userOrderPreference['prc'] ?? 'Limit')
                    : (userOrderPreference['prc'] == "SL MKT" &&
                            (orderType != "Delivery" &&
                                orderType != "Intraday"))
                        ? 'Limit'
                        : (userOrderPreference['prc'] ?? 'Limit'))
                : 'Limit';

    _isMarketOrder = ["Market", "SL MKT"].contains(priceType);
    _isStoplossOrder =
        isAdvancedOptionClicked = ["SL Limit", "SL MKT"].contains(priceType);

    priceTypes = [
      {
        "type": "Limit",
        "key": ref.read(showcaseProvide).limitprctype,
        "case": "Click here to set your order type to Limit."
      },
      {
        "type": "Market",
        "key": ref.read(showcaseProvide).marketprctype,
        "case": "Click here to set your order type to Market."
      },
      {
        "type": "SL Limit",
        "key": ref.read(showcaseProvide).sllimitprctype,
        "case": "Click here to set your order type to SL Limit."
      },
      {
        "type": "SL MKT",
        "key": ref.read(showcaseProvide).sllimktprctype,
        "case": "Click here to set your order type to SL MKT."
      },
    ];

    // bool prdcheck = widget.orderArg.prd?.isNotEmpty ?? false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invesType = prdcheck
          ? {
                "C": InvestType.delivery,
                "I": InvestType.intraday,
                "M": InvestType.carryForward,
                "F": InvestType.mtf
              }[widget.orderArg.prd] ??
              InvestType.carryForward
          : checkRawValue && widget.isBasket == "BasketEdit"
              ? {
                    "C": InvestType.delivery,
                    "I": InvestType.intraday,
                    "M": InvestType.carryForward,
                    "F": InvestType.mtf
                  }[orderRawValue['prd']] ??
                  InvestType.delivery
              : checkRawValue
                  ? {
                        "C": InvestType.delivery,
                        "I": InvestType.intraday,
                        "F": InvestType.mtf
                      }[orderRawValue['prd']] ??
                      InvestType.carryForward
                  : !widget.orderArg.isExit && isUserOrderPreferenceAvailable
                      ? userOrderPreference['prd'] == "Intraday"
                          ? InvestType.intraday
                          : (userOrderPreference['prd'] == "Delivery" &&
                                  widget.scripInfo.seg == "EQT")
                              ? InvestType.delivery
                              : InvestType.carryForward
                      : widget.scripInfo.seg == "EQT"
                          ? InvestType.delivery
                          : InvestType.carryForward;

      ref.read(ordInputProvider).chngInvesType(invesType, "PlcOrder");

      ref
          .read(ordInputProvider)
          .chngPriceType(priceType, widget.orderArg.exchange);
      _debouncedMarginUpdate();
      if (orderType != "Delivery" &&
          orderType != "Intraday" &&
          orderType != "MTF") {
        ref.read(ordInputProvider).chngOrderType(
            orderType, _isCoverOrderEnabled, _isBracketOrderEnabled);
      }
    });

    setState(() {
      formattedDate = DateFormat('dd-MM-yyyy').format(now);
      // if (widget.scripInfo.exch != "NSE" && widget.scripInfo.exch != "BSE") {
      //   orderTypes.remove("SIP");
      // }
      int sfq = int.tryParse(widget.scripInfo.frzqty?.toString() ?? '1') ?? 1;

      validityType = isUserOrderPreferenceAvailable &&
              userOrderPreference['validity'] == 'IOC'
          ? 'IOC'
          : widget.orderArg.exchange == "BSE" ||
                  widget.orderArg.exchange == "BFO"
              ? "EOS"
              : "DAY";

      _addValidityAndDisclosedQty = isUserOrderPreferenceAvailable &&
              userOrderPreference['validity'] == 'IOC'
          ? true
          : false;
      isAdvancedOptionClicked = !isAdvancedOptionClicked
          ? _addValidityAndDisclosedQty
          : isAdvancedOptionClicked;

      lotSize = SafeParse.toInt(widget.scripInfo.ls);

      frezQty = sfq > 1
          ? widget.orderArg.exchange == "MCX"
              ? ((sfq / lotSize).floor() < 1 ? 1 : (sfq / lotSize).floor())
              : (sfq / lotSize).floor() * lotSize
          : lotSize;
      // 999999 1353220
      isBuy = widget.orderArg.transType;
      sipqtyctrl = TextEditingController(text: "1");

      qtyCtrl = TextEditingController(
          text: widget.orderArg.exchange == "MCX"
              ? widget.orderArg.isExit
                  ? widget.orderArg.lotSize!.replaceAll("-", "")
                  : "1"
              : widget.orderArg.isExit
                  ? widget.orderArg.holdQty!.replaceAll("-", "")
                  : widget.orderArg.lotSize!.replaceAll("-", ""));

      if (widget.orderArg.isExit && widget.orderArg.exchange == "MCX") {
        qtyCtrl.text = ((int.tryParse(qtyCtrl.text)?? 0) ~/ lotSize).toString();
      } else if (!widget.orderArg.isExit && isUserOrderPreferenceAvailable) {
        qtyCtrl.text =
            (SafeParse.toInt(qtyCtrl.text) * SafeParse.toInt(userOrderPreference['qty']))
                .toString();
      }

      multiplayer = SafeParse.toInt(widget.orderArg.exchange == "MCX"
              ? "1"
              : widget.orderArg.isExit
                  ? widget.scripInfo.ls
                  : widget.orderArg.lotSize);

      mktProtCtrl = TextEditingController(
          text: isUserOrderPreferenceAvailable
              ? userOrderPreference['mrkprot']
              : "5");
      discQtyCtrl = TextEditingController(text: "0");

      // Try websocket data first, then fallback to orderArg.ltp
      double currentLTP = 0.0;
      if (ref.read(websocketProvider).socketDatas.containsKey(widget.scripInfo.token)) {
        currentLTP = SafeParse.toDouble("${ref.read(websocketProvider).socketDatas["${widget.scripInfo.token}"]['lp']}");
      }
      if (currentLTP <= 0) {
        currentLTP = SafeParse.toDouble(widget.orderArg.ltp);
      }
      ordPrice = currentLTP > 0 ? currentLTP.toString() : "0.00";
      priceCtrl.text = priceType == "Market" || priceType == "SL MKT" ? "Market" : ordPrice;
    });

    final quote = widget.scripInfo.ordMsg;

    if (widget.isBasket == "Basket" ||
        widget.isBasket == "BasketEdit" ||
        widget.isBasket == "BasketMode" ||
        quote == null) {
      // isAvbSecu = false;
      isSecu = true;
    } else {
      quotemsg = quote;
      // isAvbSecu = true;
      isSecu = false;
    }
    // addStoploss = orderType != "Delivery" && orderType != "Intraday" ? true : false;

    if (checkRawValue) {
      isBuy = orderRawValue['trantype'] == 'S' ? false : true;
      //   addStoploss = (res['prd'] == "B" || res['prd'] == "H") ? true : false;
      _addValidityAndDisclosedQty =
          orderRawValue['ret']?.toUpperCase() == 'IOC' ||
                  (orderRawValue['dscqty'] != null &&
                      SafeParse.toInt(orderRawValue['dscqty']) > 0)
              ? true
              : false;

      if (orderRawValue['amo'] == "Yes") {
          isAdvancedOptionClicked = true;
          _afterMarketOrder = true;
        }else{
           _afterMarketOrder = false;
        }
      // Use orderRawValue price if available and not "0", otherwise fallback to LTP
      final rawPrice = orderRawValue['prc'];
      String fallbackPrice;
      if (SafeParse.toDouble(rawPrice) <= 0) {
        // Fallback to LTP, but sanitize it too
        final ltpValue = widget.orderArg.ltp;
        fallbackPrice = SafeParse.toDouble(ltpValue) > 0 ? ltpValue! : "0.00";
      } else {
        fallbackPrice = rawPrice;
      }

      priceCtrl.text = priceType == "Market" || priceType == "SL MKT"
          ? "Market"
          : fallbackPrice;
      ordPrice = priceType == "Market" || priceType == "SL MKT"
          ? ordPrice
          : fallbackPrice;
      qtyCtrl.text = widget.scripInfo.exch == 'MCX'
          ? (SafeParse.toInt(orderRawValue['qty'], defaultValue: lotSize) / lotSize)
              .toStringAsFixed(0)
          : orderRawValue['qty'] ?? "1";

      stopLossCtrl.text = orderRawValue['blprc'] ?? "0";
      targetCtrl.text = orderRawValue['bpprc'] ?? "0";
      trailingTicksCtrl.text = orderRawValue['trailprc'] ?? "";
      validityType = orderRawValue['ret'] ?? '';
      triggerPriceCtrl.text = orderRawValue['trgprc'] ?? "0";
      mktProtCtrl.text =
          (double.tryParse(orderRawValue['mkt_protection']?.toString() ?? '5')
                      ?.toInt() ??
                  5)
              .toString();

      // **FIX FOR BASKET EDIT**: Auto-expand advanced section and set states based on order data
      if (widget.isBasket == "BasketEdit") {
        final rawPrctyp = orderRawValue['prctyp'] ?? orderRawValue['prctype'];
        // Auto-expand advanced section for stop-loss orders
        if (["SL-LMT", "SL-MKT"].contains(rawPrctyp)) {
          _isStoplossOrder = true;
          isAdvancedOptionClicked = true;
        }

        // Set market order state
        _isMarketOrder = ["MKT", "SL-MKT"].contains(rawPrctyp);

        // Auto-expand for IOC validity or disclosed quantity
        if (orderRawValue['ret']?.toUpperCase() == 'IOC' ||
            (orderRawValue['dscqty'] != null &&
                SafeParse.toInt(orderRawValue['dscqty']) > 0)) {
          isAdvancedOptionClicked = true;
          _addValidityAndDisclosedQty = true;
        }

        // Auto-expand for AMO orders
        if (orderRawValue['amo'] == "Yes") {
          isAdvancedOptionClicked = true;
          _afterMarketOrder = true;
        }

        // Set bracket order states for CO-BO orders based on product code
        if (orderType == "CO - BO") {
          // Differentiate between Cover Order (H) and Bracket Order (B)
          if (orderRawValue['prd'] == 'H') {
            // Cover Order - only Cover checkbox should be ticked
            _isCoverOrderEnabled = true;
            _isBracketOrderEnabled = false;
          } else if (orderRawValue['prd'] == 'B') {
            // Bracket Order - both Cover and Bracket checkboxes should be ticked
            _isCoverOrderEnabled = true;
            _isBracketOrderEnabled = true;
          } else {
            // Default fallback (for any other product codes)
            _isCoverOrderEnabled = true;
            _isBracketOrderEnabled = true;
          }

          // Auto-expand if bracket order has stop-loss or target values
          if ((orderRawValue['blprc'] != null &&
                  orderRawValue['blprc'] != "0") ||
              (orderRawValue['bpprc'] != null &&
                  orderRawValue['bpprc'] != "0")) {
            isAdvancedOptionClicked = true;
          }
        }
      }
    }

    // Initialize CO-BO specific flags when loaded from user preferences
    if (!checkRawValue && isUserOrderPreferenceAvailable && orderType == "CO - BO") {
      _addValidityAndDisclosedQty = false;
      _afterMarketOrder = false;
      _wasInCOBOMode = true;
      _isCoverOrderEnabled = true;
      _isBracketOrderEnabled = false;
    }

    // Initialize circuit breaker validation flag
    _hasValidCircuitBreakerValues = widget.scripInfo.lc != null &&
        widget.scripInfo.uc != null &&
        widget.scripInfo.lc != "0.00" &&
        widget.scripInfo.uc != "0.00" &&
        widget.scripInfo.lc!.isNotEmpty &&
        widget.scripInfo.uc!.isNotEmpty;

    // Check if market is closed and auto-enable AMO (except for CO-BO which doesn't support AMO)
    _isMarketClosed = _checkMarketClosed();
    if (_isMarketClosed && !checkRawValue && orderType != "CO - BO") {
      _afterMarketOrder = true;
      isAdvancedOptionClicked = true; // Auto-expand advanced section
    }

    ref.read(orderProvider).setDOrderloader(false);
    super.initState();
    anibuildctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          anibuildctrl.reset(); // Reset animation after shake
        }
      });

    // _shakeAnimation = Tween<double>(begin: 0, end: 8).animate(
    //   CurvedAnimation(parent: anibuildctrl, curve: Curves.elasticIn),
    // );
  }

  /// Shows a warning message with debounce to avoid aggressive popups while typing
  void _showDebouncedWarning(String message, {int delayMs = 800}) {
    _warningDebounceTimer?.cancel();
    _warningDebounceTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) {
        ResponsiveSnackBar.showWarning(context, message);
      }
    });
  }

  /// Cancels any pending warning - call this when input becomes valid
  void _cancelPendingWarning() {
    _warningDebounceTimer?.cancel();
  }

  @override
  void dispose() {
    _warningDebounceTimer?.cancel();
    _marginUpdateDebounceTimer?.cancel();
    anibuildctrl.dispose();
    super.dispose();
  }

  // Check if market is closed based on exchange and current time
  bool _checkMarketClosed() {
    // Always use IST timezone since Indian markets operate in IST
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final currentTime = TimeOfDay.fromDateTime(now);
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    final exchange = widget.scripInfo.exch;

    // MCX closes at 11:30 PM
    if (exchange == "MCX" || exchange == "NCOM") {
      const mcxCloseTime = 23 * 60 + 50; // 23:50 (11:50 PM)
      return currentMinutes >= mcxCloseTime;
    }

    // All other exchanges (NSE, BSE, NFO, BFO, etc.) close at 4:00 PM
    const marketCloseTime = 16 * 60; // 16:00 (4:00 PM)
    return currentMinutes >= marketCloseTime;
  }

  void _subscribeSelectedStock(BuildContext context) {
    if ((stockExchangeSelected.token?.isNotEmpty ?? false) && (stockExchangeSelected.exch?.isNotEmpty ?? false)) {
      ref.read(websocketProvider).establishConnection(
          channelInput: '${stockExchangeSelected.exch}|${stockExchangeSelected.token}',
          task: 't',
          context: context);
    }
  }

  void openFunds(String pageis, BuildContext context) {
    if (WebNavigationHelper.isAvailable) {
      WebNavigationHelper.navigateTo(Routes.fundscreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Allows back navigation
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // If system handled back, do nothing

        ref.read(ordInputProvider).clearTextField();
        await ref
            .read(marketWatchProvider)
            .requestMWScrip(context: context, isSubscribe: true);

        // If coming from chart, restore the chart overlay
        if (widget.fromChart) {
          final chartState = ref.read(chartProvider);
          if (chartState.chartArgs != null) {
            ref
                .read(chartProvider.notifier)
                .showChart(chartState.chartArgs!, previousRoute: null);
          }
        }
        // Try to close via dialog callback if available (for overlay dialogs)
        final closeNotifier = _PlaceOrderDialogCloseNotifier.of(context);
        if (closeNotifier != null) {
          closeNotifier.onClose();
        } else {
          // Fallback to regular navigation
          final navigator = Navigator.of(context, rootNavigator: true);
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            Navigator.pop(context);
          }
        }
      },
      child: Consumer(
        builder: (context, WidgetRef ref, _) {
          final orderProvide = ref.watch(orderProvider);
          final orderInput = ref.watch(ordInputProvider);
          final internet = ref.watch(networkStateProvider);
          final theme = ref.read(themeProvider);
          final trancation = ref.watch(transcationProvider);
          final clientFundDetail = ref.watch(fundProvider).fundDetailModel;

          final sip = ref.watch(siprovider);
          int frezQtyOrderSliceMaxLimit =
              ref.read(orderProvider).frezQtyOrderSliceMaxLimit;

          // Watch equls so NSE/BSE toggle updates when linked scrips load
          final latestEquls = ref.watch(marketWatchProvider).equls ?? [];
          if (_isStock && _stockExchangesList.isEmpty && latestEquls.isNotEmpty &&
              latestEquls.any((eq) => eq.token == widget.scripInfo.token)) {
            _stockExchangesList = latestEquls;
            final matchingExchange = _stockExchangesList.firstWhere(
              (exchange) => exchange.exch == widget.scripInfo.exch,
              orElse: () => _stockExchangesList[0],
            );
            stockExchangeSelected = matchingExchange;
          }

          if (internet.connectionStatus == ConnectivityResult.none) {
            return const NoInternetWidget();
          }

          return Stack(
            children: [
              GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Container(
                    color: resolveThemeColor(context,
                        dark: MyntColors.backgroundColorDark,
                        light: MyntColors.backgroundColor),
                    width: double.infinity,
                    child:

                        //  Scaffold(
                        //     resizeToAvoidBottomInset: true,
                        // appBar: AppBar(
                        //     // leadingWidth: 41,
                        //     centerTitle: false,
                        //     titleSpacing: 0,
                        //     // leading: Material(
                        //     //   color: Colors.transparent,
                        //     //   shape: const CircleBorder(),
                        //     //   clipBehavior: Clip.hardEdge,
                        //     //   child: Semantics(
                        //     //     identifier: "Back button",
                        //     //     child: IconButton(
                        //     //       // customBorder: const CircleBorder(),
                        //     //       splashColor: theme.isDarkMode ? colors.splashColorDark : colors.splashColorLight,
                        //     //       highlightColor: theme.isDarkMode ? colors.highlightDark : colors.highlightLight,
                        //     //       onPressed: () {
                        //     //       ref.read(ordInputProvider).clearTextField();

                        //     //         // If coming from chart, restore the chart overlay
                        //     //         if (widget.fromChart) {
                        //     //           final chartState = ref.read(chartProvider);
                        //     //           if (chartState.chartArgs != null) {
                        //     //             ref.read(chartProvider.notifier).showChart(chartState.chartArgs!, previousRoute: null);
                        //     //           }
                        //     //         }

                        //     //       Navigator.pop(context);
                        //     //     },
                        //     //       icon: Container(
                        //     //       width: 44, // Increased touch area
                        //     //       height: 44,
                        //     //       alignment: Alignment.center,
                        //     //       child: Icon(
                        //     //         Icons.arrow_back_ios_outlined,
                        //     //         size: 18,
                        //     //           color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
                        //     //         ),
                        //     //       ),
                        //     //     ),
                        //     //   ),
                        //     // ),
                        //     elevation: .4,
                        //     title: Container(
                        //       margin: const EdgeInsets.only(right: 10),
                        //       child:
                        //     ),
                        //     // Tab section starts here
                        //     bottom: PreferredSize(
                        //         preferredSize: const Size.fromHeight(50), // widget.orderArg.exchange == "NCOM" ? 10 :
                        //         child:
                        //  body:
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Column(children: [
                            Builder(
                              builder: (context) {
                                final dragNotifier =
                                    _PlaceOrderDialogDragNotifier.of(context);
                                final closeNotifier =
                                    _PlaceOrderDialogCloseNotifier.of(context);

                                Widget headerContent = Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: resolveThemeColor(context, dark: MyntColors.cardDark, light: const Color(0xfffafbff)),
                                    // (isBuy ?? true)
                                    //     ? resolveThemeColor(context,
                                    //             dark: MyntColors.primary,
                                    //             light: MyntColors.primary)
                                    //         .withOpacity(0.1)
                                    //     : resolveThemeColor(context,
                                    //             dark: MyntColors.tertiary,
                                    //             light: MyntColors.tertiary)
                                    //         .withOpacity(0.1),
                                    // border: Border(
                                    //   bottom: BorderSide(
                                    //     color: resolveThemeColor(context,
                                    //         dark: MyntColors.divider,
                                    //         light: MyntColors.divider,),
                                    //         width: 0
                                    //   ),
                                    // ),
                                  ),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 4.0),
                                              child: Row(children: [
                                                Text(
                                                  "${widget.scripInfo.symbol!.replaceAll("-EQ", "")} ",
                                                  style: WebTextStyles.title(
                                                    isDarkTheme:
                                                        theme.isDarkMode,
                                                    color: resolveThemeColor(context,
                                                        dark:
                                                            MyntColors.textPrimaryDark,
                                                        light: MyntColors.textPrimary),
                                                    fontWeight: WebFonts.medium,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),

                                                // Text(
                                                //     "${widget.scripInfo.symbol!.replaceAll("-EQ", "")} ",
                                                //     style: textStyle(
                                                //         theme.isDarkMode
                                                //             ? colors.colorWhite
                                                //             : colors.colorBlack,
                                                //         14,
                                                //         FontWeight.w400),
                                                //     overflow: TextOverflow.ellipsis,
                                                //     maxLines: 1),
                                                if (widget.scripInfo.expDate!
                                                    .isNotEmpty)
                                                  Text(
                                                    " ${widget.scripInfo.expDate} ",
                                                    style: WebTextStyles.title(
                                                      isDarkTheme:
                                                          theme.isDarkMode,
                                                      color: resolveThemeColor(
                                                          context,
                                                          dark: MyntColors
                                                              .textPrimaryDark,
                                                          light: MyntColors
                                                              .textPrimary),
                                                      fontWeight:
                                                          WebFonts.medium,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),

                                                // Text(" ${widget.scripInfo.expDate} ",
                                                //     style: textStyle(
                                                //         theme.isDarkMode
                                                //             ? colors.colorWhite
                                                //             : colors.colorBlack,
                                                //         14,
                                                //         FontWeight.w400)),
                                                if (widget.scripInfo.option!
                                                    .isNotEmpty)
                                                  Text(
                                                    widget.scripInfo.option!,
                                                    style: WebTextStyles.sub(
                                                      isDarkTheme:
                                                          theme.isDarkMode,
                                                      color: resolveThemeColor(
                                                          context,
                                                          dark: MyntColors
                                                              .textPrimaryDark,
                                                          light: MyntColors
                                                              .textPrimary),
                                                      fontWeight:
                                                          WebFonts.medium,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),

                                                // Text(widget.scripInfo.option!,
                                                //     style: textStyle(
                                                //         theme.isDarkMode
                                                //             ? colors.colorWhite
                                                //             : colors.colorBlack,
                                                //         14,
                                                //         FontWeight.w400),
                                                //     overflow: TextOverflow.ellipsis,
                                                //     maxLines: 1),
                                                // CustomExchBadge(
                                                //     exch: " ${widget.scripInfo.exch}"),
                                                if (_isStock && _stockExchangesList.isNotEmpty && (orderType == "Delivery" || orderType == "Intraday" || orderType == "CO - BO")) ...[
                                              const SizedBox(width: 4),
                                              SizedBox(
                                                width: 100,
                                                height: 30,
                                                child: Row(
                                                  children: List.generate(
                                                    _stockExchangesList.length,
                                                    (index) {
                                                      final isSelected = stockExchangeSelected.exch == _stockExchangesList[index].exch;
                                                      return Padding(
                                                        padding: const EdgeInsets.only(right: 6),
                                                        child: MouseRegion(
                                                          cursor: SystemMouseCursors.click,
                                                          child: InkWell(
                                                            onTap: () {
                                                              setState(() {
                                                                stockExchangeSelected = _stockExchangesList[index];
                                                                selectedStockSubscribe.exchange = stockExchangeSelected.exch ?? "";
                                                                selectedStockSubscribe.token = stockExchangeSelected.token ?? "";
                                                                selectedStockSubscribe.tSym = stockExchangeSelected.tsym ?? "";
                                                                // Reset LTP and perChange to allow fresh websocket data
                                                                selectedStockSubscribe.ltp = "";
                                                                selectedStockSubscribe.perChange = "";
                                                                widget.scripInfo.exch = stockExchangeSelected.exch ?? "";
                                                                widget.scripInfo.token = stockExchangeSelected.token ?? "";
                                                                widget.scripInfo.tsym = stockExchangeSelected.tsym ?? "";
                                                                _subscribeSelectedStock(context);
                                                              });
                                                              _debouncedMarginUpdate();
                                                            },
                                                            borderRadius: BorderRadius.circular(4),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: isSelected
                                                                    ? (theme.isDarkMode ? MyntColors.secondary : MyntColors.primary)
                                                                    : (theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8)),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                _stockExchangesList[index].exch ?? "",
                                                                style: WebTextStyles.para(
                                                                  isDarkTheme: theme.isDarkMode,
                                                                  color: isSelected
                                                                      ? Colors.white
                                                                      : (resolveThemeColor(context, dark: colors.textPrimaryDark, light: colors.textPrimaryLight)),
                                                                  fontWeight: isSelected ? WebFonts.medium : WebFonts.regular,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              ]else...[
                                                Text(
                                                  " ${stockExchangeSelected.exch ?? widget.scripInfo.exch}",
                                                  style: WebTextStyles.para(
                                                    isDarkTheme:
                                                        theme.isDarkMode,
                                                    color: resolveThemeColor(context,
                                                        dark:
                                                            MyntColors.textPrimaryDark,
                                                        light: MyntColors.textPrimary),
                                                    fontWeight: WebFonts.medium,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                            ],
                                              ]),
                                            ),
                                            Row(
                                              children: [
                                                OrderScreenHeaderWeb(
                                                  headerData: stockExchangeSelected.exch == null ? widget.orderArg : selectedStockSubscribe,
                                                ),
                                              ],
                                            ),
                                            
                                          ],
                                        ),
                                           // NSE/BSE Exchange Switch
                                            
                                        // const SizedBox(width: 12),
                                        // Buy/Sell Toggle
                                        Row(
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Green "B" Button
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        isBuy = true;
                                                        // Reset OCO when switching to BUY for EQT
                                                        if (widget.scripInfo.seg ==
                                                                "EQT" &&
                                                            isOco) {
                                                          isOco = false;
                                                          orderInput
                                                              .disableCondGTT(false);
                                                          orderInput.clearOcoFields();
                                                        }
                                                      });
                                                      _debouncedMarginUpdate();
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(5),
                                                    child: Container(
                                                      width: 20,
                                                      height: 20,
                                                      decoration: BoxDecoration(
                                                        color: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                5),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          'B',
                                                          style: WebTextStyles
                                                              .para(
                                                            isDarkTheme:
                                                                theme.isDarkMode,
                                                            color: Colors.white,
                                                            fontWeight:
                                                                WebFonts.medium,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Toggle Switch
                                                MouseRegion(
                                                  cursor: SystemMouseCursors.click,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        isBuy = !(isBuy ?? true);
                                                        // Reset OCO when switching to BUY for EQT
                                                        if (isBuy! &&
                                                            widget.scripInfo.seg ==
                                                                "EQT" &&
                                                            isOco) {
                                                          isOco = false;
                                                          orderInput
                                                              .disableCondGTT(false);
                                                          orderInput.clearOcoFields();
                                                        }
                                                      });
                                                      _debouncedMarginUpdate();
                                                    },
                                                    child: Container(
                                                      width: 43,
                                                      height: 22,
                                                      decoration: BoxDecoration(
                                                        color: resolveThemeColor(
                                                            context,
                                                            dark: MyntColors
                                                                .backgroundColorDark,
                                                            light: MyntColors
                                                                .backgroundColor),
                                                        border: Border.all(color: isBuy! ? resolveThemeColor(
                                                                    context,
                                                                    dark: MyntColors
                                                                        .primaryDark,
                                                                    light: MyntColors
                                                                        .primary) : resolveThemeColor(
                                                                    context,
                                                                    dark: MyntColors
                                                                        .errorDark,
                                                                    light: MyntColors
                                                                        .tertiary),),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                11),
                                                      ),
                                                      child: Stack(
                                                        children: [
                                                          AnimatedPositioned(
                                                            duration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        200),
                                                            curve: Curves.easeInOut,
                                                            left: (isBuy ?? true)
                                                                ? 2
                                                                : 24,
                                                            top: 2,
                                                            child: Container(
                                                              width: 16,
                                                              height: 16,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: isBuy! ? resolveThemeColor(
                                                                    context,
                                                                    dark: MyntColors
                                                                        .primaryDark,
                                                                    light: MyntColors
                                                                        .primary) : resolveThemeColor(
                                                                    context,
                                                                    dark: MyntColors
                                                                        .errorDark,
                                                                    light: MyntColors
                                                                        .tertiary),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Red "S" Button
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        isBuy = false;
                                                      });
                                                      _debouncedMarginUpdate();
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(5),
                                                    child: Container(
                                                      width: 20,
                                                      height: 20,
                                                      decoration: BoxDecoration(
                                                        color: resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.tertiary),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                5),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          'S',
                                                          style: WebTextStyles
                                                              .para(
                                                            isDarkTheme:
                                                                theme.isDarkMode,
                                                            color: Colors.white,
                                                            fontWeight:
                                                                WebFonts.medium,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
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
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(4.0),
                                                  child: Icon(
                                                    Icons.close,
                                                    color: resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary),
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
                            // Padding(
                            //   padding: const EdgeInsets.symmetric(
                            //       horizontal: 16, vertical: 8),
                            //   child: Row(
                            //       crossAxisAlignment: CrossAxisAlignment.end,
                            //       mainAxisAlignment: MainAxisAlignment.start,
                            //       children: [
                            //         // if (orderType == "Regular" ||
                            //         //     orderType == "Cover" ||
                            //         //     orderType == "Bracket" ||
                            //         //     orderType == "GTT") ...[
                            //         //   Row(children: [
                            //         //     InkWell(
                            //         //         onTap: () {
                            //         //           setState(() {
                            //         //             isBuy = true;
                            //         //           });
                            //         //         },
                            //         //         child:
                            //         //             SvgPicture.asset(assets.buyIcon)),
                            //         //     const SizedBox(width: 6),
                            //         //     CustomSwitch(
                            //         //         onChanged: (bool value) {
                            //         //           setState(() {
                            //         //             isBuy = value;
                            //         //           });
                            //         //           _debouncedMarginUpdate();
                            //         //         },
                            //         //         value: isBuy!),
                            //         //     const SizedBox(width: 6),
                            //         //     InkWell(
                            //         //         onTap: () {
                            //         //           setState(() {
                            //         //             isBuy = false;
                            //         //           });
                            //         //         },
                            //         //         child:
                            //         //             SvgPicture.asset(assets.sellIcon))
                            //         //   ])
                            //         // ]
                            //       ]),
                            // )
                          ]),

                          // if (widget.orderArg.exchange != "NCOM") ...[
                          Container(
                              height: 35,
                              padding: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.dividerDark,
                                        light: MyntColors.divider),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemBuilder: (context, index) {
                                    final isSelected =
                                        orderType == orderTypes[index]['type'];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              orderType =
                                                  orderTypes[index]['type'];
                                              updatePriceType();
                                              onOrderTypeChangeClearValues();
                                              // if (priceType == "SL MKT") {
                                              //   priceType = "Limit";
                                              // }

                                              // if (index == 2) {
                                              //   // index == 1
                                              //   addStoploss = true;
                                              // } else {
                                              //   addStoploss = false;
                                              // }
                                              if (orderType == "SIP") {
                                                sip.startdatemethod("0");
                                                sip.numberofSips.clear();
                                              }
                                            });

                                            if (orderTypes[index]['type'] ==
                                                "CO - BO") {
                                              orderInput.chngOrderType(
                                                  orderTypes[index]['type'],
                                                  _isCoverOrderEnabled,
                                                  _isBracketOrderEnabled);
                                            } else if (orderTypes[index]
                                                    ['type'] ==
                                                "Intraday") {
                                              orderInput.chngInvesType(
                                                  InvestType.intraday,
                                                  "PlcOrder");
                                            } else if (orderTypes[index]
                                                    ['type'] ==
                                                "MTF") {
                                              orderInput.chngInvesType(
                                                  InvestType.mtf, "PlcOrder");
                                            } else {
                                              // this condition works both for PlcOrder and GTT
                                              orderInput.chngInvesType(
                                                  widget.scripInfo.seg == "EQT"
                                                      ? InvestType.delivery
                                                      : InvestType.carryForward,
                                                  "PlcOrder");
                                              orderInput.chngInvesType(
                                                  widget.scripInfo.seg == "EQT"
                                                      ? InvestType.delivery
                                                      : InvestType.carryForward,
                                                  "OCO");
                                            }
                                            if (orderType != "GTT") {
                                              isOco = false;
                                              _isGTTLotToQty = true;
                                              ref.read(ordInputProvider).chngPriceType(
                                                  priceType, widget.scripInfo.exch ?? "");
                                              _debouncedMarginUpdate();
                                            } else {
                                              // Reset qty toggles so the GTT tab always opens in Qty mode
                                              _isQtyToAmount = false;
                                              _isGTTLotToQty = true;
                                              // ref.read(ordInputProvider)
                                              //     .chngInvesType(
                                              //         widget.scripInfo.seg == "EQT"
                                              //             ? InvestType.delivery
                                              //             : InvestType.carryForward,
                                              //         "GTT");
                                              if (orderInput.prcType == "MKT") {
                                                ref
                                                    .read(ordInputProvider)
                                                    .setGTTPriceTypeOrderIsMarket(true);
                                                ref
                                                    .read(ordInputProvider)
                                                    .chngGTTPriceType("Market");
                                                orderInput.priceCtrl.text = "Market";
                                              } else {
                                                ref
                                                    .read(ordInputProvider)
                                                    .setGTTPriceTypeOrderIsMarket(false);
                                                // MCX qty field accepts lot count; other exchanges accept the lot-size string.
                                                ref
                                                    .read(ordInputProvider)
                                                    .updatePrcCtrl(
                                                        "${widget.orderArg.ltp}",
                                                        widget.scripInfo.exch == "MCX"
                                                            ? "1"
                                                            : widget.orderArg.lotSize!
                                                                .replaceAll(
                                                                    "-", ""));
                                                ref
                                                    .read(ordInputProvider)
                                                    .chngGTTPriceType("Limit");
                                              }
                                              ref
                                                  .read(ordInputProvider)
                                                  .disableCondGTT(false);
                                            }
                                            if (priceType == "Market" ||
                                                priceType == "SL MKT") {
                                              priceCtrl.text = "Market";
                                            } else {
                                              priceCtrl.text =
                                                  "${widget.orderArg.ltp}";
                                              ordPrice = priceCtrl.text;
                                            }
                                            FocusScope.of(context).unfocus();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.only(
                                                left: 12, right: 12),
                                            decoration: BoxDecoration(
                                              color: resolveThemeColor(context,
                                                  dark: MyntColors
                                                      .backgroundColorDark,
                                                  light: MyntColors.backgroundColor),
                                              // isSelected
                                              //     ? (theme.isDarkMode
                                              //         ? MyntColors
                                              //             .backgroundTertiary
                                              //         : MyntColors
                                              //             .backgroundTertiary)
                                              //     : Colors.transparent,
                                              border: Border(bottom: BorderSide(
                                                color: isSelected
                                                    ? resolveThemeColor(context,
                                                        dark: MyntColors.primaryDark,
                                                        light: MyntColors.primary)
                                                    : Colors.transparent,
                                                width: isSelected ? 1.5 : 1,),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(0),
                                            ),
                                            child: Text(
                                              orderTypes[index]['type'],
                                              overflow: TextOverflow.ellipsis,
                                              style: WebTextStyles.tab(
                                                isDarkTheme: theme.isDarkMode,
                                                color: isSelected
                                                    ? resolveThemeColor(context,
                                                        dark: MyntColors
                                                            .primaryDark,
                                                        light:
                                                            MyntColors.primary)
                                                    : resolveThemeColor(context,
                                                        dark: MyntColors.textPrimaryDark,
                                                        light: MyntColors.textPrimary),
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  itemCount: orderTypes.length)),
                          // ]
                          const SizedBox(height: 10),
                          // AMO Alert Banner - shown when market is closed
                          if (_isMarketClosed && _afterMarketOrder && orderType != "CO - BO") ...[
                            Container(
                              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: MyntColors.primaryDark.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: resolveThemeColor(context, dark: MyntColors.primaryDark.withValues(alpha: 0.3), light: MyntColors.primary.withValues(alpha: 0.3)),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Market is closed. Orders will be placed as AMO (After Market Order).',
                                      style: WebTextStyles.para(
                                        isDarkTheme: theme.isDarkMode,
                                        color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
                                        fontWeight: WebFonts.regular,
                                      ),
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(children: [
                                if (orderType == "SIP") ...[
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 4),
                                            child: Row(children: [
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    headerTitleText(
                                                        "Frequency", theme),
                                                    const SizedBox(height: 5),
                                                    SizedBox(
                                                        height: 44,
                                                        child: DropdownButtonHideUnderline(
                                                            child: DropdownButton2(
                                                                dropdownStyleData: DropdownStyleData(maxHeight: 240, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: resolveThemeColor(context, dark: const Color.fromARGB(255, 18, 18, 18), light: colors.colorWhite))),
                                                                buttonStyleData: ButtonStyleData(height: 40, decoration: BoxDecoration(color: resolveThemeColor(context, dark: colors.darkGrey, light: const Color(0xffF1F3F8)), borderRadius: const BorderRadius.all(Radius.circular(32)))),
                                                                isExpanded: true,
                                                                style: textStyles.textFieldLabelStyle.copyWith(color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)),
                                                                items: sipDropdown.map((item) {
                                                                  return DropdownMenuItem(
                                                                    value: item,
                                                                    child: Text(
                                                                        item.toString()),
                                                                  );
                                                                }).toList(),
                                                                value: selectedValue,
                                                                onChanged: (newValue) {
                                                                  setState(() {
                                                                    selectedValue =
                                                                        newValue!
                                                                            .toString();

                                                                    FocusScope.of(
                                                                            context)
                                                                        .unfocus();
                                                                  });
                                                                })))
                                                  ])),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    headerTitleText(
                                                        "Qty", theme),
                                                    const SizedBox(height: 5),
                                                    SizedBox(
                                                      height: 44,
                                                      child: TextFormField(
                                                        textAlign:
                                                            TextAlign.center,
                                                        controller: sipqtyctrl,
                                                        style: theme.isDarkMode
                                                            ? textStyles
                                                                .textFieldLabelStyle
                                                                .copyWith(
                                                                color: colors
                                                                    .colorWhite)
                                                            : textStyles
                                                                .textFieldLabelStyle,
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        decoration: InputDecoration(
                                                            prefixIcon: Theme(
                                                                data: ThemeData(splashColor: Colors.transparent, splashFactory: NoSplash.splashFactory),
                                                                child: InkWell(
                                                                    // onLongPress: () {
                                                                    //   setState(
                                                                    //       () {
                                                                    //     if (sipqtyctrl
                                                                    //         .text
                                                                    //         .isNotEmpty) {
                                                                    //       if (int.parse(sipqtyctrl.text) >
                                                                    //           multiplayer) {
                                                                    //         sipqtyctrl.text = (int.parse(sipqtyctrl.text) - multiplayer).toString();
                                                                    //         double inputValue = double.tryParse(sipqtyctrl.text) ?? 0.00;
                                                                    //         double ltpsip = SafeParse.toDouble(widget.orderArg.ltp);
                                                                    //         resultsip = inputValue * ltpsip;
                                                                    //       }
                                                                    //     } else {
                                                                    //       sipqtyctrl.text =
                                                                    //           "$multiplayer";
                                                                    //     }
                                                                    //   });
                                                                    // },
                                                                    onTap: () {
                                                                      setState(
                                                                          () {
                                                                        // if () {
                                                                        int sipQty =
                                                                            int.tryParse(sipqtyctrl.text) ??
                                                                                multiplayer;
                                                                        //  if (sipQty ==
                                                                        //   multiplayer) {
                                                                        // sipqtyctrl.text = (sipQty).toString();
                                                                        //   }
                                                                        if (sipqtyctrl.text.isNotEmpty &&
                                                                            sipQty >
                                                                                multiplayer) {
                                                                          sipqtyctrl.text =
                                                                              (sipQty - multiplayer).toString();
                                                                          double
                                                                              ltpsip =
                                                                              SafeParse.toDouble(widget.orderArg.ltp);
                                                                          int inputValue =
                                                                              int.tryParse(sipqtyctrl.text) ?? 0;
                                                                          resultsip =
                                                                              inputValue * ltpsip;
                                                                          // }
                                                                        } else {
                                                                          sipqtyctrl.text =
                                                                              "$multiplayer";
                                                                        }
                                                                      });
                                                                    },
                                                                    child: SvgPicture.asset(theme.isDarkMode ? assets.darkCMinus : assets.minusIcon, fit: BoxFit.scaleDown))),
                                                            suffixIcon: Theme(
                                                                data: ThemeData(splashColor: Colors.transparent, splashFactory: NoSplash.splashFactory),
                                                                child: InkWell(
                                                                    // onLongPress: () {
                                                                    //   setState(
                                                                    //       () {
                                                                    //     if (sipqtyctrl
                                                                    //         .text
                                                                    //         .isNotEmpty) {
                                                                    //       sipqtyctrl.text =
                                                                    //           (int.parse(sipqtyctrl.text) + multiplayer).toString();
                                                                    //       double
                                                                    //           inputValue =
                                                                    //           double.tryParse(sipqtyctrl.text) ?? 0.00;
                                                                    //       double
                                                                    //           ltpsip =
                                                                    //           SafeParse.toDouble(widget.orderArg.ltp);
                                                                    //       resultsip =
                                                                    //           inputValue * ltpsip;
                                                                    //     } else {
                                                                    //       sipqtyctrl.text =
                                                                    //           "$multiplayer";
                                                                    //     }
                                                                    //   });
                                                                    // },
                                                                    onTap: () {
                                                                      setState(
                                                                          () {
                                                                        int sipQty =
                                                                            int.tryParse(sipqtyctrl.text) ??
                                                                                multiplayer;
                                                                        bool
                                                                            hasNoFreezeLimit =
                                                                            frezQty <=
                                                                                lotSize;
                                                                        bool
                                                                            withinLimit =
                                                                            hasNoFreezeLimit ||
                                                                                sipQty < frezQtyOrderSliceMaxLimit * frezQty;

                                                                        if (sipqtyctrl.text.isNotEmpty &&
                                                                            withinLimit) {
                                                                          sipqtyctrl.text =
                                                                              (sipQty + multiplayer).toString();
                                                                          double
                                                                              ltpsip =
                                                                              SafeParse.toDouble(widget.orderArg.ltp);
                                                                          int inputValue =
                                                                              int.tryParse(sipqtyctrl.text) ?? 0;
                                                                          resultsip =
                                                                              inputValue * ltpsip;
                                                                        } else if (!hasNoFreezeLimit) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Maximum Allowed Quantity $frezQty x $frezQtyOrderSliceMaxLimit = ${frezQtyOrderSliceMaxLimit * frezQty}");
                                                                          // sipqtyctrl.text =
                                                                          //     "$multiplayer";
                                                                        }
                                                                      });
                                                                    },
                                                                    child: SvgPicture.asset(theme.isDarkMode ? assets.darkAdd : assets.addIcon, fit: BoxFit.scaleDown))),
                                                            fillColor: theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8),
                                                            filled: true,
                                                            enabledBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(30)),
                                                            disabledBorder: InputBorder.none,
                                                            focusedBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(30)),
                                                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                                            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(30))),
                                                        onTap: () {},
                                                        onChanged: (value) {
                                                          if (value.isEmpty ||
                                                              value == "0") {
                                                            _showDebouncedWarning(
                                                                "The minimum quantity of this stock is one.");
                                                          } else {
                                                            _cancelPendingWarning();
                                                            setState(() {
                                                              int inputValue =
                                                                  int.tryParse(
                                                                          value) ??
                                                                      0;

                                                              double ltpsip =
                                                                  SafeParse.toDouble(widget.orderArg.ltp);
                                                              resultsip =
                                                                  inputValue *
                                                                      ltpsip;
                                                              sipLtpctrl.text =
                                                                  resultsip
                                                                      .toStringAsFixed(
                                                                          2);
                                                            });
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ]))
                                            ])),
                                        const SizedBox(height: 10),
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 4),
                                            child: Row(children: [
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    headerTitleText(
                                                        "Start Date", theme),
                                                    const SizedBox(height: 5),
                                                    SizedBox(
                                                        height: 44,
                                                        child: TextFormField(
                                                            controller:
                                                                sip.datefield,
                                                            style: theme.isDarkMode
                                                                ? textStyles
                                                                    .textFieldLabelStyle
                                                                    .copyWith(
                                                                    color: colors
                                                                        .colorWhite)
                                                                : textStyles
                                                                    .textFieldLabelStyle,
                                                            decoration: InputDecoration(
                                                                fillColor: theme
                                                                        .isDarkMode
                                                                    ? colors
                                                                        .darkGrey
                                                                    : const Color(
                                                                        0xffF1F3F8),
                                                                filled: true,
                                                                enabledBorder: OutlineInputBorder(
                                                                    borderSide:
                                                                        BorderSide
                                                                            .none,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            30)),
                                                                disabledBorder:
                                                                    InputBorder
                                                                        .none,
                                                                focusedBorder:
                                                                    OutlineInputBorder(
                                                                        borderSide: BorderSide.none,
                                                                        borderRadius: BorderRadius.circular(30)),
                                                                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                                                border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(30))),
                                                            readOnly: true,
                                                            onTap: () {
                                                              sip.providedate(
                                                                  context,
                                                                  theme,
                                                                  "2");
                                                            },
                                                            onChanged: (value) {
                                                              sip.providedate(
                                                                  context,
                                                                  theme,
                                                                  "2");
                                                            }))
                                                  ])),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    headerTitleText(
                                                        "Number of SIPs",
                                                        theme),
                                                    const SizedBox(height: 5),
                                                    SizedBox(
                                                        height: 44,
                                                        child: TextFormField(
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            controller: sip
                                                                .numberofSips,
                                                            style: theme.isDarkMode
                                                                ? textStyles.textFieldLabelStyle.copyWith(
                                                                    color: colors
                                                                        .colorWhite)
                                                                : textStyles
                                                                    .textFieldLabelStyle,
                                                            decoration: InputDecoration(
                                                                fillColor: theme.isDarkMode
                                                                    ? colors
                                                                        .darkGrey
                                                                    : const Color(
                                                                        0xffF1F3F8),
                                                                filled: true,
                                                                enabledBorder: OutlineInputBorder(
                                                                    borderSide:
                                                                        BorderSide
                                                                            .none,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            30)),
                                                                disabledBorder:
                                                                    InputBorder
                                                                        .none,
                                                                focusedBorder: OutlineInputBorder(
                                                                    borderSide: BorderSide.none,
                                                                    borderRadius: BorderRadius.circular(30)),
                                                                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                                                border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(30))),
                                                            onChanged: (value) {
                                                              int inputValue =
                                                                  int.tryParse(
                                                                          value) ??
                                                                      0;
                                                              if (value
                                                                      .isEmpty ||
                                                                  inputValue <
                                                                      1) {
                                                                _showDebouncedWarning(
                                                                    "The minimum number of this SIP is one.");
                                                              } else {
                                                                _cancelPendingWarning();
                                                              }
                                                              //  if (value.isEmpty) {
                                                              //   ScaffoldMessenger
                                                              //           .of(
                                                              //               context)
                                                              //       .showSnackBar(
                                                              //           ResponsiveSnackBar.showWarning(
                                                              //               context,
                                                              //               "The minimum number of this SIP is one."));
                                                              // }
                                                            }))
                                                  ]))
                                            ])),
                                        const SizedBox(height: 40),
                                        Center(
                                            child: Column(children: [
                                          Text(
                                            "₹${resultsip == 0.0 ? widget.orderArg.ltp : resultsip.toStringAsFixed(2)}",
                                            style: WebTextStyles.hero(
                                              isDarkTheme: theme.isDarkMode,
                                              color: MyntColors.profit,
                                              fontWeight: WebFonts.semiBold,
                                            ),
                                          ),
                                          Text("Installment Amount",
                                              style: WebTextStyles.titleMedium(
                                                isDarkTheme: theme.isDarkMode,
                                                color: theme.isDarkMode
                                                    ? MyntColors.textPrimary
                                                    : MyntColors.textPrimary,
                                                fontWeight: WebFonts.semiBold,
                                              ))
                                        ]))
                                      ])
                                ],
                                if (orderType == "GTT") ...[
                                  // GttCondition(
                                  //     isOco: false,
                                  //     isGtt: isGtt,
                                  //     isModify: widget.orderArg.isModify),

                                  // const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            headerTitleText(
                                                isOco
                                                    ? "Target Trigger Price"
                                                    : "Trigger Price",
                                                theme),
                                                // Text(" (in Rs)", style: WebTextStyles.para(isDarkTheme: theme.isDarkMode, color: resolveThemeColor(context,
                                                //                   dark: MyntColors.textPrimaryDark,
                                                //                   light: MyntColors.textPrimary))),
                                          ]),
                                          const SizedBox(height: 10),
                                          Focus(
                                            onKeyEvent: (node, event) => _handlePriceArrowKey(event, orderInput.val1Ctrl),
                                            child: SizedBox(
                                              height: 40,
                                              width: 200,
                                              child: Semantics(
                                                identifier:
                                                    'trigger_price_input',
                                                child: MyntTextField(
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .allow(RegExp(
                                                              r'^\d*\.?\d{0,2}$'))
                                                    ],
                                                    backgroundColor: theme.isDarkMode
                                                        ? colors.darkGrey
                                                        : const Color(
                                                            0xffF1F3F8),
                                                    onChanged: (value) {
                                                      double inputPrice =
                                                          double.tryParse(
                                                                  value) ??
                                                              0;

                                                      if (value.isNotEmpty &&
                                                          inputPrice > 0) {
                                                        final regex = RegExp(
                                                            r'^(\d+)?(\.\d{0,2})?$');
                                                        if (!regex
                                                            .hasMatch(value)) {
                                                          orderInput.val1Ctrl
                                                                  .text =
                                                              value.substring(
                                                                  0,
                                                                  value.length -
                                                                      1);
                                                          orderInput.val1Ctrl
                                                                  .selection =
                                                              TextSelection.collapsed(
                                                                  offset: orderInput
                                                                      .val1Ctrl
                                                                      .text
                                                                      .length);
                                                        }
                                                      }
                                                      if (value.isEmpty) {
                                                        _showDebouncedWarning(
                                                            "Target trigger price cannot be empty");
                                                      } else if (inputPrice <=
                                                          0) {
                                                        _showDebouncedWarning(
                                                            "Target trigger price cannot be 0");
                                                      } else {
                                                        _cancelPendingWarning();
                                                      }
                                                    },
                                                    placeholder:
                                                        "${widget.orderArg.ltp}",
                                                    placeholderStyle:
                                                        WebTextStyles.formInput(
                                                      isDarkTheme:
                                                          theme.isDarkMode,
                                                      color: resolveThemeColor(
                                                              context,
                                                              dark: MyntColors
                                                                  .textSecondary,
                                                              light: MyntColors
                                                                  .textSecondary)
                                                          .withValues(alpha: 0.5),
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
                                                          ? MyntColors
                                                              .textPrimaryDark
                                                          : MyntColors
                                                              .textPrimary,
                                                    ),
                                                    controller:
                                                        orderInput.val1Ctrl,
                                                    textAlign: TextAlign.start),
                                              )),
                                          ),
                                        ]),
                                  ),

                                  // const SizedBox(height: 8),
                                  // // InvesTypeWidget(
                                  // //     scripInfo: widget.scripInfo, ordType: "GTT"),
                                  // const SizedBox(height: 8),
                                  // Padding(
                                  //     padding: const EdgeInsets.only(left: 16),
                                  //     child: headerTitleText("Price type", theme)),
                                  // const SizedBox(height: 10),
                                  // PriceTypeBtn(
                                  //     isOco: false,
                                  //     isGtt: isGtt,
                                  //     ltp: "${widget.orderArg.ltp}"),
                                  // const SizedBox(height: 3),
                                  // Divider(
                                  //     color: theme.isDarkMode
                                  //         ? colors.darkColorDivider
                                  //         : colors.colorDivider),

                                  const SizedBox(height: 16),
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
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  InkWell(
                                                    onTap: (widget.scripInfo.exch == "NFO" ||
                                                        widget.scripInfo.exch == "BFO" ||
                                                        _isStock) ? () {
                                                      setState(() {
                                                        if (_isStock) {
                                                          _isQtyToAmount = !_isQtyToAmount;
                                                          if (_isQtyToAmount) {
                                                            // Seed with live LTP for Amount mode
                                                            double seedLtp = SafeParse.toDouble(widget.orderArg.ltp);
                                                            final wsD = ref.read(websocketProvider).socketDatas[widget.scripInfo.token];
                                                            if (wsD != null) {
                                                              final wl = SafeParse.toDouble(wsD['lp']);
                                                              if (wl > 0) seedLtp = wl;
                                                            }
                                                            orderInput.qtyCtrl.text = seedLtp.ceil().toString();
                                                          } else {
                                                            orderInput.qtyCtrl.text = "1";
                                                          }
                                                        } else {
                                                          // NFO/BFO: Toggle between Lot and Qty
                                                          _isGTTLotToQty = !_isGTTLotToQty;
                                                          if (_isGTTLotToQty) {
                                                            int currentLot = int.tryParse(orderInput.qtyCtrl.text) ?? 1;
                                                            orderInput.qtyCtrl.text = (currentLot * lotSize).toString();
                                                          } else {
                                                            int currentQty = int.tryParse(orderInput.qtyCtrl.text) ?? lotSize;
                                                            orderInput.qtyCtrl.text = ((currentQty / lotSize).round()).toString();
                                                          }
                                                        }
                                                      });
                                                    } : () {},
                                                    child: Row(children: [
                                                      headerTitleText(
                                                        (_isStock)
                                                            ? (_isQtyToAmount ? "Amount" : "Qty")
                                                            : widget.scripInfo.exch == "MCX"
                                                                ? "Lot"
                                                                : (_isGTTLotToQty ? "Qty" : "Lot"),
                                                        theme),
                                                      const SizedBox(width: 16),
                                                      if (widget.scripInfo.exch == "NFO" ||
                                                          widget.scripInfo.exch == "BFO" ||
                                                          _isStock)
                                                        Padding(
                                                          padding: const EdgeInsets.all(0.0),
                                                          child: SvgPicture.asset(
                                                            assets.switchIcon,
                                                            width: 16,
                                                            height: 16,
                                                            fit: BoxFit.contain,
                                                            colorFilter: ColorFilter.mode(
                                                              resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                                                              BlendMode.srcIn,
                                                            ),
                                                          ),
                                                        ),
                                                    ]),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Focus(
                                                    onKeyEvent: (node, event) => _handleQtyArrowKey(event, orderInput.qtyCtrl, !_isStock && !_isGTTLotToQty),
                                                    child: SizedBox(
                                                      height: 40,
                                                      child: Semantics(
                                                        identifier:
                                                            "GTT Qty Input",
                                                        child: MyntTextField(
                                                            backgroundColor: theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8),
                                                            placeholder: "0",
                                                            placeholderStyle: WebTextStyles.formInput(
                                                              isDarkTheme: theme.isDarkMode,
                                                              color: resolveThemeColor(
                                                                  context,
                                                                  dark: MyntColors.textSecondaryDark,
                                                                  light: MyntColors.textSecondary)
                                                                  .withValues(alpha: 0.5),
                                                            ),
                                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                            keyboardType: TextInputType.number,
                                                            textStyle: WebTextStyles.formInput(
                                                              isDarkTheme: theme.isDarkMode,
                                                              color: resolveThemeColor(
                                                                  context,
                                                                  dark: MyntColors.textPrimaryDark,
                                                                  light: MyntColors.textPrimary),
                                                            ),
                                                            leadingWidget: _isStock ? null : GestureDetector(
                                                              onTap: () {
                                                                setState(() {
                                                                  String input = orderInput.qtyCtrl.text;
                                                                  int currentValue = int.tryParse(input) ?? 0;
                                                                  int adjustedQty = currentValue >= multiplayer
                                                                    ? ((currentValue / multiplayer).floor()) * multiplayer
                                                                    : multiplayer;

                                                                  if (_isGTTLotToQty) {
                                                                    if (currentValue != adjustedQty) {
                                                                      orderInput.qtyCtrl.text = adjustedQty.toString();
                                                                    } else if (input.isNotEmpty && currentValue > multiplayer) {
                                                                      orderInput.qtyCtrl.text = (currentValue - multiplayer).toString();
                                                                    } else {
                                                                      orderInput.qtyCtrl.text = "$multiplayer";
                                                                    }
                                                                  } else {
                                                                    if (currentValue > 1) {
                                                                      orderInput.qtyCtrl.text = (currentValue - 1).toString();
                                                                    } else {
                                                                      orderInput.qtyCtrl.text = "1";
                                                                    }
                                                                  }
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
                                                                  String input = orderInput.qtyCtrl.text;
                                                                  int currentValue = int.tryParse(input) ?? 0;
                                                                  int adjustedQty = currentValue >= multiplayer
                                                                    ? ((currentValue / multiplayer).floor()) * multiplayer
                                                                    : multiplayer;

                                                                  bool hasNoFreezeLimit = frezQty <= lotSize;
                                                                  bool withinLimit = hasNoFreezeLimit || currentValue < frezQtyOrderSliceMaxLimit * frezQty;

                                                                  if (_isGTTLotToQty) {
                                                                    if (currentValue != adjustedQty) {
                                                                      orderInput.qtyCtrl.text = adjustedQty.toString();
                                                                    } else if (input.isNotEmpty && withinLimit) {
                                                                      orderInput.qtyCtrl.text = (currentValue + multiplayer).toString();
                                                                    } else if (input.isEmpty) {
                                                                      orderInput.qtyCtrl.text = "$multiplayer";
                                                                    } else if (!hasNoFreezeLimit) {
                                                                      ResponsiveSnackBar.showWarning(context,
                                                                        "Maximum Allowed Quantity $frezQty x $frezQtyOrderSliceMaxLimit = ${frezQtyOrderSliceMaxLimit * frezQty}");
                                                                    }
                                                                  } else {
                                                                    bool hasNoFreezeLimit = frezQty <= lotSize;
                                                                    int maxAllowedLots = hasNoFreezeLimit
                                                                      ? 999999
                                                                      : (frezQtyOrderSliceMaxLimit * frezQty) ~/ lotSize;

                                                                    if (input.isEmpty) {
                                                                      orderInput.qtyCtrl.text = "1";
                                                                    } else if (currentValue < maxAllowedLots) {
                                                                      orderInput.qtyCtrl.text = (currentValue + 1).toString();
                                                                    } else {
                                                                      ResponsiveSnackBar.showWarning(context,
                                                                        "Maximum Allowed Quantity $frezQty x $frezQtyOrderSliceMaxLimit = ${frezQtyOrderSliceMaxLimit * frezQty}");
                                                                    }
                                                                  }
                                                                });
                                                              },
                                                              child: Icon(
                                                                Icons.add,
                                                                size: 18,
                                                                color: theme.isDarkMode ? MyntColors.primaryDark : MyntColors.primary,
                                                              ),
                                                            ),
                                                            controller: orderInput.qtyCtrl,
                                                            textAlign: _isStock ? TextAlign.start : TextAlign.center,
                                                            onChanged: (value) {
                                                              if (value.isEmpty || value == "0") {
                                                                String fieldName = (_isStock)
                                                                  ? (_isQtyToAmount ? 'Amount' : 'Quantity')
                                                                  : (_isGTTLotToQty ? 'Quantity' : 'Lot');
                                                                _showDebouncedWarning(
                                                                    "$fieldName cannot be ${value == "0" ? '0' : 'empty'}");
                                                              } else {
                                                                String newValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                                                                double ltp = double.tryParse(widget.orderArg.ltp ?? "0.0") ?? 0.0;
                                                                var number = (_isStock)
                                                                  ? (!_isQtyToAmount
                                                                    ? int.tryParse(newValue) ?? 0
                                                                    : ((double.tryParse(newValue) ?? 0.0) ~/ ltp))
                                                                  : (!_isGTTLotToQty
                                                                    ? int.tryParse(newValue) ?? 0
                                                                    : ((int.tryParse(newValue) ?? 0) ~/ lotSize));

                                                                if (_isQtyToAmount && number < 1 && _isStock) {
                                                                  _showDebouncedWarning(
                                                                      "Minimum Allowed Amount should be greater than $ltp");
                                                                } else {
                                                                  bool hasNoFreezeLimit = frezQty <= lotSize;
                                                                  if (!hasNoFreezeLimit && number > frezQtyOrderSliceMaxLimit * frezQty) {
                                                                    _showDebouncedWarning(
                                                                        "Maximum Allowed Quantity $frezQty x $frezQtyOrderSliceMaxLimit = ${frezQtyOrderSliceMaxLimit * frezQty}");
                                                                  } else {
                                                                    _cancelPendingWarning();
                                                                  }
                                                                }

                                                                if (newValue != value) {
                                                                  orderInput.qtyCtrl.text = newValue;
                                                                  orderInput.qtyCtrl.selection = TextSelection.fromPosition(
                                                                    TextPosition(offset: newValue.length),
                                                                  );
                                                                }
                                                              }
                                                            }),
                                                      )),
                                                  ),
                                                  if (_isQtyToAmount && _isStock)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4),
                                                      child: Text(
                                                        "Qty : ${getGTTFinalQuantity(orderInput.qtyCtrl.text)}",
                                                        style: WebTextStyles.para(
                                                          isDarkTheme: theme.isDarkMode,
                                                          color: resolveThemeColor(context,
                                                            dark: MyntColors.textSecondaryDark,
                                                            light: MyntColors.textSecondary),
                                                        ),
                                                      ),
                                                    ),
                                                  if (_isGTTLotToQty && (widget.scripInfo.exch == "NFO" || widget.scripInfo.exch == "BFO"))
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4),
                                                      child: Text(
                                                        "Lot : ${((int.tryParse(orderInput.qtyCtrl.text) ?? 0) / lotSize).ceil()}",
                                                        style: WebTextStyles.para(
                                                          isDarkTheme: theme.isDarkMode,
                                                          color: resolveThemeColor(context,
                                                            dark: MyntColors.textSecondaryDark,
                                                            light: MyntColors.textSecondary),
                                                        ),
                                                      ),
                                                    ),
                                                  if (!_isGTTLotToQty && (widget.scripInfo.exch == "NFO" || widget.scripInfo.exch == "BFO"))
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4),
                                                      child: Text(
                                                        "Qty : ${(int.tryParse(orderInput.qtyCtrl.text) ?? 0) * lotSize}",
                                                        style: WebTextStyles.para(
                                                          isDarkTheme: theme.isDarkMode,
                                                          color: resolveThemeColor(context,
                                                            dark: MyntColors.textSecondaryDark,
                                                            light: MyntColors.textSecondary),
                                                        ),
                                                      ),
                                                    ),
                                                ])),
                                            const SizedBox(width: 16),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Row(
                                                      // mainAxisAlignment:
                                                      //     MainAxisAlignment
                                                      //         .spaceBetween,
                                                      children: [
                                                        headerTitleText(
                                                            "Price", theme),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          orderInput.actPrcType,
                                                          style: WebTextStyles
                                                              .formLabel(
                                                            isDarkTheme: theme
                                                                .isDarkMode,
                                                            color: resolveThemeColor(context,
                                                                dark: MyntColors
                                                                    .textPrimaryDark,
                                                                light: MyntColors
                                                                    .textPrimary),
                                                          ),
                                                        ),
                                                      ]),
                                                  const SizedBox(height: 10),
                                                  Focus(
                                                    onKeyEvent: (node, event) => _handlePriceArrowKey(event, orderInput.priceCtrl),
                                                    child: SizedBox(
                                                      height: 40,
                                                      // width: 150,
                                                      child: Semantics(
                                                        identifier:
                                                            "GTT Price Input",
                                                        child:
                                                            MyntTextField(
                                                                inputFormatters: [
                                                              FilteringTextInputFormatter
                                                                  .allow(RegExp(
                                                                      r'^\d*\.?\d{0,2}$'))
                                                            ],
                                                                backgroundColor: theme
                                                                        .isDarkMode
                                                                    ? colors
                                                                        .darkGrey
                                                                    : const Color(
                                                                        0xffF1F3F8),
                                                                onChanged:
                                                                    (value) {
                                                                  double
                                                                      inputPrice =
                                                                      double.tryParse(
                                                                              value) ??
                                                                          0;
                                                                  if (value
                                                                          .isNotEmpty &&
                                                                      inputPrice >
                                                                          0) {
                                                                    final regex =
                                                                        RegExp(
                                                                            r'^(\d+)?(\.\d{0,2})?$');
                                                                    if (!regex
                                                                        .hasMatch(
                                                                            value)) {
                                                                      orderInput
                                                                              .priceCtrl
                                                                              .text =
                                                                          value.substring(
                                                                              0,
                                                                              value.length - 1);
                                                                      orderInput
                                                                              .priceCtrl
                                                                              .selection =
                                                                          TextSelection
                                                                              .collapsed(
                                                                        offset: orderInput
                                                                            .priceCtrl
                                                                            .text
                                                                            .length,
                                                                      );
                                                                    }
                                                                  }
                                                                  if (value
                                                                      .isEmpty) {
                                                                    _showDebouncedWarning(
                                                                        "Price cannot be empty");
                                                                  } else if (inputPrice <=
                                                                      0) {
                                                                    _showDebouncedWarning(
                                                                        "Price cannot be 0");
                                                                  } else {
                                                                    _cancelPendingWarning();
                                                                    setState(
                                                                        () {
                                                                      ordPrice =
                                                                          value;
                                                                    });
                                                                  }
                                                                },
                                                                placeholder:
                                                                    "${widget.orderArg.ltp}",
                                                                placeholderStyle: WebTextStyles
                                                                    .formInput(
                                                                  isDarkTheme: theme
                                                                      .isDarkMode,
                                                                  color: (theme
                                                                          .isDarkMode
                                                                      ? MyntColors
                                                                          .textSecondaryDark
                                                                      : MyntColors
                                                                          .textSecondary).withValues(alpha: 0.5),
                                                                ),
                                                                keyboardType:
                                                                    const TextInputType
                                                                        .numberWithOptions(
                                                                        decimal:
                                                                            true),
                                                                textStyle: WebTextStyles
                                                                    .formInput(
                                                                  isDarkTheme: theme
                                                                      .isDarkMode,
                                                                  color: theme
                                                                          .isDarkMode
                                                                      ? MyntColors
                                                                          .textPrimaryDark
                                                                      : MyntColors
                                                                          .textPrimary,
                                                                ),
                                                                readOnly: orderInput.actPrcType ==
                                                                            "Limit" ||
                                                                        orderInput.actPrcType ==
                                                                            "SL Limit"
                                                                    ? false
                                                                    : true,
                                                                // prefixIcon: Container(
                                                                //     margin:
                                                                //         const EdgeInsets.all(
                                                                //             12),
                                                                //     decoration: BoxDecoration(
                                                                //         borderRadius:
                                                                //             BorderRadius.circular(20),
                                                                //         color: theme.isDarkMode ? const Color(0xff555555) : colors.colorWhite),
                                                                //     child: SvgPicture.asset(color: theme.isDarkMode ? colors.colorWhite : colors.colorGrey, orderInput.actPrcType == "Limit" || orderInput.actPrcType == "SL Limit" ? assets.ruppeIcon : assets.lock, fit: BoxFit.scaleDown)),
                                                                trailingWidget:
                                                                    Material(
                                                                  color: Colors
                                                                      .transparent,
                                                                  shape:
                                                                      const CircleBorder(),
                                                                  child:
                                                                      Semantics(
                                                                    identifier:
                                                                        "GTT Price Type button",
                                                                    child:
                                                                        InkWell(
                                                                      customBorder:
                                                                          const CircleBorder(),
                                                                      splashColor: theme.isDarkMode
                                                                          ? colors
                                                                              .splashColorDark
                                                                          : colors
                                                                              .splashColorLight,
                                                                      highlightColor: theme.isDarkMode
                                                                          ? colors
                                                                              .highlightDark
                                                                          : colors
                                                                              .highlightLight,
                                                                      onTap:
                                                                          () {
                                                                        setState(
                                                                            () {
                                                                          orderInput
                                                                              .setGTTPriceTypeOrderIsMarket(!orderInput.GTTPriceTypeOrderIsMarket);
                                                                          final newType = orderInput.GTTPriceTypeOrderIsMarket
                                                                              ? "Market"
                                                                              : "Limit";
                                                                          orderInput
                                                                              .chngGTTPriceType(newType);
                                                                          if (orderInput.actPrcType == "Market" ||
                                                                              orderInput.actPrcType == "SL MKT") {
                                                                            orderInput.priceCtrl.text =
                                                                                "Market";
                                                                          } else {
                                                                            orderInput.priceCtrl.text =
                                                                                "${widget.orderArg.ltp}";
                                                                          }
                                                                        });
                                                                      },
                                                                      child:
                                                                          Padding(
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            12.0),
                                                                        child: SvgPicture.asset(
                                                                            assets
                                                                                .switchIcon,
                                                                            fit:
                                                                                BoxFit.contain,
                                                                            colorFilter: ColorFilter.mode(
                                                                                resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                                                                                BlendMode.srcIn)),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                controller:
                                                                    orderInput
                                                                        .priceCtrl,
                                                                textAlign:
                                                                    TextAlign
                                                                        .start),
                                                      )),
                                                  ),
                                                ]))
                                          ])),
                                  const SizedBox(height: 16),
                                  // if(orderInput.actPrcType == "Market" || orderInput.actPrcType == "SL MKT") ...[
                                  //     marketProtectionDisclaimer(theme, context, widget.scripInfo, mktProtCtrl.text),
                                  //   const SizedBox(height: 16),
                                  // ],
                                  // Divider(
                                  //     color: theme.isDarkMode
                                  //         ? colors.darkColorDivider
                                  //         : colors.colorDivider),
                                  // if (orderInput.actPrcType == "SL Limit" || orderInput.actPrcType == "SL MKT") ...[
                                  //   triggerOption(theme, context, widget.scripInfo),
                                  //   Divider(
                                  //       color: theme.isDarkMode
                                  //           ? colors.darkColorDivider
                                  //           : colors.colorDivider)
                                  // ],
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        //   Expanded(
                                        //       child: Column(
                                        //           crossAxisAlignment:
                                        //               CrossAxisAlignment.start,
                                        //           children: [
                                        //         headerTitleText(
                                        //             "Validity", theme),
                                        //         const SizedBox(height: 7),
                                        //         SizedBox(
                                        //             height: 38,
                                        //             child: ListView.separated(
                                        //                 scrollDirection:
                                        //                     Axis.horizontal,
                                        //                 itemBuilder:
                                        //                     (context, index) {
                                        //                   return ElevatedButton(
                                        //                       onPressed: () {
                                        //                         setState(() {
                                        //                           validityTypeGTT =
                                        //                               validityTypesGTT[
                                        //                                   index];
                                        //                         });
                                        //                       },
                                        //                       style: ElevatedButton
                                        //                           .styleFrom(
                                        //                               elevation:
                                        //                                   0,
                                        //                               padding: const EdgeInsets
                                        //                                   .symmetric(
                                        //                                   horizontal:
                                        //                                       12,
                                        //                                   vertical:
                                        //                                       0),
                                        //                               backgroundColor: !theme
                                        //                                       .isDarkMode
                                        //                                   ? validityTypeGTT != validityTypesGTT[index]
                                        //                                       ? const Color(0xffF1F3F8)
                                        //                                       : colors.colorBlack
                                        //                                   : validityTypeGTT != validityTypesGTT[index]
                                        //                                       ? colors.darkGrey
                                        //                                       : colors.colorbluegrey,
                                        //                               shape: const StadiumBorder()),
                                        //                       child: Text(validityTypesGTT[index],
                                        //                           style: textStyle(
                                        //                               !theme.isDarkMode
                                        //                                   ? validityTypeGTT != validityTypesGTT[index]
                                        //                                       ? const Color(0xff666666)
                                        //                                       : colors.colorWhite
                                        //                                   : validityTypeGTT != validityTypesGTT[index]
                                        //                                       ? const Color(0xff666666)
                                        //                                       : colors.colorBlack,
                                        //                               14,
                                        //                               validityTypeGTT == validityTypesGTT[index] ? FontWeight.w600 : FontWeight.w500)));
                                        //                 },
                                        //                 separatorBuilder:
                                        //                     (context, index) {
                                        //                   return const SizedBox(
                                        //                       width: 8);
                                        //                 },
                                        //                 itemCount:
                                        //                     validityTypesGTT
                                        //                         .length))
                                        //       ],
                                        //       ),
                                        //       ),
                                        //   const SizedBox(width: 16),
                                        Row(
                                          children: [
                                            Text(
                                              "OCO",
                                              style: WebTextStyles.sub(
                                                isDarkTheme: theme.isDarkMode,
                                                color: theme.isDarkMode
                                                    ? MyntColors
                                                        .textPrimaryDark
                                                    : MyntColors.textSecondary,
                                              ),
                                            ),
                                            Semantics(
                                              identifier: 'GTT OCO button',
                                              child: Checkbox(
                                                value: isOco,
                                                onChanged: (bool? value) {
                                                  ScaffoldMessenger.of(context)
                                                      .removeCurrentSnackBar();
                                                  if (isBuy! &&
                                                      widget.scripInfo.seg ==
                                                          "EQT") {
                                                    ResponsiveSnackBar
                                                        .showWarning(context,
                                                            "OCO Order cannot be placed for Buy order");
                                                    return;
                                                  }

                                                  final newIsOco = value ?? false;
                                                  setState(() {
                                                    isOco = newIsOco;
                                                    orderInput
                                                        .disableCondGTT(isOco);
                                                  });
                                                  if (newIsOco) {
                                                    // Seed leg-2 price/qty when enabling OCO.
                                                    if (orderInput.ocoPrcType !=
                                                        "MKT") {
                                                      orderInput
                                                          .chngOCOPriceType(
                                                              "Limit");

                                                      ref
                                                          .read(ordInputProvider)
                                                          .updateOcoPrcQtyCtrl(
                                                            "${widget.orderArg.ltp}",
                                                            widget.scripInfo.exch == "MCX"
                                                                ? "1"
                                                                : widget
                                                                    .orderArg.lotSize!
                                                                    .replaceAll(
                                                                        "-", ""),
                                                          );
                                                    }
                                                  } else {
                                                    orderInput.clearOcoFields();
                                                  }
                                                },
                                                activeColor: theme.isDarkMode
                                                    ? MyntColors.secondary
                                                    : MyntColors.primary,
                                                checkColor: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOco) ...[
                                    // Divider(
                                    //     color: theme.isDarkMode
                                    //         ? colors.darkColorDivider
                                    //         : colors.colorDivider,
                                    //     thickness: .4),
                                    // const SizedBox(height: 16),
                                    // GttCondition(
                                    //     isOco: isOco,
                                    //     isGtt: isGtt,
                                    //     isModify: widget.orderArg.isModify),
                                    // const SizedBox(height: 8),
                                    // InvesTypeWidget(
                                    //     scripInfo: widget.scripInfo, ordType: "OCO"),
                                    // const SizedBox(height: 8),
                                    // Padding(
                                    //     padding: const EdgeInsets.only(left: 16),
                                    //     child: headerTitleText("Price type", theme)),
                                    // const SizedBox(height: 10),
                                    // PriceTypeBtn(
                                    //     isOco: isOco,
                                    //     isGtt: isGtt,
                                    //     ltp: "${widget.orderArg.ltp}"),
                                    // Divider(
                                    //     color: theme.isDarkMode
                                    //         ? colors.darkColorDivider
                                    //         : colors.colorDivider),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              headerTitleText(
                                                  isOco
                                                      ? "Stoploss Trigger Price"
                                                      : "Trigger Price",
                                                  theme),
                                                  // Text(" (in Rs)", style: WebTextStyles.para(isDarkTheme: theme.isDarkMode, color: resolveThemeColor(context,
                                                  //                 dark: MyntColors.textPrimaryDark,
                                                  //                 light: MyntColors.textPrimary))),
                                            ]),
                                            const SizedBox(height: 10),
                                            Focus(
                                              onKeyEvent: (node, event) => _handlePriceArrowKey(event, orderInput.val2Ctrl),
                                              child: SizedBox(
                                                height: 40,
                                                width: 200,
                                                child: Semantics(
                                                  identifier:
                                                      'stoploss_trigger_price',
                                                  child: MyntTextField(
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter
                                                            .allow(RegExp(
                                                                r'^\d*\.?\d{0,2}$'))
                                                      ],
                                                      backgroundColor:
                                                          theme.isDarkMode
                                                              ? colors.darkGrey
                                                              : const Color(
                                                                  0xffF1F3F8),
                                                      onChanged: (value) {
                                                        double inputPrice =
                                                            double.tryParse(
                                                                    value) ??
                                                                0;

                                                        if (value.isNotEmpty &&
                                                            inputPrice > 0) {
                                                          final regex = RegExp(
                                                              r'^(\d+)?(\.\d{0,2})?$');
                                                          if (!regex.hasMatch(
                                                              value)) {
                                                            orderInput.val2Ctrl
                                                                    .text =
                                                                value.substring(
                                                                    0,
                                                                    value.length -
                                                                        1);
                                                            orderInput.val2Ctrl
                                                                    .selection =
                                                                TextSelection.collapsed(
                                                                    offset: orderInput
                                                                        .val2Ctrl
                                                                        .text
                                                                        .length);
                                                          }
                                                        }
                                                        if (value.isEmpty) {
                                                          _showDebouncedWarning(
                                                              "Stoploss trigger price cannot be empty");
                                                        } else if (inputPrice <=
                                                            0) {
                                                          _showDebouncedWarning(
                                                              "Stoploss trigger price cannot be 0");
                                                        } else {
                                                          _cancelPendingWarning();
                                                        }
                                                      },
                                                      placeholder:
                                                          "${widget.orderArg.ltp}",
                                                      placeholderStyle: WebTextStyles
                                                          .formInput(
                                                        isDarkTheme:
                                                            theme.isDarkMode,
                                                        color: (theme.isDarkMode
                                                            ? MyntColors
                                                                .textSecondary
                                                            : MyntColors
                                                                .textSecondary).withValues(alpha: 0.5),
                                                      ),
                                                      keyboardType:
                                                          const TextInputType
                                                              .numberWithOptions(
                                                              decimal: true),
                                                      textStyle: WebTextStyles
                                                          .formInput(
                                                        isDarkTheme:
                                                            theme.isDarkMode,
                                                        color: theme.isDarkMode
                                                            ? MyntColors
                                                                .textPrimaryDark
                                                            : MyntColors
                                                                .textPrimary,
                                                      ),
                                                      controller:
                                                          orderInput.val2Ctrl,
                                                      textAlign:
                                                          TextAlign.start),
                                                )),
                                            ),
                                          ]),
                                    ),

                                    const SizedBox(height: 16),
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
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    InkWell(
                                                      onTap: (widget.scripInfo.exch == "NFO" ||
                                                          widget.scripInfo.exch == "BFO" ||
                                                          _isStock) ? () {
                                                        setState(() {
                                                          if (_isStock) {
                                                            _isQtyToAmount = !_isQtyToAmount;
                                                            if (_isQtyToAmount) {
                                                              double seedLtp = SafeParse.toDouble(widget.orderArg.ltp);
                                                              final wsD = ref.read(websocketProvider).socketDatas[widget.scripInfo.token];
                                                              if (wsD != null) {
                                                                final wl = SafeParse.toDouble(wsD['lp']);
                                                                if (wl > 0) seedLtp = wl;
                                                              }
                                                              orderInput.ocoQtyCtrl.text = seedLtp.ceil().toString();
                                                            } else {
                                                              orderInput.ocoQtyCtrl.text = "1";
                                                            }
                                                          } else {
                                                            // NFO/BFO: Toggle between Lot and Qty
                                                            _isGTTLotToQty = !_isGTTLotToQty;
                                                            if (_isGTTLotToQty) {
                                                              int currentLot = int.tryParse(orderInput.ocoQtyCtrl.text) ?? 1;
                                                              orderInput.ocoQtyCtrl.text = (currentLot * lotSize).toString();
                                                            } else {
                                                              int currentQty = int.tryParse(orderInput.ocoQtyCtrl.text) ?? lotSize;
                                                              orderInput.ocoQtyCtrl.text = ((currentQty / lotSize).round()).toString();
                                                            }
                                                          }
                                                        });
                                                      } : () {},
                                                      child: Row(children: [
                                                        headerTitleText(
                                                          (_isStock)
                                                              ? (_isQtyToAmount ? "Amount" : "Qty")
                                                              : widget.scripInfo.exch == "MCX"
                                                                  ? "Lot"
                                                                  : (_isGTTLotToQty ? "Qty" : "Lot"),
                                                          theme),
                                                        const SizedBox(width: 16),
                                                        if (widget.scripInfo.exch == "NFO" ||
                                                            widget.scripInfo.exch == "BFO" ||
                                                            _isStock)
                                                          Padding(
                                                            padding: const EdgeInsets.all(0.0),
                                                            child: SvgPicture.asset(
                                                              assets.switchIcon,
                                                              width: 16,
                                                              height: 16,
                                                              fit: BoxFit.contain,
                                                              colorFilter: ColorFilter.mode(
                                                                resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                                                                BlendMode.srcIn,
                                                              ),
                                                            ),
                                                          ),
                                                      ]),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Focus(
                                                      onKeyEvent: (node, event) => _handleQtyArrowKey(event, orderInput.ocoQtyCtrl, !_isStock && !_isGTTLotToQty),
                                                      child: SizedBox(
                                                        height: 40,
                                                        width: 200,
                                                        child: Semantics(
                                                          identifier:
                                                              'oco_qty_input',
                                                          child: MyntTextField(
                                                              backgroundColor: theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8),
                                                              placeholder: "0", //orderInput.ocoQtyCtrl.text,
                                                              placeholderStyle: WebTextStyles.formInput(
                                                                isDarkTheme: theme
                                                                    .isDarkMode,
                                                                color: (theme
                                                                        .isDarkMode
                                                                    ? MyntColors
                                                                        .textSecondary
                                                                    : MyntColors
                                                                        .textSecondary).withValues(alpha: 0.5),
                                                              ),
                                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                              keyboardType: TextInputType.number,
                                                              textStyle: WebTextStyles.formInput(
                                                                isDarkTheme: theme
                                                                    .isDarkMode,
                                                                color: theme
                                                                        .isDarkMode
                                                                    ? MyntColors
                                                                        .textPrimaryDark
                                                                    : MyntColors
                                                                        .textPrimary,
                                                              ),
                                                              leadingWidget: _isStock ? null : GestureDetector(
                                                                onTap: () {
                                                                  setState(() {
                                                                    String input = orderInput.ocoQtyCtrl.text;
                                                                    int currentValue = int.tryParse(input) ?? 0;
                                                                    int adjustedQty = currentValue >= multiplayer
                                                                      ? ((currentValue / multiplayer).floor()) * multiplayer
                                                                      : multiplayer;

                                                                    if (_isGTTLotToQty) {
                                                                      if (currentValue != adjustedQty) {
                                                                        orderInput.ocoQtyCtrl.text = adjustedQty.toString();
                                                                      } else if (input.isNotEmpty && currentValue > multiplayer) {
                                                                        orderInput.ocoQtyCtrl.text = (currentValue - multiplayer).toString();
                                                                      } else {
                                                                        orderInput.ocoQtyCtrl.text = "$multiplayer";
                                                                      }
                                                                    } else {
                                                                      if (currentValue > 1) {
                                                                        orderInput.ocoQtyCtrl.text = (currentValue - 1).toString();
                                                                      } else {
                                                                        orderInput.ocoQtyCtrl.text = "1";
                                                                      }
                                                                    }
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
                                                                    String input = orderInput.ocoQtyCtrl.text;
                                                                    int currentValue = int.tryParse(input) ?? 0;
                                                                    int adjustedQty = currentValue >= multiplayer
                                                                      ? ((currentValue / multiplayer).floor()) * multiplayer
                                                                      : multiplayer;

                                                                    bool hasNoFreezeLimit = frezQty <= lotSize;
                                                                    bool withinLimit = hasNoFreezeLimit || currentValue < frezQtyOrderSliceMaxLimit * frezQty;

                                                                    if (_isGTTLotToQty) {
                                                                      if (currentValue != adjustedQty) {
                                                                        orderInput.ocoQtyCtrl.text = adjustedQty.toString();
                                                                      } else if (input.isNotEmpty && withinLimit) {
                                                                        orderInput.ocoQtyCtrl.text = (currentValue + multiplayer).toString();
                                                                      } else if (input.isEmpty) {
                                                                        orderInput.ocoQtyCtrl.text = "$multiplayer";
                                                                      } else if (!hasNoFreezeLimit) {
                                                                        ResponsiveSnackBar.showWarning(context,
                                                                          "Maximum Allowed Quantity $frezQty x $frezQtyOrderSliceMaxLimit = ${frezQtyOrderSliceMaxLimit * frezQty}");
                                                                      }
                                                                    } else {
                                                                      bool hasNoFreezeLimit = frezQty <= lotSize;
                                                                      int maxAllowedLots = hasNoFreezeLimit
                                                                        ? 999999
                                                                        : (frezQtyOrderSliceMaxLimit * frezQty) ~/ lotSize;

                                                                      if (input.isEmpty) {
                                                                        orderInput.ocoQtyCtrl.text = "1";
                                                                      } else if (currentValue < maxAllowedLots) {
                                                                        orderInput.ocoQtyCtrl.text = (currentValue + 1).toString();
                                                                      } else {
                                                                        ResponsiveSnackBar.showWarning(context,
                                                                          "Maximum Allowed Quantity $frezQty x $frezQtyOrderSliceMaxLimit = ${frezQtyOrderSliceMaxLimit * frezQty}");
                                                                      }
                                                                    }
                                                                  });
                                                                },
                                                                child: Icon(
                                                                  Icons.add,
                                                                  size: 18,
                                                                  color: theme.isDarkMode ? MyntColors.primaryDark : MyntColors.primary,
                                                                ),
                                                              ),
                                                              controller: orderInput.ocoQtyCtrl,
                                                              textAlign: _isStock ? TextAlign.start : TextAlign.center,
                                                              onChanged: (value) {
                                                                if (value.isEmpty || value == "0") {
                                                                  String fieldName = (_isStock)
                                                                    ? (_isQtyToAmount ? 'Amount' : 'Quantity')
                                                                    : (_isGTTLotToQty ? 'Quantity' : 'Lot');
                                                                  _showDebouncedWarning(
                                                                      "OCO $fieldName cannot be ${value == "0" ? '0' : 'empty'}");
                                                                } else {
                                                                  String newValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                                                                  double ltp = double.tryParse(widget.orderArg.ltp ?? "0.0") ?? 0.0;
                                                                  var number = (_isStock)
                                                                    ? (!_isQtyToAmount
                                                                      ? int.tryParse(newValue) ?? 0
                                                                      : ((double.tryParse(newValue) ?? 0.0) ~/ ltp))
                                                                    : (!_isGTTLotToQty
                                                                      ? int.tryParse(newValue) ?? 0
                                                                      : ((int.tryParse(newValue) ?? 0) ~/ lotSize));

                                                                  if (_isQtyToAmount && number < 1 && _isStock) {
                                                                    _showDebouncedWarning(
                                                                        "Minimum Allowed Amount should be greater than $ltp");
                                                                  } else {
                                                                    bool hasNoFreezeLimit = frezQty <= lotSize;
                                                                    if (!hasNoFreezeLimit && number > frezQtyOrderSliceMaxLimit * frezQty) {
                                                                      _showDebouncedWarning(
                                                                          "Maximum Allowed Quantity $frezQty x $frezQtyOrderSliceMaxLimit = ${frezQtyOrderSliceMaxLimit * frezQty}");
                                                                    } else {
                                                                      _cancelPendingWarning();
                                                                    }
                                                                  }

                                                                  if (newValue != value) {
                                                                    orderInput.ocoQtyCtrl.text = newValue;
                                                                    orderInput.ocoQtyCtrl.selection = TextSelection.fromPosition(
                                                                      TextPosition(offset: newValue.length),
                                                                    );
                                                                  }
                                                                }
                                                              }),
                                                        )),
                                                    ),
                                                    if (_isQtyToAmount && _isStock)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4),
                                                        child: Text(
                                                          "Qty : ${getGTTFinalQuantity(orderInput.ocoQtyCtrl.text)}",
                                                          style: WebTextStyles.para(
                                                            isDarkTheme: theme.isDarkMode,
                                                            color: resolveThemeColor(context,
                                                              dark: MyntColors.textSecondaryDark,
                                                              light: MyntColors.textSecondary),
                                                          ),
                                                        ),
                                                      ),
                                                    if (_isGTTLotToQty && (widget.scripInfo.exch == "NFO" || widget.scripInfo.exch == "BFO"))
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4),
                                                        child: Text(
                                                          "Lot : ${((int.tryParse(orderInput.ocoQtyCtrl.text) ?? 0) / lotSize).ceil()}",
                                                          style: WebTextStyles.para(
                                                            isDarkTheme: theme.isDarkMode,
                                                            color: resolveThemeColor(context,
                                                              dark: MyntColors.textSecondaryDark,
                                                              light: MyntColors.textSecondary),
                                                          ),
                                                        ),
                                                      ),
                                                    if (!_isGTTLotToQty && (widget.scripInfo.exch == "NFO" || widget.scripInfo.exch == "BFO"))
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4),
                                                        child: Text(
                                                          "Qty : ${(int.tryParse(orderInput.ocoQtyCtrl.text) ?? 0) * lotSize}",
                                                          style: WebTextStyles.para(
                                                            isDarkTheme: theme.isDarkMode,
                                                            color: resolveThemeColor(context,
                                                              dark: MyntColors.textSecondaryDark,
                                                              light: MyntColors.textSecondary),
                                                          ),
                                                        ),
                                                      ),
                                                  ])),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    Row(
                                                        // mainAxisAlignment:
                                                        //     MainAxisAlignment
                                                        //         .spaceBetween,
                                                        children: [
                                                          headerTitleText(
                                                              "Price", theme),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            orderInput.actOcoPrcType,
                                                            style: WebTextStyles
                                                                .formLabel(
                                                              isDarkTheme: theme
                                                                  .isDarkMode,
                                                              color: theme
                                                                      .isDarkMode
                                                                  ? MyntColors
                                                                      .textPrimaryDark
                                                                  : MyntColors
                                                                      .textPrimary,
                                                            ),
                                                          ),
                                                        ]),
                                                    const SizedBox(height: 10),
                                                    Focus(
                                                      onKeyEvent: (node, event) => _handlePriceArrowKey(event, orderInput.ocoPriceCtrl),
                                                      child: SizedBox(
                                                        height: 40,
                                                        width: 200,
                                                        child: Semantics(
                                                          identifier:
                                                              'oco_price_input',
                                                          child:
                                                              MyntTextField(
                                                                  inputFormatters: [
                                                                FilteringTextInputFormatter
                                                                    .allow(RegExp(
                                                                        r'^\d*\.?\d{0,2}$'))
                                                              ],
                                                                  backgroundColor: theme.isDarkMode
                                                                      ? colors
                                                                          .darkGrey
                                                                      : const Color(
                                                                          0xffF1F3F8),
                                                                  onChanged:
                                                                      (value) {
                                                                    double
                                                                        inputPrice =
                                                                        double.tryParse(value) ??
                                                                            0;
                                                                    if (value
                                                                            .isNotEmpty &&
                                                                        inputPrice >
                                                                            0) {
                                                                      final regex =
                                                                          RegExp(
                                                                              r'^(\d+)?(\.\d{0,2})?$');
                                                                      if (!regex
                                                                          .hasMatch(
                                                                              value)) {
                                                                        orderInput
                                                                            .ocoPriceCtrl
                                                                            .text = value.substring(0, value.length - 1);
                                                                        orderInput
                                                                            .ocoPriceCtrl
                                                                            .selection = TextSelection.collapsed(
                                                                          offset: orderInput
                                                                              .ocoPriceCtrl
                                                                              .text
                                                                              .length,
                                                                        );
                                                                      }
                                                                    }
                                                                    if (value
                                                                        .isEmpty) {
                                                                      _showDebouncedWarning(
                                                                          "OCO price cannot be empty");
                                                                    } else if (inputPrice <=
                                                                        0) {
                                                                      _showDebouncedWarning(
                                                                          "OCO price cannot be 0");
                                                                    } else {
                                                                      _cancelPendingWarning();
                                                                      setState(
                                                                          () {
                                                                        ordPrice =
                                                                            value;
                                                                      });
                                                                    }
                                                                  },
                                                                  placeholder:
                                                                      "${widget.orderArg.ltp}",
                                                                  placeholderStyle:
                                                                      WebTextStyles
                                                                          .formInput(
                                                                    isDarkTheme:
                                                                        theme
                                                                            .isDarkMode,
                                                                    color: (theme.isDarkMode
                                                                        ? MyntColors
                                                                            .textSecondary
                                                                        : MyntColors
                                                                            .textSecondary).withValues(alpha: 0.5),
                                                                  ),
                                                                  keyboardType: const TextInputType
                                                                      .numberWithOptions(
                                                                      decimal:
                                                                          true),
                                                                  textStyle: WebTextStyles
                                                                      .formInput(
                                                                    isDarkTheme:
                                                                        theme
                                                                            .isDarkMode,
                                                                    color: theme.isDarkMode
                                                                        ? MyntColors
                                                                            .textPrimaryDark
                                                                        : MyntColors
                                                                            .textPrimary,
                                                                  ),
                                                                  readOnly: orderInput.actOcoPrcType ==
                                                                              "Limit" ||
                                                                          orderInput
                                                                                  .actOcoPrcType ==
                                                                              "SL Limit"
                                                                      ? false
                                                                      : true,
                                                                  // prefixIcon: Container(
                                                                  //     margin: const EdgeInsets.all(
                                                                  //         12),
                                                                  //     decoration: BoxDecoration(
                                                                  //         borderRadius:
                                                                  //             BorderRadius.circular(20),
                                                                  //         color: theme.isDarkMode ? const Color(0xff555555) : colors.colorWhite),
                                                                  //     child: SvgPicture.asset(color: theme.isDarkMode ? colors.colorWhite : colors.colorGrey, orderInput.actOcoPrcType == "Limit" || orderInput.actOcoPrcType == "SL Limit" ? assets.ruppeIcon : assets.lock, fit: BoxFit.scaleDown)),

                                                                  trailingWidget:
                                                                      InkWell(
                                                                    onTap: () {
                                                                      setState(
                                                                          () {
                                                                        orderInput
                                                                            .setGTTOCOPriceTypeOrderIsMarket(!orderInput.GTTOCOPriceTypeOrderIsMarket);
                                                                        final newType1 = orderInput.GTTOCOPriceTypeOrderIsMarket
                                                                            ? "Market"
                                                                            : "Limit";
                                                                        orderInput
                                                                            .chngOCOPriceType(newType1);
                                                                        if (orderInput.actOcoPrcType ==
                                                                                "Market" ||
                                                                            orderInput.actOcoPrcType ==
                                                                                "SL MKT") {
                                                                          orderInput
                                                                              .ocoPriceCtrl
                                                                              .text = "Market";
                                                                        } else {
                                                                          orderInput
                                                                              .ocoPriceCtrl
                                                                              .text = "${widget.orderArg.ltp}";
                                                                        }
                                                                      });
                                                                    },
                                                                    child:
                                                                          Padding(
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            12.0),
                                                                        child: SvgPicture.asset(
                                                                            assets
                                                                                .switchIcon,
                                                                            fit:
                                                                                BoxFit.contain,
                                                                            colorFilter: ColorFilter.mode(
                                                                                resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                                                                                BlendMode.srcIn)),
                                                                      ),
                                                                    ),
                                                                  controller:
                                                                      orderInput
                                                                          .ocoPriceCtrl,
                                                                  textAlign:
                                                                      TextAlign
                                                                          .start),
                                                        )),
                                                    ),
                                                  ]))
                                            ])),

                                    // const SizedBox(height: 3),
                                    // Divider(
                                    //     color: theme.isDarkMode
                                    //         ? colors.darkColorDivider
                                    //         : colors.colorDivider),
                                    // if (orderInput.actOcoPrcType == "SL Limit" ||
                                    //     orderInput.actOcoPrcType == "SL MKT") ...[
                                    //   Padding(
                                    //       padding: const EdgeInsets.symmetric(
                                    //           horizontal: 16),
                                    //       child: Column(
                                    //           mainAxisAlignment:
                                    //               MainAxisAlignment.start,
                                    //           crossAxisAlignment:
                                    //               CrossAxisAlignment.start,
                                    //           children: [
                                    //             const SizedBox(height: 2),
                                    //             headerTitleText("Trigger", theme),
                                    //             const SizedBox(height: 7),
                                    //             SizedBox(
                                    //                 height: 44,
                                    //                 child: CustomTextFormField(
                                    //                     fillColor: theme.isDarkMode
                                    //                         ? colors.darkGrey
                                    //                         : const Color(0xffF1F3F8),
                                    //                     hintText: "0.00",
                                    //                     hintStyle: textStyle(
                                    //                         const Color(0xff666666),
                                    //                         15,
                                    //                         FontWeight.w400),
                                    //                     onChanged: (value) {
                                    //                       if (value.isNotEmpty &&
                                    //                           double.parse(value) >
                                    //                               0) {
                                    //                         final regex = RegExp(
                                    //                             r'^(\d+)?(\.\d{0,2})?$'); // Allows numbers with up to 2 decimal places
                                    //                         if (!regex
                                    //                             .hasMatch(value)) {
                                    //                           orderInput.ocoTrgPrcCtrl
                                    //                                   .text =
                                    //                               value.substring(
                                    //                                   0,
                                    //                                   value.length -
                                    //                                       1); // Revert to previous valid input
                                    //                           orderInput.ocoTrgPrcCtrl
                                    //                                   .selection =
                                    //                               TextSelection.collapsed(
                                    //                                   offset: orderInput
                                    //                                       .ocoTrgPrcCtrl
                                    //                                       .text
                                    //                                       .length); // Keep cursor at the end
                                    //                         }
                                    //                       }
                                    //                       ScaffoldMessenger.of(
                                    //                               context)
                                    //                           .hideCurrentSnackBar();
                                    //                       if (value.isNotEmpty) {
                                    //                       } else {
                                    //                         ScaffoldMessenger.of(
                                    //                                 context)
                                    //                             .showSnackBar(
                                    //                                 ResponsiveSnackBar.showWarning(
                                    //                                     context,
                                    //                                     "Trigger cannot be empty"));
                                    //                       }
                                    //                     },
                                    //                     keyboardType:
                                    //                         const TextInputType.numberWithOptions(
                                    //                             decimal: true),
                                    //                     style: textStyle(
                                    //                         theme.isDarkMode
                                    //                             ? colors.colorWhite
                                    //                             : colors.colorBlack,
                                    //                         16,
                                    //                         FontWeight.w600),
                                    //                     prefixIcon: Container(
                                    //                         margin:
                                    //                             const EdgeInsets.all(
                                    //                                 12),
                                    //                         decoration: BoxDecoration(
                                    //                             borderRadius:
                                    //                                 BorderRadius.circular(
                                    //                                     20),
                                    //                             color: theme.isDarkMode
                                    //                                 ? const Color(
                                    //                                     0xff555555)
                                    //                                 : colors
                                    //                                     .colorWhite),
                                    //                         child: SvgPicture.asset(
                                    //                             color: theme.isDarkMode
                                    //                                 ? colors.colorWhite
                                    //                                 : colors.colorGrey,
                                    //                             assets.ruppeIcon,
                                    //                             fit: BoxFit.scaleDown)),
                                    //                     textCtrl: orderInput.ocoTrgPrcCtrl,
                                    //                     textAlign: TextAlign.start)),
                                    //           ])),
                                    //   Divider(
                                    //       color: theme.isDarkMode
                                    //           ? colors.darkColorDivider
                                    //           : colors.colorDivider)
                                    // ]
                                  ],

                                  // if (!isOco) ...[
                                  //   const SizedBox(height: 3),
                                  //   Divider(
                                  //       color: theme.isDarkMode
                                  //           ? colors.darkColorDivider
                                  //           : colors.colorDivider,
                                  //       thickness: .4)

                                  // Padding(
                                  //   padding:
                                  //       const EdgeInsets.only(bottom: 8, left: 16),
                                  //   child: headerTitleText("Remarks", theme),
                                  // ),
                                  // Container(
                                  //   padding:
                                  //       const EdgeInsets.symmetric(horizontal: 16),
                                  //   height: 40,
                                  //   child: CustomTextFormField(
                                  //       keyboardType: TextInputType.text,
                                  //       fillColor: theme.isDarkMode
                                  //           ? colors.darkGrey
                                  //           : const Color(0xffF1F3F8),
                                  //       hintStyle: textStyle(const Color(0xff666666),
                                  //           15, FontWeight.w400),
                                  //       style: textStyle(
                                  //           theme.isDarkMode
                                  //               ? colors.colorWhite
                                  //               : colors.colorBlack,
                                  //           16,
                                  //           FontWeight.w600),
                                  //       textAlign: TextAlign.start,
                                  //       onChanged: (value) {},
                                  //       textCtrl: orderInput.reMarksCtrl),
                                  // ),

                                  //  ],
                                  // if ((orderInput.actOcoPrcType == "Market" ||
                                  //         orderInput.actOcoPrcType == "SL MKT") ||
                                  //     (orderInput.actPrcType == "Market" ||
                                  //         orderInput.actPrcType == "SL MKT")) ...[
                                  //   const SizedBox(height: 16),
                                  //   marketProtectionDisclaimer(theme, context,
                                  //       widget.scripInfo, mktProtCtrl.text),
                                  //   const SizedBox(height: 16),
                                  // ],
                                  const SizedBox(height: 100)
                                ] else ...[
                                  // If Order Tab is Regular then show investment type and investment type radio button
                                  // if (orderType == "Delivery" || orderType == "Intraday") ...[
                                  //   Column(
                                  //       crossAxisAlignment:
                                  //           CrossAxisAlignment.start,
                                  //       children: [
                                  //         Padding(
                                  //             padding: const EdgeInsets.symmetric(
                                  //                 horizontal: 16),
                                  //             child: Row(
                                  //               mainAxisAlignment:
                                  //                   MainAxisAlignment
                                  //                       .spaceBetween,
                                  //               children: [
                                  //                 Text("Investment type",
                                  //                     style: textStyle(
                                  //                         theme.isDarkMode
                                  //                             ? colors.colorWhite
                                  //                             : colors.colorBlack,
                                  //                         14,
                                  //                         FontWeight.w500)),
                                  //                 InkWell(
                                  //                   onTap: () {
                                  //                     setState(() {
                                  //                       Navigator.pop(context);
                                  //                       Navigator.pushNamed(
                                  //                           context,
                                  //                           Routes.orderPrefer,
                                  //                           arguments: {
                                  //                             "orderArg":
                                  //                                 widget.orderArg,
                                  //                             "scripInfo": widget
                                  //                                 .scripInfo,
                                  //                             "isRollback": 'yes'
                                  //                           });
                                  //                     });
                                  //                   },
                                  //                   child: SvgPicture.asset(
                                  //                       'assets/profile/privacy_settings.svg'),
                                  //                 )
                                  //               ],
                                  //             )),
                                  //         Row(
                                  //             mainAxisAlignment:
                                  //                 MainAxisAlignment.start,
                                  //             children: [
                                  //               if (widget.orderArg.exchange !=
                                  //                   "NCOM") ...[
                                  //                 Radio<InvestType>(
                                  //                     fillColor:
                                  //                         WidgetStateProperty
                                  //                             .resolveWith<
                                  //                                 Color>((Set<
                                  //                                     WidgetState>
                                  //                                 states) {
                                  //                       if (states.contains(
                                  //                           WidgetState
                                  //                               .disabled)) {
                                  //                         return const Color(
                                  //                             0xff666666);
                                  //                       }
                                  //                       return theme.isDarkMode
                                  //                           ? colors.colorWhite
                                  //                           : const Color(
                                  //                               0xff666666);
                                  //                     }),
                                  //                     activeColor:
                                  //                         theme.isDarkMode
                                  //                             ? colors.colorWhite
                                  //                             : const Color(
                                  //                                 0xff666666),
                                  //                     value: InvestType.intraday,
                                  //                     groupValue:
                                  //                         orderInput.investType,
                                  //                     onChanged:
                                  //                         (InvestType? value) {
                                  //                       orderInput.chngInvesType(
                                  //                           value!, "PlcOrder");
                                  //                       if (orderType != "GTT") {
                                  //                         _debouncedMarginUpdate();
                                  //                       }
                                  //                     }),
                                  //                 Text('Intraday',
                                  //                     style: textStyle(
                                  //                         theme.isDarkMode
                                  //                             ? Color(orderInput
                                  //                                         .investType ==
                                  //                                     InvestType
                                  //                                         .intraday
                                  //                                 ? 0xffffffff
                                  //                                 : 0xff666666)
                                  //                             : Color(orderInput
                                  //                                         .investType ==
                                  //                                     InvestType
                                  //                                         .intraday
                                  //                                 ? 0xff3E4763
                                  //                                 : 0xff666666),
                                  //                         14,
                                  //                         FontWeight.w500))
                                  //               ],
                                  //               Radio<InvestType>(
                                  //                   fillColor: WidgetStateProperty
                                  //                       .resolveWith<Color>(
                                  //                           (Set<WidgetState>
                                  //                               states) {
                                  //                     if (states.contains(
                                  //                         WidgetState.disabled)) {
                                  //                       return const Color(
                                  //                           0xff666666);
                                  //                     }
                                  //                     return theme.isDarkMode
                                  //                         ? colors.colorWhite
                                  //                         : const Color(
                                  //                             0xff666666);
                                  //                   }),
                                  //                   activeColor: theme.isDarkMode
                                  //                       ? colors.colorWhite
                                  //                       : const Color(0xff666666),
                                  //                   value: widget.scripInfo.seg ==
                                  //                           "EQT"
                                  //                       ? InvestType.delivery
                                  //                       : InvestType.carryForward,
                                  //                   groupValue:
                                  //                       orderInput.investType,
                                  //                   onChanged:
                                  //                       (InvestType? value) {
                                  //                     orderInput.chngInvesType(
                                  //                         value!, "PlcOrder");
                                  //                     if (orderType != "GTT") {
                                  //                       _debouncedMarginUpdate();
                                  //                     }
                                  //                   }),
                                  //               Text(
                                  //                   widget.scripInfo.seg == "EQT"
                                  //                       ? 'Delivery'
                                  //                       : "Carry Forward",
                                  //                   style: textStyle(
                                  //                       theme.isDarkMode
                                  //                           ? Color(orderInput
                                  //                                           .investType ==
                                  //                                       InvestType
                                  //                                           .delivery ||
                                  //                                   orderInput
                                  //                                           .investType ==
                                  //                                       InvestType
                                  //                                           .carryForward
                                  //                               ? 0xffffffff
                                  //                               : 0xff666666)
                                  //                           : Color(orderInput
                                  //                                           .investType ==
                                  //                                       InvestType
                                  //                                           .delivery ||
                                  //                                   orderInput
                                  //                                           .investType ==
                                  //                                       InvestType
                                  //                                           .carryForward
                                  //                               ? 0xff3E4763
                                  //                               : 0xff666666),
                                  //                       14,
                                  //                       FontWeight.w500))
                                  //             ])
                                  //       ]),
                                  //   const SizedBox(height: 8)
                                  // ],
                                  // If Order Tab is Regular, Cover, Bracket, or GTT then show Price type Section , Quantity and Price fields
                                  // if (orderType == "Regular" || orderType == "Cover" || orderType == "Bracket" || orderType == "GTT") ...[
                                  if (orderType == "Delivery" ||
                                      orderType == "Intraday" ||
                                      orderType == "CO - BO" ||
                                      orderType == "GTT" ||
                                      orderType == "MTF") ...[
                                    //   Padding(
                                    //       padding: const EdgeInsets.symmetric(
                                    //         horizontal: 16),
                                    //         child: Row(
                                    //           mainAxisAlignment:
                                    //               MainAxisAlignment.spaceBetween,
                                    //           children: [
                                    //             Text("Price type",
                                    //                 style: textStyle(
                                    //                     theme.isDarkMode
                                    //                         ? colors.colorWhite
                                    //                         : colors.colorBlack,
                                    //                     14,
                                    //                     FontWeight.w500)),
                                    //             if (orderType != "Regular") ...[
                                    //                 InkWell(
                                    //                   onTap: () {
                                    //                       setState(() {
                                    //                         Navigator.pop(context);
                                    //                         Navigator.pushNamed(context,
                                    //                             Routes.orderPrefer,
                                    //                             arguments: {
                                    //                               "orderArg":
                                    //                                   widget.orderArg,
                                    //                               "scripInfo":
                                    //                                   widget.scripInfo,
                                    //                               "isRollback": 'yes'
                                    //                             });
                                    //                       },
                                    //                     );
                                    //                   },
                                    //                   child: SvgPicture.asset(
                                    //                       'assets/profile/privacy_settings.svg'),
                                    //                 )
                                    //             ]
                                    //           ],
                                    //         ),
                                    //     ),
                                    //       const SizedBox(height: 10),

                                    //   // Price Type section, List of buttons such as Market, Limit, SL, SL Mkt
                                    // Padding(
                                    //   padding: const EdgeInsets.only(left: 16),
                                    //   child: SizedBox(
                                    //       height: 38,
                                    //       child: ListView.separated(
                                    //           scrollDirection: Axis.horizontal,
                                    //           itemBuilder: (context, index) {
                                    //                 return ElevatedButton(
                                    //                     onPressed: () {
                                    //                     setState(() {
                                    //                         priceType =
                                    //                             priceTypes[index]
                                    //                                 ['type'];
                                    //                         if (priceType ==
                                    //                                 "Market" ||
                                    //                             priceType ==
                                    //                                 "SL MKT") {
                                    //                         priceCtrl.text =
                                    //                             "Market";

                                    //                         double ltp = (SafeParse.toDouble(widget.orderArg.ltp) *
                                    //                                 double.parse(mktProtCtrl.text.isEmpty? "0": mktProtCtrl.text)) /100;

                                    //                         if (isBuy!) {
                                    //                             ordPrice = (double.parse("${widget.orderArg.ltp ?? 0.00}") + ltp).toStringAsFixed(2);
                                    //                         } else {
                                    //                             ordPrice = (double.parse("${widget.orderArg.ltp ?? 0.00}") - ltp).toStringAsFixed(2);
                                    //                         }
                                    //                         double result = double.parse(ordPrice) + (double.parse( "${widget.scripInfo.ti}") / 2);
                                    //                         result -= result % double.parse("${widget.scripInfo.ti}");

                                    //                           if (result >=
                                    //                               double.parse(
                                    //                                   "${widget.scripInfo.uc ?? 0.00}")) {
                                    //                               ordPrice =
                                    //                                   "${widget.scripInfo.uc ?? 0.00}";
                                    //                           } else if (result <=
                                    //                               double.parse(
                                    //                                   "${widget.scripInfo.lc ?? 0.00}")) {
                                    //                               ordPrice =
                                    //                                   "${widget.scripInfo.lc ?? 0.00}";
                                    //                           } else {
                                    //                               ordPrice = result
                                    //                                   .toStringAsFixed(
                                    //                                       2);
                                    //                           }
                                    //                           } else {
                                    //                               priceCtrl.text =
                                    //                                   "${widget.orderArg.ltp}";
                                    //                               ordPrice =
                                    //                                   priceCtrl.text;
                                    //                           }
                                    //                           orderInput
                                    //                               .chngPriceType(
                                    //                                   priceTypes[
                                    //                                           index]
                                    //                                       ['type'],
                                    //                                   widget.orderArg
                                    //                                       .exchange);
                                    //                       });
                                    //                       _debouncedMarginUpdate();
                                    //                       FocusScope.of(context)
                                    //                           .unfocus();
                                    //                       },
                                    //                       style: ElevatedButton
                                    //                           .styleFrom(
                                    //                               elevation: 0,
                                    //                               padding: const EdgeInsets
                                    //                                   .symmetric(
                                    //                                   horizontal: 12,
                                    //                                   vertical: 0),
                                    //                               backgroundColor: !theme
                                    //                                       .isDarkMode
                                    //                                   ? priceType !=
                                    //                                           priceTypes[index]
                                    //                                               [
                                    //                                               'type']
                                    //                                       ? const Color(
                                    //                                           0xffF1F3F8)
                                    //                                       : colors
                                    //                                           .colorBlack
                                    //                                   : priceType !=
                                    //                                           priceTypes[index]
                                    //                                               [
                                    //                                               'type']
                                    //                                       ? colors
                                    //                                           .darkGrey
                                    //                                       : colors
                                    //                                           .colorbluegrey,
                                    //                               shape:
                                    //                                   const StadiumBorder()),
                                    //                       child: Text(
                                    //                           priceTypes[index]
                                    //                               ['type'],
                                    //                           style: textStyle(
                                    //                               !theme.isDarkMode
                                    //                                   ? priceType !=
                                    //                                           priceTypes[index]
                                    //                                               [
                                    //                                               'type']
                                    //                                       ? const Color(
                                    //                                           0xff666666)
                                    //                                       : colors
                                    //                                           .colorWhite
                                    //                                   : priceType !=
                                    //                                           priceTypes[index]
                                    //                                               ['type']
                                    //                                       ? const Color(0xff666666)
                                    //                                       : colors.colorBlack,
                                    //                               14,
                                    //                               priceType == priceTypes[index]['type'] ? FontWeight.w600 : FontWeight.w500),
                                    //                           ),
                                    //                       );
                                    //             },
                                    //             separatorBuilder:
                                    //                 (context, index) {
                                    //               return const SizedBox(width: 8);
                                    //             },
                                    //             itemCount: orderType == "Cover" || orderType == "Bracket" ? 3 : priceTypes.length
                                    //           ),
                                    //         ),
                                    //     ),
                                    //   const SizedBox(height: 3),
                                    // Divider(
                                    //     color: theme.isDarkMode
                                    //         ? colors.darkColorDivider
                                    //         : colors.colorDivider),

                                    // Quantity and Price fields
                                    if (orderType == "MTF" &&
                                        !_isMTFEnabled) ...[
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Card(
                                          color: theme.isDarkMode
                                              ? const Color(0xFF121212)
                                              : const Color(0xFFF1F3F8),
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 24, vertical: 28),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.lock_outline,
                                                    size: 40,
                                                    color: theme.isDarkMode
                                                        ? MyntColors.lossDark
                                                        : MyntColors
                                                            .loss), // your blue
                                                const SizedBox(height: 16),
                                                Text(
                                                  "MTF is not Enabled",
                                                  textAlign: TextAlign.center,
                                                  style: WebTextStyles.sub(
                                                    isDarkTheme:
                                                        theme.isDarkMode,
                                                    color: theme.isDarkMode
                                                        ? MyntColors.lossDark
                                                        : MyntColors.loss,
                                                  ),
                                                ),
                                                const SizedBox(height: 24),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
                                                      minimumSize:
                                                          const Size(0, 50),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(5),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 14),
                                                    ),
                                                    onPressed: () {
                                                      final profileDetails =
                                                          ref.read(
                                                              profileAllDetailsProvider);
                                                      final clientData =
                                                          profileDetails
                                                              .clientAllDetails
                                                              .clientData;

                                                      bool DDPIActive =
                                                          clientData?.dDPI ==
                                                              'Y';
                                                      bool POAActive =
                                                          clientData?.pOA ==
                                                              'Y';

                                                      if (!DDPIActive ||
                                                          !POAActive) {
                                                        final pendingStatuses =
                                                            profileDetails
                                                                .pendingStatusList;
                                                        if (pendingStatuses
                                                                .isNotEmpty &&
                                                            pendingStatuses[0]
                                                                    .data !=
                                                                null) {
                                                          final hasPendingChanges =
                                                              pendingStatuses[0]
                                                                  .data!
                                                                  .any((status) =>
                                                                      status ==
                                                                      'mtf_pending');
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .removeCurrentSnackBar();
                                                          if (hasPendingChanges) {
                                                            ResponsiveSnackBar
                                                                .showWarning(
                                                                    context,
                                                                    'You have pending request. Click on the E-Sign to proceed.');
                                                            return;
                                                          }
                                                        }
                                                        // Navigate to MTF screen, then close the order dialog
                                                        WebNavigationHelper
                                                            .navigateTo(
                                                                'mtfDetails');
                                                        _PlaceOrderDialogCloseNotifier
                                                                .of(context)
                                                            ?.onClose();
                                                      } else {
                                                        // Show warning and navigate to My Account before closing the dialog
                                                        ResponsiveSnackBar
                                                            .showWarning(
                                                                context,
                                                                'You need to enable DDPI before you can proceed with enabling MTF.');
                                                        WebNavigationHelper
                                                            .navigateTo(
                                                                'myAccount');
                                                        _PlaceOrderDialogCloseNotifier
                                                                .of(context)
                                                            ?.onClose();
                                                      }
                                                    },
                                                    child: Text(
                                                      "Enable MTF",
                                                      style: WebTextStyles.sub(
                                                        isDarkTheme:
                                                            theme.isDarkMode,
                                                        color: MyntColors
                                                            .backgroundColor,
                                                        fontWeight:
                                                            WebFonts.semiBold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    ] else ...[
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
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        InkWell(
                                                                  customBorder:
                                                                      const CircleBorder(),
                                                                  splashColor: theme
                                                                          .isDarkMode
                                                                      ? colors
                                                                          .splashColorDark
                                                                      : colors
                                                                          .splashColorLight,
                                                                  highlightColor: theme
                                                                          .isDarkMode
                                                                      ? colors
                                                                          .highlightDark
                                                                      : colors
                                                                          .highlightLight,
                                                                  onTap:(widget.scripInfo
                                                                        .exch ==
                                                                    "NFO" ||
                                                                widget.scripInfo
                                                                        .exch ==
                                                                    "BFO" ||
                                                                _isStock) ? () {
                                                                    setState(
                                                                        () {
                                                                      if (_isStock) {
                                                                        // NSE/BSE: Toggle between Qty and Amount
                                                                        _isQtyToAmount =
                                                                            !_isQtyToAmount;
                                                                        if (_isQtyToAmount) {
                                                                          qtyCtrl.text =
                                                                              ((double.tryParse(widget.orderArg.ltp ?? "0.00") ?? 0).ceil()).toString();
                                                                        } else {
                                                                          qtyCtrl.text =
                                                                              "1";
                                                                        }
                                                                      } else {
                                                                        // NFO/BFO: Toggle between Lot and Qty
                                                                        _isLotToQty =
                                                                            !_isLotToQty;
                                                                        if (_isLotToQty) {
                                                                          // Converting from Lot to Qty: multiply by lot size
                                                                          int currentLot =
                                                                              int.tryParse(qtyCtrl.text) ?? 1;
                                                                          qtyCtrl.text =
                                                                              (currentLot * lotSize).toString();
                                                                        } else {
                                                                          // Converting from Qty to Lot: divide by lot size
                                                                          int currentQty =
                                                                              int.tryParse(qtyCtrl.text) ?? lotSize;
                                                                          qtyCtrl.text =
                                                                              ((currentQty / lotSize).round()).toString();
                                                                          // if (qtyCtrl.text == "0") qtyCtrl.text = "1";
                                                                        }
                                                                      }
                                                                      _debouncedMarginUpdate();
                                                                    });
                                                                  } : (){},
                                                                  child: Row(
                                                            children: [
                                                              headerTitleText(
                                                                  (_isStock)
                                                                      ? (_isQtyToAmount
                                                                          ? "Amount"
                                                                          : "Qty")
                                                                      : widget.scripInfo.exch == "MCX"
                                                                          ? "Lot"
                                                                          : (_isLotToQty
                                                                              ? "Qty"
                                                                              : "Lot"),
                                                                  theme),
                                                              const SizedBox(
                                                                  width: 16),
                                                              if (widget.scripInfo
                                                                          .exch ==
                                                                      "NFO" ||
                                                                  widget.scripInfo
                                                                          .exch ==
                                                                      "BFO" ||
                                                                  _isStock)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          0.0),
                                                                  child: SvgPicture
                                                                  .asset(
                                                                assets
                                                                    .switchIcon,
                                                                width: 16,
                                                                height:
                                                                    16,
                                                                fit: BoxFit
                                                                    .contain,
                                                                colorFilter: ColorFilter.mode(
                                                                  resolveThemeColor(
                                                                    context,
                                                                    dark: MyntColors.primaryDark,
                                                                    light: MyntColors.primary,
                                                                  ),
                                                                  BlendMode.srcIn,
                                                                ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),

                                                        // Text(
                                                        // "Lot: ${widget.scripInfo.ls} ${widget.scripInfo.prcunt ?? ''}  ",
                                                        // style: textStyle(
                                                        //     const Color(
                                                        //         0xff777777),
                                                        //     11,
                                                        //     FontWeight.w600),
                                                        // )
                                                      ]),
                                                  const SizedBox(height: 10),
                                                  Focus(
                                                    onKeyEvent: (node, event) => _handleQtyArrowKey(event, qtyCtrl, !_isStock && !_isLotToQty),
                                                    child: SizedBox(
                                                    height: 40,
                                                    width: 200,
                                                    child: Semantics(
                                                      identifier: 'qty_input',
                                                      child:
                                                          MyntTextField(
                                                        backgroundColor: theme
                                                                .isDarkMode
                                                            ? colors.darkGrey
                                                            : const Color(
                                                                0xffF1F3F8),
                                                        placeholder:
                                                            "0", //qtyCtrl.text,
                                                        placeholderStyle: WebTextStyles
                                                            .formInput(
                                                          isDarkTheme:
                                                              theme.isDarkMode,
                                                          color: (theme
                                                                  .isDarkMode
                                                              ? MyntColors
                                                                  .textSecondary
                                                              : MyntColors
                                                                  .textSecondary).withValues(alpha: 0.5),
                                                        ),
                                                        inputFormatters: [
                                                          FilteringTextInputFormatter
                                                              .digitsOnly
                                                        ],
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        textStyle: WebTextStyles
                                                            .formInput(
                                                          isDarkTheme:
                                                              theme.isDarkMode,
                                                          color: theme
                                                                  .isDarkMode
                                                              ? MyntColors
                                                                  .textPrimaryDark
                                                              : MyntColors
                                                                  .textPrimary,
                                                        ),
                                                        leadingWidget: _isStock
                                                            ? null
                                                            : GestureDetector(
                                                                  onTap: () {
                                                                    setState(
                                                                        () {
                                                                      String
                                                                          input =
                                                                          qtyCtrl
                                                                              .text;
                                                                      int currentValue =
                                                                          int.tryParse(input) ??
                                                                              0;
                                                                      int adjustedQty = currentValue >=
                                                                              multiplayer
                                                                          ? ((currentValue / multiplayer).floor()) *
                                                                              multiplayer
                                                                          : multiplayer;

                                                                      if (_isLotToQty) {
                                                                        // Qty mode: decrement by Lot size
                                                                        if (currentValue !=
                                                                            adjustedQty) {
                                                                          qtyCtrl.text =
                                                                              (adjustedQty).toString();
                                                                        } else if (input.isNotEmpty &&
                                                                            currentValue >
                                                                                multiplayer) {
                                                                          qtyCtrl.text =
                                                                              (currentValue - multiplayer).toString();
                                                                        } else {
                                                                          qtyCtrl.text =
                                                                              "$multiplayer";
                                                                        }
                                                                      } else {
                                                                        // Lot mode: decrement by 1
                                                                        if (currentValue >
                                                                            1) {
                                                                          qtyCtrl.text =
                                                                              (currentValue - 1).toString();
                                                                        } else {
                                                                          qtyCtrl.text =
                                                                              "1";
                                                                        }
                                                                      }
                                                                      qtyCtrl.selection = TextSelection.collapsed(offset: qtyCtrl.text.length);
                                                                      _debouncedMarginUpdate();
                                                                    });
                                                                  },
                                                                  child: Icon(
                                                                    Icons.remove,
                                                                    size: 18,
                                                                    color: theme.isDarkMode
                                                                        ? MyntColors.primaryDark
                                                                        : MyntColors.primary,
                                                                  ),
                                                                ),

                                                        trailingWidget: _isStock
                                                            ? null
                                                            : GestureDetector(
                                                                  onTap: () {
                                                                    setState(
                                                                        () {
                                                                      String
                                                                          input =
                                                                          qtyCtrl
                                                                              .text;
                                                                      int currentValue =
                                                                          int.tryParse(input) ??
                                                                              0;
                                                                      int adjustedQty = currentValue >=
                                                                              multiplayer
                                                                          ? ((currentValue / multiplayer).floor()) *
                                                                              multiplayer
                                                                          : multiplayer;

                                                                      bool
                                                                          hasNoFreezeLimit =
                                                                          frezQty <=
                                                                              lotSize;
                                                                      bool
                                                                          withinLimit =
                                                                          hasNoFreezeLimit ||
                                                                              currentValue < frezQtyOrderSliceMaxLimit * frezQty;

                                                                      if (_isLotToQty) {
                                                                        // Qty mode: increment by Lot Size, check against freeze limit
                                                                        if (currentValue !=
                                                                            adjustedQty) {
                                                                          qtyCtrl.text =
                                                                              adjustedQty.toString();
                                                                        } else if (input.isNotEmpty &&
                                                                            withinLimit) {
                                                                          qtyCtrl.text =
                                                                              (currentValue + multiplayer).toString();
                                                                        } else if (input
                                                                            .isEmpty) {
                                                                          qtyCtrl.text =
                                                                              "$multiplayer";
                                                                        } else if (!hasNoFreezeLimit) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Maximum Allowed Quantity $frezQty x $frezQtyOrderSliceMaxLimit = ${frezQtyOrderSliceMaxLimit * frezQty}");
                                                                          // qtyCtrl.text =
                                                                          //     "$multiplayer";
                                                                        }
                                                                      } else {
                                                                        // Lot mode: increment by 1 lot, check against freeze limit
                                                                        bool
                                                                            hasNoFreezeLimit =
                                                                            frezQty <=
                                                                                lotSize;
                                                                        int maxAllowedLots = hasNoFreezeLimit
                                                                            ? 999999
                                                                            : (frezQtyOrderSliceMaxLimit * frezQty) ~/
                                                                                lotSize;

                                                                        if (input
                                                                            .isEmpty) {
                                                                          qtyCtrl.text =
                                                                              "1";
                                                                        } else if (currentValue <
                                                                            maxAllowedLots) {
                                                                          qtyCtrl.text =
                                                                              (currentValue + 1).toString();
                                                                        } else {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              _freezeCapMessage());
                                                                        }
                                                                      }
                                                                      qtyCtrl.selection = TextSelection.collapsed(offset: qtyCtrl.text.length);
                                                                      _debouncedMarginUpdate();
                                                                    });
                                                                  },
                                                                  child: Icon(
                                                                    Icons.add,
                                                                    size: 18,
                                                                    color: theme.isDarkMode
                                                                        ? MyntColors.primaryDark
                                                                        : MyntColors.primary,
                                                                  ),
                                                                ),

                                                        controller: qtyCtrl,
                                                        textAlign: _isStock
                                                            ? TextAlign.start
                                                            : TextAlign.center,
                                                        onChanged: (value) {
                                                          if (value.isEmpty ||
                                                              value == "0") {
                                                            String fieldName = (_isStock)
                                                                ? (_isQtyToAmount
                                                                    ? 'Amount'
                                                                    : 'Quantity')
                                                                : (_isLotToQty
                                                                    ? 'Quantity'
                                                                    : 'Lot');
                                                            _showDebouncedWarning(
                                                                "$fieldName cannot be ${value == "0" ? '0' : 'empty'}");
                                                                _marginUpdateDebounceTimer?.cancel();
                                                            ref.read(orderProvider).resetMargin();
                                                          } else {
                                                            String newValue =
                                                                value.replaceAll(
                                                                    RegExp(
                                                                        r'[^0-9]'),
                                                                    '');
                                                            double ltp = double
                                                                    .tryParse(widget
                                                                            .orderArg
                                                                            .ltp ??
                                                                        "0.0") ??
                                                                0.0;
                                                            var number = (_isStock)
                                                                ? (!_isQtyToAmount
                                                                    ? int.tryParse(
                                                                            newValue) ??
                                                                        0
                                                                    : ((double.tryParse(newValue) ??
                                                                            0.0) ~/
                                                                        ltp))
                                                                : (!_isLotToQty
                                                                    ? int.tryParse(
                                                                            newValue) ??
                                                                        0
                                                                    : ((int.tryParse(newValue) ??
                                                                            0) ~/
                                                                        lotSize));

                                                            if (_isQtyToAmount &&
                                                                number < 1 &&
                                                                (_isStock)) {
                                                              _showDebouncedWarning(
                                                                  "Minimum Allowed Amount should be greater than $ltp");
                                                            } else {
                                                              bool
                                                                  hasNoFreezeLimit =
                                                                  frezQty <=
                                                                      lotSize;
                                                              final int valueInUnits =
                                                                  (!_isStock && !_isLotToQty)
                                                                      ? number * lotSize
                                                                      : number;
                                                              if (!hasNoFreezeLimit &&
                                                                  valueInUnits >
                                                                      frezQtyOrderSliceMaxLimit *
                                                                          frezQty) {
                                                                _showDebouncedWarning(
                                                                    _freezeCapMessage());
                                                              } else {
                                                                _cancelPendingWarning();
                                                              }
                                                            }

                                                            if (newValue !=
                                                                value) {
                                                              qtyCtrl.text =
                                                                  newValue;
                                                              qtyCtrl.selection =
                                                                  TextSelection
                                                                      .fromPosition(
                                                                TextPosition(
                                                                    offset: newValue
                                                                        .length),
                                                              );
                                                            }
                                                            _debouncedMarginUpdate();
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  ),
                                                  // if (widget.scripInfo.frzqty != null) ...[
                                                  //         const SizedBox(height: 8),
                                                  //         Text("Frz Qty : $frezQty",
                                                  //             style: textStyle(
                                                  //                 const Color(
                                                  //                     0xff666666),
                                                  //                 12,
                                                  //                 FontWeight.w500))
                                                  // ]
                                                  if (_isQtyToAmount &&
                                                      (_isStock))
                                                    Text(
                                                      "Qty : ${getFinalQuantity(qtyCtrl.text)}",
                                                      style: WebTextStyles.sub(
                                                        isDarkTheme:
                                                            theme.isDarkMode,
                                                        color: theme.isDarkMode
                                                            ? MyntColors
                                                                .textPrimaryDark
                                                            : MyntColors
                                                                .textSecondary,
                                                      ),
                                                    ),
                                                  if (_isLotToQty &&
                                                      (widget.scripInfo.exch ==
                                                              "NFO" ||
                                                          widget.scripInfo
                                                                  .exch ==
                                                              "BFO"))
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 4),
                                                      child: Text(
                                                        "Lot : ${((int.tryParse(qtyCtrl.text) ?? 0) / lotSize).ceil()}",
                                                        style:
                                                            WebTextStyles.para(
                                                          isDarkTheme:
                                                              theme.isDarkMode,
                                                          color: theme
                                                                  .isDarkMode
                                                              ? MyntColors
                                                                  .textPrimaryDark
                                                              : MyntColors
                                                                  .textSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                  // Text(
                                                  //     "Qty : ${getFinalQuantity(qtyCtrl.text)}",
                                                  //     style: textStyle(
                                                  //         const Color(
                                                  //             0xff666666),
                                                  //         14,
                                                  //         FontWeight.w500)),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  InkWell(
                                                    customBorder: const CircleBorder(),
                                                              splashColor: theme.isDarkMode
                                                                  ? colors.splashColorDark
                                                                  : colors.splashColorLight,
                                                              highlightColor: theme.isDarkMode
                                                                  ? colors.highlightDark
                                                                  : colors.highlightLight,
                                                    onTap: () {
                                                       if (orderType == "CO - BO" &&
                                                                  _isStoplossOrder &&
                                                                  !_isMarketOrder) {
                                                                ResponsiveSnackBar.showWarning(
                                                                    context,
                                                                    "SL Market order is not allowed for CO-BO orders");
                                                                return;
                                                              }
                                                              setState(() {
                                                                _isMarketOrder = !_isMarketOrder;
                                                                updatePriceType();
                                                                orderInput.chngPriceType(
                                                                    priceType,
                                                                    widget.orderArg.exchange);
                                                                _debouncedMarginUpdate();
                                                              });
                                                    },
                                                    child: Row(
                                                        children: [
                                                          headerTitleText(
                                                              "Price", theme),
                                                          const SizedBox(
                                                              width: 8),
                                                          SvgPicture.asset(
                                                            assets.switchIcon,
                                                            width: 16,
                                                            height: 16,
                                                            fit: BoxFit.contain,
                                                            colorFilter: ColorFilter.mode(
                                                              resolveThemeColor(
                                                                context,
                                                                dark: MyntColors.primaryDark,
                                                                light: MyntColors.primary,
                                                              ),
                                                              BlendMode.srcIn,
                                                            ),
                                                          ),
                                                        ]),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Focus(
                                                    onKeyEvent: (node, event) => _handlePriceArrowKey(event, priceCtrl),
                                                    child: SizedBox(
                                                      height: 40,
                                                      width: 200,
                                                      child: Semantics(
                                                        identifier:
                                                            'price_input',
                                                        child:
                                                            MyntTextField(
                                                                inputFormatters: [
                                                              FilteringTextInputFormatter
                                                                  .allow(RegExp(
                                                                      r'^\d*\.?\d{0,2}$'))
                                                            ],
                                                                backgroundColor: theme
                                                                        .isDarkMode
                                                                    ? colors
                                                                        .darkGrey
                                                                    : const Color(
                                                                        0xffF1F3F8),
                                                                onChanged:
                                                                    (value) {
                                                                  double
                                                                      inputPrice =
                                                                      double.tryParse(
                                                                              value) ??
                                                                          0;
                                                                  if (value
                                                                          .isNotEmpty &&
                                                                      inputPrice >
                                                                          0) {
                                                                    final regex =
                                                                        RegExp(
                                                                            r'^(\d+)?(\.\d{0,2})?$');
                                                                    if (!regex
                                                                        .hasMatch(
                                                                            value)) {
                                                                      priceCtrl
                                                                              .text =
                                                                          value.substring(
                                                                              0,
                                                                              value.length - 1);
                                                                      priceCtrl
                                                                              .selection =
                                                                          TextSelection
                                                                              .collapsed(
                                                                        offset: priceCtrl
                                                                            .text
                                                                            .length,
                                                                      );
                                                                    }
                                                                  }
                                                                  if (value
                                                                      .isEmpty) {
                                                                    _showDebouncedWarning(
                                                                        "Price cannot be empty");
                                                                    _marginUpdateDebounceTimer?.cancel();
                                                                    ref.read(orderProvider).resetMargin();
                                                                  } else if (inputPrice <=
                                                                      0) {
                                                                    _showDebouncedWarning(
                                                                        "Price cannot be 0");
                                                                    _marginUpdateDebounceTimer?.cancel();
                                                                    ref.read(orderProvider).resetMargin();
                                                                  } else {
                                                                    _cancelPendingWarning();
                                                                    setState(
                                                                        () {
                                                                      ordPrice =
                                                                          value;
                                                                      _debouncedMarginUpdate();
                                                                    });
                                                                  }
                                                                },
                                                                placeholder:
                                                                    "${widget.orderArg.ltp}",
                                                                placeholderStyle: WebTextStyles
                                                                    .formInput(
                                                                  isDarkTheme: theme
                                                                      .isDarkMode,
                                                                  color: (theme
                                                                          .isDarkMode
                                                                      ? MyntColors
                                                                          .textSecondary
                                                                      : MyntColors
                                                                          .textSecondary).withValues(alpha: 0.5),
                                                                ),
                                                                keyboardType:
                                                                    const TextInputType
                                                                        .numberWithOptions(
                                                                        decimal:
                                                                            true),
                                                                textStyle: WebTextStyles
                                                                    .formInput(
                                                                  isDarkTheme: theme
                                                                      .isDarkMode,
                                                                  color: theme
                                                                          .isDarkMode
                                                                      ? MyntColors
                                                                          .textPrimaryDark
                                                                      : MyntColors
                                                                          .textPrimary,
                                                                ),
                                                                readOnly: priceType ==
                                                                            "Limit" ||
                                                                        priceType ==
                                                                            "SL Limit"
                                                                    ? false
                                                                    : true,
                                                                controller:
                                                                    priceCtrl,
                                                                textAlign:
                                                                    TextAlign
                                                                        .start),
                                                      )),
                                                  ),
                                                  // const SizedBox(height: 8),
                                                  // Text(
                                                  //     "Cir Lv : ${widget.scripInfo.lc ?? 0.00} - ${widget.scripInfo.uc ?? 0.00}",
                                                  //     style: textStyle(
                                                  //         const Color(
                                                  //             0xff666666),
                                                  //         12,
                                                  //         FontWeight.w500))
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      if ((priceType == "Market" ||
                                          priceType == "SL MKT")) ...[
                                        const SizedBox(height: 16),
                                        marketProtectionDisclaimer(
                                            theme,
                                            context,
                                            widget.scripInfo,
                                            mktProtCtrl.text),
                                        // const SizedBox(height: 16),
                                      ],

                                      // if (orderType == "Delivery" || orderType == "Intraday" || orderType == "MTF" || orderType == "CO - BO") ...[
                                      // Advance Option section
                                      const SizedBox(height: 10),
                                      Column(
                                        children: [
                                          Center(
                                            child: SizedBox(
                                              width: 150,
                                              child: TextButton(
                                                style: TextButton.styleFrom(
                                                  shape:
                                                      const RoundedRectangleBorder(),
                                                  padding:
                                                      const EdgeInsets.all(0),
                                                  backgroundColor: Colors.transparent,
                                                  foregroundColor: Colors.transparent,
                                                  elevation: 0.0,
                                                  minimumSize:
                                                      const Size(0, 30),
                                                  side: BorderSide.none,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    if (!_isStoplossOrder &&
                                                        !_afterMarketOrder &&
                                                        !_addValidityAndDisclosedQty) {
                                                      isAdvancedOptionClicked =
                                                          !isAdvancedOptionClicked;
                                                    }
                                                    updatePriceType();
                                                  });
                                                },
                                                child: Container(
                                                  color: resolveThemeColor(context,
                                                      dark: MyntColors.backgroundColorDark,
                                                      light: MyntColors.backgroundColor), // To make the full width tappable
                                                  height: 40,
                                                  child: Center(
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text('Advance',
                                                            style: WebTextStyles
                                                                .sub(
                                                              isDarkTheme: theme
                                                                  .isDarkMode,
                                                              color: theme
                                                                      .isDarkMode
                                                                  ? MyntColors
                                                                      .primaryDark
                                                                  : MyntColors
                                                                      .primary,
                                                              fontWeight:
                                                                  WebFonts
                                                                      .semiBold,
                                                            )),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 4),
                                                          child: Icon(
                                                            isAdvancedOptionClicked
                                                                ? Icons
                                                                    .keyboard_arrow_up
                                                                : Icons
                                                                    .keyboard_arrow_down,
                                                            color: theme
                                                                    .isDarkMode
                                                                ? MyntColors.primaryDark : MyntColors.primary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Visibility(
                                            visible: isAdvancedOptionClicked,
                                            child: Column(
                                              children: [
                                                Divider(
                                                        color: theme.isDarkMode
                                                            ? Colors.transparent
                                                            : colors.colorDivider,
                                                        thickness: 0.5,),

                                                // Column with Stoploss and Add validity (stacked vertically)
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Stoploss order
                                                    Theme(
                                                      data: ThemeData(
                                                        unselectedWidgetColor:
                                                            theme.isDarkMode
                                                                ? MyntColors
                                                                    .textPrimary
                                                                : MyntColors
                                                                    .textPrimary,
                                                      ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
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
                                                                    WebTextStyles
                                                                        .sub(
                                                                  isDarkTheme: theme
                                                                      .isDarkMode,
                                                                  color: resolveThemeColor(context,
                                                                      dark: MyntColors.textPrimaryDark,
                                                                      light: MyntColors.textSecondary),
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                            // Text(
                                                            //   'Stoploss order',
                                                            //   style: textStyle(
                                                            //     theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                                                            //     14,
                                                            //     FontWeight.w400,
                                                            //   ),
                                                            // ),
                                                            Checkbox(
                                                              value:
                                                                  _isStoplossOrder,
                                                              onChanged: (bool?
                                                                  value) {
                                                                setState(() {
                                                                  _isStoplossOrder =
                                                                      value ??
                                                                          false;
                                                                  updatePriceType();
                                                                  orderInput.chngPriceType(
                                                                      priceType,
                                                                      widget
                                                                          .orderArg
                                                                          .exchange);
                                                                  _debouncedMarginUpdate();
                                                                });
                                                              },
                                                              activeColor: colors
                                                                  .colorBlue,
                                                              checkColor:
                                                                  Colors.white,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    // Trigger option (only if stoploss is on)
                                                    if (priceType ==
                                                            "SL Limit" ||
                                                        priceType ==
                                                            "SL MKT") ...[
                                                      triggerOption(
                                                          theme,
                                                          context,
                                                          widget.scripInfo),
                                                    ],
                                                    // Divider after Stoploss order
                                                    Divider(
                                                        color: theme.isDarkMode
                                                            ? Colors.transparent
                                                            : colors.colorDivider,
                                                        thickness: 0.5,),

                                                    // Add validity & Disclosed Qty (only if not CO-BO)
                                                    if (!(orderType ==
                                                        "CO - BO")) ...[
                                                      Theme(
                                                        data: ThemeData(
                                                          unselectedWidgetColor: theme
                                                                  .isDarkMode
                                                              ? colors
                                                                  .textPrimaryDark
                                                              : colors
                                                                  .textPrimaryLight,
                                                        ),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 5),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Flexible(
                                                                child: Text(
                                                                  'Add validity & Disclosed quantity',
                                                                  style:
                                                                      WebTextStyles
                                                                          .sub(
                                                                    isDarkTheme:
                                                                        theme
                                                                            .isDarkMode,
                                                                    color: resolveThemeColor(context,
                                                                        dark: MyntColors.textPrimaryDark,
                                                                        light: MyntColors.textSecondary),
                                                                  ),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                              // Text(
                                                              //   'Add validity & Disclosed quantity',
                                                              //   style: textStyle(
                                                              //     theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                                                              //     14,
                                                              //     FontWeight.w400,
                                                              //   ),
                                                              // ),
                                                              Checkbox(
                                                                value:
                                                                    _addValidityAndDisclosedQty,
                                                                onChanged:
                                                                    (bool?
                                                                        value) {
                                                                  setState(() {
                                                                    _addValidityAndDisclosedQty =
                                                                        value ??
                                                                            false;
                                                                  });
                                                                },
                                                                activeColor: colors
                                                                    .colorBlue,
                                                                checkColor:
                                                                    Colors
                                                                        .white,
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

                                                if (!(orderType ==
                                                    "CO - BO")) ...[
                                                  // AMO switch section
                                                  Divider(
                                                        color: theme.isDarkMode
                                                            ? Colors.transparent
                                                            : colors.colorDivider,
                                                        thickness: 0.5,),
                                                  Theme(
                                                    data: ThemeData(
                                                      unselectedWidgetColor: theme
                                                              .isDarkMode
                                                          ? colors
                                                              .textPrimaryDark
                                                          : colors
                                                              .textPrimaryLight,
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
                                                          Text(
                                                            'After market order (AMO)',
                                                            style: WebTextStyles
                                                                .sub(
                                                              isDarkTheme: theme
                                                                  .isDarkMode,
                                                              color: resolveThemeColor(context,
                                                                  dark: MyntColors.textPrimaryDark,
                                                                  light: MyntColors.textSecondary),
                                                            ),
                                                          ),
                                                          // Text(
                                                          //   'After market order (AMO)',
                                                          //   style: textStyle(
                                                          //     theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                                                          //     14,
                                                          //     FontWeight.w400,
                                                          //   ),
                                                          // ),
                                                          Checkbox(
                                                            value:
                                                                _afterMarketOrder,
                                                            onChanged:
                                                                (bool? value) {
                                                              setState(() {
                                                                _afterMarketOrder =
                                                                    value ??
                                                                        false;
                                                                // isAmo = !isAmo; // if needed
                                                              });
                                                            },
                                                            activeColor: colors
                                                                .colorBlue,
                                                            checkColor:
                                                                Colors.white,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],

                                                // Divider(
                                                //         color: resolveThemeColor(
                                                //             context,
                                                //             dark: colors
                                                //                 .darkColorDivider,
                                                //             light: colors
                                                //                 .colorDivider),thickness: 0.5,),
                                                // SizedBox(
                                                //     height: priceType == "Market"
                                                //         ? 180
                                                //         : 100)
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      // ],
                                      if (orderType == "CO - BO") ...[
                                         // Divider(
                                                //         color: resolveThemeColor(
                                                //             context,
                                                //             dark: colors
                                                //                 .darkColorDivider,
                                                //             light: colors
                                                //                 .colorDivider),thickness: 0.5,),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 16,
                                                        vertical: 12),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          'Cover - Only SL',
                                                          style:
                                                              WebTextStyles.sub(
                                                            isDarkTheme: theme
                                                                .isDarkMode,
                                                            color: resolveThemeColor(context,
                                                                dark: MyntColors
                                                                    .textPrimaryDark,
                                                                light: MyntColors
                                                                    .textSecondary),
                                                          ),
                                                        ),
                                                        // Text(
                                                        //   'Cover - Only SL',
                                                        //   style: textStyle(
                                                        //     theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                                                        //     14,
                                                        //     FontWeight.w400,
                                                        //   ),
                                                        // ),
                                                        Checkbox(
                                                          value:
                                                              _isCoverOrderEnabled,
                                                          onChanged:
                                                              (bool? value) {
                                                            setState(() {
                                                              _isCoverOrderEnabled =
                                                                  value ??
                                                                      false;
                                                              _isBracketOrderEnabled =
                                                                  !_isCoverOrderEnabled;

                                                              // updatePriceType();
                                                              // orderInput.chngPriceType(priceType, widget.orderArg.exchange);
                                                              orderInput
                                                                  .chngOrderType(
                                                                orderType,
                                                                _isCoverOrderEnabled,
                                                                _isBracketOrderEnabled,
                                                              );
                                                              _debouncedMarginUpdate();
                                                            });
                                                          },
                                                          activeColor:
                                                              colors.colorBlue,
                                                          checkColor:
                                                              Colors.white,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 16,
                                                        vertical: 12),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          'Bracket - TGT / SL',
                                                          style:
                                                              WebTextStyles.sub(
                                                            isDarkTheme: theme
                                                                .isDarkMode,
                                                            color: resolveThemeColor(context,
                                                                dark: MyntColors
                                                                    .textPrimaryDark,
                                                                light: MyntColors
                                                                    .textSecondary),
                                                          ),
                                                        ),
                                                        // Text(
                                                        Checkbox(
                                                          value:
                                                              _isBracketOrderEnabled,
                                                          onChanged:
                                                              (bool? value) {
                                                            setState(() {
                                                              _isBracketOrderEnabled =
                                                                  value ??
                                                                      false;
                                                              _isCoverOrderEnabled =
                                                                  !_isBracketOrderEnabled;

                                                              orderInput
                                                                  .chngOrderType(
                                                                orderType,
                                                                _isCoverOrderEnabled,
                                                                _isBracketOrderEnabled,
                                                              );
                                                              _debouncedMarginUpdate();
                                                            });
                                                          },
                                                          activeColor:
                                                              colors.colorBlue,
                                                          checkColor:
                                                              Colors.white,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Divider(
                                                    color: theme.isDarkMode
                                                        ? Colors.transparent
                                                        : colors.colorDivider),
                                              ],
                                            ),
                                              const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                
                                            if (_isBracketOrderEnabled) ...[
                                              targetOption(theme, context,
                                                  widget.scripInfo),
                                              // const SizedBox(width: 10)
                                            ],

                                            //    if (_isCoverOrderEnabled) ...[
                                            stopLossOption(theme, context,
                                                widget.scripInfo),
                                                
                                              ],
                                            ),
                                            const SizedBox(height: 10),

                                            if (_isBracketOrderEnabled) ...[
                                              trailingTicksOption(theme,
                                                  context, widget.scripInfo),
                                            ],
                                            // const SizedBox(height: 30),
                                            // ],
                                            // Text( "Cover: ${_isCoverOrderEnabled} Bracket: ${_isBracketOrderEnabled}"),
                                            // Text("Order Type: ${orderType}"),
                                          ],
                                        ),
                                      ],

                                      // if (priceType == "Market" || priceType == "SL MKT") ...[
                                      //   const SizedBox(height: 8),
                                      //   Padding(
                                      //     padding: const EdgeInsets.symmetric(
                                      //         horizontal: 16),
                                      //     child: Text(
                                      //         "A market order carries the risk of execution at a less advantageous price",
                                      //         style: textStyle(
                                      //             const Color(0xff666666),
                                      //             12,
                                      //             FontWeight.w500)),
                                      //   ),
                                      // ],
                                      // Divider(
                                      //     color: theme.isDarkMode
                                      //         ? colors.darkColorDivider
                                      //         : colors.colorDivider)
                                    ],
                                  ]
                                ],
                              ]),
                            ),
                          ),
                          Container(
                              color: theme.isDarkMode
                                  ? MyntColors.backgroundColorDark
                                  : MyntColors.backgroundColor,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (orderType != "GTT" &&
                                        orderType != "SIP") ...[
                                      if (orderType == "MTF" &&
                                          !_isMTFEnabled) ...[
                                        const SizedBox.shrink()
                                      ] else ...[
                                        Container(
                                            width: MediaQuery.of(context)
                                                .size
                                                .width,
                                            decoration: BoxDecoration(
                                                color: resolveThemeColor(context, dark: MyntColors.cardDark, light: const Color(0xfffafbff)),
                                                border: Border(
                                                    top: BorderSide(
                                                        color: theme.isDarkMode
                                                            ? Colors.transparent
                                                            : colors
                                                                .colorDivider),
                                                    bottom: BorderSide(
                                                        color: theme.isDarkMode
                                                            ? Colors.transparent
                                                            : colors
                                                                .colorDivider))),
                                            padding: const EdgeInsets.only(
                                                left: 16.0, right: 3, top: 0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // if (isAvbSecu) ...[
                                                //   AnimatedBuilder(
                                                //     animation: anibuildctrl,
                                                //     builder: (context, child) {
                                                //       return Transform.translate(
                                                //         offset: Offset(
                                                //             _shakeAnimation.value *
                                                //                 sin(DateTime.now().millisecondsSinceEpoch * 0.01),
                                                //             0),
                                                //         child: GestureDetector(
                                                //           onTap: () {
                                                //             final dynamic tooltip = tooltipKey.currentState;
                                                //             tooltip?.ensureTooltipVisible(); // Manually show tooltip on tap
                                                //           },
                                                //           child: AnimatedContainer(
                                                //               duration: const Duration(milliseconds: 300),
                                                //               curve: Curves.easeInCubic,
                                                //               margin: const EdgeInsets.only(right: 16, top: 16, bottom: 0),
                                                //               padding: const EdgeInsets.all(0),
                                                //               decoration: BoxDecoration(
                                                //                 color: const Color(0xffFFF6E6),
                                                //                 borderRadius: BorderRadius.circular(6),
                                                //                 border: Border.all(
                                                //                   color: anibuildctrl.isAnimating
                                                //                       ? colors.darkred
                                                //                       : const Color(0xffFFF6E6), // Border color
                                                //                   width: anibuildctrl.isAnimating
                                                //                       ? 1.0
                                                //                       : 0.0, // Border width (1px)
                                                //                 ),
                                                //                 boxShadow: anibuildctrl.isAnimating
                                                //                     ? [
                                                //                         BoxShadow(
                                                //                           color: colors.darkred.withOpacity(0.6),
                                                //                           blurRadius: 10,
                                                //                           spreadRadius: 3,
                                                //                           offset: const Offset(0, 0),
                                                //                         ),
                                                //                       ]
                                                //                     : [],
                                                //               ),
                                                //               child: Row(
                                                //                 mainAxisAlignment: MainAxisAlignment.start,
                                                //                 children: [
                                                //                   IconButton(
                                                //                       onPressed: () {
                                                //                         setState(() {
                                                //                           isSecu = !isSecu;
                                                //                         });
                                                //                       },
                                                //                       icon: SvgPicture.asset(
                                                //                           isSecu ? assets.checkedbox : assets.checkbox)),
                                                //                   Expanded(
                                                //                       // Ensures text takes available space and wraps
                                                //                       child: Column(
                                                //                     crossAxisAlignment: CrossAxisAlignment.start,
                                                //                     children: [
                                                //                       RichText(
                                                //                         text: TextSpan(
                                                //                           style: textStyle(
                                                //                             const Color(0xffB37702),
                                                //                             13,
                                                //                             FontWeight.w500,
                                                //                           ),
                                                //                           children: [
                                                //                             const WidgetSpan(
                                                //                               child: Icon(Icons.warning_outlined,
                                                //                                   color: Color.fromARGB(190, 255, 170, 0),
                                                //                                   size: 16),
                                                //                             ),
                                                //                             const TextSpan(
                                                //                                 text:
                                                //                                     " Exchange surveillance active — confirm to proceed with your order."),
                                                //                             WidgetSpan(
                                                //                               child: Tooltip(
                                                //                                 key: tooltipKey,
                                                //                                 // enableTapToDismiss: false,
                                                //                                 preferBelow: false,
                                                //                                 message: quotemsg,
                                                //                                 textStyle: const TextStyle(
                                                //                                   color: Colors.white,
                                                //                                   fontSize: 13,
                                                //                                 ),
                                                //                                 padding: const EdgeInsets.symmetric(
                                                //                                     vertical: 8, horizontal: 16),
                                                //                                 margin: const EdgeInsets.symmetric(
                                                //                                     horizontal: 16),
                                                //                                 decoration: BoxDecoration(
                                                //                                   color: Colors.black,
                                                //                                   borderRadius: BorderRadius.circular(8),
                                                //                                 ),
                                                //                                 child: Text(
                                                //                                   " Know more",
                                                //                                   style: textStyle(
                                                //                                     !theme.isDarkMode
                                                //                                         ? colors.colorBlue
                                                //                                         : colors.colorLightBlue,
                                                //                                     13,
                                                //                                     FontWeight.w500,
                                                //                                   ),
                                                //                                 ),
                                                //                               ),
                                                //                             ),
                                                //                           ],
                                                //                         ),
                                                //                         softWrap: true,
                                                //                       ),
                                                //                     ],
                                                //                   ))
                                                //                 ],
                                                //               )),
                                                //         ),
                                                //       );
                                                //     },
                                                //   ),
                                                // ],
                                                SingleChildScrollView(
                                                  padding:
                                                      const EdgeInsets.all(0),
                                                  scrollDirection:
                                                      Axis.horizontal,
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
                                                                      _debouncedMarginUpdate();
                                                                      BrokerageInput brokerageInput = BrokerageInput(
                                                                          exch:
                                                                              "${widget.scripInfo.exch}",
                                                                          prc: priceCtrl
                                                                              .text,
                                                                          prd: orderInput
                                                                              .orderType,
                                                                          qty:
                                                                              "${widget.scripInfo.ls}",
                                                                          trantype: isBuy!
                                                                              ? "B"
                                                                              : "S",
                                                                          tsym:
                                                                              "${widget.scripInfo.tsym}");
                                                                      ref.read(orderProvider).fetchGetBrokerage(
                                                                          brokerageInput,
                                                                          context);

                                                                      {
                                                                        // On web, show dialog as overlay entry above the order screen
                                                                        final overlay = Overlay.of(
                                                                            context,
                                                                            rootOverlay:
                                                                                true);
                                                                        late OverlayEntry
                                                                            dialogOverlayEntry;

                                                                        dialogOverlayEntry =
                                                                            OverlayEntry(
                                                                          builder: (overlayContext) =>
                                                                              Stack(
                                                                            children: [
                                                                              // Backdrop
                                                                              Positioned.fill(
                                                                                child: GestureDetector(
                                                                                  onTap: () {
                                                                                    dialogOverlayEntry.remove();
                                                                                  },
                                                                                  child: Container(
                                                                                    color: Colors.black.withOpacity(0.5),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              // Dialog centered
                                                                              Center(
                                                                                child: Material(
                                                                                  color: Colors.transparent,
                                                                                  child: MarginDetailsDialogWeb(
                                                                                    onClose: () {
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
                                                                      }
                                                                    },
                                                              widget: Row(
                                                                  children: [
                                                                    Text(
                                                                      "Required ",
                                                                      style: WebTextStyles
                                                                          .para(
                                                                        isDarkTheme:
                                                                            theme.isDarkMode,
                                                                        color: resolveThemeColor(context,
                                                                  dark: MyntColors.textPrimaryDark,
                                                                  light: MyntColors.textSecondary),
                                                                      ),
                                                                    ),

                                                                    Text(
                                                                      "${(orderProvide.orderMarginModel == null ? "0.00" : orderProvide.orderMarginModel!.ordermargin ?? "0.00").toIndianFormat()}  + ${(orderProvide.getBrokerageModel == null ? "0.00" : orderProvide.getBrokerageModel!.brkageAmt ?? "0.00").toIndianFormat()}",
                                                                      style: WebTextStyles
                                                                          .para(
                                                                        isDarkTheme:
                                                                            theme.isDarkMode,
                                                                        color: theme.isDarkMode
                                                                            ? MyntColors.primaryDark
                                                                            : MyntColors.primary,
                                                                        fontWeight:
                                                                            WebFonts.semiBold,
                                                                      ),
                                                                    ),

                                                                    // Text(
                                                                    //     "${orderProvide.orderMarginModel == null ? 0.00 : orderProvide.orderMarginModel!.ordermargin}  + ${orderProvide.getBrokerageModel == null ? 0.00 : orderProvide.getBrokerageModel!.brkageAmt ?? 0.00}",
                                                                    //     style: textStyle(
                                                                    //         !theme.isDarkMode ? colors.colorBlue : colors.colorLightBlue,
                                                                    //         12,
                                                                    //         FontWeight.bold)),
                                                                    Icon(
                                                                        Icons
                                                                            .arrow_drop_down,
                                                                        color: theme.isDarkMode ?
                                                                            MyntColors.primaryDark : MyntColors.primary
                                                                            )
                                                                  ])),

                                                          const SizedBox(
                                                              width: 16),
                                                          Row(
                                                            children: [
                                                              Text(
                                                                "Balance ",
                                                                style:
                                                                    WebTextStyles
                                                                        .para(
                                                                  isDarkTheme: theme
                                                                      .isDarkMode,
                                                                  color: resolveThemeColor(context,
                                                                  dark: MyntColors.textPrimaryDark,
                                                                  light: MyntColors.textSecondary),
                                                                ),
                                                              ),
                                                              // const SizedBox(width: 4),
                                                              Text(
                                                                " ${(clientFundDetail?.avlMrg ?? '0.00').toIndianFormat()}",
                                                                style:
                                                                    WebTextStyles
                                                                        .para(
                                                                  isDarkTheme: theme
                                                                      .isDarkMode,
                                                                  color: resolveThemeColor(context,
                                                                  dark: MyntColors.textPrimaryDark,
                                                                  light: MyntColors.textPrimary),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 4),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          orderProvide.orderMarginModel !=
                                                                  null
                                                              ? orderProvide
                                                                          .orderMarginModel!
                                                                          .remarks ==
                                                                      "Insufficient Balance"
                                                                  ? InkWell(
                                                                      onTap:
                                                                          () {
                                                                        // ref.read(transcationProvider).fetchValidateToken(
                                                                        //     context);
                                                                        // Future.delayed(
                                                                        //     const Duration(milliseconds: 100),
                                                                        //     () async {
                                                                        //   await trancation
                                                                        //       .ip();
                                                                        //   await trancation.fetchupiIdView(
                                                                        //       trancation.bankdetails!.dATA![trancation.indexss][1],
                                                                        //       trancation.bankdetails!.dATA![trancation.indexss][2]);
                                                                        //   await trancation
                                                                        //       .fetchcwithdraw(context);
                                                                        // });

                                                                        // trancation
                                                                        //     .changebool(true);
                                                                        // showDialog(
                                                                        //     context:
                                                                        //         context,
                                                                        //     builder: (context) =>
                                                                        //         FundScreenWeb(dd: trancation));
                                                                        openFunds('fund', context);
                                                                      },
                                                                      child:
                                                                          Row(
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
                                                                              style: WebTextStyles.para(
                                                                                isDarkTheme: theme.isDarkMode,
                                                                                color: theme.isDarkMode ? MyntColors.primaryDark : MyntColors.primary,
                                                                                fontWeight: WebFonts.semiBold,
                                                                              )),
                                                                          const SizedBox(
                                                                              width: 8),
                                                                        ],
                                                                      ),
                                                                    )
                                                                  : const SizedBox()
                                                              : const SizedBox(),

                                                          // CustomWidgetButton(
                                                          //     onPress: internet
                                                          //                 .connectionStatus ==
                                                          //             ConnectivityResult
                                                          //                 .none
                                                          //         ? () {}
                                                          //         : () {
                                                          //             BrokerageInput brokerageInput = BrokerageInput(
                                                          //                 exch:"${widget.scripInfo.exch}",
                                                          //                 prc: priceCtrl.text,
                                                          //                 prd: orderInput.orderType,
                                                          //                 qty:"${widget.scripInfo.ls}",
                                                          //                 trantype: isBuy!? "B": "S",
                                                          //                 tsym:"${widget.scripInfo.tsym}");
                                                          //                 ref.read(orderProvider)
                                                          //                 .fetchGetBrokerage(brokerageInput,context);
                                                          //             showModalBottomSheet(useSafeArea:true,
                                                          //                 isScrollControlled:true,
                                                          //                 shape: const RoundedRectangleBorder(
                                                          //                 borderRadius: BorderRadius.vertical(
                                                          //                 top: Radius.circular(16))),
                                                          //                 context:context,
                                                          //                 builder:(context) {
                                                          //                   return const ChargesDetailsBottomsheet();
                                                          //                 });
                                                          //           },
                                                          //     widget: Row(
                                                          //         children: [
                                                          //           Text(
                                                          //               "Charges: ",
                                                          //               style: textStyle(
                                                          //                   const Color(
                                                          //                       0xff666666),
                                                          //                   12,
                                                          //                   FontWeight
                                                          //                       .w500)),
                                                          //           Text(
                                                          //               "₹${orderProvide.getBrokerageModel == null ? 0.00 : orderProvide.getBrokerageModel!.brkageAmt ?? 0.00}",
                                                          //               style: textStyle(
                                                          //                   !theme.isDarkMode
                                                          //                       ? colors.colorBlue
                                                          //                       : colors.colorLightBlue,
                                                          //                   12,
                                                          //                   FontWeight.w600)),
                                                          //           Icon(
                                                          //               Icons
                                                          //                   .arrow_drop_down,
                                                          //               color: !theme.isDarkMode
                                                          //                   ? colors
                                                          //                       .colorBlue
                                                          //                   : colors
                                                          //                       .colorLightBlue)
                                                          //         ]))
                                                        ]),
                                                        IconButton(
                                                            onPressed: internet
                                                                        .connectionStatus ==
                                                                    ConnectivityResult
                                                                        .none
                                                                ? null
                                                                : () {
                                                                    _debouncedMarginUpdate();
                                                                  },
                                                            icon: SvgPicture
                                                                .asset(assets
                                                                    .reloadIcon)),
                                                      ]),
                                                ),
                                              ],
                                            ))
                                      ],
                                    ],
                                    if (orderType == "MTF" &&
                                        !_isMTFEnabled) ...[
                                      const SizedBox.shrink()
                                    ] else ...[
                                      Builder(
                                        builder: (context) {
                                          final closeNotifier =
                                              _PlaceOrderDialogCloseNotifier.of(
                                                  context);
                                          return Padding(
                                            padding: const EdgeInsets.all(10.0),
                                            child: Row(
                                              children: [
                                                // Expanded(
                                                //   child: Container(
                                                //     height: 40,
                                                //     decoration: BoxDecoration(
                                                //       border: theme.isDarkMode
                                                //           ? null
                                                //           : Border.all(
                                                //               color: colors
                                                //                   .primaryLight,
                                                //               width: 1),
                                                //       color: theme.isDarkMode
                                                //           ? colors
                                                //               .textSecondaryDark
                                                //               .withOpacity(0.6)
                                                //           : colors.btnBg,
                                                //       borderRadius:
                                                //           BorderRadius.circular(
                                                //               5),
                                                //     ),
                                                //     child: Material(
                                                //       color: Colors.transparent,
                                                //       shape:
                                                //           const BeveledRectangleBorder(),
                                                //       child: InkWell(
                                                //         customBorder:
                                                //             const BeveledRectangleBorder(),
                                                //         splashColor: theme
                                                //                 .isDarkMode
                                                //             ? colors
                                                //                 .splashColorDark
                                                //             : colors
                                                //                 .splashColorLight,
                                                //         highlightColor: theme
                                                //                 .isDarkMode
                                                //             ? colors
                                                //                 .highlightDark
                                                //             : colors
                                                //                 .highlightLight,
                                                //         onTap: closeNotifier
                                                //             ?.onClose,
                                                //         child: Center(
                                                //           child: Text(
                                                //             "Close",
                                                //             style: WebTextStyles
                                                //                 .buttonMd(
                                                //               isDarkTheme: theme
                                                //                   .isDarkMode,
                                                //               color: theme.isDarkMode
                                                //                   ? colors
                                                //                       .colorWhite
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
                                                      onPressed: internet
                                                                  .connectionStatus ==
                                                              ConnectivityResult
                                                                  .none
                                                          ? null
                                                          : () async {
                                                              if (!orderProvide
                                                                  .orderloader) {
                                                                if (orderType ==
                                                                    "SIP") {
                                                                  if (sipqtyctrl
                                                                          .text
                                                                          .isEmpty ||
                                                                      sipqtyctrl
                                                                              .text ==
                                                                          "0") {
                                                                    ResponsiveSnackBar.showWarning(
                                                                        context,
                                                                        sipqtyctrl.text.isEmpty
                                                                            ? "Quantity cannot be empty"
                                                                            : "Quantity cannot be 0");
                                                                  } else if (sip
                                                                          .numberofSips
                                                                          .text
                                                                          .isEmpty ||
                                                                      sip.numberofSips
                                                                              .text ==
                                                                          "0") {
                                                                    ResponsiveSnackBar.showWarning(
                                                                        context,
                                                                        sip.numberofSips.text.isEmpty
                                                                            ? "Number of SIP cannot be empty"
                                                                            : "Number of SIP cannot be 0");
                                                                  } else {
                                                                    bool sipQty = int.tryParse(sipqtyctrl.text) !=
                                                                            null
                                                                        ? true
                                                                        : false;
                                                                    bool numberOfSips = int.tryParse(sip.numberofSips.text) !=
                                                                            null
                                                                        ? true
                                                                        : false;

                                                                    if (!sipQty ||
                                                                        !numberOfSips) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "Provide a valid value for SIP");
                                                                    } else {
                                                                      sipOrder(
                                                                          ref);
                                                                    }
                                                                  }
                                                                } else if (orderType ==
                                                                    "GTT") {
                                                                  // Guard: Amount-mode (stocks) can produce qty 0 when amount < LTP.
                                                                  // Block submission and tell the user before any other validation runs.
                                                                  final computedQty = SafeParse.toDouble(
                                                                      getGTTFinalQuantity(orderInput.qtyCtrl.text));
                                                                  if (orderInput.qtyCtrl.text.trim().isNotEmpty &&
                                                                      computedQty <= 0) {
                                                                    ResponsiveSnackBar.showWarning(
                                                                        context,
                                                                        _isStock && _isQtyToAmount
                                                                            ? "Minimum Allowed Amount should be greater than ${widget.orderArg.ltp}"
                                                                            : "Quantity cannot be 0");
                                                                    return;
                                                                  }
                                                                  if (orderInput.disableGTTCond) {
                                                                    final computedOcoQty = SafeParse.toDouble(
                                                                        getGTTFinalQuantity(orderInput.ocoQtyCtrl.text));
                                                                    if (orderInput.ocoQtyCtrl.text.trim().isNotEmpty &&
                                                                        computedOcoQty <= 0) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          _isStock && _isQtyToAmount
                                                                              ? "Minimum Allowed Amount should be greater than ${widget.orderArg.ltp}"
                                                                              : "Quantity cannot be 0");
                                                                      return;
                                                                    }
                                                                  }
                                                                  if (orderInput
                                                                      .disableGTTCond) {
                                                                    if ((orderInput.val1Ctrl.text.isNotEmpty &&
                                                                            orderInput
                                                                                .val2Ctrl.text.isNotEmpty &&
                                                                            orderInput
                                                                                .priceCtrl.text.isNotEmpty &&
                                                                            orderInput
                                                                                .ocoPriceCtrl.text.isNotEmpty &&
                                                                            orderInput
                                                                                .ocoQtyCtrl.text.isNotEmpty) &&
                                                                        orderInput
                                                                            .qtyCtrl
                                                                            .text
                                                                            .isNotEmpty &&
                                                                        double.tryParse(orderInput.val1Ctrl.text) !=
                                                                            null &&
                                                                        double.tryParse(orderInput.val1Ctrl.text)! >
                                                                            0 &&
                                                                        double.tryParse(orderInput.val2Ctrl.text) !=
                                                                            null &&
                                                                        double.tryParse(orderInput.val2Ctrl.text)! >
                                                                            0 &&
                                                                        double.tryParse(orderInput.qtyCtrl.text) !=
                                                                            null &&
                                                                        double.tryParse(orderInput.qtyCtrl.text)! >
                                                                            0 &&
                                                                        double.tryParse(orderInput.ocoQtyCtrl.text) !=
                                                                            null &&
                                                                        double.tryParse(orderInput.ocoQtyCtrl.text)! >
                                                                            0 &&
                                                                        (orderInput.priceCtrl.text ==
                                                                                "Market" ||
                                                                            (double.tryParse(orderInput.priceCtrl.text) != null &&
                                                                                double.tryParse(orderInput.priceCtrl.text)! >
                                                                                    0)) &&
                                                                        (orderInput.ocoPriceCtrl.text ==
                                                                                "Market" ||
                                                                            (double.tryParse(orderInput.ocoPriceCtrl.text) != null &&
                                                                                double.tryParse(orderInput.ocoPriceCtrl.text)! > 0))) {
                                                                      // if (orderInput
                                                                      //             .actOcoPrcType == "SL Limit" ||
                                                                      //     orderInput
                                                                      //             .actOcoPrcType == "SL MKT") {
                                                                      //   if (orderInput
                                                                      //       .ocoTrgPrcCtrl
                                                                      //       .text
                                                                      //       .isEmpty) {
                                                                      //     ScaffoldMessenger.of(
                                                                      //             context)
                                                                      //         .showSnackBar(ResponsiveSnackBar.showWarning(
                                                                      //             context,
                                                                      //             "Trigger cannot be empty"));
                                                                      //   } else {
                                                                      //     prepareToPlaceOCOOrder(orderInput);
                                                                      //   }
                                                                      // }
                                                                      // else {
                                                                      // Use live WebSocket LTP for validation, fallback to orderArg.ltp
                                                                      double ltp = SafeParse.toDouble(widget.orderArg.ltp);
                                                                      final wsData = ref.read(websocketProvider).socketDatas[widget.scripInfo.token];
                                                                      if (wsData != null) {
                                                                        final wsLtp = SafeParse.toDouble(wsData['lp']);
                                                                        if (wsLtp > 0) ltp = wsLtp;
                                                                      }
                                                                      double
                                                                          val1 =
                                                                          SafeParse.toDouble(orderInput
                                                                              .val1Ctrl
                                                                              .text);
                                                                      double
                                                                          val2 =
                                                                          SafeParse.toDouble(orderInput
                                                                              .val2Ctrl
                                                                              .text);

                                                                      // SELL OCO: target > LTP, stoploss < LTP. BUY OCO (F&O): target < LTP, stoploss > LTP.
                                                                      final bool ocoConditionValid = (isBuy ?? false)
                                                                          ? (val1 < ltp && val2 > ltp)
                                                                          : (val1 > ltp && val2 < ltp);

                                                                      if (ocoConditionValid) {
                                                                        prepareToPlaceOCOOrder(
                                                                            orderInput);
                                                                      } else {
                                                                        final String ocoErrorMsg = (isBuy ?? false)
                                                                            ? (val1 >= ltp
                                                                                ? "Target trigger price cannot be greater than or equal to LTP"
                                                                                : val2 <= ltp
                                                                                    ? "Stoploss trigger price cannot be less than or equal to LTP"
                                                                                    : "Invalid trigger prices")
                                                                            : (val1 <= ltp
                                                                                ? "Target trigger price cannot be less than LTP"
                                                                                : val2 >= ltp
                                                                                    ? "Stoploss trigger price cannot be greater than LTP"
                                                                                    : "Target trigger price cannot be equal to LTP");
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            ocoErrorMsg);
                                                                      }
                                                                      // }
                                                                    } else {
                                                                      if (orderInput
                                                                          .val1Ctrl
                                                                          .text
                                                                          .isEmpty) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Target trigger price cannot be empty");
                                                                      } else if (SafeParse.toDouble(orderInput.val1Ctrl.text) <=
                                                                          0) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Target trigger price cannot be 0");
                                                                      } else if (orderInput
                                                                          .qtyCtrl
                                                                          .text
                                                                          .isEmpty) {
                                                                        String qtyFieldName = (_isStock) ? (_isQtyToAmount ? 'Amount' : 'Quantity') : (_isGTTLotToQty ? 'Quantity' : 'Lot');
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "$qtyFieldName cannot be empty");
                                                                      } else if (SafeParse.toDouble(orderInput.qtyCtrl.text) <=
                                                                          0) {
                                                                        String qtyFieldName = (_isStock) ? (_isQtyToAmount ? 'Amount' : 'Quantity') : (_isGTTLotToQty ? 'Quantity' : 'Lot');
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "$qtyFieldName cannot be 0");
                                                                      } else if (orderInput
                                                                          .priceCtrl
                                                                          .text
                                                                          .isEmpty) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Price cannot be empty");
                                                                      } else if (orderInput.priceCtrl.text != "Market" &&
                                                                          double.tryParse(orderInput.priceCtrl.text) !=
                                                                              null &&
                                                                          SafeParse.toDouble(orderInput.priceCtrl.text) <=
                                                                              0) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Price cannot be 0");
                                                                      } else if (orderInput
                                                                          .val2Ctrl
                                                                          .text
                                                                          .isEmpty) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Stoploss trigger price cannot be empty");
                                                                      } else if (SafeParse.toDouble(orderInput.val2Ctrl.text) <=
                                                                          0) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Stoploss trigger price cannot be 0");
                                                                      } else if (orderInput
                                                                          .ocoQtyCtrl
                                                                          .text
                                                                          .isEmpty) {
                                                                        String ocoQtyFieldName = (_isStock) ? (_isQtyToAmount ? 'Amount' : 'Quantity') : (_isGTTLotToQty ? 'Quantity' : 'Lot');
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "OCO $ocoQtyFieldName cannot be empty");
                                                                      } else if (SafeParse.toDouble(orderInput
                                                                              .ocoQtyCtrl
                                                                              .text) <=
                                                                          0) {
                                                                        String ocoQtyFieldName = (_isStock) ? (_isQtyToAmount ? 'Amount' : 'Quantity') : (_isGTTLotToQty ? 'Quantity' : 'Lot');
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "OCO $ocoQtyFieldName cannot be 0");
                                                                      } else if (orderInput
                                                                          .ocoPriceCtrl
                                                                          .text
                                                                          .isEmpty) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "OCO price cannot be empty");
                                                                      } else if (orderInput
                                                                              .ocoPriceCtrl
                                                                              .text !=
                                                                          "Market") {
                                                                        final ocoPrice = double.tryParse(orderInput
                                                                            .ocoPriceCtrl
                                                                            .text);
                                                                        if (ocoPrice ==
                                                                            null) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Invalid OCO price");
                                                                        } else if (ocoPrice <=
                                                                            0) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "OCO price cannot be 0");
                                                                        }
                                                                      } else {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Enter all Input fields");
                                                                      }
                                                                    }
                                                                  } else {
                                                                    if ((orderInput.val1Ctrl.text.isNotEmpty &&
                                                                            orderInput
                                                                                .priceCtrl.text.isNotEmpty) &&
                                                                        orderInput
                                                                            .qtyCtrl
                                                                            .text
                                                                            .isNotEmpty &&
                                                                        SafeParse.toDouble(orderInput.val1Ctrl.text) >
                                                                            0 &&
                                                                        SafeParse.toDouble(orderInput.qtyCtrl.text) >
                                                                            0 &&
                                                                        (orderInput.priceCtrl.text ==
                                                                                "Market" ||
                                                                            SafeParse.toDouble(orderInput.priceCtrl.text) >
                                                                                0)) {
                                                                      // if (orderInput
                                                                      //             .actPrcType == "SL Limit" ||
                                                                      //     orderInput
                                                                      //             .actPrcType == "SL MKT") {
                                                                      //   if (orderInput
                                                                      //       .trgPrcCtrl
                                                                      //       .text
                                                                      //       .isEmpty) {
                                                                      //     ScaffoldMessenger.of(
                                                                      //             context)
                                                                      //         .showSnackBar(ResponsiveSnackBar.showWarning(
                                                                      //             context,
                                                                      //             "Trigger cannot be empty"));
                                                                      //   } else {
                                                                      //     prepareToPlaceGttOrder(orderInput);
                                                                      //   }
                                                                      // } else {

                                                                      double ltp = SafeParse.toDouble(widget.orderArg.ltp);
                                                                      final wsDataGtt = ref.read(websocketProvider).socketDatas[widget.scripInfo.token];
                                                                      if (wsDataGtt != null) {
                                                                        final wsLtpGtt = SafeParse.toDouble(wsDataGtt['lp']);
                                                                        if (wsLtpGtt > 0) ltp = wsLtpGtt;
                                                                      }
                                                                      double
                                                                          val1 =
                                                                          SafeParse.toDouble(orderInput
                                                                              .val1Ctrl
                                                                              .text);

                                                                      if (val1 >
                                                                          ltp) {
                                                                        orderInput
                                                                            .chngCond("Greater than");
                                                                        orderInput
                                                                            .chngAlert("LTP");
                                                                        prepareToPlaceGttOrder(
                                                                            orderInput);
                                                                      } else if (val1 <
                                                                          ltp) {
                                                                        orderInput
                                                                            .chngCond("Less than");
                                                                        orderInput
                                                                            .chngAlert("LTP");
                                                                        prepareToPlaceGttOrder(
                                                                            orderInput);
                                                                      } else {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Target trigger price cannot be equal to LTP");
                                                                      }
                                                                      // }
                                                                    } else {
                                                                      if (orderInput
                                                                          .val1Ctrl
                                                                          .text
                                                                          .isEmpty) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Target trigger price cannot be empty");
                                                                      } else if (SafeParse.toDouble(orderInput.val1Ctrl.text) <=
                                                                          0) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Target trigger price cannot be 0");
                                                                      } else if (orderInput
                                                                          .qtyCtrl
                                                                          .text
                                                                          .isEmpty) {
                                                                        String qtyFieldName = (_isStock) ? (_isQtyToAmount ? 'Amount' : 'Quantity') : (_isGTTLotToQty ? 'Quantity' : 'Lot');
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "$qtyFieldName cannot be empty");
                                                                      } else if (SafeParse.toDouble(orderInput.qtyCtrl.text) <=
                                                                          0) {
                                                                        String qtyFieldName = (_isStock) ? (_isQtyToAmount ? 'Amount' : 'Quantity') : (_isGTTLotToQty ? 'Quantity' : 'Lot');
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "$qtyFieldName cannot be 0");
                                                                      } else if (orderInput
                                                                          .priceCtrl
                                                                          .text
                                                                          .isEmpty) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Price cannot be empty");
                                                                      } else if (SafeParse.toDouble(orderInput.priceCtrl.text) <=
                                                                          0) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Price cannot be 0");
                                                                      } else if (orderInput
                                                                          .val2Ctrl
                                                                          .text
                                                                          .isEmpty) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Stoploss trigger price cannot be empty");
                                                                      } else if (SafeParse.toDouble(orderInput
                                                                              .val2Ctrl
                                                                              .text) <=
                                                                          0) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Stoploss trigger price cannot be 0");
                                                                      } else if (orderInput
                                                                          .ocoQtyCtrl
                                                                          .text
                                                                          .isEmpty) {
                                                                        String ocoQtyFieldName = (_isStock) ? (_isQtyToAmount ? 'Amount' : 'Quantity') : (_isGTTLotToQty ? 'Quantity' : 'Lot');
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "OCO $ocoQtyFieldName cannot be empty");
                                                                      } else if (SafeParse.toDouble(orderInput
                                                                              .ocoQtyCtrl
                                                                              .text) <=
                                                                          0) {
                                                                        String ocoQtyFieldName = (_isStock) ? (_isQtyToAmount ? 'Amount' : 'Quantity') : (_isGTTLotToQty ? 'Quantity' : 'Lot');
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "OCO $ocoQtyFieldName cannot be 0");
                                                                      } else if (orderInput
                                                                          .ocoPriceCtrl
                                                                          .text
                                                                          .isEmpty) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "OCO price cannot be empty");
                                                                      } else if (SafeParse.toDouble(orderInput
                                                                              .ocoPriceCtrl
                                                                              .text) <=
                                                                          0) {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "OCO price cannot be 0");
                                                                      } else {
                                                                        ResponsiveSnackBar.showWarning(
                                                                            context,
                                                                            "Enter all Input fields");
                                                                      }
                                                                    }
                                                                  }
                                                                } else {
                                                                  setState(() {
                                                                    if (frezQty ==
                                                                        0) {
                                                                      quantity = SafeParse.toInt(getFinalQuantity(qtyCtrl.text));
                                                                      // frezQty;
                                                                    } else {
                                                                      quantity = SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) ~/
                                                                          frezQty;
                                                                    }
                                                                    reminder = SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) -
                                                                        (frezQty *
                                                                            quantity);
                                                                    maxQty =
                                                                        frezQty *
                                                                            frezQtyOrderSliceMaxLimit;
                                                                  });
                                                                  if (getFinalQuantity(qtyCtrl.text)
                                                                          .trim()
                                                                          .isEmpty ||
                                                                      priceCtrl.text
                                                                          .trim()
                                                                          .isEmpty) {
                                                                    String fieldName = (_isStock)
                                                                        ? (_isQtyToAmount
                                                                            ? "Amount"
                                                                            : "Quantity")
                                                                        : widget.scripInfo.exch == "MCX"
                                                                            ? "Lot"
                                                                            : (_isLotToQty
                                                                                ? "Quantity"
                                                                                : "Lot");
                                                                    ResponsiveSnackBar.showWarning(
                                                                        context,
                                                                        getFinalQuantity(qtyCtrl.text).isEmpty
                                                                            ? "$fieldName cannot be empty"
                                                                            : "Price cannot be empty");
                                                                  } else if ((getFinalQuantity(qtyCtrl.text).trim()) == "0" ||
                                                                      priceCtrl.text.trim() ==
                                                                          "0") {
                                                                    String fieldName = (_isStock)
                                                                        ? (_isQtyToAmount
                                                                            ? "Amount"
                                                                            : "Quantity")
                                                                        : widget.scripInfo.exch == "MCX"
                                                                            ? "Lot"
                                                                            : (_isLotToQty
                                                                                ? "Quantity"
                                                                                : "Lot");
                                                                    ResponsiveSnackBar.showWarning(
                                                                        context,
                                                                        getFinalQuantity(qtyCtrl.text) == "0"
                                                                            ? (_isStock)
                                                                                ? (_isQtyToAmount ? (qtyCtrl.text != "0" ? "Minimum Allowed Amount should be greater than ${widget.orderArg.ltp}" : "Amount cannot be 0") : "Quantity cannot be 0")
                                                                                : "$fieldName cannot be 0"
                                                                            : "Price cannot be 0");
                                                                  } else if (frezQty > lotSize &&
                                                                      SafeParse.toInt(getFinalQuantity(qtyCtrl.text).trim()) >
                                                                          frezQtyOrderSliceMaxLimit *
                                                                              frezQty) {
                                                                    ResponsiveSnackBar.showWarning(
                                                                        context,
                                                                        _freezeCapMessage());
                                                                  } else if ((priceType == "Limit" || priceType == "SL Limit") &&
                                                                      _hasValidCircuitBreakerValues &&
                                                                      ((SafeParse.toDouble(ordPrice) < SafeParse.toDouble(widget.scripInfo.lc)) ||
                                                                          (SafeParse.toDouble(ordPrice) >
                                                                              SafeParse.toDouble(widget
                                                                                  .scripInfo.uc)))) {
                                                                    ResponsiveSnackBar.showWarning(
                                                                        context,
                                                                        SafeParse.toDouble(ordPrice) <
                                                                                SafeParse.toDouble(widget.scripInfo.lc)
                                                                            ? "Price cannot be lesser than Lower Circuit Limit ${widget.scripInfo.lc}"
                                                                            : "Price cannot be greater than Upper Circuit Limit ${widget.scripInfo.uc}");
                                                                  } else if ((orderType == "Delivery" || orderType == "Intraday") &&
                                                                      (priceType == "SL Limit" ||
                                                                          priceType ==
                                                                              "SL MKT")) {
                                                                    if (triggerPriceCtrl
                                                                            .text
                                                                            .isEmpty ||
                                                                        triggerPriceCtrl.text ==
                                                                            "0") {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          triggerPriceCtrl.text.isEmpty
                                                                              ? "Trigger cannot be empty"
                                                                              : "Trigger cannot be 0");
                                                                    } else {
                                                                      if (isBuy!) {
                                                                        if (priceType ==
                                                                            "SL MKT") {
                                                                          if (SafeParse.toDouble(triggerPriceCtrl.text) <
                                                                              SafeParse.toDouble(widget.orderArg.ltp)) {
                                                                            ResponsiveSnackBar.showWarning(context,
                                                                                "Trigger should be greater than LTP");
                                                                          } else if (_hasValidCircuitBreakerValues &&
                                                                              SafeParse.toDouble(triggerPriceCtrl.text) > SafeParse.toDouble(widget.scripInfo.uc)) {
                                                                            ResponsiveSnackBar.showWarning(context,
                                                                                "Trigger cannot be greater than upper circuit limit of ${widget.scripInfo.uc}");
                                                                          } else {
                                                                            if ((SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) > frezQty &&
                                                                                widget.scripInfo.frzqty != null)) {
                                                                              placeOrder(orderInput, true, theme);
                                                                            } else {
                                                                              placeOrder(orderInput, false, theme);
                                                                            }
                                                                          }
                                                                        } else {
                                                                          if (_hasValidCircuitBreakerValues &&
                                                                              SafeParse.toDouble(triggerPriceCtrl.text) < SafeParse.toDouble(widget.scripInfo.lc)) {
                                                                            ResponsiveSnackBar.showWarning(context,
                                                                                "Trigger cannot be lesser than lower circuit limit of ${widget.scripInfo.lc}");
                                                                          } else if (SafeParse.toDouble(ordPrice) < SafeParse.toDouble(triggerPriceCtrl.text)) {
                                                                            ResponsiveSnackBar.showWarning(context,
                                                                                "Trigger should be less than price");
                                                                          } else if (_hasValidCircuitBreakerValues && SafeParse.toDouble(triggerPriceCtrl.text) > SafeParse.toDouble(widget.scripInfo.uc)) {
                                                                            ResponsiveSnackBar.showWarning(context,
                                                                                "Trigger cannot be greater than upper circuit limit of ${widget.scripInfo.uc}");
                                                                          } else {
                                                                            if ((SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) > frezQty &&
                                                                                widget.scripInfo.frzqty != null)) {
                                                                              placeOrder(orderInput, true, theme);
                                                                            } else {
                                                                              placeOrder(orderInput, false, theme);
                                                                            }
                                                                          }
                                                                        }
                                                                      } else {
                                                                        if (priceType ==
                                                                            "SL MKT") {
                                                                          if (SafeParse.toDouble(triggerPriceCtrl.text) >
                                                                              SafeParse.toDouble(widget.orderArg.ltp)) {
                                                                            ResponsiveSnackBar.showWarning(context,
                                                                                "Trigger should be lesser than LTP");
                                                                          } else if (_hasValidCircuitBreakerValues &&
                                                                              SafeParse.toDouble(triggerPriceCtrl.text) < SafeParse.toDouble(widget.scripInfo.lc)) {
                                                                            ResponsiveSnackBar.showWarning(context,
                                                                                "Trigger cannot be lesser than lower circuit limit of ${widget.scripInfo.lc ?? 0.00}");
                                                                          } else {
                                                                            if ((SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) > frezQty &&
                                                                                widget.scripInfo.frzqty != null)) {
                                                                              placeOrder(orderInput, true, theme);
                                                                            } else {
                                                                              placeOrder(orderInput, false, theme);
                                                                            }
                                                                          }
                                                                        } else {
                                                                          if (_hasValidCircuitBreakerValues &&
                                                                              SafeParse.toDouble(triggerPriceCtrl.text) > SafeParse.toDouble(widget.scripInfo.uc)) {
                                                                            ResponsiveSnackBar.showWarning(context,
                                                                                "Trigger cannot be greater than upper circuit limit of ${widget.scripInfo.uc ?? 0.00}");
                                                                          } else if (SafeParse.toDouble(ordPrice) > SafeParse.toDouble(triggerPriceCtrl.text)) {
                                                                            ResponsiveSnackBar.showWarning(context,
                                                                                "Trigger should be greater than price");
                                                                          } else if (_hasValidCircuitBreakerValues && SafeParse.toDouble(triggerPriceCtrl.text) < SafeParse.toDouble(widget.scripInfo.lc)) {
                                                                            ResponsiveSnackBar.showWarning(context,
                                                                                "Trigger cannot be lesser than lower circuit limit of ${widget.scripInfo.lc ?? 0.00}");
                                                                          } else {
                                                                            if ((SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) > frezQty &&
                                                                                widget.scripInfo.frzqty != null)) {
                                                                              placeOrder(orderInput, true, theme);
                                                                            } else {
                                                                              placeOrder(orderInput, false, theme);
                                                                            }
                                                                          }
                                                                        }
                                                                      }
                                                                    }
                                                                  } else if (_isCoverOrderEnabled &&
                                                                      orderType == "CO - BO" &&
                                                                      (priceType == "Limit" || priceType == "Market")) {
                                                                    if (stopLossCtrl
                                                                            .text
                                                                            .isEmpty ||
                                                                        stopLossCtrl.text ==
                                                                            "0") {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          stopLossCtrl.text.isEmpty
                                                                              ? "Stoploss cannot be empty"
                                                                              : "Stoploss cannot be 0");
                                                                    } else {
                                                                      if (isBuy!) {
                                                                        if (_hasValidCircuitBreakerValues &&
                                                                            (SafeParse.toDouble(ordPrice) - SafeParse.toDouble(stopLossCtrl.text)) <
                                                                                SafeParse.toDouble(widget.scripInfo.lc)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Price(Order price - Stoploss = ${(SafeParse.toDouble(ordPrice) - SafeParse.toDouble(stopLossCtrl.text)).toStringAsFixed(2)}) Stoploss cannot be lower than ${widget.scripInfo.lc}");
                                                                        } else {
                                                                          if ((SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) > frezQty &&
                                                                              widget.scripInfo.frzqty != null)) {
                                                                            placeOrder(
                                                                                orderInput,
                                                                                true,
                                                                                theme);
                                                                          } else {
                                                                            placeOrder(
                                                                                orderInput,
                                                                                false,
                                                                                theme);
                                                                          }
                                                                        }
                                                                      } else {
                                                                        if (_hasValidCircuitBreakerValues &&
                                                                            (SafeParse.toDouble(ordPrice) + SafeParse.toDouble(stopLossCtrl.text)) >
                                                                                SafeParse.toDouble(widget.scripInfo.uc)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Price(Order price + Stoploss = ${(SafeParse.toDouble(ordPrice) + SafeParse.toDouble(stopLossCtrl.text))}) Stoploss cannot be greater than ${widget.scripInfo.uc}");
                                                                        } else {
                                                                          if ((SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) > frezQty &&
                                                                              widget.scripInfo.frzqty != null)) {
                                                                            placeOrder(
                                                                                orderInput,
                                                                                true,
                                                                                theme);
                                                                          } else {
                                                                            placeOrder(
                                                                                orderInput,
                                                                                false,
                                                                                theme);
                                                                          }
                                                                        }
                                                                      }
                                                                    }
                                                                  } else if (_isCoverOrderEnabled && orderType == "CO - BO" && (priceType == "SL Limit")) {
                                                                    double
                                                                        userOrderPrice =
                                                                        double.tryParse(ordPrice) ??
                                                                            0;
                                                                    double
                                                                        userStopLoss =
                                                                        double.tryParse(stopLossCtrl.text) ??
                                                                            0;
                                                                    double
                                                                        userTriggerPrice =
                                                                        double.tryParse(triggerPriceCtrl.text) ??
                                                                            0;
                                                                    double lc =
                                                                        double.tryParse(widget.scripInfo.lc ??
                                                                                "0") ??
                                                                            0;
                                                                    double uc =
                                                                        double.tryParse(widget.scripInfo.uc ??
                                                                                "0") ??
                                                                            0;

                                                                    if (stopLossCtrl
                                                                            .text
                                                                            .isEmpty ||
                                                                        stopLossCtrl.text ==
                                                                            "0") {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          stopLossCtrl.text.isEmpty
                                                                              ? "Stoploss cannot be empty"
                                                                              : "Stoploss cannot be 0");
                                                                    } else if (isBuy! &&
                                                                        (userOrderPrice -
                                                                                userStopLoss) <
                                                                            lc) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "Price(Order price - Stoploss = ${(SafeParse.toDouble(ordPrice) - SafeParse.toDouble(stopLossCtrl.text)).toStringAsFixed(2)}) Stoploss cannot be lower than ${widget.scripInfo.lc ?? 0.00}");
                                                                    } else if (!isBuy! &&
                                                                        (userOrderPrice +
                                                                                userStopLoss) >
                                                                            uc) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "Price(Order price + Stoploss = ${(SafeParse.toDouble(ordPrice) + SafeParse.toDouble(stopLossCtrl.text))}) Stoploss cannot be greater than ${widget.scripInfo.uc ?? 0.00}");
                                                                    } else if ((triggerPriceCtrl.text.isEmpty ||
                                                                            triggerPriceCtrl.text ==
                                                                                "0") &&
                                                                        priceType ==
                                                                            "SL Limit") {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          triggerPriceCtrl.text.isEmpty
                                                                              ? "Trigger cannot be empty"
                                                                              : "Trigger cannot be 0");
                                                                    } else {
                                                                      if (isBuy!) {
                                                                        if (userTriggerPrice <
                                                                            lc) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger cannot be lesser than lower circuit limit of $lc");
                                                                        } else if (userOrderPrice <
                                                                            userTriggerPrice) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger should be less than price");
                                                                        } else if (userTriggerPrice >
                                                                            uc) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger cannot be greater than upper circuit limit of $uc");
                                                                        } else {
                                                                          if (SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) > frezQty &&
                                                                              widget.scripInfo.frzqty != null) {
                                                                            placeOrder(
                                                                                orderInput,
                                                                                true,
                                                                                theme);
                                                                          } else {
                                                                            placeOrder(
                                                                                orderInput,
                                                                                false,
                                                                                theme);
                                                                          }
                                                                        }
                                                                      } else {
                                                                        if (userTriggerPrice >
                                                                            uc) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger cannot be greater than upper circuit limit of $uc");
                                                                        } else if (userOrderPrice >
                                                                            userTriggerPrice) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger should be greater than price");
                                                                        } else if (userTriggerPrice <
                                                                            lc) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger cannot be lesser than lower circuit limit of ${widget.scripInfo.lc ?? 0.00}");
                                                                        } else {
                                                                          if (SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) > frezQty &&
                                                                              widget.scripInfo.frzqty != null) {
                                                                            placeOrder(
                                                                                orderInput,
                                                                                true,
                                                                                theme);
                                                                          } else {
                                                                            placeOrder(
                                                                                orderInput,
                                                                                false,
                                                                                theme);
                                                                          }
                                                                        }
                                                                      }
                                                                    }
                                                                  } else if (_isBracketOrderEnabled && orderType == "CO - BO" && (priceType == "Limit" || priceType == "Market")) {
                                                                    double
                                                                        tickSize =
                                                                        SafeParse.toDouble(widget
                                                                            .scripInfo
                                                                            .ti);
                                                                    double
                                                                        enteredValue =
                                                                        double.tryParse(trailingTicksCtrl.text) ??
                                                                            0;
                                                                    double
                                                                        trailTicksQuotient =
                                                                        enteredValue /
                                                                            tickSize;
                                                                    double
                                                                        trailTicksRemainder =
                                                                        (trailTicksQuotient -
                                                                                trailTicksQuotient.round())
                                                                            .abs();

                                                                    if (stopLossCtrl
                                                                            .text
                                                                            .isEmpty ||
                                                                        targetCtrl
                                                                            .text
                                                                            .isEmpty) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "${targetCtrl.text.isEmpty ? "Target" : "Stoploss"} cannot be empty");
                                                                    } else if (SafeParse.toDouble(stopLossCtrl.text) <= 0 ||
                                                                        SafeParse.toDouble(targetCtrl.text) <=
                                                                            0) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "${SafeParse.toDouble(targetCtrl.text) <= 0 ? "Target" : "Stoploss"} cannot be 0");
                                                                    } else if (isBuy! &&
                                                                        _hasValidCircuitBreakerValues &&
                                                                        (SafeParse.toDouble(ordPrice) - SafeParse.toDouble(stopLossCtrl.text)) <
                                                                            SafeParse.toDouble(widget
                                                                                .scripInfo.lc)) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "Price(Order price - Stoploss = ${(SafeParse.toDouble(ordPrice) - SafeParse.toDouble(stopLossCtrl.text)).toStringAsFixed(2)}) Stoploss cannot be lower than ${widget.scripInfo.lc}");
                                                                    } else if (!isBuy! &&
                                                                        _hasValidCircuitBreakerValues &&
                                                                        (SafeParse.toDouble(ordPrice) + SafeParse.toDouble(stopLossCtrl.text)) >
                                                                            SafeParse.toDouble(widget
                                                                                .scripInfo.uc)) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "Price(Order price + Stoploss = ${(SafeParse.toDouble(ordPrice) + SafeParse.toDouble(stopLossCtrl.text))}) Stoploss cannot be greater than ${widget.scripInfo.uc}");
                                                                    } else if (trailingTicksCtrl
                                                                            .text
                                                                            .isNotEmpty &&
                                                                        (trailTicksRemainder >
                                                                            0.0001)) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "Trailing SL should be in multiples of tick size: $tickSize");
                                                                    } else if (trailingTicksCtrl
                                                                            .text
                                                                            .isNotEmpty &&
                                                                        (enteredValue <=
                                                                            0)) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "Trailing SL should be positive value");
                                                                    } else {
                                                                      if ((SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) >
                                                                              frezQty &&
                                                                          widget.scripInfo.frzqty !=
                                                                              null)) {
                                                                        placeOrder(
                                                                            orderInput,
                                                                            true,
                                                                            theme);
                                                                      } else {
                                                                        placeOrder(
                                                                            orderInput,
                                                                            false,
                                                                            theme);
                                                                      }
                                                                    }
                                                                  } else if (_isBracketOrderEnabled && orderType == "CO - BO" && (priceType == "SL Limit")) {
                                                                    double
                                                                        userOrderPrice =
                                                                        double.tryParse(ordPrice) ??
                                                                            0;
                                                                    double
                                                                        userStopLoss =
                                                                        double.tryParse(stopLossCtrl.text) ??
                                                                            0;
                                                                    double
                                                                        userTriggerPrice =
                                                                        double.tryParse(triggerPriceCtrl.text) ??
                                                                            0;
                                                                    double lc =
                                                                        double.tryParse(widget.scripInfo.lc ??
                                                                                "0") ??
                                                                            0;
                                                                    double uc =
                                                                        double.tryParse(widget.scripInfo.uc ??
                                                                                "0") ??
                                                                            0;

                                                                    if (stopLossCtrl
                                                                            .text
                                                                            .isEmpty ||
                                                                        targetCtrl
                                                                            .text
                                                                            .isEmpty) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "${stopLossCtrl.text.isEmpty ? "Stoploss" : "Target"} cannot be empty");
                                                                    } else if (isBuy! &&
                                                                        (userOrderPrice -
                                                                                userStopLoss) <
                                                                            lc) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "Price(Order price - Stoploss = ${(SafeParse.toDouble(ordPrice) - SafeParse.toDouble(stopLossCtrl.text)).toStringAsFixed(2)}) Stoploss cannot be lower than ${widget.scripInfo.lc ?? 0.00}");
                                                                    } else if (!isBuy! &&
                                                                        (userOrderPrice +
                                                                                userStopLoss) >
                                                                            uc) {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "Price(Order price + Stoploss = ${(SafeParse.toDouble(ordPrice) + SafeParse.toDouble(stopLossCtrl.text))}) Stoploss cannot be greater than ${widget.scripInfo.uc ?? 0.00}");
                                                                    } else if (triggerPriceCtrl
                                                                            .text
                                                                            .isEmpty &&
                                                                        priceType ==
                                                                            "SL Limit") {
                                                                      ResponsiveSnackBar.showWarning(
                                                                          context,
                                                                          "Trigger cannot be empty");
                                                                    } else {
                                                                      if (isBuy!) {
                                                                        if (userTriggerPrice <
                                                                            lc) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger cannot be lesser than lower circuit limit of ${widget.scripInfo.lc ?? 0.00}");
                                                                        } else if (userOrderPrice <
                                                                            userTriggerPrice) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger should be less than price");
                                                                        } else if (userTriggerPrice >
                                                                            uc) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger cannot be greater than upper circuit limit of ${widget.scripInfo.uc ?? 0.00}");
                                                                        } else {
                                                                          if ((SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) > frezQty &&
                                                                              widget.scripInfo.frzqty != null)) {
                                                                            placeOrder(
                                                                                orderInput,
                                                                                true,
                                                                                theme);
                                                                          } else {
                                                                            placeOrder(
                                                                                orderInput,
                                                                                false,
                                                                                theme);
                                                                          }
                                                                        }
                                                                      } else {
                                                                        if (userTriggerPrice >
                                                                            uc) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger cannot be greater than upper circuit limit of ${widget.scripInfo.uc ?? 0.00}");
                                                                        } else if (userOrderPrice >
                                                                            userTriggerPrice) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger should be greater than price");
                                                                        } else if (userTriggerPrice <
                                                                            lc) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger cannot be lesser than lower circuit limit of ${widget.scripInfo.lc ?? 0.00}");
                                                                        } else {
                                                                          if ((SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) > frezQty &&
                                                                              widget.scripInfo.frzqty != null)) {
                                                                            placeOrder(
                                                                                orderInput,
                                                                                true,
                                                                                theme);
                                                                          } else {
                                                                            placeOrder(
                                                                                orderInput,
                                                                                false,
                                                                                theme);
                                                                          }
                                                                        }
                                                                      }
                                                                    }
                                                                  } else {
                                                                    if ((SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) >
                                                                            frezQty &&
                                                                        widget.scripInfo.frzqty !=
                                                                            null)) {
                                                                      placeOrder(
                                                                          orderInput,
                                                                          true,
                                                                          theme);
                                                                    } else {
                                                                      placeOrder(
                                                                          orderInput,
                                                                          false,
                                                                          theme);
                                                                    }
                                                                  }
                                                                }
                                                              }
                                                            },
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        minimumSize:
                                                            const Size(0, 40),
                                                        // padding: const EdgeInsets.symmetric(vertical: 15),
                                                        backgroundColor: (widget
                                                                        .isBasket ==
                                                                    "Basket" ||
                                                                widget.isBasket ==
                                                                    "BasketEdit" ||
                                                                widget.isBasket ==
                                                                    "BasketMode")
                                                            ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary) // Use primary color for basket mode
                                                            : isBuy!
                                                                ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary)
                                                                : resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.tertiary),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(5),
                                                        ),
                                                      ),
                                                      child: orderProvide
                                                              .orderloader
                                                          ? const SizedBox(
                                                              width: 18,
                                                              height: 20,
                                                              child: CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                  color: Color(
                                                                      0xffffffff)),
                                                            )
                                                          : Text(
                                                              (widget.isBasket == "Basket" ||
                                                                      widget.isBasket ==
                                                                          "BasketEdit" ||
                                                                      widget.isBasket ==
                                                                          "BasketMode")
                                                                  ? widget.isBasket ==
                                                                          "BasketEdit"
                                                                      ? "Edit to Basket"
                                                                      : "Add to Basket"
                                                                  : orderType ==
                                                                          "SIP"
                                                                      ? "Create SIP"
                                                                      : isBuy!
                                                                          ? 'Buy'
                                                                          : "Sell",
                                                              style:
                                                                  WebTextStyles
                                                                      .buttonMd(
                                                                isDarkTheme: theme
                                                                    .isDarkMode,
                                                                color: theme
                                                                        .isDarkMode
                                                                    ? orderType ==
                                                                            "SIP"
                                                                        ? MyntColors
                                                                            .backgroundColorDark
                                                                        : MyntColors
                                                                            .backgroundColor
                                                                    : MyntColors
                                                                        .backgroundColor,
                                                              )),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      // if (defaultTargetPlatform ==
                                      //     TargetPlatform.iOS)
                                      // const SizedBox(height: 10)
                                    ]
                                  ]))
                        ]),
                    // bottomNavigationBar:
                  )),
            ],
          );
        },
      ),
    );
  }

  Padding addValidityAndDisclosedQtyOption(
      ThemesProvider theme, BuildContext context, ScripInfoModel scripInfo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Validity field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerTitleText("Validity", theme),
              const SizedBox(height: 8),
              SizedBox(
                  height: 30,
                  child: ListView.separated(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        return ElevatedButton(
                          onPressed: () {
                            setState(() {
                              validityType = validityTypes[index];
                            });
                          },
                          style: ElevatedButton.styleFrom(
                              elevation: 0,
                              minimumSize: const Size(0, 0),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                              backgroundColor: !theme.isDarkMode
                                  ? validityType != validityTypes[index]
                                      ? const Color(0xffF1F3F8)
                                      : resolveThemeColor(context,
                                          dark: MyntColors.secondary,
                                          light: MyntColors.primary)
                                  : validityType != validityTypes[index]
                                      ? colors.darkGrey
                                      : resolveThemeColor(context,
                                          dark: MyntColors.secondary,
                                          light: MyntColors.primary),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(5)),
                              )
                              //   const StadiumBorder()
                              ),
                          child: Text(
                            validityTypes[index],
                            style: WebTextStyles.formInput(
                              isDarkTheme: theme.isDarkMode,
                              color: resolveThemeColor(context,
                                  dark:  validityType != validityTypes[index]
                                      ? MyntColors.textSecondaryDark
                                      : MyntColors.backgroundColor,
                                  light: validityType != validityTypes[index]
                                      ? MyntColors.textSecondary
                                      : MyntColors.backgroundColor),
                                  
                                  // : ,
                              fontWeight: validityType == validityTypes[index]
                                  ? WebFonts.medium
                                  : WebFonts.regular,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                      separatorBuilder: (context, index) {
                        return const SizedBox(width: 8);
                      },
                      itemCount: widget.orderArg.exchange == "BSE" ||
                              widget.orderArg.exchange == "BFO"
                          ? validityTypes.length
                          : 2)),
            ],
          ),
          const SizedBox(width: 16),
          // Disclosed Qty field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerTitleText("Disclosed Qty", theme),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                width: 200,
                child: Semantics(
                  identifier: "Disclosed Qty",
                  child: MyntTextField(
                      backgroundColor: theme.isDarkMode
                          ? colors.darkGrey
                          : const Color(0xffF1F3F8),
                      placeholder: "0",
                      placeholderStyle: WebTextStyles.formInput(
                        isDarkTheme: theme.isDarkMode,
                        color: (theme.isDarkMode
                            ? MyntColors.textSecondary
                            : MyntColors.textSecondary).withValues(alpha: 0.5),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      textStyle: WebTextStyles.formInput(
                        isDarkTheme: theme.isDarkMode,
                        color: theme.isDarkMode
                            ? MyntColors.textPrimaryDark
                            : MyntColors.textPrimary,
                      ),
                      // prefixIcon: InkWell(
                      //   onTap: () {
                      //     setState(() {
                      //       if (discQtyCtrl
                      //           .text
                      //           .isNotEmpty) {
                      //         if (int.parse(
                      //                 discQtyCtrl
                      //                     .text) >
                      //             0) {
                      //           discQtyCtrl
                      //                   .text =
                      //               (int.parse(discQtyCtrl.text) -
                      //                       1)
                      //                   .toString();
                      //         } else {
                      //           discQtyCtrl
                      //                   .text =
                      //               "0";
                      //         }
                      //       } else {
                      //         discQtyCtrl
                      //             .text = "0";
                      //       }
                      //     });
                      //   },
                      //   child: SvgPicture.asset(
                      //       theme.isDarkMode
                      //           ? assets
                      //               .darkCMinus
                      //           : assets
                      //               .minusIcon,
                      //       fit: BoxFit
                      //           .scaleDown),
                      // ),
                      // suffixIcon: InkWell(
                      //   onTap: () {
                      //     setState(() {
                      //       int number =
                      //           int.parse(
                      //               discQtyCtrl
                      //                   .text);
                      //       if (discQtyCtrl
                      //           .text
                      //           .isNotEmpty) {
                      //         if (number <
                      //             9999999999) {
                      //           discQtyCtrl
                      //                   .text =
                      //               (int.parse(discQtyCtrl.text) +
                      //                       1)
                      //                   .toString();
                      //         }
                      //       } else {
                      //         discQtyCtrl
                      //             .text = "0";
                      //       }
                      //     });
                      //   },
                      //   child: SvgPicture.asset(
                      //       theme.isDarkMode
                      //           ? assets
                      //               .darkAdd
                      //           : assets
                      //               .addIcon,
                      //       fit: BoxFit
                      //           .scaleDown),
                      // ),
                      controller: discQtyCtrl,
                      textAlign: TextAlign.start),
                ),
              ),
            ],
          )
        ],
      ),
    );
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
                //                                                   dark: MyntColors.textPrimaryDark,
                //                                                   light: MyntColors.textPrimary))),
              ],),
              const SizedBox(height: 10),
              Focus(
                onKeyEvent: (node, event) => _handlePriceArrowKey(event, triggerPriceCtrl),
                child: SizedBox(
                  height: 40,
                  width: 200,
                  child: Semantics(
                    identifier: "Stoploss Trigger",
                    child: MyntTextField(
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$'))
                        ],
                        backgroundColor: theme.isDarkMode
                            ? colors.darkGrey
                            : const Color(0xffF1F3F8),
                        placeholder: "0.00",
                        placeholderStyle: WebTextStyles.formInput(
                          isDarkTheme: theme.isDarkMode,
                          color: (theme.isDarkMode
                              ? MyntColors.textSecondary
                              : MyntColors.textSecondary).withValues(alpha: 0.5),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && SafeParse.toDouble(value) > 0) {
                            final regex = RegExp(
                                r'^(\d+)?(\.\d{0,2})?$'); // Allows numbers with up to 2 decimal places
                            if (!regex.hasMatch(value)) {
                              triggerPriceCtrl.text = value.substring(
                                  0,
                                  value.length -
                                      1); // Revert to previous valid input
                              triggerPriceCtrl.selection =
                                  TextSelection.collapsed(
                                      offset: triggerPriceCtrl.text
                                          .length); // Keep cursor at the end
                            }
                          }

                          if (value.isNotEmpty && value != "0") {
                            _debouncedMarginUpdate();
                          } else if (value == "0") {
                            ResponsiveSnackBar.showWarning(
                                context, "Trigger cannot be 0");
                          } else {
                            ResponsiveSnackBar.showWarning(
                                context, "Trigger cannot be empty");
                          }
                        },
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textStyle: WebTextStyles.formInput(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? MyntColors.textPrimaryDark
                              : MyntColors.textPrimary,
                        ),
                        // prefixIcon: Container(
                        //     margin: const EdgeInsets.all(12),
                        //     decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: theme.isDarkMode ? const Color(0xff555555) : colors.colorWhite),
                        //     child: SvgPicture.asset(color: theme.isDarkMode ? colors.colorWhite : colors.colorGrey, assets.ruppeIcon, fit: BoxFit.scaleDown)),
                        controller: triggerPriceCtrl,
                        textAlign: TextAlign.start),
                  )),
              ),
              // const SizedBox(height: 8),
              // Text(
              //     "Your order will be executed after a stock crosses this trigger price set for you",
              //     style:
              //         textStyle(const Color(0xff666666), 12, FontWeight.w500))
            ]));
  }

  Padding targetOption(
      ThemesProvider theme, BuildContext context, ScripInfoModel scripInfo) {
    return Padding(
      padding: const EdgeInsets.only(left: 16,right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              
          headerTitleText("Target", theme),
          Text(" (in Rs)", style: WebTextStyles.para(isDarkTheme: theme.isDarkMode, color: resolveThemeColor(context,
                                                                  dark: MyntColors.textPrimaryDark,
                                                                  light: MyntColors.textPrimary))),
          
            ],
          ),
          const SizedBox(height: 10),
          Focus(
            onKeyEvent: (node, event) => _handlePriceArrowKey(event, targetCtrl),
            child: SizedBox(
              height: 40,
              width: 200,
              child: Semantics(
                identifier: "Bracket Target Input",
                child: MyntTextField(
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$'))
                    ],
                    backgroundColor: theme.isDarkMode
                        ? colors.darkGrey
                        : const Color(0xffF1F3F8),
                    placeholder: "0.00",
                    onChanged: (value) {
                      if (value.isNotEmpty && SafeParse.toDouble(value) > 0) {
                        final regex = RegExp(
                            r'^(\d+)?(\.\d{0,2})?$');
                        if (!regex.hasMatch(value)) {
                          targetCtrl.text = value.substring(
                              0,
                              value.length - 1);
                          targetCtrl.selection = TextSelection.collapsed(
                              offset: targetCtrl.text.length);
                        }
                      }

                      if (value.isEmpty) {
                        ResponsiveSnackBar.showWarning(
                            context, "Target cannot be empty");
                      } else if (value.isNotEmpty && SafeParse.toDouble(value) <= 0) {
                        ResponsiveSnackBar.showWarning(
                            context, "Target cannot be 0");
                      }
                    },
                    placeholderStyle: WebTextStyles.formInput(
                      isDarkTheme: theme.isDarkMode,
                      color: (theme.isDarkMode
                          ? MyntColors.textSecondary
                          : MyntColors.textSecondary).withValues(alpha: 0.5),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textStyle: WebTextStyles.formInput(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? MyntColors.textPrimaryDark
                          : MyntColors.textPrimary,
                    ),
                    controller: targetCtrl,
                    textAlign: TextAlign.start),
              ),
            ),
          ),
          const SizedBox(height: 10)
        ],
      ),
    );
  }

  Padding stopLossOption(
      ThemesProvider theme, BuildContext context, ScripInfoModel scripInfo) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            headerTitleText("Stoploss", theme),
            Text(" (in Rs)", style: WebTextStyles.para(isDarkTheme: theme.isDarkMode, color: resolveThemeColor(context,
                                                                  dark: MyntColors.textPrimaryDark,
                                                                  light: MyntColors.textPrimary))),
          ],),
          const SizedBox(height: 10),
          Focus(
            onKeyEvent: (node, event) => _handlePriceArrowKey(event, stopLossCtrl),
            child: SizedBox(
              height: 40,
              width: 200,
              child: Semantics(
                identifier: "Stoploss cover sl",
                child: MyntTextField(
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$'))
                    ],
                    backgroundColor: theme.isDarkMode
                        ? colors.darkGrey
                        : const Color(0xffF1F3F8),
                    onChanged: (value) {
                      if (value.isNotEmpty && SafeParse.toDouble(value) > 0) {
                        final regex = RegExp(r'^(\d+)?(\.\d{0,2})?$');
                        if (!regex.hasMatch(value)) {
                          stopLossCtrl.text = value.substring(
                              0, value.length - 1);
                          stopLossCtrl.selection = TextSelection.collapsed(
                              offset: stopLossCtrl.text.length);
                        }
                      }
                      if (value.isEmpty) {
                        ResponsiveSnackBar.showWarning(
                            context, "Stoploss cannot be empty");
                      } else if (value.isNotEmpty && SafeParse.toDouble(value) <= 0) {
                        ResponsiveSnackBar.showWarning(
                            context, "Stoploss cannot be 0");
                      }
                    },
                    placeholder: "0.00",
                    placeholderStyle: WebTextStyles.formInput(
                      isDarkTheme: theme.isDarkMode,
                      color: (theme.isDarkMode
                          ? MyntColors.textSecondary
                          : MyntColors.textSecondary).withValues(alpha: 0.5),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textStyle: WebTextStyles.formInput(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? MyntColors.textPrimaryDark
                          : MyntColors.textPrimary,
                    ),
                    controller: stopLossCtrl,
                    textAlign: TextAlign.start),
              ),
            ),
          ),
          const SizedBox(height: 10)
        ],
      ),
    );
  }

  Padding trailingTicksOption(
      ThemesProvider theme, BuildContext context, ScripInfoModel scripInfo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
          headerTitleText("Trailing SL", theme),
          Text(" (in Rs)", style: WebTextStyles.para(isDarkTheme: theme.isDarkMode, color: resolveThemeColor(context,
                                                                  dark: MyntColors.textPrimaryDark,
                                                                  light: MyntColors.textPrimary))),
          ],),
          const SizedBox(height: 10),
          Focus(
            onKeyEvent: (node, event) => _handlePriceArrowKey(event, trailingTicksCtrl),
            child: SizedBox(
              height: 40,
              width: 200,
              child: Semantics(
                identifier: "Trailing SL Input",
                child: MyntTextField(
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$'))
                    ],
                    backgroundColor: theme.isDarkMode
                        ? colors.darkGrey
                        : const Color(0xffF1F3F8),
                    placeholder: "0.00",
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        double tickSize = SafeParse.toDouble(scripInfo.ti);
                        double enteredValue =
                            (double.tryParse(value) ?? 0).abs();

                        if (enteredValue <= 0) {
                          trailingTicksCtrl.text =
                              value.substring(0, value.length - 1);
                          trailingTicksCtrl.selection = TextSelection.collapsed(
                              offset: trailingTicksCtrl.text.length);
                          return;
                        }

                        double quotient = enteredValue / tickSize;
                        double remainder = (quotient - quotient.round()).abs();
                        if (remainder > 0.0001) {
                          ResponsiveSnackBar.showWarning(context,
                              "Trailing SL should be in multiples of tick size: $tickSize");
                        }
                      }
                      if (value.isEmpty) {
                        ResponsiveSnackBar.showWarning(
                            context, "Trailing SL cannot be empty");
                      }
                    },
                    placeholderStyle: WebTextStyles.formInput(
                      isDarkTheme: theme.isDarkMode,
                      color: (theme.isDarkMode
                          ? MyntColors.textSecondary
                          : MyntColors.textSecondary).withValues(alpha: 0.5),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textStyle: WebTextStyles.formInput(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? MyntColors.textPrimaryDark
                          : MyntColors.textPrimary,
                    ),
                    controller: trailingTicksCtrl,
                    textAlign: TextAlign.start),
              ),
            ),
          ),
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
                    color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                  )),
              Semantics(
                identifier: "Market Protection %",
                child: InkWell(
                  // borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      mktProtDialogCtrl.text = mktProtCtrl.text;
                      mktProtErrorText = "";
                    });
                    PlaceOrderScreenWeb.showDialogOverlay(
                      context: context,
                      builder: (BuildContext dialogContext, VoidCallback closeDialog) {
                        return StatefulBuilder(
                          builder: (BuildContext context,
                              StateSetter dialogSetState) {
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
                                      splashColor: theme.isDarkMode ? colors.splashColorDark : colors.splashColorLight,
                                      highlightColor: theme.isDarkMode ? colors.splashColorDark : colors.splashColorLight,
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
                                  Semantics(
                                    identifier: "Market Protection % Input",
                                    child: MyntTextField(
                                      backgroundColor: theme.isDarkMode
                                          ? colors.darkGrey
                                          : const Color(0xffF1F3F8),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'^(0|[1-9][0-9]{0,19})$'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        dialogSetState(() {
                                          if (value.isEmpty) {
                                            mktProtErrorText =
                                                "Market Protection cannot be empty";
                                          } else {
                                            int intValue =
                                                int.tryParse(value) ?? 0;

                                            if (intValue > 20) {
                                              // force value back to 20
                                              mktProtDialogCtrl.text = "20";
                                              mktProtDialogCtrl.selection =
                                                  TextSelection.fromPosition(
                                                TextPosition(
                                                    offset: mktProtDialogCtrl
                                                        .text.length),
                                              );
                                              mktProtErrorText =
                                                  "Cannot enter greater than 20%";
                                            } else if (intValue < 1) {
                                              mktProtErrorText =
                                                  "Cannot enter less than 1%";
                                            } else {
                                              mktProtErrorText = "";
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
                                      controller: mktProtDialogCtrl,
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
                                  ),
                                  if (mktProtErrorText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Semantics(
                                        identifier:
                                            "Market Protection % Error Text",
                                        child: Text(
                                          mktProtErrorText,
                                          style: WebTextStyles.para(
                                            isDarkTheme: theme.isDarkMode,
                                            color: theme.isDarkMode
                                                ? MyntColors.errorDark
                                                : MyntColors.loss,
                                          ),
                                        ),
                                      ),
                                      //  Text(
                                      //   mktProtErrorText,
                                      //   style: TextStyle(
                                      //     color: Colors.red,
                                      //     fontSize: 12,
                                      //   ),
                                      // ),
                                    ),
                                ],
                              ),
                              actions: [
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (mktProtDialogCtrl.text.isEmpty) {
                                        dialogSetState(() {
                                          mktProtErrorText =
                                              "Market Protection cannot be empty";
                                        });
                                        return;
                                      }

                                      double intValue = double.tryParse(
                                              mktProtDialogCtrl.text) ??
                                          0;
                                      if (intValue > 20 || intValue < 1) {
                                        return;
                                      }

                                      updatePriceType();
                                      setState(() {
                                        mktProtCtrl.text =
                                            mktProtDialogCtrl.text;
                                        mktProtErrorText = "";
                                      });
                                      closeDialog();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      minimumSize:
                                          const Size(0, 45), // width, height
                                      side: BorderSide(
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.cardBorderDark,
                                              light: colors.btnOutlinedBorder)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      backgroundColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
                                    ),
                                    child: Text("Ok",
                                        style: WebTextStyles.buttonMd(
                                          isDarkTheme: theme.isDarkMode,
                                          color: Colors.white,
                                          fontWeight: WebFonts.semiBold,
                                        )),
                                  ),
                                ),

                                // TextButton(
                                //   onPressed: () => Navigator.of(context).pop(),
                                //   child: const Text('Cancel'),
                                // ),
                                // TextButton(
                                //   onPressed: () {
                                //     Navigator.of(context).pop();
                                //   },
                                //   child: const Text('OK'),
                                // ),
                              ],
                            );
                          },
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
                    //  Text(
                    //   " $marketProtection %",
                    //   style: textStyle(
                    //     theme.isDarkMode
                    //         ? colors.colorLightBlue
                    //         : colors.colorBlue,
                    //     14,
                    //     FontWeight.w600,
                    //   ).copyWith(
                    //     decoration: TextDecoration.underline,
                    //   ),
                    // ),
                  ),
                ),
              )
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

  sipOrder(WidgetRef ref) async {
    final sip = ref.watch(siprovider);
    SipInputField sipOrderInput = SipInputField(
        regdate: sipdateformat(formattedDate),
        startdate: sipdateformat(sip.datefield.text),
        frequency: selectedValue == "Daily"
            ? "0"
            : selectedValue == "Weekly"
                ? "1"
                : selectedValue == "Fortnightly"
                    ? "2"
                    : "3",
        endperiod: sip.numberofSips.text.toString(),
        sipname: widget.scripInfo.tsym,
        exch: widget.scripInfo.exch,
        tysm: widget.scripInfo.tsym,
        prd: "C",
        token: widget.scripInfo.token,
        qty: sipqtyctrl.text);
    await ref.read(orderProvider).fetchSipPlaceOrder(context, sipOrderInput);
  }

  placeOrder(OrderInputProvider orderInput, bool isSliceOrd,
      ThemesProvider theme) async {
    // Guard: for stocks in Amount mode, an amount below LTP floors to qty 0.
    // Compute what would actually be sent to the API and block if it's 0.
    final int finalApiQty = widget.scripInfo.exch == 'MCX'
        ? SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) * lotSize
        : SafeParse.toInt(getFinalQuantity(qtyCtrl.text));
    if (qtyCtrl.text.trim().isNotEmpty && finalApiQty <= 0) {
      ResponsiveSnackBar.showWarning(
          context,
          _isStock && _isQtyToAmount
              ? "Minimum Allowed Amount should be greater than ${widget.orderArg.ltp}"
              : "Quantity cannot be 0");
      return;
    }
    String bsktName = ref.read(orderProvider).selectedBsktName;
    int frezQtyOrderSliceMaxLimit =
        ref.read(orderProvider).frezQtyOrderSliceMaxLimit;
    if (widget.isBasket == "Basket" ||
        widget.isBasket == "BasketEdit" ||
        widget.isBasket == "BasketMode") {
      if (widget.isBasket == "BasketEdit") {
        final rawIndex = widget.orderArg.raw['index'];
        final bsktIndex = rawIndex is int
            ? rawIndex
            : int.tryParse(rawIndex?.toString() ?? '') ?? 0;
        await ref
            .read(orderProvider)
            .removeBsktScrip(bsktIndex, bsktName);
      }
      // Pass false for stay so basket dialog stays open when adding new symbols
      // Only close basket dialog when editing existing basket script
      addBasketScrip(orderInput, bsktName, false);
    } else {
      if (!isSliceOrd) {
        bool placeorder = true;
        if (priceType == "Limit" || priceType == "SL Limit") {
          String r = roundOffWithInterval(SafeParse.toDouble(priceCtrl.text), tik)
              .toStringAsFixed(2);
          if (SafeParse.toDouble(priceCtrl.text) != SafeParse.toDouble(r)) {
            placeorder = false;
            ResponsiveSnackBar.showWarning(
                context, "Price should be multiple of tick size $tik => $r");
          }
        }
        if (placeorder && (priceType == "SL Limit" || priceType == "SL MKT")) {
          String r =
              roundOffWithInterval(SafeParse.toDouble(triggerPriceCtrl.text), tik)
                  .toStringAsFixed(2);
          if (SafeParse.toDouble(triggerPriceCtrl.text) != SafeParse.toDouble(r)) {
            placeorder = false;
            ResponsiveSnackBar.showWarning(
                context, "Trigger should be multiple of tick size $tik => $r");
          }
        }
        int q = ((SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) / lotSize).round() *
            lotSize);
        if (SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) != q &&
            widget.scripInfo.exch != 'MCX') {
          placeorder = false;
          ResponsiveSnackBar.showWarning(context,
              "Quantity should be multiple of lot size $lotSize => $q");
        }

        if ((priceType == "Market" || priceType == "SL MKT") &&
            (mktProtCtrl.text.isEmpty ||
                SafeParse.toDouble(mktProtCtrl.text.toString()) > 20 ||
                SafeParse.toDouble(mktProtCtrl.text.toString()) < 1)) {
          placeorder = false;
          ResponsiveSnackBar.showWarning(
              context, "Market Protection between 1% to 20%");
        }
        if (!isSecu) {
          placeorder = false;
          // anibuildctrl.forward();
          _showSurveillanceBottomSheet(orderInput, isSliceOrd, theme);
        }

        if (placeorder) {
          ref.read(orderProvider).setOrderloader(true);
          PlaceOrderInput placeOrderInput = PlaceOrderInput(
              amo: _afterMarketOrder ? "Yes" : "",
              blprc: orderType == "CO - BO" ? stopLossCtrl.text : '',
              bpprc: orderType == "CO - BO" && _isBracketOrderEnabled
                  ? targetCtrl.text
                  : '',
              dscqty: discQtyCtrl.text,
              exch: stockExchangeSelected.exch == null ? widget.scripInfo.exch! : stockExchangeSelected.exch??"",
              prc: ordPrice,
              prctype: orderInput.prcType,
              prd: orderInput.orderType,
              qty: widget.scripInfo.exch == 'MCX'
                  ? (SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) * lotSize)
                      .toString()
                  : getFinalQuantity(qtyCtrl.text),
              ret: validityType,
              trailprc: orderType == "CO - BO" &&
                      trailingTicksCtrl.text.isNotEmpty &&
                      (double.tryParse(trailingTicksCtrl.text) ?? 0) > 0
                  ? trailingTicksCtrl.text
                  : '',
              trantype: isBuy! ? 'B' : 'S',
              trgprc: priceType == "SL Limit" || priceType == "SL MKT"
                  ? triggerPriceCtrl.text
                  : "",
              tsym: stockExchangeSelected.tsym == null ? widget.scripInfo.tsym! : stockExchangeSelected.tsym??"",
              mktProt: priceType == "Market" || priceType == "SL MKT"
                  ? mktProtCtrl.text
                  : '',
              channel: '');
          await ref.read(orderProvider).fetchPlaceOrder(
              context, placeOrderInput, widget.orderArg.isExit);
          ref.read(orderProvider).setOrderloader(false);
          // Close the place order dialog after order is placed (for overlay dialogs)
          // Only close if sticky order window is not enabled
          bool stickyOrderWindow = userOrderPreference['stickysrc'] == "True" || userOrderPreference['stickysrc'] == true;
          if (!stickyOrderWindow) {
            final closeNotifier = _PlaceOrderDialogCloseNotifier.of(context);
            if (closeNotifier != null) {
              // Add a small delay to allow order confirmation dialog to appear first
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  closeNotifier.onClose();
                }
              });
            }
          }
        }
      } else {
        int q = ((SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) / lotSize).round() *
            lotSize);
        if (SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) != q &&
            widget.scripInfo.exch != 'MCX') {
          ResponsiveSnackBar.showWarning(context,
              "Quantity should be multiple of lot size $lotSize => $q");
        } else if (frezQtyOrderSliceMaxLimit < quantity) {
          ResponsiveSnackBar.showWarning(context,
              "Quantity can only be split into a maximum of $frezQtyOrderSliceMaxLimit slice. (Ex: $frezQty x $frezQtyOrderSliceMaxLimit = ${frezQty * frezQtyOrderSliceMaxLimit})");
        } else if (!isSecu) {
          _showSurveillanceBottomSheet(orderInput, isSliceOrd, theme);
        } else {
          SliceOrderSheetWeb.showAsOverlay(
            context: context,
            scripInfo: widget.scripInfo,
            isBuy: isBuy!,
            quantity: quantity,
            frezQty: frezQty,
            reminder: reminder,
            lotSize: lotSize,
            isAmo: _afterMarketOrder,
            orderType: orderType,
            priceType: priceType,
            ordPrice: ordPrice,
            validityType: validityType,
            stopLossCtrl: stopLossCtrl,
            targetCtrl: targetCtrl,
            discQtyCtrl: discQtyCtrl,
            triggerPriceCtrl: triggerPriceCtrl,
            mktProtCtrl: mktProtCtrl,
            isBracketOrderEnabled: _isBracketOrderEnabled,
          );
        }
      }
    }
  }

  headerTitleText(String text, ThemesProvider theme) {
    return Text(
      text,
      style: WebTextStyles.formLabel(
        isDarkTheme: theme.isDarkMode,
        color: resolveThemeColor(context,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
      ),
    );
  }

  /// Debounced version of marginUpdate to reduce API calls
  /// Delays the API call by 500ms and cancels any pending calls
  void _debouncedMarginUpdate() {
    _marginUpdateDebounceTimer?.cancel();
    _marginUpdateDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        marginUpdate();
      }
    });
  }

  void marginUpdate() {
    OrderMarginInput input = OrderMarginInput(
        exch: stockExchangeSelected.exch == null ? "${widget.scripInfo.exch}" : stockExchangeSelected.exch??"",
        prc: (priceType == "Market" || priceType == "SL MKT") ? "0" : ordPrice,
        prctyp: ref.read(ordInputProvider).prcType,
        prd: ref.read(ordInputProvider).orderType,
        qty: widget.scripInfo.exch == 'MCX'
            ? (SafeParse.toDouble(getFinalQuantity(qtyCtrl.text)).toInt() * lotSize)
                .toString()
            : getFinalQuantity(qtyCtrl.text),
        rorgprc: '0',
        rorgqty: '0',
        trantype: isBuy! ? "B" : "S",
        tsym: stockExchangeSelected.tsym == null ? "${widget.scripInfo.tsym}" : stockExchangeSelected.tsym??"",
        blprc: orderType == "CO - BO" ? stopLossCtrl.text : '',
        bpprc: orderType == "CO - BO" ? targetCtrl.text : '',
        trgprc: priceType == "SL Limit" || priceType == "SL MKT"
            ? triggerPriceCtrl.text
            : "");
    ref.read(orderProvider).fetchOrderMargin(input, context);
    BrokerageInput brokerageInput = BrokerageInput(
        exch: stockExchangeSelected.exch == null ? "${widget.scripInfo.exch}" : stockExchangeSelected.exch??"",
        prc: (priceType == "Market" || priceType == "SL MKT") ? "0" : ordPrice,
        prd: ref.read(ordInputProvider).orderType,
        qty: widget.scripInfo.exch == 'MCX'
            ? (SafeParse.toDouble(getFinalQuantity(qtyCtrl.text)).toInt() * lotSize)
                .toString()
            : getFinalQuantity(qtyCtrl.text),
        trantype: isBuy! ? "B" : "S",
        tsym: stockExchangeSelected.tsym == null ? "${widget.scripInfo.tsym}" : stockExchangeSelected.tsym??"");
    ref.read(orderProvider).fetchGetBrokerage(brokerageInput, context);
  }

  // Directly disable all chart iframes and reset cursor (like chart's onExit)
  void _disableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'none';
          // Reset cursor style to prevent cursor bleeding
          iframe.style.cursor = 'default';
        }
      }
      // Also reset cursor on document body to ensure it's reset globally
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

  void _showSurveillanceBottomSheet(
      OrderInputProvider orderInput, bool isSliceOrd, ThemesProvider theme) {
    // Show surveillance dialog as overlay entry above the order screen
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry surveillanceOverlayEntry;

    surveillanceOverlayEntry = OverlayEntry(
      builder: (overlayContext) => Consumer(
        builder: (context, ref, _) {
          final currentTheme = ref.watch(themeProvider);
          return Stack(
            children: [
              // Backdrop
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    surveillanceOverlayEntry.remove();
                    setState(() {
                      _pendingSurveillanceAction = null;
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
              ),
              // Dialog centered
              Center(
                child: Material(
                  color: Colors.transparent,
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
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 500),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: currentTheme.isDarkMode
                                  ? MyntColors.dialogDark
                                  : MyntColors.dialog,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: currentTheme.isDarkMode
                                    ? MyntColors.dividerDark
                                    : MyntColors.divider,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_outlined,
                                      color: Color.fromARGB(190, 255, 170, 0),
                                      size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Exchange surveillance active',
                                    style: WebTextStyles.dialogTitle(
                                      isDarkTheme: currentTheme.isDarkMode,
                                      color: currentTheme.isDarkMode
                                          ? MyntColors.textPrimaryDark
                                          : MyntColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  splashColor: currentTheme.isDarkMode
                                      ? Colors.white.withOpacity(.15)
                                      : Colors.black.withOpacity(.15),
                                  highlightColor: currentTheme.isDarkMode
                                      ? Colors.white.withOpacity(.08)
                                      : Colors.black.withOpacity(.08),
                                  onTap: () {
                                    ChartIframeGuard.release();
                                    _enableAllChartIframes();
                                    surveillanceOverlayEntry.remove();
                                    setState(() {
                                      _pendingSurveillanceAction = null;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quotemsg.isNotEmpty
                                    ? quotemsg
                                    : 'Security is under surveillance. Would you like to continue?',
                                style: WebTextStyles.custom(
                                  fontSize: 13,
                                  isDarkTheme: currentTheme.isDarkMode,
                                  color: currentTheme.isDarkMode
                                      ? MyntColors.textPrimaryDark
                                      : MyntColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    ChartIframeGuard.release();
                                    _enableAllChartIframes();
                                    surveillanceOverlayEntry.remove();
                                    final action = _pendingSurveillanceAction;
                                    _pendingSurveillanceAction = null;
                                    if (action != null) {
                                      setState(() {
                                        isSecu = true;
                                      });
                                      await action();
                                      // Close the place order dialog after order is placed
                                      // Only close if sticky order window is not enabled
                                      bool stickyOrderWindow = userOrderPreference['stickysrc'] == "True" || userOrderPreference['stickysrc'] == true;
                                      if (!stickyOrderWindow) {
                                        final closeNotifier =
                                            _PlaceOrderDialogCloseNotifier.of(
                                                context);
                                        if (closeNotifier != null) {
                                          // Add a small delay to allow order confirmation dialog to appear first
                                          Future.delayed(
                                              const Duration(milliseconds: 300),
                                              () {
                                            if (mounted) {
                                              closeNotifier.onClose();
                                            }
                                          });
                                        }
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: currentTheme.isDarkMode
                                        ? MyntColors.secondary
                                        : MyntColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  child: Text(
                                    "Continue",
                                    style: WebTextStyles.custom(
                                      fontSize: 14,
                                      isDarkTheme: currentTheme.isDarkMode,
                                      color: resolveThemeColor(context, dark: MyntColors.backgroundColor, light: MyntColors.backgroundColor),
                                      fontWeight: FontWeight.w600,
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
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    overlay.insert(surveillanceOverlayEntry);

    setState(() {
      _pendingSurveillanceAction = () async {
        setState(() {
          isSecu = true;
        });
        placeOrder(orderInput, isSliceOrd, theme);
      };
    });
  }

  prepareToPlaceGttOrder(OrderInputProvider orderInput) async {
    PlaceGTTOrderInput input = PlaceGTTOrderInput(
        exch: stockExchangeSelected.exch == null ? '${widget.scripInfo.exch}' : stockExchangeSelected.exch??"",
        qty: getGTTFinalQuantity(orderInput.qtyCtrl.text),
        tsym: stockExchangeSelected.tsym == null ? '${widget.scripInfo.tsym}' : stockExchangeSelected.tsym??"",
        validity: "GTT",
        prc: orderInput.actPrcType == "Market" ||
                orderInput.actPrcType == "SL MKT"
            ? "0.00"
            : orderInput.priceCtrl.text,
        prd: orderInput.orderType,
        trantype: isBuy! ? 'B' : "S",
        ret: 'DAY',
        ait: orderInput.ait,
        d: orderInput.val1Ctrl.text,
        prctyp: orderInput.prcType,
        remarks: orderInput.reMarksCtrl.text,
        trgprc: orderInput.actPrcType == "SL Limit" ||
                orderInput.actPrcType == "SL MKT"
            ? orderInput.trgPrcCtrl.text
            : "",
        alid: '');

    final closeNotifier = _PlaceOrderDialogCloseNotifier.of(context);
    final orderProv = ref.read(orderProvider);
    orderProv.setOrderloader(true);
    try {
      await orderProv.placeGTTOrder(input, context);

      final placeResult = orderProv.placeGttOrderModel;
      final wasSuccessful = placeResult?.stat == "OI created";

      if (wasSuccessful && mounted) {
        ResponsiveSnackBar.showSuccess(context, "GTT Order Placed Successfully");
        bool stickyOrderWindow = userOrderPreference['stickysrc'] == "True" || userOrderPreference['stickysrc'] == true;
        if (!stickyOrderWindow && closeNotifier != null) {
          closeNotifier.onClose();
        }
      }
    } finally {
      orderProv.setOrderloader(false);
    }
  }

  prepareToPlaceOCOOrder(OrderInputProvider orderInput) async {
    PlaceOcoOrderInput input = PlaceOcoOrderInput(
        exch: stockExchangeSelected.exch == null ? '${widget.scripInfo.exch}' : stockExchangeSelected.exch??"",
        tsym: stockExchangeSelected.tsym == null ? '${widget.scripInfo.tsym}' : stockExchangeSelected.tsym??"",
        validity: "GTT",
        trantype: isBuy! ? 'B' : "S",
        ret: 'DAY',
        remarks: orderInput.reMarksCtrl.text,
        qty1: getGTTFinalQuantity(orderInput.qtyCtrl.text),
        trgprc1: orderInput.actOcoPrcType == "SL Limit" ||
                orderInput.actOcoPrcType == "SL MKT"
            ? orderInput.trgPrcCtrl.text
            : "",
        prc1: orderInput.actPrcType == "Market" ||
                orderInput.actPrcType == "SL MKT"
            ? "0.00"
            : orderInput.priceCtrl.text,
        prd1: orderInput.orderType,
        d1: orderInput.val1Ctrl.text,
        prctyp1: orderInput.prcType,
        d2: orderInput.val2Ctrl.text,
        prctyp2: orderInput.ocoPrcType,
        prc2: orderInput.actOcoPrcType == "Market" ||
                orderInput.actOcoPrcType == "SL MKT"
            ? "0.00"
            : orderInput.ocoPriceCtrl.text,
        prd2: orderInput.ocoOrderType,
        qty2: getGTTFinalQuantity(orderInput.ocoQtyCtrl.text),
        trgprc2: orderInput.actOcoPrcType == "SL Limit" ||
                orderInput.actOcoPrcType == "SL MKT"
            ? orderInput.ocoTrgPrcCtrl.text
            : "",
        alid: '');

    final closeNotifier = _PlaceOrderDialogCloseNotifier.of(context);
    final orderProv = ref.read(orderProvider);
    orderProv.setOrderloader(true);
    try {
      await orderProv.placeOCOOrder(input, context);

      final placeResult = orderProv.placeGttOrderModel;
      final wasSuccessful = placeResult?.stat == "OI created";

      if (wasSuccessful && mounted) {
        ResponsiveSnackBar.showSuccess(context, "OCO Order Placed Successfully");
        bool stickyOrderWindow = userOrderPreference['stickysrc'] == "True" || userOrderPreference['stickysrc'] == true;
        if (!stickyOrderWindow && closeNotifier != null) {
          closeNotifier.onClose();
        }
      }
    } finally {
      orderProv.setOrderloader(false);
    }
  }

  addBasketScrip(
      OrderInputProvider orderInput, String bsktName, bool stay) async {
    // Get close callback before async operations
    final closeNotifier = _PlaceOrderDialogCloseNotifier.of(context);
    
    Map<String, dynamic> data = {};
    String curDate = convDateWithTime();

    // Convert lots to qty if in lot mode, then validate
    // For MCX, multiply by lotSize to get actual qty (same as placeOrder)
    final quantity = widget.scripInfo.exch == 'MCX'
        ? SafeParse.toInt(getFinalQuantity(qtyCtrl.text)) * lotSize
        : SafeParse.toInt(getFinalQuantity(qtyCtrl.text));
    final lotSizeVal = lotSize;

    if (quantity % lotSizeVal != 0) {
      ResponsiveSnackBar.showError(context,
          "Quantity must be multiple of lot size ($lotSizeVal). Current: $quantity");
      return; // Exit the function without adding to basket
    }

    // Use user-specific storage if available, otherwise general storage
    final userId = pref.clientId;
    if (userId != null && userId.isNotEmpty) {
      final userBasketScrips = pref.getBasketScripsForUser(userId) ?? "";
      data = userBasketScrips.isEmpty ? {} : jsonDecode(userBasketScrips);
    } else {
      data = pref.bsktScrips!.isEmpty ? {} : jsonDecode(pref.bsktScrips!);
    }

    List scripList = data[bsktName] ?? [];

    // Calculate splits needed for current order
    List<int> splitQuantities = [];
    // For MCX, convert frezQty from lots to actual qty to match quantity
    final freezeQty = widget.scripInfo.exch == 'MCX' ? frezQty * lotSize : frezQty;
    final orderProv = ref.read(orderProvider);
    final frezQtyOrderSliceMaxLimit = orderProv.frezQtyOrderSliceMaxLimit;

    if (widget.scripInfo.frzqty != null && quantity > freezeQty) {
      // Calculate number of full splits and remainder
      final fullSplits = quantity ~/ freezeQty; // Integer division
      final remainder = quantity % freezeQty;

      // Add full splits
      for (int i = 0; i < fullSplits; i++) {
        splitQuantities.add(freezeQty);
      }

      // Add remainder if exists
      if (remainder > 0) {
        splitQuantities.add(remainder);
      }
    } else {
      // No split needed
      splitQuantities.add(quantity);
    }

    // Check if total basket items would exceed the limit
    int currentBasketOrders = scripList.length;
    int newOrders = splitQuantities.length;
    int remainingSlots = frezQtyOrderSliceMaxLimit - currentBasketOrders;

    if (newOrders > frezQtyOrderSliceMaxLimit) {
      ResponsiveSnackBar.showError(context,
          "Maximum allowed quantity is $frezQty x $frezQtyOrderSliceMaxLimit = ${frezQty * frezQtyOrderSliceMaxLimit}");
      return;
    }

    if (newOrders > remainingSlots) {
      ResponsiveSnackBar.showError(context,
          remainingSlots <= 0
              ? "Basket is full. Maximum $frezQtyOrderSliceMaxLimit items allowed per basket."
              : "Order requires $newOrders slices but basket can only hold $remainingSlots more.");
      return;
    }

    // Add each split as separate entry to basket
    for (int splitQty in splitQuantities) {
      scripList.add({
        "dname": "${widget.scripInfo.dname}",
        "token": widget.scripInfo.token,
        "frzqty": widget.scripInfo.frzqty?.toString() ?? "0",
        "date": curDate,
        "amo": _afterMarketOrder ? "Yes" : "",
        "blprc": orderType == "CO - BO" ? stopLossCtrl.text : '',
        "bpprc": orderType == "CO - BO" && _isBracketOrderEnabled
            ? targetCtrl.text
            : '',
        "dscqty": discQtyCtrl.text,
        "exch": stockExchangeSelected.exch == null ? "${widget.scripInfo.exch}" : stockExchangeSelected.exch??"",
        "prc": ordPrice,
        "prctype": orderInput.prcType,
        "prd": orderInput.orderType,
        "ordType": orderInput.orderType == "I"
            ? "MIS"
            : orderInput.orderType == "C"
                ? "CNC"
                : orderInput.orderType == "M"
                    ? "NRML"
                    : orderInput.orderType == "H"
                        ? "CO"
                        : "BO",
        "qty": splitQty
            .toString(), // Use the split quantity instead of original quantity
        "ret": validityType,
        "trailprc": orderType == "CO - BO" &&
                trailingTicksCtrl.text.isNotEmpty &&
                (double.tryParse(trailingTicksCtrl.text) ?? 0) > 0
            ? trailingTicksCtrl.text
            : '',
        "trantype": isBuy! ? 'B' : 'S',
        "trgprc": priceType == "SL Limit" || priceType == "SL MKT"
            ? triggerPriceCtrl.text
            : "",
        "tsym": stockExchangeSelected.tsym == null ? UrlUtils.encodeParameter(widget.scripInfo.tsym!) : UrlUtils.encodeParameter(stockExchangeSelected.tsym?? ""),
        "mktProt": priceType == "Market" || priceType == "SL MKT"
            ? mktProtCtrl.text
            : '',
        "ls": widget.scripInfo.ls?.toString() ?? '1',
      });
    }

    data.addAll({bsktName: scripList});

    String jsonData = jsonEncode(data);


    // Save to the same storage type we read from
    if (userId != null && userId.isNotEmpty) {
      await pref.setBasketScripForUser(userId, jsonData);

      // Clear general storage to prevent conflicts
      if (pref.bsktScrips != null && pref.bsktScrips!.isNotEmpty) {
        await pref.setBasketScrip("{}");
      }
    } else {
      await pref.setBasketScrip(jsonData);
    }

    // **FIX: Add small delay to ensure storage write completes before reading**
    await Future.delayed(const Duration(milliseconds: 100));

    await ref.read(orderProvider).getBasketName();

    // Ensure WebSocket subscription for the updated basket
    // final orderProv = ref.read(orderProvider);
    if (orderProv.selectedBsktName == bsktName) {
      // Re-subscribe to ensure new items get real-time updates
      await orderProv.chngBsktName(bsktName, context, true);
    }

    await ref.read(orderProvider).fetchBasketMargin();
    
    // Close the order screen overlay (not the basket dialog)
    if (closeNotifier != null && mounted) {
      closeNotifier.onClose();
    }
  }

  void updatePriceType() {
    if ((orderType == "Delivery" ||
            orderType == "Intraday" ||
            orderType == "MTF") &&
        _isStoplossOrder &&
        _isMarketOrder) {
      priceType = "SL MKT";
    } else if (((orderType == "Delivery" ||
                orderType == "Intraday" ||
                orderType == "MTF" ||
                orderType == "CO - BO") &&
            _isStoplossOrder &&
            !_isMarketOrder) ||
        (orderType == "CO - BO" && _isStoplossOrder && _isMarketOrder)) {
      priceType = "SL Limit";
    } else if (_isMarketOrder) {
      priceType = "Market";
    } else {
      priceType = "Limit";
    }

    // Get current LTP from websocket first, then fallback to orderArg.ltp
    String currentLtp = widget.orderArg.ltp ?? "0.00";
    final socketData = ref.read(websocketProvider).socketDatas[widget.scripInfo.token];
    if (socketData != null) {
      final wsLtp = socketData['lp']?.toString();
      if (wsLtp != null && wsLtp != "null" && wsLtp != "0" && wsLtp != "0.00") {
        currentLtp = wsLtp;
      }
    }
    // If still 0, try using existing ordPrice if it's valid
    if ((currentLtp == "0.00" || currentLtp == "0" || currentLtp.isEmpty) &&
        ordPrice != "0.00" && ordPrice != "0" && ordPrice.isNotEmpty && ordPrice != "Market") {
      currentLtp = ordPrice;
    }

    // Update price controller based on type
    if (priceType == "Market" || priceType == "SL MKT") {
      priceCtrl.text = "Market";
      double ltp = (SafeParse.toDouble(currentLtp) *
              SafeParse.toDouble(mktProtCtrl.text)) /
          100;

      if (isBuy!) {
        ordPrice = (SafeParse.toDouble(currentLtp) + ltp)
            .toStringAsFixed(2);
      } else {
        ordPrice = (SafeParse.toDouble(currentLtp) - ltp)
            .toStringAsFixed(2);
      }
      double result =
          SafeParse.toDouble(ordPrice) + (SafeParse.toDouble(widget.scripInfo.ti) / 2);
      result -= result % SafeParse.toDouble(widget.scripInfo.ti);

      if (_hasValidCircuitBreakerValues) {
        if (result >= SafeParse.toDouble(widget.scripInfo.uc)) {
          ordPrice = widget.scripInfo.uc!;
        } else if (result <= SafeParse.toDouble(widget.scripInfo.lc)) {
          ordPrice = widget.scripInfo.lc!;
        } else {
          ordPrice = result.toStringAsFixed(2);
        }
      } else {
        ordPrice = result.toStringAsFixed(2);
      }
    } else if (priceCtrl.text == "Market") {
      priceCtrl.text = currentLtp;
      ordPrice = priceCtrl.text;
    }
  }

  void onOrderTypeChangeClearValues() {
    if (orderType == "Delivery" ||
        orderType == "Intraday" ||
        orderType == "MTF") {
      _isCoverOrderEnabled = true;
      _isBracketOrderEnabled = false;
      // Only restore saved AMO value when switching back from CO-BO
      if (_wasInCOBOMode) {
        _afterMarketOrder = _savedAfterMarketOrder;
        _wasInCOBOMode = false;
      }
    } else if (orderType == "CO - BO") {
      _addValidityAndDisclosedQty = false;
      // Save AMO value before disabling it for CO-BO
      _savedAfterMarketOrder = _afterMarketOrder;
      _afterMarketOrder = false;
      _wasInCOBOMode = true;
    }
  }

  String convertQtyOrAmtValue(String value, bool isQtyToAmount) {
    if (value.trim().isEmpty) return "";
    if (!isQtyToAmount) return value;
    double ltp = double.tryParse(widget.orderArg.ltp ?? "0.0") ?? 0.0;
    final wsD = ref.read(websocketProvider).socketDatas[widget.scripInfo.token];
    if (wsD != null) {
      final wl = SafeParse.toDouble(wsD['lp']);
      if (wl > 0) ltp = wl;
    }
    return ((double.tryParse(value) ?? 0.0) ~/ ltp).toString();
  }

  String convertLotOrQtyValue(String value, bool isLotToQty) {
    if (value.trim().isEmpty) return "";
    return isLotToQty
        ? ((int.tryParse(value) ?? 0) ~/ lotSize).toString()
        : value;
  }

  // Get the final quantity for order placement
  String getFinalQuantity(String value) {
    if (value.trim().isEmpty) return "0";

    if (_isStock) {
      // NSE/BSE: convert amount to qty if in amount mode
      return convertQtyOrAmtValue(value, _isQtyToAmount);
    } else {
      // NFO/BFO: if in lot mode, multiply by lotSize; if in qty mode, use as is
      int inputValue = int.tryParse(value) ?? 0;
      return _isLotToQty ? value : (inputValue * lotSize).toString();
    }
  }

  /// Returns the API-ready qty for the GTT/OCO submit.
  ///
  /// MCX: input is lot count, multiply by lot size.
  /// NSE/BSE: input is qty or amount depending on [_isQtyToAmount].
  /// NFO/BFO: input is qty or lot depending on [_isGTTLotToQty].
  String getGTTFinalQuantity(String value) {
    if (value.trim().isEmpty) return "0";
    if (widget.scripInfo.exch == 'MCX') {
      int lotCount = int.tryParse(value) ?? 0;
      return (lotCount * lotSize).toString();
    }
    if (_isStock) return convertQtyOrAmtValue(value, _isQtyToAmount);
    int inputValue = int.tryParse(value) ?? 0;
    return _isGTTLotToQty ? value : (inputValue * lotSize).toString();
  }
}

// Draggable Place Order Screen Dialog Widget
class _DraggablePlaceOrderScreenDialog extends ConsumerStatefulWidget {
  final OrderScreenArgs orderArg;
  final ScripInfoModel scripInfo;
  final String isBasket;
  final bool fromChart;
  final Offset initialPosition;
  final Function(Offset) onPositionChanged;
  final VoidCallback onClose;

  const _DraggablePlaceOrderScreenDialog({
    required this.orderArg,
    required this.scripInfo,
    required this.isBasket,
    required this.fromChart,
    required this.initialPosition,
    required this.onPositionChanged,
    required this.onClose,
  });

  @override
  ConsumerState<_DraggablePlaceOrderScreenDialog> createState() =>
      _DraggablePlaceOrderScreenDialogState();
}

class _DraggablePlaceOrderScreenDialogState
    extends ConsumerState<_DraggablePlaceOrderScreenDialog> {
  late Offset _position;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForNavigationChanges();
    });
  }

  // Directly disable all chart iframes and reset cursor (like chart's onExit)
  void _disableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'none';
          // Reset cursor style to prevent cursor bleeding
          iframe.style.cursor = 'default';
        }
      }
      // Also reset cursor on document body to ensure it's reset globally
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

  void _listenForNavigationChanges() {
    // Monitor for navigation events that might indicate the place order dialog should close
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Stop checking after 30 seconds to prevent memory leaks
      if (timer.tick > 150) {
        // 30 seconds
        timer.cancel();
        return;
      }

      // Check if a new route has been pushed (like confirmation screen)
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        // Get the current route to check if it's a confirmation screen
        final currentRoute = ModalRoute.of(context);
        final routeName = currentRoute?.settings.name;

        // Don't close for surveillance dialogs or other temporary dialogs
        // Only close for actual confirmation screens or permanent navigation
        if (routeName != null &&
            (routeName.contains('confirmation') ||
                routeName.contains('order_confirmation'))) {
          // Close this dialog after a short delay to allow the confirmation to fully appear
          Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              widget.onClose();
            }
          });
          timer.cancel();
        }
        // For other dialogs (like surveillance), let them stay open
      }
    });
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
                  onTap: () {},
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
                      child: _PlaceOrderDialogCloseNotifier(
                        onClose: widget.onClose,
                        child: _PlaceOrderDialogDragNotifier(
                          onPanStart: (details) {
                            setState(() {
                              _isDragging = true;
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              _position = Offset(
                                _position.dx + details.delta.dx,
                                _position.dy + details.delta.dy,
                              );
                            });
                            widget.onPositionChanged(_position);
                          },
                          onPanEnd: (details) {
                            setState(() {
                              _isDragging = false;
                            });
                          },
                          isDragging: _isDragging,
                          child: PlaceOrderScreenWeb(
                            orderArg: widget.orderArg,
                            scripInfo: widget.scripInfo,
                            isBasket: widget.isBasket,
                            fromChart: widget.fromChart,
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

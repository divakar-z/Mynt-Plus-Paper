import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../models/marketwatch_model/scrip_info.dart';
import '../../../models/order_book_model/gtt_order_book.dart';
import '../../../models/order_book_model/place_gtt_order.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/network_state_provider.dart';
import '../../../provider/order_input_provider.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/res.dart';
import '../../../res/global_font_web.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import '../../../sharedWidget/common_text_fields_web.dart';
import '../../../sharedWidget/no_internet_widget.dart';
import '../../../sharedWidget/snack_bar.dart';
import '../../../utils/safe_parse.dart';
import 'dart:html' as html;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../market_watch/tv_chart/chart_iframe_guard.dart';
import '../../../utils/overlay_manager.dart';
import '../order/order_depth_panel_web.dart';


/// Rejects a keystroke that would make a numeric field invalid, keeping the
/// last valid value instead of clearing it. Empty is always allowed so the
/// user can still backspace the field clear. Replaces the earlier anchored
/// allow-filter, which wiped the whole field on any non-matching input
/// (a letter, or a second decimal point) and then fired a spurious warning.
TextInputFormatter _rejectIfNoMatch(RegExp pattern) =>
    TextInputFormatter.withFunction((oldValue, newValue) =>
        (newValue.text.isEmpty || pattern.hasMatch(newValue.text))
            ? newValue
            : oldValue);


// InheritedWidget to pass close callback to child widgets
class _ModifyGttDialogCloseNotifier extends InheritedWidget {
  final VoidCallback onClose;

  const _ModifyGttDialogCloseNotifier({
    required this.onClose,
    required super.child,
  });

  static _ModifyGttDialogCloseNotifier? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ModifyGttDialogCloseNotifier>();
  }

  @override
  bool updateShouldNotify(_ModifyGttDialogCloseNotifier oldWidget) {
    return onClose != oldWidget.onClose;
  }
}

// InheritedWidget to pass drag callbacks to child widgets
class _ModifyGttDialogDragNotifier extends InheritedWidget {
  final void Function(DragStartDetails) onPanStart;
  final void Function(DragUpdateDetails) onPanUpdate;
  final void Function(DragEndDetails) onPanEnd;
  final bool isDragging;

  const _ModifyGttDialogDragNotifier({
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.isDragging,
    required super.child,
  });

  static _ModifyGttDialogDragNotifier? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ModifyGttDialogDragNotifier>();
  }

  @override
  bool updateShouldNotify(_ModifyGttDialogDragNotifier oldWidget) {
    return onPanStart != oldWidget.onPanStart ||
        onPanUpdate != oldWidget.onPanUpdate ||
        onPanEnd != oldWidget.onPanEnd ||
        isDragging != oldWidget.isDragging;
  }
}

class ModifyGttWeb extends ConsumerStatefulWidget {
  final GttOrderBookModel gttOrderBook;
  final ScripInfoModel scripInfo;
  
  const ModifyGttWeb({
    super.key,
    required this.scripInfo,
    required this.gttOrderBook,
  });

  @override
  ConsumerState<ModifyGttWeb> createState() => _ModifyGttWebState();

  // Static variable to remember the last position of the dialog
  static Offset? _lastSavedPosition;

  /// Static method to show ModifyGttWeb as a draggable dialog
  static void showDraggable({
    required BuildContext context,
    required GttOrderBookModel gttOrderBook,
    required ScripInfoModel scripInfo,
    Offset? initialPosition,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry overlayEntry;

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

    overlayEntry = OverlayEntry(
      maintainState: false,
      builder: (context) => _DraggableModifyGttDialog(
        gttOrderBook: gttOrderBook,
        scripInfo: scripInfo,
        initialPosition: position,
        onPositionChanged: (newPosition) {
          // Save the position for next time
          _lastSavedPosition = newPosition;
        },
        onClose: () {
          // Remove overlay immediately for quick response
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
          // Unregister from overlay manager
          OverlayManager.unregister(overlayEntry);
        },
      ),
    );

    overlay.insert(overlayEntry);

    // Register with overlay manager for global control
    OverlayManager.register(overlayEntry);
  }
}

class _ModifyGttWebState extends ConsumerState<ModifyGttWeb> {
  bool? isBuy;
  bool isOco = false;
  bool isGtt = true;
  String product = "I";
  int lotSize = 0;
  int multiplayer = 0;
  int frezQty = 0;
  String price = "0.00";
  bool _GTTPriceTypeIsMarket = false;
  bool _GTTOCOPriceTypeIsMarket = false;
  
  // For real-time LTP updates
  String? currentLtp;
  String? currentChange;
  String? currentPerChange;

  late final double tik;

  double roundOffWithInterval(double input, double interval) {
    return ((input / interval).round() * interval);
  }

  /// MCX uses lot count in the qty field; multiply by lot size to get the actual qty.
  String _lotsToActualQty(String value) {
    if (widget.gttOrderBook.exch == "MCX") {
      final int lotCount = int.tryParse(value) ?? 0;
      return (lotCount * lotSize).toString();
    }
    return value;
  }

  /// Returns true if the field value (after MCX lots→units conversion) exceeds
  /// the freeze qty cap. GTT has no slicing, so cap = single frezQty.
  bool _exceedsFreezeCap(String value) {
    if (frezQty <= lotSize) return false; // no real freeze limit for this scrip
    final int parsed = int.tryParse(value) ?? 0;
    final int finalUnits =
        widget.gttOrderBook.exch == "MCX" ? parsed * lotSize : parsed;
    return finalUnits > frezQty;
  }

  /// Freeze-cap warning text. MCX shows lots to match field display;
  /// everything else shows qty (since modify GTT field stores units).
  String _gttFreezeCapMessage() {
    if (widget.gttOrderBook.exch == "MCX" && lotSize > 0) {
      return "Maximum Allowed Lots: ${frezQty ~/ lotSize}";
    }
    return "Maximum Allowed Quantity $frezQty";
  }

  /// Tick-size check for a GTT price/trigger field.
  
  String? _gttTickError(String value, String fieldName) {
    if (tik <= 0) return null; // no tick size on this scrip — nothing to check
    final String text = value.trim();
    if (text.isEmpty || text == "Market") return null;
    final double parsed = SafeParse.toDouble(text);
    if (parsed <= 0) return null;
    final String rounded = roundOffWithInterval(parsed, tik).toStringAsFixed(2);
    if (parsed == SafeParse.toDouble(rounded)) return null;
    return "$fieldName should be multiple of tick size $tik => $rounded";
  }

  /// Field label for the quantity box. MCX holds a lot COUNT; everything
  /// else holds units.
  String _qtyFieldLabel({bool isOcoLeg = false}) =>
      "${isOcoLeg ? "OCO " : ""}${widget.gttOrderBook.exch == "MCX" ? "Lot" : "Quantity"}";

  /// Empty / zero check for a price or trigger field.
  ///
  /// Market is a real value for an MKT leg, not a zero - without this skip it
  /// parses to 0 and every Market GTT becomes impossible to modify.
  String? _gttPriceFieldError(String value, String fieldName) {
    final String text = value.trim();
    if (text.isEmpty) return "$fieldName cannot be empty";
    if (text == "Market") return null;
    if (SafeParse.toDouble(text) > 0) return null;
    return "$fieldName cannot be 0";
  }

  /// Lot-multiple check ONLY.
  ///
  /// Returns null for empty and non-positive values so it can run as an early
  /// guard without stealing their messages. The Place Order GTT branch had it
  /// the other way round and reported a bogus "multiple of lot size 1 => 1"
  /// on a blank field (TC_114) - do not make this fire on empty.
  ///
  /// MCX is skipped: its field holds a lot count, so it is a whole number of
  /// lots by construction.
  String? _gttLotError(String value, {bool isOcoLeg = false}) {
    if (widget.gttOrderBook.exch == "MCX" || lotSize <= 0) return null;
    final int parsed = int.tryParse(value.trim()) ?? 0;
    if (parsed <= 0) return null;
    int rounded = (parsed / lotSize).round() * lotSize;
    if (rounded < lotSize) rounded = lotSize; // never suggest 0
    if (parsed == rounded) return null;
    return "${_qtyFieldLabel(isOcoLeg: isOcoLeg)} should be multiple of lot size $lotSize => $rounded";
  }

  /// Empty / zero / freeze-cap / lot-multiple check for a quantity field.
  String? _gttQtyFieldError(String value, {bool isOcoLeg = false}) {
    final String text = value.trim();
    final String label = _qtyFieldLabel(isOcoLeg: isOcoLeg);
    if (text.isEmpty) return "$label cannot be empty";
    if ((int.tryParse(text) ?? 0) <= 0) return "$label cannot be 0";
    if (_exceedsFreezeCap(text)) return _gttFreezeCapMessage();
    return _gttLotError(text, isOcoLeg: isOcoLeg);
  }

  /// Diagnostic chain for the gate else branch.
  ///
  /// Walks the fields in the SAME order the Place Order GTT chain reports
  /// them - target trigger, quantity, price, then the OCO leg - and returns
  /// the first problem, so both screens name the same field for the same
  /// input. Falls back to the original generic text if nothing is found.
  String _gttFieldError(OrderInputProvider o, {required bool isOco}) {
    String? e = _gttPriceFieldError(o.val1Ctrl.text, "Target trigger price");
    if (e != null) return e;
    e = _gttQtyFieldError(o.qtyCtrl.text);
    if (e != null) return e;
    e = _gttPriceFieldError(o.priceCtrl.text, "Price");
    if (e != null) return e;
    if (!isOco) return "Enter all Input fields";
    e = _gttPriceFieldError(o.val2Ctrl.text, "Stoploss trigger price");
    if (e != null) return e;
    e = _gttQtyFieldError(o.ocoQtyCtrl.text, isOcoLeg: true);
    if (e != null) return e;
    e = _gttPriceFieldError(o.ocoPriceCtrl.text, "OCO price");
    if (e != null) return e;
    return "Enter all Input fields";
  }

  bool get _isStockExch =>
      widget.gttOrderBook.exch == "NSE" || widget.gttOrderBook.exch == "BSE";

  /// Step size that moves the qty field by exactly one lot.
  int get _qtyStep =>
      widget.gttOrderBook.exch == "MCX" ? 1 : (lotSize > 0 ? lotSize : 1);

  void _decrementQty(TextEditingController ctrl) {
    final int step = _qtyStep;
    setState(() {
      final int current = int.tryParse(ctrl.text) ?? 0;
      final int snapped =
          current >= step ? ((current / step).floor()) * step : step;
      if (current != snapped) {
        ctrl.text = snapped.toString();
      } else if (current > step) {
        ctrl.text = (current - step).toString();
      } else {
        ctrl.text = step.toString();
      }
    });
  }

  void _incrementQty(TextEditingController ctrl) {
    final int step = _qtyStep;
    setState(() {
      final String input = ctrl.text;
      final int current = int.tryParse(input) ?? 0;
      final int snapped =
          current >= step ? ((current / step).floor()) * step : step;
      if (input.isEmpty) {
        ctrl.text = step.toString();
      } else if (current != snapped) {
        ctrl.text = snapped.toString();
      } else {
        final String nextValue = (current + step).toString();
        if (_exceedsFreezeCap(nextValue)) {
          showResponsiveWarningMessage(context, _gttFreezeCapMessage());
        } else {
          ctrl.text = nextValue;
        }
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
    setState(() {});
    return KeyEventResult.handled;
  }

  /// Handles keyboard up/down arrow to increment/decrement qty by one lot.
  KeyEventResult _handleQtyArrowKey(KeyEvent event, TextEditingController ctrl) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    final isUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final isDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!isUp && !isDown) return KeyEventResult.ignored;

    if (isUp) {
      _incrementQty(ctrl);
    } else {
      _decrementQty(ctrl);
    }
    ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    return KeyEventResult.handled;
  }

  @override
  void initState() {
    final int initialLotSize = int.tryParse("${widget.scripInfo.ls ?? 0}") ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ordInputProvider).getModifyData(widget.gttOrderBook, lotSize: initialLotSize);
    });

    tik = double.tryParse(widget.scripInfo.ti.toString()) ?? 0.00;

    setState(() {
      isOco = widget.gttOrderBook.placeOrderParamsLeg2 != null;
      lotSize = int.parse("${widget.scripInfo.ls ?? 0}");
      isBuy = widget.gttOrderBook.trantype == "B";

      multiplayer = int.parse((widget.gttOrderBook.exch == "MCX"
              ? widget.scripInfo.prcqqty
              : widget.gttOrderBook.ls)
          .toString());

      final int sfq = int.tryParse(widget.scripInfo.frzqty?.toString() ?? '1') ?? 1;
      frezQty = sfq > 1 ? (sfq / lotSize).floor() * lotSize : lotSize;

      product = "I";
      
      // Initialize LTP from order book
      currentLtp = widget.gttOrderBook.ltp ?? widget.gttOrderBook.prc ?? "0.00";
      currentChange = widget.gttOrderBook.change ?? "0.00";
      currentPerChange = widget.gttOrderBook.perChange ?? "0.00";
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Market depth panel (Task #9168): view only on GTT, a tapped price has
    // no single field to go to (trigger vs order price).
    OrderDepthController.syncFrom(
      context,
      token: widget.gttOrderBook.token ?? "",
      exch: widget.gttOrderBook.exch ?? "",
      instname: widget.scripInfo.instname,
      onPriceTap: null,
    );
    final theme = ref.read(themeProvider);
    final internet = ref.watch(networkStateProvider);
    
    // PERFORMANCE FIX: Use ref.read() for stream - watching causes double rebuild
    return StreamBuilder<Map>(
      stream: ref.read(websocketProvider).socketDataStream,
      builder: (context, snapshot) {
        final socketDatas = snapshot.data ?? {};
        
        // Get updated LTP, change, and perChange from websocket if available
        String? updatedLtp = currentLtp;
        String? updatedChange = currentChange;
        String? updatedPerChange = currentPerChange;
        
        if (widget.gttOrderBook.token != null && socketDatas.containsKey(widget.gttOrderBook.token)) {
          final socketData = socketDatas[widget.gttOrderBook.token];
          if (socketData != null) {
            final lp = socketData['lp']?.toString();
            final pc = socketData['pc']?.toString();
            final chng = socketData['chng']?.toString();
            
            if (lp != null && lp != "null" && lp != "0" && lp != "0.00") {
              updatedLtp = lp;
            }
            
            if (pc != null && pc != "null" && pc != "0" && pc != "0.00") {
              updatedPerChange = pc;
            }
            
            if (chng != null && chng != "null") {
              updatedChange = chng;
            }
          }
        }
        
        // Update state variables if changed
        if (updatedLtp != currentLtp || updatedChange != currentChange || updatedPerChange != currentPerChange) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                currentLtp = updatedLtp;
                currentChange = updatedChange;
                currentPerChange = updatedPerChange;
              });
            }
          });
        }
        
        return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        ref.read(ordInputProvider).clearTextField();
        await ref
            .read(marketWatchProvider)
            .requestMWScrip(context: context, isSubscribe: true);
      },
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.isDarkMode ? MyntColors.backgroundColorDark : MyntColors.backgroundColor,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(theme),
            
            // Content
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Symbol and Exchange Info
                      // _buildSymbolSection(theme),
                      // const SizedBox(height: 24),
                      
                      // Trigger Price Section
                      _buildTriggerPriceSection(theme),
                      const SizedBox(height: 24),
                      
                      // Qty and Price Section
                      _buildQtyPriceSection(theme),
                      const SizedBox(height: 24),
                      
                      // OCO Section (if applicable)
                      if (isOco) ...[
                        _buildOcoTriggerSection(theme),
                        const SizedBox(height: 24),
                        _buildOcoQtyPriceSection(theme),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer with Modify Button
            if (internet.connectionStatus == ConnectivityResult.none)
              const NoInternetWidget()
            else
              _buildFooter(theme),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildHeader(ThemesProvider theme) {
    final symbol = widget.gttOrderBook.symbol?.replaceAll("-EQ", "").toUpperCase() ?? widget.scripInfo.symbol ?? '';
    final expDate = widget.gttOrderBook.expDate ?? widget.scripInfo.expDate ?? '';
    final option = widget.gttOrderBook.option ?? widget.scripInfo.option ?? '';
    final exchange = widget.gttOrderBook.exch ?? widget.scripInfo.exch ?? '';
    // Prefer the backend display name (DerivativeMaster) for derivatives.
    final master = widget.gttOrderBook.masterName ?? widget.scripInfo.masterName;

    final ltp = currentLtp ?? widget.gttOrderBook.ltp ?? widget.gttOrderBook.prc ?? '0.00';
    final change = currentChange ?? widget.gttOrderBook.change ?? '0.00';
    final perChange = currentPerChange ?? widget.gttOrderBook.perChange ?? '0.00';

    // Get drag notifier for header dragging
    final dragNotifier = _ModifyGttDialogDragNotifier.of(context);
    final closeNotifier = _ModifyGttDialogCloseNotifier.of(context);

    Widget headerContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.isDarkMode ? MyntColors.overlayBgDark : const Color(0xfffafbff),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Symbol and Exchange
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      Text(
                        "${master ?? "$symbol $expDate $option"} ",
                        style: WebTextStyles.title(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode ? MyntColors.textPrimaryDark : MyntColors.textPrimary,
                          fontWeight: WebFonts.medium,
                        ),
                      ),
                      Text(
                        exchange,
                        style: WebTextStyles.para(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode ? MyntColors.textPrimaryDark : MyntColors.textPrimary,
                            fontWeight: WebFonts.medium,
                        ),
                      ),
                    ],
                  ),
                ),
                // Price and Change
                Row(
                  children: [
                    Text(
                      ltp,
                      style: WebTextStyles.sub(
                        isDarkTheme: theme.isDarkMode,
                        color: (change == "null" || change == "0.00")
                            ? MyntColors.textSecondaryDark
                            : (change.startsWith("-") == true || perChange.startsWith("-") == true)
                                ? resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss)
                                : MyntColors.profit,
                        fontWeight: WebFonts.medium,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${(double.tryParse(change) ?? 0.00).toStringAsFixed(2)} ($perChange%)",
                      style: WebTextStyles.sub(
                        isDarkTheme: theme.isDarkMode,
                        color: theme.isDarkMode ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                        fontWeight: WebFonts.medium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Market depth toggle (Task #9168)
          const OrderDepthToggle(padding: EdgeInsets.only(right: 6)),
          // Close button
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
                  color: theme.isDarkMode ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
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
  }

  Widget _buildSymbolSection(ThemesProvider theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "LTP",
                style: WebTextStyles.para(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode ? MyntColors.textSecondary : MyntColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentLtp ?? widget.gttOrderBook.ltp ?? widget.gttOrderBook.prc ?? '0.00',
                style: WebTextStyles.title(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode ? MyntColors.textPrimary : MyntColors.textPrimary,
                  fontWeight: WebFonts.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Lot Size",
                style: WebTextStyles.para(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode ? MyntColors.textSecondary : MyntColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$lotSize",
                style: WebTextStyles.title(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode ? MyntColors.textPrimary : MyntColors.textPrimary,
                  fontWeight: WebFonts.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerPriceSection(ThemesProvider theme) {
    final orderInput = ref.watch(ordInputProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isOco ? "Target Trigger Price" : "Trigger Price",
          style: WebTextStyles.formLabel(
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode ? MyntColors.textPrimaryDark : MyntColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        // Arrow-key stepping — the Price / OCO Price fields already have
        // this; the two trigger fields were missing it, so up/down did
        // nothing on them (Place Order GTT wires all four).
        Focus(
          onKeyEvent: (node, event) =>
              _handlePriceArrowKey(event, orderInput.val1Ctrl),
          child: SizedBox(
            height: 40,
            width: 200,
            child: MyntTextField(
           backgroundColor: theme.isDarkMode
                                                              ? colors.darkGrey
                                                              : const Color(
                                                                  0xffF1F3F8),
              onChanged: (value) {
                double inputPrice = double.tryParse(value) ?? 0;

                if (value.isNotEmpty && inputPrice > 0) {
                  final regex = RegExp(r'^(\d+)?(\.\d{0,2})?$');
                  if (!regex.hasMatch(value)) {
                    orderInput.val1Ctrl.text = value.substring(0, value.length - 1);
                    orderInput.val1Ctrl.selection = TextSelection.collapsed(
                      offset: orderInput.val1Ctrl.text.length,
                    );
                  }
                }
                if (value.isEmpty || inputPrice <= 0) {
                  showResponsiveWarningMessage(
                    context,
                    "Trigger Price can not be ${inputPrice <= 0 ? 'zero' : 'empty'}",
                  );
                }
              },
              placeholder: currentLtp ?? widget.gttOrderBook.ltp ?? "",
            placeholderStyle: WebTextStyles.formInput(
                                  isDarkTheme: theme.isDarkMode,
                                  color: theme.isDarkMode
                                      ? MyntColors.textSecondary
                                      : MyntColors.textSecondary,
                                ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                _rejectIfNoMatch(RegExp(r'^\d*\.?\d{0,2}$')),
              ],
            textStyle: WebTextStyles.formInput(
                                  isDarkTheme: theme.isDarkMode,
                                  color: theme.isDarkMode
                                      ? MyntColors.textPrimaryDark
                                      : MyntColors.textPrimary,
                                ),
              controller: orderInput.val1Ctrl,
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQtyPriceSection(ThemesProvider theme) {
    final orderInput = ref.watch(ordInputProvider);
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.scripInfo.exch == "MCX" ? "Lot" : "Qty",
                style: WebTextStyles.formLabel(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode ? MyntColors.textPrimaryDark : MyntColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Focus(
                onKeyEvent: (node, event) => _handleQtyArrowKey(event, orderInput.qtyCtrl),
                child: SizedBox(
                height: 40,
                width: 200,
                child: MyntTextField(
                  backgroundColor: theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8),
                  placeholder: orderInput.qtyCtrl.text,
                   placeholderStyle: WebTextStyles.formInput(
                                isDarkTheme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? MyntColors.textSecondary
                                    : MyntColors.textSecondary,
                              ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textStyle: WebTextStyles.formInput(
                                isDarkTheme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? MyntColors.textPrimaryDark
                                    : MyntColors.textPrimary,
                              ),
                  leadingWidget: _isStockExch ? null : GestureDetector(
                    onTap: () => _decrementQty(orderInput.qtyCtrl),
                    child: Icon(
                      Icons.remove,
                      size: 18,
                      color: theme.isDarkMode ? MyntColors.primaryDark : MyntColors.primary,
                    ),
                  ),
                  trailingWidget: _isStockExch ? null : GestureDetector(
                    onTap: () => _incrementQty(orderInput.qtyCtrl),
                    child: Icon(
                      Icons.add,
                      size: 18,
                      color: theme.isDarkMode ? MyntColors.primaryDark : MyntColors.primary,
                    ),
                  ),
                  controller: orderInput.qtyCtrl,
                  textAlign: _isStockExch ? TextAlign.start : TextAlign.center,
                  onChanged: (value) {
                    if (value.isEmpty || value == "0") {
                      showResponsiveWarningMessage(
                        context,
                        "Quantity can not be ${value == "0" ? 'zero' : 'empty'}",
                      );
                    } else {
                      String newValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (newValue != value) {
                        orderInput.qtyCtrl.text = newValue;
                        orderInput.qtyCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: newValue.length),
                        );
                      }
                      if (_exceedsFreezeCap(newValue)) {
                        showResponsiveWarningMessage(
                            context, _gttFreezeCapMessage());
                      }
                    }
                  },
                ),
              ),
              ),
              // MCX field is in lots — show the actual quantity underneath,
              // kept live via the controller listener. Uses the SAME
              // _lotsToActualQty conversion as the submit payload, so the
              // shown qty always matches what gets placed.
              if (widget.scripInfo.exch == "MCX")
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: orderInput.qtyCtrl,
                  builder: (context, value, _) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Qty : ${_lotsToActualQty(value.text)}",
                      style: WebTextStyles.para(
                        isDarkTheme: theme.isDarkMode,
                        color: theme.isDarkMode
                            ? MyntColors.textSecondaryDark
                            : MyntColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                splashColor: theme.isDarkMode
                    ? colors.splashColorDark
                    : colors.splashColorLight,
                highlightColor: theme.isDarkMode
                    ? colors.highlightDark
                    : colors.highlightLight,
                onTap: () {
                  setState(() {
                    _GTTPriceTypeIsMarket = !_GTTPriceTypeIsMarket;
                    orderInput.chngGTTPriceType(
                      _GTTPriceTypeIsMarket ? "Market" : "Limit",
                    );
                    if (orderInput.actPrcType == "Market" ||
                        orderInput.actPrcType == "SL MKT") {
                      orderInput.priceCtrl.text = "Market";
                    } else {
                      // A leg saved as MKT stores prc "0.00" - a real string,
                      // not null - so the `??` below never fell through to LTP
                      // and the box showed 0.00. Treat a non-positive stored
                      // price as absent and seed from LTP, as Place Order does.
                      // A leg saved as LMT still restores its own price.
                      final String storedPrc =
                          widget.gttOrderBook.placeOrderParams?.prc ?? "";
                      orderInput.priceCtrl.text =
                          SafeParse.toDouble(storedPrc) > 0
                              ? storedPrc
                              : (currentLtp ??
                                  widget.gttOrderBook.ltp ??
                                  "0.00");
                    }
                  });
                },
                child: Row(
                  children: [
                    Text(
                      "Price",
                      style: WebTextStyles.formLabel(
                        isDarkTheme: theme.isDarkMode,
                        color: theme.isDarkMode ? MyntColors.textPrimaryDark : MyntColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SvgPicture.asset(
                      assets.switchIcon,
                      width: 16,
                      height: 16,
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(
                        resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Focus(
                onKeyEvent: (node, event) => _handlePriceArrowKey(event, orderInput.priceCtrl),
                child: SizedBox(
                height: 40,
                width: 200,
                child: MyntTextField(
                  backgroundColor: theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      showResponsiveWarningMessage(context, "Price can not be empty");
                    } else {
                      setState(() {
                        price = value;
                      });
                    }
                  },
                  placeholder: "${widget.gttOrderBook.placeOrderParams!.prc}",
               placeholderStyle: WebTextStyles.formInput(
                                isDarkTheme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? MyntColors.textSecondary
                                    : MyntColors.textSecondary,
                              ),
                   textStyle: WebTextStyles.formInput(
                                isDarkTheme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? MyntColors.textPrimaryDark
                                    : MyntColors.textPrimary,
                              ),
                  inputFormatters: [
                    _rejectIfNoMatch(RegExp(r'^\d*\.?\d{0,2}$')),
                  ],
                  readOnly: orderInput.actPrcType == "Limit" ||
                      orderInput.actPrcType == "SL Limit"
                      ? false
                      : true,
                  controller: orderInput.priceCtrl,
                  textAlign: TextAlign.start,
                ),
              ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOcoTriggerSection(ThemesProvider theme) {
    final orderInput = ref.watch(ordInputProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isOco ? "Stoploss Trigger Price" : "Trigger Price",
          style: WebTextStyles.formLabel(
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode ? MyntColors.textPrimaryDark : MyntColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        // Arrow-key stepping — the Price / OCO Price fields already have
        // this; the two trigger fields were missing it, so up/down did
        // nothing on them (Place Order GTT wires all four).
        Focus(
          onKeyEvent: (node, event) =>
              _handlePriceArrowKey(event, orderInput.val2Ctrl),
          child: SizedBox(
            height: 40,
            width: 200,
            child: MyntTextField(
              backgroundColor: theme.isDarkMode
                                                              ? colors.darkGrey
                                                              : const Color(
                                                                  0xffF1F3F8),
              onChanged: (value) {
                double inputPrice = double.tryParse(value) ?? 0;

                if (value.isNotEmpty && inputPrice > 0) {
                  final regex = RegExp(r'^(\d+)?(\.\d{0,2})?$');
                  if (!regex.hasMatch(value)) {
                    orderInput.val2Ctrl.text = value.substring(0, value.length - 1);
                    orderInput.val2Ctrl.selection = TextSelection.collapsed(
                      offset: orderInput.val2Ctrl.text.length,
                    );
                  }
                }
                if (value.isEmpty || inputPrice <= 0) {
                  showResponsiveWarningMessage(
                    context,
                    "Trigger Price can not be ${inputPrice <= 0 ? 'zero' : 'empty'}",
                  );
                }
              },
              placeholder: currentLtp ?? widget.gttOrderBook.ltp ?? "",
             placeholderStyle: WebTextStyles.formInput(
                                  isDarkTheme: theme.isDarkMode,
                                  color: theme.isDarkMode
                                      ? MyntColors.textSecondary
                                      : MyntColors.textSecondary,
                                ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                _rejectIfNoMatch(RegExp(r'^\d*\.?\d{0,2}$')),
              ],
              textStyle: WebTextStyles.formInput(
                                  isDarkTheme: theme.isDarkMode,
                                  color: theme.isDarkMode
                                      ? MyntColors.textPrimaryDark
                                      : MyntColors.textPrimary,
                                ),
              controller: orderInput.val2Ctrl,
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOcoQtyPriceSection(ThemesProvider theme) {
    final orderInput = ref.watch(ordInputProvider);
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.scripInfo.exch == "MCX" ? "Lot" : "Qty",
                style: WebTextStyles.formLabel(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode ? MyntColors.textPrimaryDark : MyntColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Focus(
                onKeyEvent: (node, event) => _handleQtyArrowKey(event, orderInput.ocoQtyCtrl),
                child: SizedBox(
                height: 40,
                width: 200,
                child: MyntTextField(
                  backgroundColor: theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8),
                  placeholder: orderInput.ocoQtyCtrl.text,
                  placeholderStyle: WebTextStyles.formInput(
                                isDarkTheme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? MyntColors.textSecondary
                                    : MyntColors.textSecondary,
                              ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textStyle: WebTextStyles.formInput(
                                isDarkTheme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? MyntColors.textPrimaryDark
                                    : MyntColors.textPrimary,
                              ),
                  leadingWidget: _isStockExch ? null : GestureDetector(
                    onTap: () => _decrementQty(orderInput.ocoQtyCtrl),
                    child: Icon(
                      Icons.remove,
                      size: 18,
                      color: theme.isDarkMode ? MyntColors.primaryDark : MyntColors.primary,
                    ),
                  ),
                  trailingWidget: _isStockExch ? null : GestureDetector(
                    onTap: () => _incrementQty(orderInput.ocoQtyCtrl),
                    child: Icon(
                      Icons.add,
                      size: 18,
                      color: theme.isDarkMode ? MyntColors.primaryDark : MyntColors.primary,
                    ),
                  ),
                  controller: orderInput.ocoQtyCtrl,
                  textAlign: _isStockExch ? TextAlign.start : TextAlign.center,
                  onChanged: (value) {
                    if (value.isEmpty || value == "0") {
                      showResponsiveWarningMessage(
                        context,
                        "Quantity can not be ${value == "0" ? 'zero' : 'empty'}",
                      );
                    } else {
                      String newValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (newValue != value) {
                        orderInput.ocoQtyCtrl.text = newValue;
                        orderInput.ocoQtyCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: newValue.length),
                        );
                      }
                      if (_exceedsFreezeCap(newValue)) {
                        showResponsiveWarningMessage(
                            context, _gttFreezeCapMessage());
                      }
                    }
                  },
                ),
              ),
              ),
              // MCX field is in lots — show the actual quantity underneath,
              // kept live via the controller listener (same conversion as the
              // submit payload).
              if (widget.scripInfo.exch == "MCX")
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: orderInput.ocoQtyCtrl,
                  builder: (context, value, _) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Qty : ${_lotsToActualQty(value.text)}",
                      style: WebTextStyles.para(
                        isDarkTheme: theme.isDarkMode,
                        color: theme.isDarkMode
                            ? MyntColors.textSecondaryDark
                            : MyntColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                splashColor: theme.isDarkMode
                    ? colors.splashColorDark
                    : colors.splashColorLight,
                highlightColor: theme.isDarkMode
                    ? colors.highlightDark
                    : colors.highlightLight,
                onTap: () {
                  setState(() {
                    _GTTOCOPriceTypeIsMarket = !_GTTOCOPriceTypeIsMarket;
                    orderInput.chngOCOPriceType(
                      _GTTOCOPriceTypeIsMarket ? "Market" : "Limit",
                    );
                    if (orderInput.actOcoPrcType == "Market" ||
                        orderInput.actOcoPrcType == "SL MKT") {
                      orderInput.ocoPriceCtrl.text = "Market";
                    } else {
                      // The OCO leg saved as MKT stores prc "0.00" - a real string,
                      // not null - so the `??` below never fell through to LTP
                      // and the box showed 0.00. Treat a non-positive stored
                      // price as absent and seed from LTP, as Place Order does.
                      // The OCO leg saved as LMT still restores its own price.
                      final String storedOcoPrc =
                          widget.gttOrderBook.placeOrderParamsLeg2?.prc ?? "";
                      orderInput.ocoPriceCtrl.text =
                          SafeParse.toDouble(storedOcoPrc) > 0
                              ? storedOcoPrc
                              : (currentLtp ??
                                  widget.gttOrderBook.ltp ??
                                  "0.00");
                    }
                  });
                },
                child: Row(
                  children: [
                    Text(
                      "Price",
                      style: WebTextStyles.formLabel(
                        isDarkTheme: theme.isDarkMode,
                        color: theme.isDarkMode ? MyntColors.textPrimaryDark : MyntColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SvgPicture.asset(
                      assets.switchIcon,
                      width: 16,
                      height: 16,
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(
                        resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Focus(
                onKeyEvent: (node, event) => _handlePriceArrowKey(event, orderInput.ocoPriceCtrl),
                child: SizedBox(
                height: 40,
                width: 200,
                child: MyntTextField(
                  backgroundColor: theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8),
                  onChanged: (value) {},
                  placeholder: "${widget.gttOrderBook.placeOrderParamsLeg2!.prc}",
                  placeholderStyle: WebTextStyles.formInput(
                                isDarkTheme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? MyntColors.textSecondary
                                    : MyntColors.textSecondary,
                              ),
                 textStyle: WebTextStyles.formInput(
                                isDarkTheme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? MyntColors.textPrimaryDark
                                    : MyntColors.textPrimary,
                              ),
                  inputFormatters: [
                    _rejectIfNoMatch(RegExp(r'^\d*\.?\d{0,2}$')),
                  ],
                  readOnly: orderInput.actOcoPrcType == "Limit" ||
                      orderInput.actOcoPrcType == "SL Limit"
                      ? false
                      : true,
                  controller: orderInput.ocoPriceCtrl,
                  textAlign: TextAlign.start,
                ),
              ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(ThemesProvider theme) {
    final orderInput = ref.watch(ordInputProvider);
    final internet = ref.watch(networkStateProvider);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.isDarkMode ? MyntColors.dividerDark : MyntColors.divider,
          ),
        ),
      ),
      child: Row(
        children: [
          // Expanded(
          //   child: Container(
          //     height: 40,
          //     decoration: BoxDecoration(
          //       border: theme.isDarkMode
          //           ? null
          //           : Border.all(
          //               color: colors.primaryLight,
          //               width: 1),
          //       color: theme.isDarkMode
          //           ? colors.textSecondaryDark.withOpacity(0.6)
          //           : colors.btnBg,
          //       borderRadius: BorderRadius.circular(5),
          //     ),
          //     child: Material(
          //       color: Colors.transparent,
          //       shape: const BeveledRectangleBorder(),
          //       child: InkWell(
          //         customBorder: const BeveledRectangleBorder(),
          //         splashColor: theme.isDarkMode
          //             ? colors.splashColorDark
          //             : colors.splashColorLight,
          //         highlightColor: theme.isDarkMode
          //             ? colors.highlightDark
          //             : colors.highlightLight,
          //         onTap: () {
          //           ref.read(ordInputProvider).clearTextField();
          //           // Try to use draggable dialog close callback, fallback to Navigator.pop
          //           if (closeNotifier != null) {
          //             closeNotifier.onClose();
          //           } else {
          //             Navigator.pop(context);
          //           }
          //         },
          //         child: Center(
          //           child: Text(
          //             "Close",
          //             style: WebTextStyles.buttonMd(
          //               isDarkTheme: theme.isDarkMode,
          //               color: theme.isDarkMode
          //                   ? colors.colorWhite
          //                   : colors.primaryLight,
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
                onPressed: internet.connectionStatus == ConnectivityResult.none ||
                    ref.read(orderProvider).loading
                    ? null
                    : () async {
                        // Freeze qty cap guard — GTT has no slicing, so block any
                        // qty whose final units exceed single freeze qty (frezQty).
                        if (_exceedsFreezeCap(orderInput.qtyCtrl.text)) {
                          showResponsiveWarningMessage(
                              context, _gttFreezeCapMessage());
                          return;
                        }
                        if (orderInput.disableGTTCond &&
                            _exceedsFreezeCap(orderInput.ocoQtyCtrl.text)) {
                          showResponsiveWarningMessage(
                              context, _gttFreezeCapMessage());
                          return;
                        }
                        // Lot-multiple guard - runs before the gate, as Place Order GTT does,
                        // because the gate itself does not test lot multiples. Returns null for
                        // empty/zero so it can never steal their messages (TC_114).
                        String? gttLotErr = _gttLotError(orderInput.qtyCtrl.text);
                        if (gttLotErr == null && orderInput.disableGTTCond) {
                          gttLotErr =
                              _gttLotError(orderInput.ocoQtyCtrl.text, isOcoLeg: true);
                        }
                        if (gttLotErr != null) {
                          showResponsiveWarningMessage(context, gttLotErr);
                          return;
                        }
                        // Tick-size guard — trigger/price must be a multiple of the scrip's
                        // tick size, matching the Place Order GTT path. Early return so the
                        // existing validation chain below is untouched.
                        String? gttTickErr =
                            _gttTickError(orderInput.val1Ctrl.text, "Target trigger price");
                        gttTickErr ??= _gttTickError(orderInput.priceCtrl.text, "Price");
                        if (gttTickErr == null && orderInput.disableGTTCond) {
                          gttTickErr = _gttTickError(
                              orderInput.val2Ctrl.text, "Stoploss trigger price");
                          gttTickErr ??=
                              _gttTickError(orderInput.ocoPriceCtrl.text, "OCO price");
                        }
                        if (gttTickErr != null) {
                          showResponsiveWarningMessage(context, gttTickErr);
                          return;
                        }
                        if (orderInput.disableGTTCond) {
                          // Gate - every field present AND positive, mirroring the Place Order
                          // GTT gate. Market is a real price for an MKT leg, not a zero.
                          if ((orderInput.val1Ctrl.text.isNotEmpty &&
                                  orderInput.val2Ctrl.text.isNotEmpty &&
                                  orderInput.priceCtrl.text.isNotEmpty &&
                                  orderInput.ocoPriceCtrl.text.isNotEmpty &&
                                  orderInput.ocoQtyCtrl.text.isNotEmpty) &&
                              orderInput.qtyCtrl.text.isNotEmpty &&
                              SafeParse.toDouble(orderInput.val1Ctrl.text) > 0 &&
                              SafeParse.toDouble(orderInput.val2Ctrl.text) > 0 &&
                              SafeParse.toDouble(orderInput.qtyCtrl.text) > 0 &&
                              SafeParse.toDouble(orderInput.ocoQtyCtrl.text) > 0 &&
                              (orderInput.priceCtrl.text == "Market" ||
                                  SafeParse.toDouble(orderInput.priceCtrl.text) > 0) &&
                              (orderInput.ocoPriceCtrl.text == "Market" ||
                                  SafeParse.toDouble(orderInput.ocoPriceCtrl.text) > 0)) {
                            double ltp = SafeParse.toDouble(currentLtp ?? widget.gttOrderBook.ltp);
                            double val1 = SafeParse.toDouble(orderInput.val1Ctrl.text);
                            double val2 = SafeParse.toDouble(orderInput.val2Ctrl.text);

                            // SELL OCO: target > LTP, stoploss < LTP. BUY OCO (F&O): target < LTP, stoploss > LTP.
                            final bool ocoConditionValid = (isBuy ?? false)
                                ? (val1 < ltp && val2 > ltp)
                                : (val1 > ltp && val2 < ltp);

                            if (ocoConditionValid) {
                              prepareToModifyOCOOrder(orderInput);
                            } else {
                              final String ocoErrorMsg = (isBuy ?? false)
                                  ? (val1 >= ltp
                                      ? "Target Trigger Price can not be Greater than or equal to LTP"
                                      : val2 <= ltp
                                          ? "Stoploss Trigger Price can not be Less than or equal to LTP"
                                          : "Invalid trigger prices")
                                  // Both sell branches reject the equal case as well, so the
                                  // wording has to say so. The buy branch above already spelled
                                  // it out; the mismatch meant a trigger typed exactly at LTP was
                                  // refused with "cannot be less than LTP", which contradicted
                                  // what the user had entered (TC_274 / TC_276). The old third
                                  // branch here read "cannot be equal to LTP" and was
                                  // unreachable - every failing sell case is caught by one of the
                                  // two above it - so it now matches the buy fallback.
                                  : (val1 <= ltp
                                      ? "Target Trigger Price can not be Less than or equal to LTP"
                                      : val2 >= ltp
                                          ? "Stoploss Trigger Price can not be Greater than or equal to LTP"
                                          : "Invalid trigger prices");
                              showResponsiveWarningMessage(context, ocoErrorMsg);
                            }
                          } else {
                            showResponsiveWarningMessage(
                                context, _gttFieldError(orderInput, isOco: true));
                          }
                        } else {
                          // Gate - every field present AND positive, mirroring the Place Order
                          // GTT gate. Market is a real price for an MKT leg, not a zero.
                          if ((orderInput.val1Ctrl.text.isNotEmpty &&
                                  orderInput.priceCtrl.text.isNotEmpty) &&
                              orderInput.qtyCtrl.text.isNotEmpty &&
                              SafeParse.toDouble(orderInput.val1Ctrl.text) > 0 &&
                              SafeParse.toDouble(orderInput.qtyCtrl.text) > 0 &&
                              (orderInput.priceCtrl.text == "Market" ||
                                  SafeParse.toDouble(orderInput.priceCtrl.text) > 0)) {
                            double ltp = SafeParse.toDouble(currentLtp ?? widget.gttOrderBook.ltp);
                            double val1 = SafeParse.toDouble(orderInput.val1Ctrl.text);

                            // chngCond must run before chngAlert (chngAlert reads _actCond to set _ait).
                            if (val1 > ltp) {
                              orderInput.chngCond("Greater than");
                              orderInput.chngAlert("LTP");
                              prepareToModifyGttOrder(orderInput);
                            } else if (val1 < ltp) {
                              orderInput.chngCond("Less than");
                              orderInput.chngAlert("LTP");
                              prepareToModifyGttOrder(orderInput);
                            } else {
                              showResponsiveWarningMessage(
                                context,
                                "Trigger Price can not be equal to LTP",
                              );
                            }
                          } else {
                            showResponsiveWarningMessage(
                                context, _gttFieldError(orderInput, isOco: false));
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  backgroundColor: isBuy! 
                      ? (theme.isDarkMode ? MyntColors.secondary : MyntColors.primary)
                      : (theme.isDarkMode ? MyntColors.errorDark : MyntColors.tertiary),
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: ref.read(orderProvider).loading
                    ? const SizedBox(
                        width: 18,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xff666666),
                        ),
                      )
                    : Text(
                        "Modify",
                        style: WebTextStyles.buttonMd(
                          isDarkTheme: theme.isDarkMode,
                          color: MyntColors.backgroundColor,
                          fontWeight: WebFonts.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  prepareToModifyGttOrder(OrderInputProvider orderInput) async {
    PlaceGTTOrderInput input = PlaceGTTOrderInput(
      exch: '${widget.gttOrderBook.exch}',
      qty: _lotsToActualQty(orderInput.qtyCtrl.text),
      tsym: '${widget.gttOrderBook.tsym}',
      validity: "GTT",
      prc: orderInput.priceCtrl.text,
      prd: orderInput.orderType,
      trantype: isBuy! ? 'B' : "S",
      ret: 'DAY',
      ait: orderInput.ait,
      d: orderInput.val1Ctrl.text,
      prctyp: orderInput.prcType,
      remarks: orderInput.reMarksCtrl.text,
      trgprc: orderInput.actPrcType == "SL Limit" || orderInput.actPrcType == "SL MKT"
          ? orderInput.trgPrcCtrl.text
          : "",
      alid: '${widget.gttOrderBook.alId}',
    );
    
    // Get the result before calling modify
    final orderProv = ref.read(orderProvider);
    
    // Close the draggable dialog callback (get it before the async call)
    final closeNotifier = _ModifyGttDialogCloseNotifier.of(context);
    
    await orderProv.modifyGTTOrder(input, context);
    
    // Check if modification was successful by checking the model
    final modifyResult = orderProv.modifyGttOrderModel;
    final wasSuccessful = modifyResult?.stat == "OI replaced";
    
    // Close the draggable dialog immediately if modification was successful
    // Close right away to prevent user from seeing cleared fields
    if (wasSuccessful && closeNotifier != null && mounted) {
      // Close immediately - don't wait
      closeNotifier.onClose();
    }
  }

  prepareToModifyOCOOrder(OrderInputProvider orderInput) async {
    PlaceOcoOrderInput input = PlaceOcoOrderInput(
      exch: '${widget.gttOrderBook.exch}',
      tsym: '${widget.gttOrderBook.tsym}',
      validity: "GTT",
      trantype: isBuy! ? 'B' : "S",
      ret: 'DAY',
      remarks: orderInput.reMarksCtrl.text,
      qty1: _lotsToActualQty(orderInput.qtyCtrl.text),
      trgprc1: orderInput.actOcoPrcType == "SL Limit" || orderInput.actOcoPrcType == "SL MKT"
          ? orderInput.trgPrcCtrl.text
          : "",
      prc1: orderInput.priceCtrl.text,
      prd1: orderInput.orderType,
      d1: orderInput.val1Ctrl.text,
      prctyp1: orderInput.prcType,
      d2: orderInput.val2Ctrl.text,
      prctyp2: orderInput.ocoPrcType,
      prc2: orderInput.ocoPriceCtrl.text,
      prd2: orderInput.ocoOrderType,
      qty2: _lotsToActualQty(orderInput.ocoQtyCtrl.text),
      trgprc2: orderInput.actOcoPrcType == "SL Limit" || orderInput.actOcoPrcType == "SL MKT"
          ? orderInput.ocoTrgPrcCtrl.text
          : "",
      alid: '${widget.gttOrderBook.alId}',
    );
    
    // Get the result before calling modify
    final orderProv = ref.read(orderProvider);
    
    // Close the draggable dialog callback (get it before the async call)
    final closeNotifier = _ModifyGttDialogCloseNotifier.of(context);
    
    await orderProv.modifyOCOOrder(input, context);
    
    // Check if modification was successful by checking the model
    final modifyResult = orderProv.modifyGttOrderModel;
    final wasSuccessful = modifyResult?.stat == "OI replaced";
    
    // Close the draggable dialog immediately if modification was successful
    // Close right away to prevent user from seeing cleared fields
    if (wasSuccessful && closeNotifier != null && mounted) {
      // Close immediately - don't wait
      closeNotifier.onClose();
    }
  }

}

// Draggable Modify GTT Dialog Widget
class _DraggableModifyGttDialog extends ConsumerStatefulWidget {
  final GttOrderBookModel gttOrderBook;
  final ScripInfoModel scripInfo;
  final Offset initialPosition;
  final Function(Offset) onPositionChanged;
  final VoidCallback onClose;

  const _DraggableModifyGttDialog({
    required this.gttOrderBook,
    required this.scripInfo,
    required this.initialPosition,
    required this.onPositionChanged,
    required this.onClose,
  });

  @override
  ConsumerState<_DraggableModifyGttDialog> createState() => _DraggableModifyGttDialogState();
}

class _DraggableModifyGttDialogState extends ConsumerState<_DraggableModifyGttDialog> {
  late Offset _position;
  bool _isDragging = false;

  // Where the window is drawn (clamped) plus any drag since the last frame.
  Offset _dragBase = Offset.zero;

  late final OrderDepthController _depth;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _depth = OrderDepthController()..addListener(_onDepthChanged);
  }

  void _onDepthChanged() {
    if (mounted) setState(() {});
  }

  // Same chart-iframe guard as the order window, for the depth panel.
  Widget _guardChartIframes(Widget child) {
    return PointerInterceptor(
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        // _disableAllChartIframes also resets the page cursor to the arrow
        // on every move, which wiped the hand cursor on the depth rows. The
        // panel only needs the chart iframes kept from taking the mouse.
        onEnter: (_) {
          ChartIframeGuard.acquire();
          _blockChartIframesOnly();
        },
        onHover: (_) => _blockChartIframesOnly(),
        onExit: (_) {
          ChartIframeGuard.release();
          _enableAllChartIframes();
        },
        child: Listener(
          onPointerMove: (_) => _blockChartIframesOnly(),
          child: child,
        ),
      ),
    );
  }

  void _blockChartIframesOnly() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement &&
            iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'none';
        }
      }
    } catch (e) {
      // DOM access can fail during teardown — ignore
    }
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
    _depth.removeListener(_onDepthChanged);
    _depth.dispose();
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
    // final constrainedPosition = Offset(
    //   _position.dx.clamp(0, screenSize.width - dialogWidth),
    //   _position.dy.clamp(0, screenSize.height - dialogHeight),
    // );
    // Market depth panel beside the window (Task #9168).
    final depthPlacement = OrderDepthPlacement.of(
      screenWidth: screenSize.width,
      windowLeft: _position.dx.clamp(0, screenSize.width - dialogWidth),
      windowWidth: dialogWidth,
      showPanel: _depth.showing,
    );
    final double top =
        _position.dy.clamp(0, screenSize.height - dialogHeight);
    final constrainedPosition = Offset(depthPlacement.windowLeft, top);
    _dragBase = constrainedPosition;

    return Stack(
      children: [
        if (depthPlacement.panelLeft != null)
          Positioned(
            left: depthPlacement.panelLeft,
            top: top,
            child: _guardChartIframes(OrderDepthDock(controller: _depth)),
          ),
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
                    color: theme.isDarkMode ? MyntColors.backgroundColorDark : MyntColors.backgroundColor,
                    child: Container(
                      width: dialogWidth,
                      height: dialogHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: theme.isDarkMode ? MyntColors.dividerDark : MyntColors.divider,
                        ),
                      ),
                      child: _ModifyGttDialogCloseNotifier(
                        onClose: widget.onClose,
                        child: _ModifyGttDialogDragNotifier(
                          onPanStart: (details) {
                            setState(() {
                              _isDragging = true;
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              // _position = Offset(
                              //   _position.dx + details.delta.dx,
                              //   _position.dy + details.delta.dy,
                              // );
                              // Move from where the window is drawn, updated
                              // per event (same as the Place Order shell).
                              _dragBase = _dragBase + details.delta;
                              _position = _dragBase;
                            });
                            widget.onPositionChanged(_position);
                          },
                          onPanEnd: (details) {
                            setState(() {
                              _isDragging = false;
                            });
                          },
                          isDragging: _isDragging,
                          child: OrderDepthScope(
                            controller: _depth,
                            child: ModifyGttWeb(
                              gttOrderBook: widget.gttOrderBook,
                              scripInfo: widget.scripInfo,
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
        ),
      ],
    );
  }
}

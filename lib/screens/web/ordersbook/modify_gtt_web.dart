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
        SizedBox(
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
                      orderInput.priceCtrl.text =
                          widget.gttOrderBook.placeOrderParams?.prc ??
                              currentLtp ??
                              "0.00";
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
        SizedBox(
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
                      orderInput.ocoPriceCtrl.text =
                          widget.gttOrderBook.placeOrderParamsLeg2?.prc ??
                              currentLtp ??
                              "0.00";
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
                        if (orderInput.disableGTTCond) {
                          if ((orderInput.val1Ctrl.text.isNotEmpty &&
                                  orderInput.val2Ctrl.text.isNotEmpty &&
                                  orderInput.priceCtrl.text.isNotEmpty &&
                                  orderInput.ocoPriceCtrl.text.isNotEmpty &&
                                  orderInput.ocoQtyCtrl.text.isNotEmpty) &&
                              orderInput.qtyCtrl.text.isNotEmpty) {
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
                                  : (val1 <= ltp
                                      ? "Target Trigger Price can not be Less than LTP"
                                      : val2 >= ltp
                                          ? "Stoploss Trigger Price can not be Greater than LTP"
                                          : "Trigger Price can not be equal to LTP");
                              showResponsiveWarningMessage(context, ocoErrorMsg);
                            }
                          } else {
                            showResponsiveWarningMessage(context, "Enter all Input fields");
                          }
                        } else {
                          if ((orderInput.val1Ctrl.text.isNotEmpty &&
                                  orderInput.priceCtrl.text.isNotEmpty) &&
                              orderInput.qtyCtrl.text.isNotEmpty) {
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
                            showResponsiveWarningMessage(context, "Enter all Input fields");
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
      ],
    );
  }
}

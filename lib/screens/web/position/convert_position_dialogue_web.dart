import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../models/portfolio_model/position_book_model.dart';
import '../../../models/portfolio_model/position_convertion_model.dart';
import '../../../provider/portfolio_provider.dart';
import '../../../res/res.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/responsive_extensions.dart';
import '../../../sharedWidget/snack_bar.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../sharedWidget/common_text_fields_web.dart';
import '../market_watch/tv_chart/chart_iframe_guard.dart';

class ConvertPositionDialogueWeb extends ConsumerStatefulWidget {
  final PositionBookModel convertPosition;
  const ConvertPositionDialogueWeb({super.key, required this.convertPosition});

  @override
  ConsumerState<ConvertPositionDialogueWeb> createState() =>
      _ConvertPositionDialogueWebState();
}

class _ConvertPositionDialogueWebState
    extends ConsumerState<ConvertPositionDialogueWeb> {
  late TextEditingController _qtyController;
  late String _maxQty;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Disable chart iframe pointer events when dialog opens
    ChartIframeGuard.acquire();
    _disableAllChartIframes();

    _maxQty = widget.convertPosition.netqty!.replaceAll("-", "");
    String initialQty = _maxQty;
    int lotSize = int.parse("${widget.convertPosition.ls ?? 1}");

    if (widget.convertPosition.exch == "MCX") {
      _maxQty = (int.parse(_maxQty) ~/ lotSize).toString();
      initialQty = _maxQty;
    }

    _qtyController = TextEditingController(text: initialQty);
    // Rebuild so the Lot / Qty helper line follows what is typed
    _qtyController.addListener(_onQtyChanged);

    // Request focus after dialog animation completes
    Future.delayed(const Duration(milliseconds: 250), () {
      _focusNode.requestFocus();
      // Position cursor at end
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_qtyController.text.isNotEmpty) {
          _qtyController.selection = TextSelection.collapsed(
            offset: _qtyController.text.length,
          );
        }
      });
    });
  }

  void _onQtyChanged() {
    if (mounted) setState(() {});
  }

  bool get _isMcx => widget.convertPosition.exch == 'MCX';

  int get _lotSize {
    final ls = int.tryParse("${widget.convertPosition.ls ?? 1}") ?? 1;
    return ls > 0 ? ls : 1;
  }

  // Same helper lines as Place Order: MCX box is in lots (show Qty),
  // other lot-based contracts box is in units (show Lot).
  String _qtyHelperText() {
    final typed = int.tryParse(_qtyController.text) ?? 0;
    if (_isMcx) {
      return "Max Lot: $_maxQty · Qty: ${typed * _lotSize}";
    }
    if (_lotSize > 1) {
      return "Max Qty: $_maxQty · Lot: ${(typed / _lotSize).ceil()}";
    }
    return "Max Qty: $_maxQty";
  }

  @override
  void dispose() {
    _qtyController.removeListener(_onQtyChanged);
    _qtyController.dispose();
    _focusNode.dispose();
    // Re-enable chart iframe pointer events when dialog closes
    ChartIframeGuard.release();
    _enableAllChartIframes();
    super.dispose();
  }

  // Disable all chart iframes to allow dialog interaction
  void _disableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement &&
            iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'none';
          iframe.style.cursor = 'default';
        }
      }
      html.document.body?.style.cursor = 'default';
    } catch (e) {
    }
  }

  // Re-enable all chart iframes
  void _enableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement &&
            iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'auto';
          iframe.style.cursor = '';
        }
      }
      html.document.body?.style.cursor = '';
    } catch (e) {
    }
  }

  String _getTargetProduct() {
    if (widget.convertPosition.sPrdtAli == "MIS" &&
        (widget.convertPosition.exch == "NSE" ||
            widget.convertPosition.exch == "BSE")) {
      return "CNC";
    } else if (widget.convertPosition.sPrdtAli == "MIS") {
      return "NRML";
    } else if (widget.convertPosition.sPrdtAli == "CNC") {
      return "MIS";
    } else {
      return "MIS";
    }
  }

  String _getTargetProductCode() {
    if (widget.convertPosition.sPrdtAli == "MIS" &&
        (widget.convertPosition.exch == "NSE" ||
            widget.convertPosition.exch == "BSE")) {
      return "C";
    } else if (widget.convertPosition.sPrdtAli == "MIS") {
      return "M";
    } else if (widget.convertPosition.sPrdtAli == "CNC") {
      return "I";
    } else {
      return "I";
    }
  }

  Future<void> _handleConvert() async {

    // if (_qtyController.text.isEmpty || _qtyController.text == "0") {
    if (_qtyController.text.isEmpty ||
        (int.tryParse(_qtyController.text) ?? 0) <= 0) {
      showResponsiveWarningMessage(
        context,
        _qtyController.text.isEmpty
            ? 'Quantity cannot be empty'
            : "Quantity cannot be 0",
      );
      return;
    }

    if (int.parse(_qtyController.text) > int.parse(_maxQty)) {
      setState(() {
        _qtyController.text = _maxQty;
      });
      showResponsiveWarningMessage(
        context,
        // 'Quantity cannot be greater than Max Quantity',
        _isMcx
            ? 'Lot cannot be greater than Max Lot'
            : 'Quantity cannot be greater than Max Quantity',
      );
      return;
    }

    // Lot-multiple guard, same rule and message as Place Order (MCX box is in lots)
    if (!_isMcx) {
      final enteredQty = int.parse(_qtyController.text);
      int q = (enteredQty / _lotSize).round() * _lotSize;
      if (q < _lotSize) q = _lotSize; // never suggest 0 — minimum is one lot
      if (enteredQty != q) {
        showResponsiveWarningMessage(
          context,
          "Quantity should be multiple of lot size $_lotSize => $q",
        );
        return;
      }
    }

    final finalQty = widget.convertPosition.exch == 'MCX'
        ? (int.parse(_qtyController.text) *
                int.parse(widget.convertPosition.ls.toString()))
            .toInt()
            .toString()
        : _qtyController.text;


    PositionConvertionInput positionConvertionInput = PositionConvertionInput(
      exch: "${widget.convertPosition.exch}",
      postype: "DAY",
      prd: _getTargetProductCode(),
      prevprd: "${widget.convertPosition.prd}",
      qty: finalQty,
      trantype: widget.convertPosition.netqty!.startsWith('-') ? "S" : "B",
      tsym: "${widget.convertPosition.tsym}",
    );

    await ref
        .read(portfolioProvider)
        .fetchPositionConverstion(positionConvertionInput, context);
  }

  @override
  Widget build(BuildContext context) {
    // Responsive dialog sizing
    final dialogWidth = context.responsiveValue<double>(
      mobile: context.screenWidth * 0.9,
      smallTablet: 360,
      tablet: 380,
      desktop: 400,
    );
    final contentPadding = context.responsive<double>(
      mobile: 12,
      tablet: 14,
      desktop: 16,
    );
    final sectionSpacing = context.responsive<double>(
      mobile: 16,
      tablet: 20,
      desktop: 24,
    );

    final targetProduct = _getTargetProduct();

    return PointerInterceptor(
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
          child: Center(
            child: shadcn.Card(
              borderRadius: BorderRadius.circular(8),
              padding: EdgeInsets.zero,
              child: Container(
                width: dialogWidth,
                constraints: const BoxConstraints(maxHeight: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: contentPadding,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: shadcn.Theme.of(context).colorScheme.border,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${widget.convertPosition.symbol} ${widget.convertPosition.option ?? ''} ${widget.convertPosition.exch}",
                              style: context.isMobile
                                  ? MyntWebTextStyles.body(
                                      context,
                                      color: resolveThemeColor(
                                        context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary,
                                      ),
                                      fontWeight: MyntFonts.medium,
                                    )
                                  : MyntWebTextStyles.title(
                                      context,
                                      color: resolveThemeColor(
                                        context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary,
                                      ),
                                      fontWeight: MyntFonts.medium,
                                    ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          MyntCloseButton(
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.all(contentPadding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Order Type Section
                            Text(
                              "Order Type",
                              style: MyntWebTextStyles.body(
                                context,
                                fontWeight: MyntFonts.semiBold,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.textSecondaryDark,
                                  light: MyntColors.textSecondary,
                                ),
                              ),
                            ),
                            SizedBox(height: context.responsive<double>(
                              mobile: 8,
                              tablet: 9,
                              desktop: 10,
                            )),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Current product (NRML/MIS/CNC)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.listItemBgDark,
                                      light: MyntColors.listItemBg,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    "${widget.convertPosition.sPrdtAli}",
                                    style: MyntWebTextStyles.body(
                                      context,
                                      fontWeight: MyntFonts.semiBold,
                                      color: resolveThemeColor(
                                        context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),

                                // Arrow icon
                                SvgPicture.asset(
                                  assets.rightarrow,
                                  colorFilter: ColorFilter.mode(
                                    resolveThemeColor(
                                      context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary,
                                    ),
                                    BlendMode.srcIn,
                                  ),
                                  width: 18,
                                  height: 18,
                                ),

                                // Target product
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.secondary,
                                      light: MyntColors.primary,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    targetProduct,
                                    style: MyntWebTextStyles.body(
                                      context,
                                      fontWeight: MyntFonts.semiBold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: sectionSpacing),

                            // Quantity Section
                            Text(
                              // "Quantity (Lot Size: ${widget.convertPosition.ls})",
                              _isMcx ? "Lot" : "Qty",
                              style: MyntWebTextStyles.body(
                                context,
                                fontWeight: MyntFonts.semiBold,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.textSecondaryDark,
                                  light: MyntColors.textSecondary,
                                ),
                              ),
                            ),
                            SizedBox(height: context.responsive<double>(
                              mobile: 8,
                              tablet: 9,
                              desktop: 10,
                            )),
                            MyntFormTextField(
                              controller: _qtyController,
                              focusNode: _focusNode,
                              // placeholder: 'Enter quantity',
                              placeholder: _isMcx ? 'Enter lot' : 'Enter quantity',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              // "Max Qty: $_maxQty",
                              _qtyHelperText(),
                              style: MyntWebTextStyles.para(
                                context,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.textSecondaryDark,
                                  light: MyntColors.textSecondary,
                                ),
                              ),
                            ),
                            SizedBox(height: sectionSpacing),

                            // Convert Position Button
                            MyntPrimaryButton(
                              size: context.isMobile
                                  ? MyntButtonSize.medium
                                  : MyntButtonSize.large,
                              label: 'Convert Position',
                              isFullWidth: true,
                              onPressed: _handleConvert,
                            ),
                          ],
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
    );
  }
}

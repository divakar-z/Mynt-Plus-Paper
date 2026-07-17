import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/global_state_text.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart' hide WebTextStyles;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/res.dart';

import '../../../../models/ipo_model/ipo_details_model.dart';
import '../../../../models/ipo_model/ipo_mainstream_model.dart';
import '../../../../models/ipo_model/ipo_place_order_model.dart';
import '../../../../models/ipo_model/ipo_sme_model.dart';
import '../../../../provider/iop_provider.dart';
import '../../../../provider/transcation_provider.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import '../../../../sharedWidget/snack_bar.dart';

// InheritedWidget to pass close callback to child widgets
class _IpoOrderDialogCloseNotifier extends InheritedWidget {
  final VoidCallback onClose;

  const _IpoOrderDialogCloseNotifier({
    required this.onClose,
    required super.child,
  });

  static _IpoOrderDialogCloseNotifier? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_IpoOrderDialogCloseNotifier>();
  }

  @override
  bool updateShouldNotify(_IpoOrderDialogCloseNotifier oldWidget) {
    return onClose != oldWidget.onClose;
  }
}

// InheritedWidget to pass drag handlers to child widgets
class _IpoOrderDialogDragNotifier extends InheritedWidget {
  final void Function(DragStartDetails) onPanStart;
  final void Function(DragUpdateDetails) onPanUpdate;
  final void Function(DragEndDetails) onPanEnd;
  final bool isDragging;

  const _IpoOrderDialogDragNotifier({
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.isDragging,
    required super.child,
  });

  static _IpoOrderDialogDragNotifier? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_IpoOrderDialogDragNotifier>();
  }

  @override
  bool updateShouldNotify(_IpoOrderDialogDragNotifier oldWidget) {
    return onPanStart != oldWidget.onPanStart ||
        onPanUpdate != oldWidget.onPanUpdate ||
        onPanEnd != oldWidget.onPanEnd ||
        isDragging != oldWidget.isDragging;
  }
}

class UnifiedIpoOrderScreen extends ConsumerStatefulWidget {
  final dynamic ipoData; // Can be either SMEIPO or MainIPO
  const UnifiedIpoOrderScreen({
    super.key,
    required this.ipoData,
  });

  @override
  ConsumerState<UnifiedIpoOrderScreen> createState() =>
      _UnifiedIpoOrderScreenState();

  // Static variable to track the current overlay entry
  static OverlayEntry? _currentOverlayEntry;

  /// Static method to show UnifiedIpoOrderScreen as a draggable dialog
  static void showDraggable({
    required BuildContext context,
    required dynamic ipoData,
    Offset? initialPosition,
  }) {
    final overlay = Overlay.of(context);

    // Close existing IPO order screen if one is already open
    if (_currentOverlayEntry != null) {
      try {
        _currentOverlayEntry!.remove();
      } catch (e) {
        // Entry might already be removed, ignore error
      }
      _currentOverlayEntry = null;
    }

    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width < 500 ? size.width * 0.9 : 420.0;
    final dialogHeight = size.height * 0.8;

    final position = initialPosition ??
        Offset(
          (size.width - dialogWidth) / 2,
          (size.height - dialogHeight) / 2,
        );

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _DraggableIpoOrderScreenDialog(
        ipoData: ipoData,
        initialPosition: position,
        onPositionChanged: (newPosition) {
          // Position can be saved if needed
        },
        onClose: () {
          overlayEntry.remove();
          _currentOverlayEntry = null;
        },
      ),
    );

    // Store the current overlay entry
    _currentOverlayEntry = overlayEntry;
    overlay.insert(overlayEntry);
  }
}

class _UnifiedIpoOrderScreenState extends ConsumerState<UnifiedIpoOrderScreen> {
  String upierrortext = "";
  String _upiErrorText = "";
  String selectedChip = "Individual";
  List<IpoDetails> addIpo = [];
  bool _isTermsAccepted = false;

  // Helper getters to determine IPO type and access data
  bool get isSME => widget.ipoData is SMEIPO;
  bool get isMainstream => widget.ipoData is MainIPO;

  dynamic get ipoData => widget.ipoData;
  String get ipoName => isSME ? (ipoData.name ?? "") : (ipoData.name ?? "");
  String get ipoKey => isSME ? "SME" : "IPO";
  String get ipoSymbol =>
      isSME ? (ipoData.symbol ?? "") : (ipoData.symbol ?? "");
  String get ipoType => isSME ? (ipoData.type ?? "") : (ipoData.type ?? "");
  String get lotSize =>
      isSME ? (ipoData.lotSize ?? "") : (ipoData.lotSize ?? "");
  String get minPrice =>
      isSME ? (ipoData.minPrice ?? "") : (ipoData.minPrice ?? "");
  String get maxPrice =>
      isSME ? (ipoData.maxPrice ?? "") : (ipoData.maxPrice ?? "");
  String get minBidQuantity =>
      isSME ? (ipoData.minBidQuantity ?? "") : (ipoData.minBidQuantity ?? "");
  String get dailyStartTime =>
      isSME ? (ipoData.dailyStartTime ?? "") : (ipoData.dailyStartTime ?? "");
  String get dailyEndTime =>
      isSME ? (ipoData.dailyEndTime ?? "") : (ipoData.dailyEndTime ?? "");
  String get biddingStartDate => isSME
      ? (ipoData.biddingStartDate ?? "")
      : (ipoData.biddingStartDate ?? "");
  String get biddingEndDate =>
      isSME ? (ipoData.biddingEndDate ?? "") : (ipoData.biddingEndDate ?? "");

  bool get isCutOffAllowed {
    final settings = ipoData.subCategorySettings as List?;
    if (settings == null || settings.isEmpty) return true;
    final type = (ipoData.type ?? "").toString();
    bool matches(dynamic s) {
      switch (selectedChip) {
        case "Individual":
          return s.subCatCode == "IND" &&
              (type == "BSE" || s.caCode == "RETAIL");
        case "HNI":
          return s.subCatCode == "IND" && s.caCode == "NIB";
        case "Employee":
          return s.subCatCode == "EMP";
        case "Shareholder":
          return s.subCatCode == "SHA";
        case "Policyholder":
          return s.subCatCode == "POL";
        default:
          return false;
      }
    }

    for (final s in settings) {
      if (matches(s)) return s.allowCutOff ?? true;
    }
    return true;
  }

  @override
  void initState() {
    setState(() {
      addNewItem();
    });
    super.initState();
  }

  void addNewItem() {
    setState(() {
      addIpo.add(IpoDetails(
          qualitytext: minBidQuantity,
          bidprice:
              "${double.parse(minPrice.isEmpty ? "0" : minPrice).toInt()}",
          lotsize: int.parse(lotSize.isEmpty ? "0" : lotSize),
          requriedprice: mininv(
                  double.parse(minPrice.isEmpty ? "0" : minPrice).toDouble(),
                  int.parse(minBidQuantity.isEmpty ? "0" : minBidQuantity)
                      .toInt())
              .toInt(),
          isChecked: false));
    });
  }

  void removeItem(int index) {
    setState(() {
      addIpo.removeAt(index);
    });
  }

  // Helper method to get appropriate provider methods based on IPO type
  void _updateProviderState(IPOProvider ipo) {
    if (isSME) {
      if (ipo.checkForErrorsInSMEPlaceOrder(addIpo)) {
        ipo.setisSMEPlaceOrderBtnActiveValue = true;
      }
      ipo.setsmePlaceOrderRequiredMaxPrice = addIpo;
    } else {
      if (ipo.checkForErrorsInSMEPlaceOrder(addIpo)) {
        ipo.setisMainIPOPlaceOrderBtnActiveValue = true;
      }
      ipo.setMainIPOPlaceOrderRequiredMaxPrice = addIpo;
    }
  }

  // Helper method to get button active state
  bool _getButtonActiveState(IPOProvider ipo) {
    return isSME
        ? ipo.isSMEPlaceOrderBtnActive
        : ipo.isMainIPOPlaceOrderBtnActive;
  }

  // Helper method to get max price
  int _getMaxPrice(IPOProvider ipo) {
    return isSME
        ? ipo.smePlaceOrderRequiredMaxPrice
        : ipo.mainIPOPlaceOrderRequiredMaxPrice;
  }

  // Helper method to set button active state
  void _setButtonActiveState(IPOProvider ipo, bool value) {
    if (isSME) {
      ipo.setisSMEPlaceOrderBtnActiveValue = value;
    } else {
      ipo.setisMainIPOPlaceOrderBtnActiveValue = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Consumer(
        builder: (context, ref, child) {
          final ipo = ref.watch(ipoProvide);
          final theme = ref.watch(themeProvider);
          final upiProvider = ref.watch(transcationProvider);
          final status = ipostartdate(biddingStartDate, biddingEndDate);
          final isOpen = status == "Open";

          final screenSize = MediaQuery.of(context).size;
          // Scale factor based on screen width for responsive text sizing
          final double textScale = screenSize.width < 1400
              ? (screenSize.width / 1400).clamp(0.85, 1.0)
              : 1.0;
          final double paddingScale = screenSize.width < 1400
              ? (screenSize.width / 1400).clamp(0.7, 1.0)
              : 1.0;

          var chips = ipo.ipoCategory
              .map((e) => e['subCatCode'] as String)
              .toSet()
              .toList();
          if (selectedChip == "Individual" &&
              chips.isNotEmpty &&
              !chips.contains("Individual")) {
            selectedChip = chips[0];
          }

          _updateProviderState(ipo);

          final closeNotifier = _IpoOrderDialogCloseNotifier.of(context);
          final dragNotifier = _IpoOrderDialogDragNotifier.of(context);

          // Custom Header
          Widget headerSection = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  theme.isDarkMode ? MyntColors.dialogDark : MyntColors.dialog,
              border: Border(
                bottom: BorderSide(
                  color: theme.isDarkMode
                      ? MyntColors.dividerDark
                      : MyntColors.divider,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget.titleText(
                        text: ipoName,
                        theme: theme.isDarkMode,
                        color: theme.isDarkMode
                            ? colors.textPrimaryDark
                            : colors.textPrimaryLight,
                        fw: 1),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TextWidget.paraText(
                            text: ipoKey,
                            theme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? colors.textSecondaryDark
                                : colors.textSecondaryLight,
                            fw: 0),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? (theme.isDarkMode
                                    ? MyntColors.profitDark.withValues(alpha: 0.15)
                                    : const Color(0xffE6F4EA))
                                : (theme.isDarkMode
                                    ? MyntColors.lossDark.withValues(alpha: 0.15)
                                    : const Color(0xffFCE8E6)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOpen
                                  ? (theme.isDarkMode
                                      ? MyntColors.profitDark
                                      : const Color(0xff1E8E3E))
                                  : (theme.isDarkMode
                                      ? MyntColors.lossDark
                                      : const Color(0xffD93025)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (closeNotifier != null)
                  IconButton(
                    onPressed: closeNotifier.onClose,
                    icon: Icon(Icons.close,
                        color: theme.isDarkMode
                            ? MyntColors.textPrimaryDark
                            : MyntColors.textPrimary),
                  ),
              ],
            ),
          );

          if (dragNotifier != null) {
            headerSection = MouseRegion(
              cursor: SystemMouseCursors.move,
              child: GestureDetector(
                onPanStart: dragNotifier.onPanStart,
                onPanUpdate: dragNotifier.onPanUpdate,
                onPanEnd: dragNotifier.onPanEnd,
                child: headerSection,
              ),
            );
          }

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              backgroundColor:
                  theme.isDarkMode ? MyntColors.dialogDark : MyntColors.dialog,
              body: Column(
                children: [
                  headerSection,
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(16.0 * paddingScale),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextWidget.subText(
                              text: "Category",
                              theme: false,
                              fw: 1,
                              color: theme.isDarkMode
                                  ? colors.textPrimaryDark
                                  : colors.textPrimaryLight,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedChip,
                              icon: const Icon(Icons.keyboard_arrow_down),
                              items: chips
                                  .map((chip) => DropdownMenuItem<String>(
                                        value: chip,
                                        child: Text(chip,
                                            style: MyntWebTextStyles.body(
                                                context)),
                                      ))
                                  .toList(),
                              onChanged: (value) async {
                                if (value != null) {
                                  setState(() {
                                    selectedChip = value;
                                  });
                                  ipo.chngCategoryType(value);
                                  await ipo.categoryOnChange(
                                    addIpo,
                                    ipo.maxUPIAmt,
                                    _getButtonActiveState(ipo),
                                    selectedChip,
                                  );
                                }
                              },
                              decoration: InputDecoration(
                                fillColor: theme.isDarkMode
                                    ? MyntColors.inputBgDark
                                    : const Color(0xffF1F3F8),
                                filled: true,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: theme.isDarkMode
                                            ? MyntColors.dividerDark
                                            : colors.btnOutlinedBorder),
                                    borderRadius: BorderRadius.circular(5)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: theme.isDarkMode
                                            ? MyntColors.primaryDark
                                            : colors.primary),
                                    borderRadius: BorderRadius.circular(5)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Bid Rows
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: addIpo.length,
                              itemBuilder: (context, index) {
                                return _buildBidRow(index, ipo, theme);
                              },
                            ),

                            // Add Another Bid Link
                            if (addIpo.length < 3)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Center(
                                  child: InkWell(
                                    onTap: ipo.loading
                                        ? null
                                        : () {
                                            addNewItem();
                                            ipo.categoryOnChange(
                                                addIpo,
                                                ipo.maxUPIAmt,
                                                _getButtonActiveState(ipo),
                                                selectedChip);
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextWidget.subText(
                                            text: "Add another bid",
                                            theme: false,
                                            fw: 0,
                                            color: theme.isDarkMode
                                                ? MyntColors.primaryDark
                                                : MyntColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 18,
                                             color: theme.isDarkMode
                                                ? MyntColors.primaryDark
                                                : MyntColors.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),

                            // Global Validation Error Messages
                            ...(() {
                              final List<String> errorMessages = [];
                              for (var e in addIpo) {
                                if (e.qualityerrortext.isNotEmpty &&
                                    !errorMessages
                                        .contains(e.qualityerrortext.trim())) {
                                  errorMessages.add(e.qualityerrortext.trim());
                                }
                                if (e.biderrortext.isNotEmpty &&
                                    !errorMessages
                                        .contains(e.biderrortext.trim())) {
                                  errorMessages.add(e.biderrortext.trim());
                                }
                              }

                              return errorMessages.map((msg) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: theme.isDarkMode
                                            ? MyntColors.warningDark.withValues(alpha: 0.15)
                                            : const Color(0xFFFFF4E5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: theme.isDarkMode
                                                ? MyntColors.warningDark
                                                : const Color(0xFFFF8C00),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              msg,
                                              style:
                                                  MyntWebTextStyles.bodySmall(
                                                context,
                                                color: theme.isDarkMode
                                                    ? MyntColors.warningDark
                                                    : const Color(0xFFFF8C00),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ));
                            })(),

                            const SizedBox(height: 24),

                            // UPI ID Section
                            TextWidget.subText(
                              text: "UPI ID (Virtual payment address)",
                              theme: false,
                              fw: 1,
                              color: theme.isDarkMode
                                  ? colors.textPrimaryDark
                                  : colors.textPrimaryLight,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: upiProvider.upiid,
                              decoration: InputDecoration(
                                hintText: "Add UPI ID",
                                fillColor: theme.isDarkMode
                                    ? MyntColors.inputBgDark
                                    : const Color(0xffF1F3F8),
                                filled: true,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: theme.isDarkMode
                                            ? MyntColors.dividerDark
                                            : colors.btnOutlinedBorder),
                                    borderRadius: BorderRadius.circular(5)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: theme.isDarkMode
                                            ? MyntColors.primaryDark
                                            : colors.primary),
                                    borderRadius: BorderRadius.circular(5)),
                                contentPadding: const EdgeInsets.all(13),
                              ),
                              style: MyntWebTextStyles.body(context),
                              onChanged: (value) => setState(() {}),
                            ),
                             if (ipo.upierror.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 4),
                                child: Text(
                                  ipo.upierror,
                                  style: MyntWebTextStyles.bodySmall(
                                    context,
                                    color: theme.isDarkMode
                                        ? MyntColors.lossDark
                                        : const Color(0xffD93025),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 24),

                            // Terms Section
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _isTermsAccepted,
                                  onChanged: (val) {
                                    setState(() {
                                      _isTermsAccepted = val ?? false;
                                    });
                                  },
                                  activeColor: theme.isDarkMode
                                      ? MyntColors.primaryDark
                                      : MyntColors.primary,
                                  side: theme.isDarkMode
                                      ? const BorderSide(color: Color(0xFF6E7681), width: 1.5)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "I hereby undertake that I have read the Red Herring Prospectus and I am eligible bidder as per the applicable provisions of SEBI (Issue of Capital & Disclosure Agreement, 2009) regulations",
                                    style: MyntWebTextStyles.bodySmall(
                                      context,
                                      color: theme.isDarkMode
                                          ? colors.textSecondaryDark
                                          : colors.textSecondaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer Section
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.isDarkMode
                              ? MyntColors.cardDark
                              : const Color(0xffF1F3F8),
                          border: Border(
                            top: BorderSide(
                              color: theme.isDarkMode
                                  ? MyntColors.dividerDark
                                  : MyntColors.divider,
                            ),
                          ),
                        ),
                        child: Center(
                          child: TextWidget.paraText(
                            text:
                                "Margin · ${_getMaxPrice(ipo).toStringAsFixed(2)}",
                            theme: false,
                             color: theme.isDarkMode
                                                ? MyntColors.primaryDark
                                                : MyntColors.primary,
                            fw: 1,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton(
                            onPressed: (!ipo.ipoOrderLoading &&
                                    _getButtonActiveState(ipo) &&
                                    _isTermsAccepted &&
                                    upiProvider.upiid.text.isNotEmpty)
                                ? () {
                                    final lastBid = addIpo[addIpo.length - 1];
                                    if (lastBid.requriedprice > ipo.maxUPIAmt) {
                                      showResponsiveWarning(context,
                                          "Maximum investment upto ₹${double.parse(ipo.maxUPIAmt.toString()).toInt()} only ");
                                      _setButtonActiveState(ipo, false);
                                    } else if (lastBid.bidpricecontroller.text.isEmpty ||
                                        lastBid.bidpricecontroller.text == "0") {
                                      showResponsiveWarning(
                                          context,
                                          lastBid.bidpricecontroller.text == "0"
                                              ? "Bid Price Value cannot be 0"
                                              : "* Bid Price Value is required");
                                    } else if (lastBid.qualityController.text.isEmpty ||
                                        lastBid.qualityController.text == "0") {
                                      showResponsiveWarning(
                                          context,
                                          lastBid.qualityController.text == "0"
                                              ? "* Quantity cannot be 0"
                                              : "* Quantity cannot be empty");
                                    } else if (!RegExp(r'^[\w.-]+@[\w]+$')
                                        .hasMatch(upiProvider.upiid.text)) {
                                      setState(() {
                                        _upiErrorText = "Invalid UPI ID format";
                                      });
                                    } else if (ipo.checkForErrorsInSMEPlaceOrder(addIpo)) {
                                      _setButtonActiveState(ipo, true);
                                      ipoplaceorder(upiProvider, ipo);
                                    } else {
                                      showResponsiveWarning(context,
                                          "Can't place order with current selected combination of bids");
                                      _setButtonActiveState(ipo, false);
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.isDarkMode
                                  ? MyntColors.secondary
                                  : MyntColors.primary,
                              disabledBackgroundColor: (theme.isDarkMode
                                      ? MyntColors.secondary
                                      : MyntColors.primary)
                                  .withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            child: ipo.ipoOrderLoading
                                ? MyntLoader.inline()
                                : TextWidget.titleText(
                                     text: "Continue",
                              theme: false,
                              color: colors.colorWhite,
                              fw: 2,
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
        },
      ),
    );
  }

  Widget _buildBidRow(int index, IPOProvider ipo, ThemesProvider theme) {
    return Column(
      children: [
        // Headers Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextWidget.subText(
                text: "Qty",
                theme: false,
                fw: 1,
                color: theme.isDarkMode
                    ? colors.textPrimaryDark
                    : colors.textPrimaryLight,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextWidget.subText(
                    text: "Bid Price",
                    theme: false,
                    fw: 1,
                    color: theme.isDarkMode
                        ? colors.textPrimaryDark
                        : colors.textPrimaryLight,
                  ),
                  if (isCutOffAllowed)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom:
                                  2), // Minor adjustment for checkbox alignment
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: Checkbox(
                              value: addIpo[index].isChecked,
                              onChanged: (val) {
                                if (isSME) {
                                  ipo.smecutoffprice(addIpo[index], ipoData);
                                } else {
                                  ipo.cutoffprice(addIpo[index], ipoData);
                                }
                                setState(() {
                                  _updateProviderState(ipo);
                                });
                              },
                              activeColor: theme.isDarkMode
                                  ? MyntColors.primaryDark
                                  : MyntColors.primary,
                              side: theme.isDarkMode
                                  ? const BorderSide(
                                      color: Color(0xFF6E7681), width: 1.5)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextWidget.paraText(
                          text: "Cut-off",
                          theme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? colors.textSecondaryDark
                              : colors.textSecondaryLight,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Inputs Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Qty Input
            Expanded(
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: theme.isDarkMode
                      ? MyntColors.inputBgDark
                      : const Color(0xffF1F3F8),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: theme.isDarkMode
                          ? MyntColors.dividerDark
                          : colors.btnOutlinedBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: ipo.loading
                          ? null
                          : () {
                              if (isSME) {
                                ipo.smequantityminusfunction(
                                    addIpo[index],
                                    _getButtonActiveState(ipo),
                                    ipoData,
                                    ipo.maxUPIAmt,
                                    selectedChip);
                              } else {
                                ipo.quantityminusfunction(
                                    addIpo[index],
                                    _getButtonActiveState(ipo),
                                    ipo,
                                    ipoData,
                                    selectedChip);
                              }
                              setState(() {
                                _updateProviderState(ipo);
                              });
                            },
                      icon: Icon(Icons.remove, size: 18, color: theme.isDarkMode ? MyntColors.primaryDark : MyntColors.primary),
                    ),
                    Expanded(
                      child: TextFormField(
                        readOnly: ipo.loading,
                        textAlign: TextAlign.center,
                        controller: addIpo[index].qualityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onEditingComplete: () => FocusScope.of(context).unfocus(),
                        onChanged: (value) {
                          if (isSME) {
                            ipo.smequantityOnchange(
                                value,
                                addIpo[index],
                                ipoData,
                                _getButtonActiveState(ipo),
                                ipo.maxUPIAmt,
                                selectedChip);
                          } else {
                            ipo.quantityOnchange(
                                addIpo[index],
                                _getButtonActiveState(ipo),
                                ipo,
                                value,
                                ipoData,
                                selectedChip);
                          }
                          setState(() {
                            _updateProviderState(ipo);
                          });
                        },
                        style: MyntWebTextStyles.body(context,
                            fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: ipo.loading
                          ? null
                          : () {
                              if (isSME) {
                                ipo.smequalityplusefunction(
                                    addIpo[index],
                                    _getButtonActiveState(ipo),
                                    ipoData,
                                    ipo.maxUPIAmt,
                                    selectedChip);
                              } else {
                                ipo.qualityplusefunction(
                                    addIpo[index],
                                    _getButtonActiveState(ipo),
                                    ipo,
                                    ipoData,
                                    selectedChip);
                              }
                              setState(() {
                                _updateProviderState(ipo);
                              });
                            },
                      icon: Icon(Icons.add, size: 18, color: theme.isDarkMode ? MyntColors.primaryDark : MyntColors.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Bid Price Input
            Expanded(
              child: SizedBox(
                height: 45, // Match height of Qty Input container
                child: TextFormField(
                  controller: addIpo[index].bidpricecontroller,
                  readOnly: addIpo[index].isChecked,
                  decoration: InputDecoration(
                    prefixText: "₹ ",
                    fillColor: addIpo[index].isChecked
                        ? (theme.isDarkMode
                            ? MyntColors.inputBgDark.withValues(alpha: 0.5)
                            : const Color(0xffF1F3F8).withValues(alpha: 0.5))
                        : (theme.isDarkMode
                            ? MyntColors.inputBgDark
                            : const Color(0xffF1F3F8)),
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: addIpo[index].isChecked
                                ? (theme.isDarkMode
                                    ? MyntColors.dividerDark.withValues(alpha: 0.5)
                                    : colors.btnOutlinedBorder.withValues(alpha: 0.5))
                                : (theme.isDarkMode
                                    ? MyntColors.dividerDark
                                    : colors.btnOutlinedBorder)),
                        borderRadius: BorderRadius.circular(5)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: theme.isDarkMode
                                ? MyntColors.primaryDark
                                : colors.primary),
                        borderRadius: BorderRadius.circular(5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  style: MyntWebTextStyles.body(
                    context,
                    color: addIpo[index].isChecked
                        ? (theme.isDarkMode
                            ? colors.textPrimaryDark.withOpacity(0.4)
                            : colors.textPrimaryLight.withOpacity(0.4))
                        : (theme.isDarkMode
                            ? colors.textPrimaryDark
                            : colors.textPrimaryLight),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (value) {
                    if (isSME) {
                      ipo.smebidpriceOnChange(value, addIpo[index],
                          _getButtonActiveState(ipo), ipoData);
                    } else {
                      ipo.bidpricefunction(addIpo[index], ipoData, value,
                          _getButtonActiveState(ipo));
                    }
                    setState(() {
                      _updateProviderState(ipo);
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: addIpo[index].qualityerrortext.isNotEmpty
                  ? TextWidget.captionText(
                      theme: false,
                      text: addIpo[index].qualityerrortext,
                      color: colors.error,
                      fw: 0,
                    )
                  : const SizedBox(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: addIpo[index].biderrortext.isNotEmpty
                  ? TextWidget.captionText(
                      theme: false,
                      text: addIpo[index].biderrortext,
                      color: colors.error,
                      fw: 0,
                    )
                  : const SizedBox(),
            ),
          ],
        ),
        if (index > 0) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: ipo.loading ? null : () => removeItem(index),
              icon: Icon(Icons.delete_outline,
                  color: resolveThemeColor(context,
                      dark: MyntColors.lossDark, light: MyntColors.loss),
                  size: 18),
              label: Text("Delete",
                  style: TextStyle(
                      color: resolveThemeColor(context,
                          dark: MyntColors.lossDark, light: MyntColors.loss),
                      fontSize: 12)),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  ipoplaceorder(TranctionProvider upiid, IPOProvider ipo) async {
    MenuData menudata = MenuData(
      flow: "now",
      type: ipoType,
      symbol: ipoSymbol,
      category:
          ipo.ipoCategoryvalue == "Individual" || ipo.ipoCategoryvalue == "HNI"
              ? "IND"
              : ipo.ipoCategoryvalue == "Employee"
                  ? "EMP"
                  : ipo.ipoCategoryvalue == "Shareholder"
                      ? "SHA"
                      : ipo.ipoCategoryvalue == "Policyholder"
                          ? "POL"
                          : "",
      name: ipoName,
      applicationNumber: '',
      respBid: [BidReference(bidReferenceNumber: '')],
    );
    final String iposupiid = upiid.upiid.text;
    List<IposBid> iposbids = [];
    for (int i = 0; i < addIpo.length; i++) {
      iposbids.add(IposBid(
          bitis: true,
          qty: int.parse(addIpo[i].qualityController.text).toInt(),
          cutoff: addIpo[i].isChecked,
          price: double.parse(addIpo[i].bidpricecontroller.text).toDouble(),
          total: addIpo[i].requriedprice.toDouble()));
    }

    // Check if we're in an overlay dialog wrapper
    final closeNotifier = _IpoOrderDialogCloseNotifier.of(context);

    final success = await ref.read(ipoProvide).fetchupiidvalidation(
        context, upiid.upiid.text, "343245", menudata, iposbids, iposupiid,
        isOverlayDialog: closeNotifier != null);

    if (closeNotifier != null && success) {
      // Add a small delay to allow success message to appear first
      Future.delayed(const Duration(milliseconds: 300), () {
        closeNotifier.onClose();
      });
    }
  }
}

// Wrapper widget to pass close callbacks to OrderScreenbottomPage
class PaymentDialogWrapper extends InheritedWidget {
  final VoidCallback onClose;
  final VoidCallback?
      onOrderScreenClose; // Callback to close the order screen overlay

  const PaymentDialogWrapper({
    super.key,
    required this.onClose,
    this.onOrderScreenClose,
    required super.child,
  });

  static PaymentDialogWrapper? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PaymentDialogWrapper>();
  }

  @override
  bool updateShouldNotify(PaymentDialogWrapper oldWidget) {
    return onClose != oldWidget.onClose ||
        onOrderScreenClose != oldWidget.onOrderScreenClose;
  }
}

TextStyle textStyle(Color color, double fontSize, fWeight) {
  return TextStyle(
    fontWeight: fWeight,
    color: color,
    fontSize: fontSize,
  );
}

// Draggable IPO Order Screen Dialog Widget
class _DraggableIpoOrderScreenDialog extends ConsumerStatefulWidget {
  final dynamic ipoData;
  final Offset initialPosition;
  final Function(Offset) onPositionChanged;
  final VoidCallback onClose;

  const _DraggableIpoOrderScreenDialog({
    required this.ipoData,
    required this.initialPosition,
    required this.onPositionChanged,
    required this.onClose,
  });

  @override
  ConsumerState<_DraggableIpoOrderScreenDialog> createState() =>
      _DraggableIpoOrderScreenDialogState();
}

class _DraggableIpoOrderScreenDialogState
    extends ConsumerState<_DraggableIpoOrderScreenDialog> {
  Offset? _customPosition;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Start with null to use automatic centering in build
    _customPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final screenSize = MediaQuery.of(context).size;

    // Constrain position to screen bounds
    final dialogWidth = (screenSize.width * 0.9).clamp(280.0, 420.0);
    final dialogHeight = screenSize.height * 0.8;

    final currentPosition = _customPosition ??
        Offset(
          (screenSize.width - dialogWidth) / 2,
          (screenSize.height - dialogHeight) / 2,
        );

    // Clamp current position to ensure it stays on screen during resize
    final constrainedPosition = Offset(
      currentPosition.dx.clamp(
          0.0, (screenSize.width - dialogWidth).clamp(0.0, double.infinity)),
      currentPosition.dy.clamp(
          0.0, (screenSize.height - dialogHeight).clamp(0.0, double.infinity)),
    );

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.4),
          ),
        ),
        // Actual dialog
        Positioned(
          left: constrainedPosition.dx,
          top: constrainedPosition.dy,
          child: GestureDetector(
            onTap: () {}, // Prevent tap from propagating to background
            child: Material(
              elevation: _isDragging ? 16 : 8,
              borderRadius: BorderRadius.circular(8),
              color: theme.isDarkMode
                  ? MyntColors.dialogDark
                  : MyntColors.dialog,
              child: Container(
                width: dialogWidth,
                height: dialogHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.isDarkMode
                        ? MyntColors.dividerDark
                        : MyntColors.divider,
                  ),
                ),
                child: _IpoOrderDialogCloseNotifier(
                  onClose: widget.onClose,
                  child: _IpoOrderDialogDragNotifier(
                    onPanStart: (details) {
                      setState(() {
                        _isDragging = true;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        final basePos = constrainedPosition;
                        _customPosition = Offset(
                          basePos.dx + details.delta.dx,
                          basePos.dy + details.delta.dy,
                        );
                      });
                      if (_customPosition != null) {
                        widget.onPositionChanged(_customPosition!);
                      }
                    },
                    onPanEnd: (details) {
                      setState(() {
                        _isDragging = false;
                      });
                    },
                    isDragging: _isDragging,
                    child: Navigator(
                      onGenerateRoute: (settings) => PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            UnifiedIpoOrderScreen(ipoData: widget.ipoData),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
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

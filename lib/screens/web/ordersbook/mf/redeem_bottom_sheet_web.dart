import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../provider/thems.dart';
import '../../../../../provider/mf_provider.dart';
import '../../../../../res/global_font_web.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../sharedWidget/cust_text_formfield.dart';
import '../../../../../sharedWidget/mynt_loader.dart';
import '../../../../../sharedWidget/snack_bar.dart';

class RedemptionBottomSheetWeb extends ConsumerStatefulWidget {
  const RedemptionBottomSheetWeb({super.key});

  @override
  ConsumerState<RedemptionBottomSheetWeb> createState() => _RedemptionBottomSheetWebState();
}

class _RedemptionBottomSheetWebState extends ConsumerState<RedemptionBottomSheetWeb> {
  final TextEditingController _redemptionQtyController = TextEditingController();

  // Client-side validation message shown inline under the quantity field
  // (team convention: inline for our own checks, toast for API responses).
  String? _qtyError;

  @override
  void initState() {
    super.initState();
    // Set initial value to current units
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mfData = ref.read(mfProvider);
      if (mfData.holssinglelist?.isNotEmpty == true) {
        _redemptionQtyController.text = mfData.holssinglelist![0]?.avgQty ?? '0';
      }
    });
  }

  @override
  void dispose() {
    _redemptionQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeProvider);
    final mfData = ref.watch(mfProvider);
    final isDark = theme.isDarkMode;

    final holding = mfData.holssinglelist?.isNotEmpty == true ? mfData.holssinglelist![0] : null;

    if (holding == null) {
      return Center(child: MyntLoader.simple());
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: isDark ? MyntColors.dialogDark : MyntColors.backgroundColor,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? MyntColors.dividerDark
                        : MyntColors.divider,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    holding.name ?? 'N/A',
                    style: WebTextStyles.dialogTitle(
                      isDarkTheme: isDark,
                      color: isDark ? MyntColors.textPrimaryDark : MyntColors.textPrimary,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      splashColor: isDark
                          ? Colors.white.withOpacity(.15)
                          : Colors.black.withOpacity(.15),
                      highlightColor: isDark
                          ? Colors.white.withOpacity(.08)
                          : Colors.black.withOpacity(.08),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: isDark
                              ? MyntColors.iconSecondaryDark
                              : MyntColors.iconSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 0, bottom: 20, left: 20, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Redemption Form
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _buildRedemptionForm(holding, theme, mfData),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }




  Widget _buildRedemptionForm(dynamic holding, ThemesProvider theme, MFProvider mfData) {
    final isDark = theme.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [


        // Redemption Quantity Input
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Redemption Quantity',
              style: WebTextStyles.dialogContent(
                isDarkTheme: isDark,
                color: isDark ? MyntColors.textPrimaryDark : MyntColors.textPrimary,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Units:',
                  style: WebTextStyles.sub(
                    isDarkTheme: isDark,
                    color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  holding.avgQty ?? '0',
                  style: WebTextStyles.sub(
                    isDarkTheme: isDark,
                    color: isDark ? MyntColors.textPrimaryDark : MyntColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: CustomTextFormField(
            fillColor: isDark
                ? MyntColors.inputBgDark
                : MyntColors.listItemBg,
            onChanged: (value) {
              // Clear the inline error once the user edits the value
              if (_qtyError != null) {
                setState(() => _qtyError = null);
              }
            },
            hintText: 'Enter quantity to redeem',
            hintStyle: WebTextStyles.formInput(
              isDarkTheme: isDark,
            ),
            keyboardType: TextInputType.number,
            // Digits with at most one decimal point. Rejecting keystroke
            // style (keeps the previous valid value) — the anchored
            // allow(RegExp) variant wipes the whole field on a bad key.
            inputFormate: [
              TextInputFormatter.withFunction((oldValue, newValue) =>
                  (newValue.text.isEmpty ||
                          RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text))
                      ? newValue
                      : oldValue),
            ],
            style: WebTextStyles.formInput(
              isDarkTheme: isDark,
            ),
            textCtrl: _redemptionQtyController,
            textAlign: TextAlign.start,
            autofocus: false,
          ),
        ),
        // Inline client-side validation error (API errors go to toast)
        if (_qtyError != null && _qtyError!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _qtyError!,
              style: WebTextStyles.sub(
                isDarkTheme: isDark,
                color: isDark ? MyntColors.lossDark : MyntColors.loss,
              ),
            ),
          ),

        // Redeem Button
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: () {
              _handleRedemption(holding, mfData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? MyntColors.secondary
                  : MyntColors.primary,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            child: Text(
              'Redeem',
              style: WebTextStyles.buttonMd(
                isDarkTheme: isDark,
                color: MyntColors.textWhite,
                fontWeight: WebFonts.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String title, String value, ThemesProvider theme, {Color? valueColor}) {
    final isDark = theme.isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: WebTextStyles.dialogContent(
              isDarkTheme: isDark,
              color: isDark ? MyntColors.textPrimaryDark : MyntColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: WebTextStyles.dialogContent(
              isDarkTheme: isDark,
              color: valueColor ?? (isDark ? MyntColors.textPrimaryDark : MyntColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Color _getValueColor(String value, ThemesProvider theme) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) {
      return theme.isDarkMode ? MyntColors.profitDark : MyntColors.profit;
    } else if (numValue < 0) {
      return theme.isDarkMode ? MyntColors.lossDark : MyntColors.loss;
    } else {
      return theme.isDarkMode ? MyntColors.textSecondaryDark : MyntColors.textSecondary;
    }
  }

  Future<void> _handleRedemption(dynamic holding, MFProvider mfData) async {
    final redemptionQty = _redemptionQtyController.text.trim();

    // Client-side checks show INLINE under the field (team convention);
    // only the API's own response is surfaced via toast further below.
    if (redemptionQty.isEmpty) {
      // _showErrorDialog('Please enter redemption quantity');
      setState(() => _qtyError = 'Please enter redemption quantity');
      return;
    }

    final qty = double.tryParse(redemptionQty);
    final availableQty = double.tryParse(holding.avgQty ?? '0') ?? 0;

    if (qty == null || qty <= 0) {
      // _showErrorDialog('Please enter a valid quantity');
      setState(() => _qtyError = 'Please enter a valid quantity');
      return;
    }

    if (qty > availableQty) {
      // _showErrorDialog('Redemption quantity cannot exceed available units');
      setState(() =>
          _qtyError = 'Redemption quantity cannot exceed available units');
      return;
    }

    // Set redemption quantity in provider
    mfData.redemptionQty.text = redemptionQty;

    // Call redemption validation and process
    try {
      final minRedemptionQty = holding.minRedemptionQty;
      final netUnits = holding.avgQty;
      final navStr = holding.avgNav;

      if (mfData.checkRedemption(redemptionQty, minRedemptionQty, netUnits, navStr)) {
        final schemeCode = holding.sCHEMECODE ?? 'DefaultScheme';
        await mfData.mfRedemption(context, schemeCode, redemptionQty);
        // On success mfRedemption pops this sheet; on failure it stays open and
        // leaves the backend error on redemptionData — surface it as a toast.
        // NOTE: this API returns its rejection reason in `Remarks` (e.g.
        // "FAILED: ORDER QTY IS LESS THAN MINIMUM SPECIFIED FOR SCHEME");
        // `emsg` is not part of this response. Prefer Remarks, fall back to
        // emsg, and only show the generic contact-support line when the
        // response carries no reason at all.
        if (!mounted) return;
        final res = mfData.redemptionData;
        if (res?.stat != 'Ok') {
          final remarks = res?.remarks;
          final err = res?.emsg;
          if (remarks != null && remarks.isNotEmpty && remarks != 'null') {
            warningMessage(context, remarks);
          } else if (err != null && err.isNotEmpty && err != 'null') {
            warningMessage(context, err);
          } else {
            warningMessage(context,
                "Unable to process the redemption.\nPlease contact our support team.");
          }
        }
      } else {
        // Show the provider's SPECIFIC validation message inline (e.g.
        // "Redemption Qty should not be less than 0.001") instead of the
        // old generic dialog.
        // _showErrorDialog('Please check the data you have provided');
        final providerMsg = mfData.redemptionError;
        setState(() => _qtyError =
            (providerMsg != null && providerMsg.isNotEmpty)
                ? providerMsg
                : 'Please check the data you have provided');
      }
    } catch (e) {
      // _showErrorDialog('Error processing redemption: ${e.toString()}');
      setState(
          () => _qtyError = 'Error processing redemption: ${e.toString()}');
    }
  }

  // Retired: client-side validation now shows inline under the quantity
  // field (team convention) instead of this popup dialog.
  // void _showErrorDialog(String message) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Error'),
  //       content: Text(message),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(),
  //           child: const Text('OK'),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

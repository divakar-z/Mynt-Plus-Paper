import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';

import '../../../provider/mf_provider.dart';
import '../../../provider/privacy_provider.dart';
import '../../../provider/thems.dart';
import '../../../res/global_state_text.dart';
import '../../../res/res.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/global_font_web.dart';
// import '../../sharedWidget/loader_ui.dart';
// import '../mutual_fund_old/mf_order_filter_sheet.dart';

class mfholdsinlepageWeb extends StatefulWidget {
  const mfholdsinlepageWeb({super.key});
  @override
  State<mfholdsinlepageWeb> createState() => _mfholdsinlepageWeb();
}

class _mfholdsinlepageWeb extends State<mfholdsinlepageWeb>
    with SingleTickerProviderStateMixin {
  // Helper method to safely format values
  String _formatValue(String? value) {
    return (value == null || value.isEmpty) ? "0.00" : value;
  }

  // Helper method to determine color based on value
  Color _getColorBasedOnValue(String? valueStr, ThemesProvider theme) {
    final value = double.tryParse(valueStr ?? "0") ?? 0;
    return value >= 0
        ? theme.isDarkMode
            ? colors.profitDark
            : colors.profitLight
        : theme.isDarkMode
            ? colors.lossDark
            : colors.lossLight;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final theme = ref.watch(themeProvider);
      final mfdata = ref.watch(mfProvider);

      // Check if data is available
      final hasData = mfdata.holssinglelist != null &&
          mfdata.holssinglelist!.isNotEmpty &&
          mfdata.holssinglelist![0] != null;

      return Scaffold(
        backgroundColor:
            theme.isDarkMode ? MyntColors.backgroundColorDark : colors.colorWhite,
        body: Column(
          children: [
            // Header with close button and title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.isDarkMode
                        ? colors.darkColorDivider
                        : colors.colorDivider,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close,
                      size: 24,
                      color: theme.isDarkMode
                          ? colors.textPrimaryDark
                          : colors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextWidget.titleText(
                    text: "Holding Details",
                    color: theme.isDarkMode
                        ? colors.textPrimaryDark
                        : colors.textPrimaryLight,
                    fw: 1,
                    theme: theme.isDarkMode,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: hasData
                  ? _buildHoldingDetails(context, theme, mfdata)
                  : const Center(
                      child: NoDataFound(
                      secondaryEnabled: false,
                    )),
            ),
          ],
        ),
      );
    });
  }

  // Extracted method to build holding details
  Widget _buildHoldingDetails(
      BuildContext context, ThemesProvider theme, MFProvider mfdata) {
    final data = mfdata.holssinglelist![0];

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fund name with logo
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fund logo
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(
                    "https://v3.mynt.in/mfapi/static/images/mf/${data.iSIN?.substring(0, 4) ?? 'default'}.png",
                  ),
                  backgroundColor: Colors.grey.shade200,
                ),
                const SizedBox(width: 12),
                // Fund name
                Expanded(
                  child: TextWidget.subText(
                    text: data.name ?? "Unknown Fund",
                    color: theme.isDarkMode
                        ? colors.textPrimaryDark
                        : colors.textPrimaryLight,
                    textOverflow: TextOverflow.ellipsis,
                    theme: theme.isDarkMode,
                    maxLines: 2,
                    fw: 1,
                  ),
                ),
              ],
            ),

            // Units and Avg Price

            rowOfInfoData(
              "Returns",
              "${_formatValue(data.profitLoss)} (${(double.tryParse(data.changeprofitLoss ?? '0') ?? 0).toStringAsFixed(2)}%)",
              theme,
              valueColor: _getColorBasedOnValue(data.profitLoss, theme),
              maskedValue: "$kPrivacyMask ($kPrivacyMask%)",
            ),

            // Units and Avg Price
            rowOfInfoData(
              "Units",
              "${data.avgQty ?? '0'}",
              theme,
            ),

            rowOfInfoData(
              "Avg Price",
              "${data.avgNav ?? '0'}",
              theme,
            ),

            rowOfInfoData(
              "NAV",
              "${data.curNav ?? '0'}",
              theme,
              maskable: false,
            ),

            // Pledged Units and Current NAV
            rowOfInfoData(
              "Pledged Units",
              "0",
              theme,
            ),

            rowOfInfoData(
              "Current",
              "${data.currentValue ?? '0'}",
              theme,
            ),

            // Invested and Current Value
            rowOfInfoData(
              "Invested",
              "${data.investedValue ?? '0'}",
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget rowOfInfoData(String title1, String value1, ThemesProvider theme,
      {Color? valueColor, bool maskable = true, String? maskedValue}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.isDarkMode ? colors.dividerDark : colors.dividerLight,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                title1,
                style: MyntWebTextStyles.bodyMedium(
                  context,
                  color: theme.isDarkMode
                      ? MyntColors.textSecondaryDark
                      : MyntColors.textSecondary,
                  fontWeight: MyntFonts.regular,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              // Privacy Mode: value masked (and any profit/loss colour
              // dropped) unless the row is market data like NAV.
              child: Consumer(builder: (context, ref, _) {
                final privacy = ref.watch(privacyProvider);
                final isMasked = maskable && privacy.isPrivate;
                return Text(
                  isMasked ? (maskedValue ?? kPrivacyMask) : value1,
                  textAlign: TextAlign.right,
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    color: (isMasked ? null : valueColor) ??
                        (theme.isDarkMode
                            ? MyntColors.textPrimaryDark
                            : MyntColors.textPrimary),
                    fontWeight: MyntFonts.medium,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showBottomSheet(BuildContext context, Widget BottomSheet) {
    showModalBottomSheet(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        useSafeArea: true,
        isDismissible: true,
        backgroundColor: Colors.white,
        context: context,
        isScrollControlled: true,
        builder: (context) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: BottomSheet));
  }
}

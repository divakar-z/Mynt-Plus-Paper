import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/mf_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

class MfPaymentRespAlert extends StatefulWidget {
  final Map<String, dynamic>? upiData;
  final String? conditionval;
  const MfPaymentRespAlert({
    this.conditionval,
    this.upiData,
    super.key,
  });

  @override
  State<MfPaymentRespAlert> createState() => _MfPaymentRespAlertState();
}

class _MfPaymentRespAlertState extends State<MfPaymentRespAlert> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Consumer(
          builder: (context, ref, child) {
            final theme = ref.watch(themeProvider);
            final mfpro = ref.watch(mfProvider);
            final condval = widget.conditionval ?? '';
            final data = widget.upiData;

            return Container(
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.backgroundColorDark,
                  light: MyntColors.backgroundColor,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.dividerDark,
                    light: MyntColors.divider,
                  ),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: theme.isDarkMode ? 0.4 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header / Close Icon
                  Padding(
                    padding: const EdgeInsets.only(top: 12, right: 12),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          FocusScope.of(context).unfocus();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Status Icon + Titles
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildStatusContent(context, theme, mfpro, condval, data),
                  ),

                  // Detail rows
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildDetails(context, theme, mfpro, condval, data),
                  ),

                  const SizedBox(height: 16),

                  // Footer button
                  _buildFooter(context, theme),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusContent(
    BuildContext context,
    ThemesProvider theme,
    MFProvider mfpro,
    String condval,
    Map<String, dynamic>? data,
  ) {
    final IconData icon;
    final Color iconColor;
    final String title;
    final String? subtitle;
    final String? amount;
    final String? datetime;

    if (condval == 'timeout') {
      icon = Icons.cancel_rounded;
      iconColor = resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss);
      title = 'Request timeout';
      subtitle = data?["status"] == "PAYMENT COMPLETED" ? "Transaction Success" : "Transaction fail";
      final rawAmount = data?["OrderVal"] ?? data?["InstallmentAmount"];
      amount = (rawAmount != null && rawAmount.toString().isNotEmpty && rawAmount.toString() != 'null')
          ? "₹$rawAmount"
          : null;
      final rawDate = data?["datetime"];
      datetime = (rawDate != null && rawDate.toString().isNotEmpty && rawDate.toString() != 'null')
          ? "$rawDate"
          : null;
    } else if (condval == 'reinitiateerror' || (condval.isNotEmpty && condval != 'timeout')) {
      icon = Icons.cancel_rounded;
      iconColor = resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss);
      title = 'Payment Not Initiated';
      subtitle = 'Payment initiate fail';
      amount = null;
      datetime = null;
    } else {
      // Default — actual payment response
      final status = (data?["status"] ?? '').toString();
      final isSuccess = status == "PAYMENT COMPLETED" || status == "REGISTERED";
      final isProcessing = status == "PAYMENT PROCESSING";

      icon = isSuccess
          ? Icons.check_circle_rounded
          : isProcessing
              ? Icons.schedule
              : Icons.cancel_rounded;
      iconColor = isSuccess
          ? resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit)
          : isProcessing
              ? resolveThemeColor(context, dark: MyntColors.warningDark, light: MyntColors.warning)
              : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss);
      title = status.isEmpty ? 'Payment Status' : status;
      subtitle = mfpro.mfOrderTpye != 'SIP'
          ? (isSuccess
              ? "Transaction Success"
              : isProcessing
                  ? "Transaction pending"
                  : "Transaction fail")
          : null;
      final rawAmount = data?["OrderVal"] ?? data?["InstallmentAmount"];
      amount = (rawAmount != null && rawAmount.toString().isNotEmpty && rawAmount.toString() != 'null')
          ? "₹$rawAmount"
          : null;
      final rawDate = data?["datetime"];
      datetime = (rawDate != null && rawDate.toString().isNotEmpty && rawDate.toString() != 'null')
          ? "$rawDate"
          : null;
    }

    return Column(
      children: [
        Icon(icon, color: iconColor, size: 64),
        const SizedBox(height: 16),
        Text(
          title,
          style: MyntWebTextStyles.title(
            context,
            fontWeight: MyntFonts.semiBold,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: MyntWebTextStyles.para(
              context,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (amount != null) ...[
          const SizedBox(height: 12),
          Text(
            amount,
            style: MyntWebTextStyles.title(
              context,
              fontWeight: MyntFonts.bold,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
            ).copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
        ],
        if (datetime != null) ...[
          const SizedBox(height: 8),
          Text(
            datetime,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDetails(
    BuildContext context,
    ThemesProvider theme,
    MFProvider mfpro,
    String condval,
    Map<String, dynamic>? data,
  ) {
    final rows = <MapEntry<String, String>>[];

    if (condval == 'timeout') {
      final orderId = data?["OrderId"];
      final transNo = data?["TransNo"];
      if (orderId != null && orderId.toString().isNotEmpty && orderId.toString() != 'null') {
        rows.add(MapEntry("Order ID", "$orderId"));
      } else if (transNo != null && transNo.toString().isNotEmpty && transNo.toString() != 'null') {
        rows.add(MapEntry("TransNo", "$transNo"));
      }
      if (transNo != null && transNo.toString().isNotEmpty && transNo.toString() != 'null') {
        rows.add(MapEntry("UPI Transaction ID", "$transNo"));
      }
      rows.add(const MapEntry("Status Description", "Request Timeout reinitiate from orderbook"));
    } else if (condval == 'reinitiateerror') {
      final pType = data?["type"] ?? data?["paymentType"];
      if (pType != null && pType.toString().isNotEmpty && pType.toString() != 'null') {
        rows.add(MapEntry("Payment type", "$pType"));
      }
      final statusDesc = data?['responsestring'] ?? data?['emsg'] ?? data?['Remarks'];
      if (statusDesc != null && statusDesc.toString().isNotEmpty && statusDesc.toString() != 'null') {
        rows.add(MapEntry("Status Description", "$statusDesc"));
      } else {
        rows.add(const MapEntry("Status Description", "Payment initiation failed. Please try again."));
      }
    } else if (condval.isNotEmpty && condval != 'timeout') {
      rows.add(MapEntry("Status Description", condval));
    } else {
      // Default payment response
      final orderId = data?["OrderId"];
      final transNo = data?["TransNo"];
      if (mfpro.mfOrderTpye != 'SIP') {
        if (orderId != null && orderId.toString().isNotEmpty && orderId.toString() != 'null') {
          rows.add(MapEntry("Order ID", "$orderId"));
        }
      } else {
        final sipTrans = orderId ?? transNo;
        if (sipTrans != null && sipTrans.toString().isNotEmpty && sipTrans.toString() != 'null') {
          rows.add(MapEntry("TransNo", "$sipTrans"));
        }
      }
      if (transNo != null && transNo.toString().isNotEmpty && transNo.toString() != 'null') {
        rows.add(MapEntry("UPI Transaction ID", "$transNo"));
      }
      final remarks = data?['Remarks'] ?? data?['responsestring'] ?? data?['emsg'];
      if (remarks != null && remarks.toString().isNotEmpty && remarks.toString() != 'null') {
        rows.add(MapEntry("Status Description", "$remarks"));
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: rows.map((entry) => _dataRow(context, entry.key, entry.value)).toList(),
    );
  }

  Widget _dataRow(BuildContext context, String label, String value) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.medium,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.medium,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Divider(
          height: 1,
          thickness: 0.5,
          color: resolveThemeColor(
            context,
            dark: MyntColors.dividerDark,
            light: MyntColors.divider,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, ThemesProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: resolveThemeColor(
          context,
          dark: MyntColors.cardDark.withValues(alpha: 0.5),
          light: MyntColors.backgroundColor,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(
            color: resolveThemeColor(
              context,
              dark: MyntColors.dividerDark,
              light: MyntColors.divider,
            ),
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            FocusScope.of(context).unfocus();
          },
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: resolveThemeColor(
              context,
              dark: MyntColors.secondary,
              light: MyntColors.primary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: Text(
            'Done',
            style: MyntWebTextStyles.bodySmall(
              context,
              fontWeight: MyntFonts.semiBold,
              color: MyntColors.backgroundColor,
            ),
          ),
        ),
      ),
    );
  }
}

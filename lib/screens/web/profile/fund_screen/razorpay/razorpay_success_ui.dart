import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/transcation_provider.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';
import 'package:mynt_plus/sharedWidget/list_divider.dart';
import 'package:mynt_plus/sharedWidget/loader_ui.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';


/// Success dialog for QR and Enter UPI ID payment methods.
class UpiSuccessUi extends StatefulWidget {
  final String amount;
  const UpiSuccessUi({super.key, required this.amount});

  @override
  State<UpiSuccessUi> createState() => _UpiSuccessUiState();
}

class _UpiSuccessUiState extends State<UpiSuccessUi> {
  String time = '';
  @override
  void initState() {
    time = convDateWithTime();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
      },
      child: SafeArea(
        child: Consumer(
          builder: (context, ref, child) {
            final fund = ref.watch(transcationProvider);
            final checkData = fund.qrCheckStatusResponse?.data;
            final amountString = checkData?.amount ?? widget.amount;

            return TransparentLoaderScreen(
              isLoading: fund.fundLoading,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.cardDark,
                    light: MyntColors.card,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.profitDark,
                              light: MyntColors.profit,
                            ),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "SUCCESS",
                            style: MyntWebTextStyles.title(
                              context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                              fontWeight: MyntFonts.semiBold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Payment Successful",
                            style: MyntWebTextStyles.bodySmall(
                              context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "₹$amountString",
                            style: MyntWebTextStyles.head(
                              context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                              fontWeight: MyntFonts.semiBold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            time,
                            style: MyntWebTextStyles.bodySmall(
                              context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const ListDivider(),

                    // Details
                    _dataRow(
                      context,
                      "UPI ID",
                      checkData?.clientVPA ?? "",
                    ),
                    const ListDivider(),
                    _dataRow(
                      context,
                      "Payment ID",
                      checkData?.orderNumber ?? "",
                    ),
                    const ListDivider(),
                    _dataRow(
                      context,
                      "UPI Transaction ID",
                      checkData?.upiTransactionNo ?? "",
                    ),
                    const SizedBox(height: 24),
                    _closeButton(context, ref, fund),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dataRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: MyntWebTextStyles.bodySmall(
              context,
              fontWeight: MyntFonts.medium,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: MyntWebTextStyles.bodySmall(
              context,
              fontWeight: MyntFonts.semiBold,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closeButton(BuildContext context, WidgetRef ref, TranctionProvider fund) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: () {
          fund.amount.clear();
          fund.textFiledonChange('');
          fund.resetAmountValue();
          fund.clearPaymentResult();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          'Close',
          style: MyntWebTextStyles.body(
            context,
            color: Colors.white,
            fontWeight: MyntFonts.semiBold,
          ),
        ),
      ),
    );
  }
}


/// Success dialog for Net Banking payment method.
class NetBankingSuccessUi extends StatefulWidget {
  final String amount;
  const NetBankingSuccessUi({super.key, required this.amount});

  @override
  State<NetBankingSuccessUi> createState() => _NetBankingSuccessUiState();
}

class _NetBankingSuccessUiState extends State<NetBankingSuccessUi> {
  String time = '';

  @override
  void initState() {
    time = convDateWithTime();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
      },
      child: SafeArea(
        child: Consumer(
          builder: (context, ref, child) {
            final fund = ref.watch(transcationProvider);
            final netBankingRes = fund.razorpayTranstationRes;
            final amountString = netBankingRes?.amount != null
                ? (netBankingRes!.amount! / 100).toStringAsFixed(2)
                : widget.amount;

            return TransparentLoaderScreen(
              isLoading: fund.fundLoading,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.cardDark,
                    light: MyntColors.card,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.profitDark,
                              light: MyntColors.profit,
                            ),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "SUCCESS",
                            style: MyntWebTextStyles.title(
                              context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                              fontWeight: MyntFonts.semiBold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Payment Successful",
                            style: MyntWebTextStyles.bodySmall(
                              context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "₹$amountString",
                            style: MyntWebTextStyles.head(
                              context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                              fontWeight: MyntFonts.semiBold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            time,
                            style: MyntWebTextStyles.bodySmall(
                              context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const ListDivider(),
                    if (netBankingRes?.notes?.bankname != null && netBankingRes!.notes!.bankname!.isNotEmpty) ...[
                      _dataRow(context, "Bank Name", netBankingRes.notes!.bankname!),
                      const ListDivider(),
                    ],
                    if (netBankingRes?.notes?.accNo != null && netBankingRes!.notes!.accNo!.isNotEmpty) ...[
                      _dataRow(context, "A/c No", netBankingRes.notes!.accNo!),
                      const ListDivider(),
                    ],
                    if (netBankingRes?.id != null) ...[
                      _dataRow(context, "Payment ID", netBankingRes!.id!),
                      const ListDivider(),
                    ],
                    if (netBankingRes?.acquirerData?.bankTransactionId != null)
                      _dataRow(context, "Bank Transaction ID", netBankingRes!.acquirerData!.bankTransactionId!),
                    const SizedBox(height: 24),
                    _closeButton(context, ref, fund),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dataRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: MyntWebTextStyles.bodySmall(
              context,
              fontWeight: MyntFonts.medium,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: MyntWebTextStyles.bodySmall(
              context,
              fontWeight: MyntFonts.semiBold,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closeButton(BuildContext context, WidgetRef ref, TranctionProvider fund) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: () {
          fund.amount.clear();
          fund.textFiledonChange('');
          fund.resetAmountValue();
          fund.clearPaymentResult();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          'Close',
          style: MyntWebTextStyles.body(
            context,
            color: Colors.white,
            fontWeight: MyntFonts.semiBold,
          ),
        ),
      ),
    );
  }
}

class RazorpaySuccessUi extends StatefulWidget {
  final String amount;
  final bool isNetBanking;
  const RazorpaySuccessUi({
    super.key,
    required this.amount,
    this.isNetBanking = false,
  });

  @override
  State<RazorpaySuccessUi> createState() => _RazorpaySuccessUiState();
}

class _RazorpaySuccessUiState extends State<RazorpaySuccessUi> {
  @override
  Widget build(BuildContext context) {
    if (widget.isNetBanking) {
      return NetBankingSuccessUi(amount: widget.amount);
    }
    return UpiSuccessUi(amount: widget.amount);
  }
}
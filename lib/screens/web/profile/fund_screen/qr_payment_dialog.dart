import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../provider/transcation_provider.dart';
import '../../../../res/res.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';


/// What a user's cancel returns: a final status stays as it is, anything else
/// (PENDING, FAILURE and so on, or no status) closes as 'CANCELLED'.
String paymentCancelResult(String? status) {
  const finalStatuses = {'SUCCESS', 'FAILED', 'REJECTED', 'EXPIRED'};
  return finalStatuses.contains(status) ? status! : 'CANCELLED';
}

class QrPaymentDialog extends ConsumerStatefulWidget {
  const QrPaymentDialog({super.key});

  @override
  ConsumerState<QrPaymentDialog> createState() => _QrPaymentDialogState();
}

class _QrPaymentDialogState extends ConsumerState<QrPaymentDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fund = ref.read(transcationProvider);
      fund.startQrStatusPolling(context, onStatusUpdate: (status) {
        if (!mounted) return;
        Navigator.of(context).pop(status);
      });
    });
  }

  @override
  void dispose() {
    ref.read(transcationProvider).stopQrStatusPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fund = ref.watch(transcationProvider);
    final amount =
        fund.indentUpiResponse?.data?.amount ?? fund.amount.text;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: resolveThemeColor(
        context,
        dark: MyntColors.cardDark,
        light: MyntColors.card,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              "Scan QR code with any UPI app",
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
            const SizedBox(height: 16),

            // UPI app logos
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildUpiLogo("G Pay", assets.biggpay),
                const SizedBox(width: 20),
                _buildUpiLogo("PhonePe", assets.bigphnpay),
                const SizedBox(width: 20),
                _buildUpiLogo("Paytm", assets.bigpaytm),
                const SizedBox(width: 20),
                _buildMoreIcon(),
              ],
            ),
            const SizedBox(height: 24),

            // QR Code
            if (fund.qrCodeUrl != null)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.cardBorderDark,
                      light: MyntColors.cardBorder,
                    ),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    fund.qrCodeUrl!,
                    width: 300,
                    height: 300,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        width: 240,
                        height: 240,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MyntColors.primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return SizedBox(
                        width: 240,
                        height: 240,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  color: MyntColors.error, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                "Failed to load QR code",
                                style: MyntWebTextStyles.bodySmall(
                                  context,
                                  color: MyntColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Amount
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "Pay ",
                    style: MyntWebTextStyles.body(
                      context,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary,
                      ),
                    ),
                  ),
                  TextSpan(
                    text: "₹$amount",
                    style: MyntWebTextStyles.title(
                      context,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary,
                      ),
                      fontWeight: MyntFonts.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Waiting indicator
            if (fund.qrPolling)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: 
                   resolveThemeColor(context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary)
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Waiting for payment...",
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
            const SizedBox(height: 8),

            // Cancel button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () async {
                  fund.stopQrStatusPolling();
                  final result = await fund.checkQrStatusOnce();
                  if (mounted) {
                    Navigator.of(context)
                        .pop(paymentCancelResult(result?.data?.status));
                  }
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
                ),
                child: Text(
                  "Cancel Transaction",
                  style: MyntWebTextStyles.body(
                    context,
                    color: Colors.white,
                    fontWeight: MyntFonts.semiBold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpiLogo(String label, String assetPath) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          assetPath,
          width: 32,
          height: 32,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: MyntWebTextStyles.caption(
            context,
            color: resolveThemeColor(
              context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoreIcon() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: resolveThemeColor(
              context,
              dark: MyntColors.inputBgDark,
              light: MyntColors.inputBg,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.more_horiz,
            size: 20,
            color: resolveThemeColor(
              context,
              dark: MyntColors.iconSecondaryDark,
              light: MyntColors.iconSecondary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "More",
          style: MyntWebTextStyles.caption(
            context,
            color: resolveThemeColor(
              context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

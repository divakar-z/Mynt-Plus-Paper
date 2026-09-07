// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../provider/mf_provider.dart';
import '../../../../../provider/thems.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../sharedWidget/payment_loader.dart';
import '../../../../../sharedWidget/snack_bar.dart';
import '../profile/fund_screen/upi_id_screens/mf_payment_resp_alert.dart';

class MfUPIProcessingScreenWeb extends ConsumerStatefulWidget {
  const MfUPIProcessingScreenWeb({super.key, this.data});
  final String? data;
  @override
  ConsumerState<MfUPIProcessingScreenWeb> createState() =>
      _MfUPIProcessingScreenWebState();
}

class _MfUPIProcessingScreenWebState extends ConsumerState<MfUPIProcessingScreenWeb> {
  Timer? _timer;
  Timer? _autoPopTimer;
  @override
  void initState() {
    super.initState();
    _handleInitialLogic();
  }

  void _handleInitialLogic() async {
    final mfProv = ref.read(mfProvider);

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await mfProv.getpaymentstatus(widget.data, context); // Use await if async

      final status = mfProv.statusCheckUpi?.status;
      if ( mfProv.statusCheckUpi?.stat == 'Not_Ok' || (status == 'PAYMENT REJECTED') || (status == 'PAYMENT COMPLETED' ||status ==  'PAYMENT PROCESSING')) {
        _timer?.cancel(); // This is safe even if already cancelled
        _autoPopTimer?.cancel(); // Cancel auto-pop if running

        mfProv.setterformftrigger(false);
        ref.read(mfProvider).IsPaymentCalled(false);

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => MfPaymentRespAlert(
              upiData: mfProv.statusCheckUpi?.toJson(),
              conditionval : mfProv.statusCheckUpi?.stat == 'Not_Ok' ? mfProv.statusCheckUpi?.remarks : '',
            ),
          );
        }
        warningMessage(context, '$status');
            mfProv.fetchmfsiplist();
        mfProv.fetchMfOrderbook(context);
      }
    });

    _autoPopTimer = Timer(const Duration(minutes: 3), () {
      _timer?.cancel(); // Also stop periodic timer here as a fallback
      mfProv.setterformftrigger(false);
      ref.read(mfProvider).IsPaymentCalled(false);

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => MfPaymentRespAlert(
              upiData: mfProv.statusCheckUpi?.toJson(),
              conditionval : 'timeout'
            ),
          );
        warningMessage(context, 'Timeout try again');
            mfProv.fetchmfsiplist();
      mfProv.fetchMfOrderbook(context);
      }
    });
    
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoPopTimer?.cancel();
    super.dispose();
  }

  void _triggerButtonAction() {
    // Clear the amount text field

    ref.read(mfProvider).setterformftrigger(false);
    _timer?.cancel(); // This is safe even if already cancelled
    _autoPopTimer?.cancel();
    Navigator.pop(context);
    ref.read(mfProvider).IsPaymentCalled(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeProvider);
    final mfprovider = ref.read(mfProvider);

    return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
        },
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: resolveThemeColor(context,
                  dark: MyntColors.backgroundColorDark,
                  light: MyntColors.backgroundColor),
              border: Border.all(
                color: resolveThemeColor(context,
                    dark: MyntColors.dividerDark, light: MyntColors.divider),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                    border: Border(
                      bottom: BorderSide(
                        color: resolveThemeColor(context,
                            dark: MyntColors.dividerDark,
                            light: MyntColors.divider),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Processing',
                        style: MyntWebTextStyles.title(
                          context,
                          fontWeight: MyntFonts.semiBold,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: _triggerButtonAction,
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: resolveThemeColor(context,
                              dark: MyntColors.iconSecondaryDark,
                              light: MyntColors.iconSecondary),
                        ),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 32),
                  child: Column(
                    children: [
                      Text(
                        'Awaiting ${mfprovider.paymentName} confirmation',
                        style: MyntWebTextStyles.body(
                          context,
                          fontWeight: MyntFonts.medium,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const ProgressiveDotsLoader(),
                      const SizedBox(height: 24),
                      Text(
                        'This will take a few seconds.',
                        style: MyntWebTextStyles.para(
                          context,
                          darkColor: MyntColors.textSecondaryDark,
                          lightColor: MyntColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: resolveThemeColor(context,
                            dark: MyntColors.dividerDark,
                            light: MyntColors.divider),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _triggerButtonAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.isDarkMode
                            ? MyntColors.secondary
                            : MyntColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        elevation: 0,
                      ),
                      child: Text(
                        'Cancel Transaction',
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          fontWeight: MyntFonts.semiBold,
                          color: MyntColors.backgroundColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}

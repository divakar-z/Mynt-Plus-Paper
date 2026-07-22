// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/provider/fund_provider.dart';
import 'package:mynt_plus/res/global_state_text.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/list_divider.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import 'package:mynt_plus/utils/no_emoji_inputformatter.dart';
import 'razorpay/razorpay_web.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../sharedWidget/common_text_fields_web.dart';
import '../../../../../sharedWidget/common_buttons_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;


// import 'package:remove_emoji_input_formatter/remove_emoji_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../provider/privacy_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../provider/transcation_provider.dart';
// import '../../../../sharedWidget/custom_back_btn.dart';
import '../../../../sharedWidget/custom_drag_handler.dart';
import '../../../../sharedWidget/custom_switch_btn.dart';
import '../../../../sharedWidget/fund_function.dart';
import '../../../../../provider/fund_provider.dart';
import '../../../../../res/global_state_text.dart';
import '../../../../../sharedWidget/list_divider.dart';
import '../../../../../sharedWidget/loader_ui.dart';
import '../../../../../utils/no_emoji_inputformatter.dart';
import '../../../../../models/fund_model_testing_copy/secured_bank_detalis_model.dart';
import '../../../../../models/fund_model_testing_copy/secured_client_data_model.dart';
import 'ios_fund_screen/ios_no_upi_apps_ui.dart';
import 'ios_fund_screen/ios_upi_apps_bottomsheet.dart';
import 'razorpay/razorpay_failed_ui.dart';
import 'razorpay/razorpay_success_ui.dart';
import 'upi_id_screens/upi_id_cancel_alert.dart';
import 'qr_payment_dialog.dart';
import 'withdraw/withdraw_screen.dart';

class FundScreen extends ConsumerStatefulWidget {
  final TranctionProvider dd;
  final VoidCallback? onBack;
  final VoidCallback? onViewTransactions;
  const FundScreen({super.key, required this.dd, this.onBack, this.onViewTransactions});

  @override
  ConsumerState<FundScreen> createState() => _FundScreenState();
}

class _FundScreenState extends ConsumerState<FundScreen> {
  bool _isInitialized = false;
  bool _isUpiIdExpanded = false;
  int _selectedPaymentMethod = -1; // -1 = none, 0 = Scan QR, 1 = UPI ID, 2 = Net Banking
  String _selectedGateway = 'RAZORPAY'; // 'RAZORPAY' or 'ATOM'

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      checkIosAvailableApps();
    }

    // Initialize data after frame is built and only when data is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreenData();
    });
  }

  /// Initialize screen data only when bank details and client data are available
  void _initializeScreenData() {
    final fund = ref.read(transcationProvider);
    
    // Check if required data is available
    if (fund.bankdetails?.dATA != null && 
        fund.bankdetails!.dATA!.isNotEmpty &&
        fund.decryptclientcheck != null) {
      // Data is ready, initialize the screen
      fund.initialdata(context);
      fund.focusNode.requestFocus();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } else {
      // Data not ready yet, retry after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _initializeScreenData();
        }
      });
    }
  }

  bool _isDisposedIos = false;

  @override
  void dispose() {
    _isDisposedIos = true;
    super.dispose();
  }

  Future<void> _handleAndroidUpiPayment(
      BuildContext context, TranctionProvider fund) async {
    // Reset bottom sheet state when starting a new payment process
    fund.resetBottomSheetState();

    await fund.fetchValidateToken(context);
    fund.focusNode.unfocus();
    await fund.fetchUPIPaymet(
      context,
      "${fund.amount.text}.00",
      fund.multipleAccno,
      fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][0],
      fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][2],
    );

    await fund.fetchUpiPaymentstatus(
      context,
      "${fund.hdfcdirectpayment?.data?.orderNumber}",
      "${fund.hdfcdirectpayment?.data?.upiTransactionNo}",
    );
  }

  Future<void> _handleIosUpiPayment(BuildContext context,
      TranctionProvider fund, dynamic availableApps, dynamic theme) async {
    // Reset bottom sheet state when starting a new payment process
    fund.resetBottomSheetState();

    if (availableApps.isEmpty) {
      showModalBottomSheet(
          enableDrag: false,
          useSafeArea: true,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          backgroundColor: const Color(0xffffffff),
          context: context,
          builder: (context) {
            return IosNOUpiAppsSheet(theme: theme);
          });
    } else {
      fund.focusNode.unfocus();

      await fund.fetchUPIPaymet(
        context,
        "${fund.amount.text}.00",
        fund.multipleAccno,
        fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][0],
        fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][2],
      );

      await fund.fetchUpiPaymentstatus(
        context,
        "${fund.hdfcdirectpayment?.data?.orderNumber}",
        "${fund.hdfcdirectpayment?.data?.upiTransactionNo}",
      );

      showModalBottomSheet(
          enableDrag: false,
          useSafeArea: true,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          backgroundColor: const Color(0xffffffff),
          context: context,
          builder: (context) {
            return UpiAppsBottomSheet(upiapps: availableApps, theme: theme);
          });
    }
  }

  _showUpiIdForm(BuildContext context, TranctionProvider fund, dynamic theme,
      dynamic colors) {
    // Reset loading state and clear errors when opening the sheet
    fund.togglefundLoading(false);
    fund.clearerror();

    // This should show a dialog or navigate to a new screen with the UPI ID form
    showModalBottomSheet(
        enableDrag: false,
        useSafeArea: false,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            
        backgroundColor: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
        context: context,
        builder: (context) {
          return SafeArea(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
                border: Border(
                  top: BorderSide(
                    color: theme.isDarkMode
                        ? colors.textSecondaryDark.withOpacity(0.5)
                        : colors.colorWhite,
                  ),
                  left: BorderSide(
                    color: theme.isDarkMode
                        ? colors.textSecondaryDark.withOpacity(0.5)
                        : colors.colorWhite,
                  ),
                  right: BorderSide(
                    color: theme.isDarkMode
                        ? colors.textSecondaryDark.withOpacity(0.5)
                        : colors.colorWhite,
                  ),
                ),
              ),
              child: Consumer(
                builder: (context, ref, child) {
                  final fund = ref.watch(transcationProvider);
                  // Check if context is still mounted before building
                  if (!context.mounted) return const SizedBox.shrink();
                  return _buildUpiIdForm(fund, theme, colors, context, null);
                },
              ),
            ),
          );
        }).then((_) {
      // Reset loading state when sheet is dismissed
      fund.togglefundLoading(false);
    });
  }

  Widget _buildUpiIdForm(TranctionProvider fund, dynamic theme, dynamic colors,
      BuildContext context, StateSetter? setState) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 0,
        bottom: 16.0 +
            MediaQuery.of(context).viewInsets.bottom, // Add keyboard padding
      ),
      child: SingleChildScrollView(
        physics: ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CustomDragHandler(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: TextWidget.titleText(
                      text: "UPI ID",
                      color: theme.isDarkMode
                          ? colors.textPrimaryDark
                          : colors.textPrimaryLight,
                      theme: theme.isDarkMode,
                      fw: 1,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              color: theme.isDarkMode
                  ? colors.darkColorDivider
                  : colors.colorDivider,
              height: 0,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: fund.upiid,
              style: TextWidget.textStyle(
                                      fontSize: 16,
                                      color: theme.isDarkMode
                                          ? colors.textPrimaryDark
                                          : colors.textPrimaryLight,
                                      theme: theme.isDarkMode,
                                      fw: 0,
                                    ),
              inputFormatters: [
                NoEmojiInputFormatter(),
                FilteringTextInputFormatter.deny(RegExp('[π£•₹€℅™∆√¶/,]')),
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              decoration: InputDecoration(
                hintText: "Enter UPI ID",
                
                hintStyle: TextWidget.textStyle(
                    fontSize: 14,  theme: false, color: (theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight).withOpacity(0.4), fw: 0),
                    

                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colors.colorBlue),
                borderRadius: BorderRadius.circular(5)),
            disabledBorder: InputBorder.none,
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colors.colorBlue),
                borderRadius: BorderRadius.circular(5)),
            border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(5)),
                fillColor: theme.isDarkMode
                    ? colors.darkGrey
                    : const Color(0xffF1F3F8),
                filled: true,
              ),
              onChanged: (value) {
                fund.upiidOnchange(value);
                fund.validateUPI(value);
              },
            ),
            if (fund.upiiderror != null && fund.upiiderror!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextWidget.captionText(
                    text: "${fund.upiiderror}",
                    theme: false,
                    color: theme.isDarkMode ? colors.errorDark : colors.errorLight,
                    fw: 0,
                    align: TextAlign.left),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    minimumSize: const Size(0, 45),
                    backgroundColor: theme.isDarkMode
                        ? colors.primaryDark
                        : colors.primaryLight,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: () async {
                    // Validate and show errors if any
                    fund.upiidOnchange(fund.upiid.text);
                    fund.validateUPI(fund.upiid.text);

                    // Only proceed if validation passes
                    if (fund.upiiderror == null || fund.upiiderror!.isEmpty) {
                      await _handleUpiIdPayment(context, fund);
                    }
                  },
                  child: fund.fundLoading
                      ? SizedBox(
                          width: 18,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: colors.colorWhite),
                        )
                      : TextWidget.subText(
                          text: "Pay Via UPI ID",
                          theme: false,
                          color: colors.colorWhite,
                          fw: 2,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpiIdPayment(
      BuildContext context, TranctionProvider fund) async {
    // Reset bottom sheet state when starting a new payment process
    fund.resetBottomSheetState();

    try {
      // Step 1: Verify UPI ID via checkClientVPA
      await fund.fetcUPIIDPayment(
          context,
          fund.upiid.text,
          fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][0],
          fund.bankdetails!.dATA![fund.indexss][2]);

      // Check if UPI ID validation was successful
      if (fund.upiiderror != null && fund.upiiderror!.isNotEmpty) {
        return; // Stop if there's an error
      }

      if (fund.hdfcpaymentdata!.data!.verifiedVPAStatus1 == "Available" ||
          fund.hdfcpaymentdata!.data!.verifiedVPAStatus2 == "Available") {

        // Step 2: Initiate UPI Collect Request via wrapper
        final success = await fund.fetchUpiCollectRequest(context);
        if (!success) {
          if (mounted) {
            warningMessage(context,
                fund.upiCollectResponse?.emsg ?? "Failed to initiate UPI payment");
          }
          return;
        }

        if (!mounted) return;
        fund.focusNode.unfocus();

        // Step 3: Start polling for payment status via wrapper/check_status
        fund.startUpiCollectStatusPolling(context, onStatusUpdate: (status) {
          if (!mounted) return;
          // Close the awaiting dialog with the status
          Navigator.of(context, rootNavigator: true).pop(status);
        });

        // Step 4: Show awaiting confirmation dialog and wait for result
        final upiIdStatus = await showDialog<String>(
            barrierDismissible: false,
            context: context,
            builder: (BuildContext context) {
              return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop) return;
                  },
                  child: Center(
                    child: shadcn.Card(
                      borderRadius: BorderRadius.circular(8),
                      padding: EdgeInsets.zero,
                      child: Container(
                        width: 400,
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          color: resolveThemeColor(context,
                              dark: MyntColors.dialogDark,
                              light: MyntColors.dialog),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: shadcn.Theme.of(context)
                                        .colorScheme
                                        .border,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Awaiting UPI Confirmation',
                                    style: MyntWebTextStyles.title(
                                      context,
                                      color: resolveThemeColor(
                                        context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  MyntCloseButton(
                                    onPressed: () async {
                                      fund.stopUpiCollectStatusPolling();
                                      final result = await fund.checkUpiCollectStatusOnce();
                                      if (context.mounted) {
                                        Navigator.of(context).pop(result?.data?.status ?? 'CANCELLED');
                                        fund.focusNode.unfocus();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            // Content
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: resolveThemeColor(
                                          context,
                                          dark: MyntColors.primaryDark,
                                          light: MyntColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'This will take a few seconds.',
                                      textAlign: TextAlign.center,
                                      style: MyntWebTextStyles.body(
                                        context,
                                        fontWeight: FontWeight.w500,
                                        color: resolveThemeColor(
                                          context,
                                          dark: MyntColors.textPrimaryDark,
                                          light: MyntColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    MyntButton(
                                      type: MyntButtonType.primary,
                                      size: MyntButtonSize.large,
                                      label: 'Cancel Transaction',
                                      isFullWidth: true,
                                      backgroundColor: resolveThemeColor(
                                        context,
                                        dark: MyntColors.secondary,
                                        light: MyntColors.primary,
                                      ),
                                      onPressed: () async {
                                        fund.stopUpiCollectStatusPolling();
                                        final result = await fund.checkUpiCollectStatusOnce();
                                        if (context.mounted) {
                                          Navigator.of(context).pop(result?.data?.status ?? 'CANCELLED');
                                          fund.focusNode.unfocus();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ));
            });

        fund.stopUpiCollectStatusPolling();
        if (!mounted) return;

        // Step 5: Handle the result status and refresh balance
        if (upiIdStatus == "SUCCESS") {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: UpiSuccessUi(amount: fund.amount.text),
              ),
            ),
          ).then((_) {
            fund.amount.clear();
            ref.read(fundProvider).fetchFunds(context);
          });
          ref.read(fundProvider).fetchFunds(context);
        } else if (upiIdStatus != null) {
          final collectData = await fund.checkUpiCollectStatusOnce();
          if (!mounted) return;
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: RazorpayFailedUi(
                  amount: fund.amount.text,
                  upiAddress: fund.upiid.text,
                  orderId: collectData?.data?.orderNumber ?? fund.upiCollectResponse?.data?.orderNumber,
                  upiTransactionId: collectData?.data?.upiTransactionNo ?? fund.upiCollectResponse?.data?.upiTransactionNo,
                  statusDescription: collectData?.data?.statusDescription ?? upiIdStatus,
                  status: collectData?.data?.status ?? upiIdStatus,
                ),
              ),
            ),
          ).then((_) {
            ref.read(fundProvider).fetchFunds(context);
          });
          ref.read(fundProvider).fetchFunds(context);
        }
      }
    } catch (e) {
      // Ensure loading state is reset on any error
      fund.togglefundLoading(false);
      rethrow;
    }
  }

  Future<void> _handleRazorpayPayment(
      BuildContext context, TranctionProvider fund) async {
    fund.resetBottomSheetState();

    await fund.fetchrazorpay(
      context,
      int.parse(fund.amount.text).toString(),
      fund.accno,
      fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][2],
      fund.ifsc,
      null,
    );

    if (fund.razorpayOptions != null && mounted) {
      try {
        await openRazorpayWeb(
          options: fund.razorpayOptions!,
          onSuccess: (paymentId, orderId, signature) {
            if (mounted && paymentId != null && paymentId.isNotEmpty) {
              _handleWebPaymentSuccess(paymentId);
            }
          },
          onError: (code, description, paymentId) {
            if (mounted) {
              _handleWebPaymentError();
            }
          },
        );
      } catch (e, st) {
        debugPrint('Razorpay open failed: $e\n$st');
        if (mounted) {
          warningMessage(context, "Failed to open payment gateway");
        }
      }
    }
  }

  Future<void> _handleAtomPayment(
      BuildContext context, TranctionProvider fund) async {
    fund.resetBottomSheetState();

    final clientData =
        fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss];
    final clientCode = clientData[0];
    final clientName = clientData[2];
    final clientEmail = clientData[4];
    final clientMobile = clientData[5];
    final amt = '${fund.amount.text}.00';
    final ifsc4 = fund.ifsc.length >= 4 ? fund.ifsc.substring(0, 4) : fund.ifsc;

    final url = 'https://fundapi.mynt.in/atom/atomredirect'
        '?seg=${Uri.encodeComponent(fund.textValue)}'
        '&code=${Uri.encodeComponent(clientCode)}'
        '&amt=${Uri.encodeComponent(amt)}'
        '&custacc=${Uri.encodeComponent(fund.accno)}'
        '&bankifsc=${Uri.encodeComponent(ifsc4)}'
        '&name=${Uri.encodeComponent(clientName)}'
        '&mobile=${Uri.encodeComponent(clientMobile)}'
        '&email=${Uri.encodeComponent(clientEmail)}'
        '&bankname=${Uri.encodeComponent(fund.bankname)}'
        '&ru=${Uri.encodeComponent('https://fundapi.mynt.in/atom/fromatom')}';

    try {
      html.window.open(
        url,
        'AtomPayment',
        'width=800,height=700,scrollbars=yes,resizable=yes,left=200,top=100',
      );
    } catch (e) {
      if (mounted) {
        warningMessage(context, "Failed to open Atom payment gateway");
      }
    }
  }

  Future<void> _handleScanQrPayment(
      BuildContext context, TranctionProvider fund) async {
    fund.resetBottomSheetState();
    fund.focusNode.unfocus();

    await fund.fetchValidateToken(context);

    final success = await fund.fetchIndentUpiRequest(context);
    if (!success) {
      if (mounted) {
        warningMessage(context,
            fund.indentUpiResponse?.emsg ?? "Failed to initiate QR payment");
      }
      return;
    }

    if (!mounted) return;

    final status = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const QrPaymentDialog(),
    );

    if (!mounted) return;

    if (status == "SUCCESS") {
      ref.read(fundProvider).fetchFunds(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: UpiSuccessUi(amount: fund.amount.text),
          ),
        ),
      ).then((_) {
        ref.read(fundProvider).fetchFunds(context);
      });
    } else if (status != null && status != 'CANCELLED') {
      ref.read(fundProvider).fetchFunds(context);
      final qrData = fund.qrCheckStatusResponse?.data;
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: RazorpayFailedUi(
              amount: qrData?.amount ?? fund.amount.text,
              upiAddress: qrData?.clientVPA ?? fund.upiid.text,
              orderId: qrData?.orderNumber ?? fund.hdfcUPIStatus?.data?.orderNumber,
              upiTransactionId: qrData?.upiTransactionNo ?? fund.hdfcUPIStatus?.data?.upiTransactionNo,
              statusDescription: qrData?.statusDescription ?? fund.hdfcUPIStatus?.data?.statusDescription,
              status: qrData?.status ?? fund.hdfcUPIStatus?.data?.status,
            ),
          ),
        ),
      ).then((_) {
        ref.read(fundProvider).fetchFunds(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
   
    return Consumer(
      builder: (context, ref, child) {
        final theme = ref.watch(themeProvider);
        final fund = ref.watch(transcationProvider);
        final funds = ref.watch(fundProvider);
        final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
      
        if (!_isInitialized ||
        fund.bankdetails == null ||
        fund.decryptclientcheck == null) {
      return Scaffold(
        backgroundColor: resolveThemeColor(
          context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor,
        ),
        appBar: AppBar(
          centerTitle: false,
          leadingWidth: 48,
          titleSpacing: 6,
          backgroundColor: resolveThemeColor(
            context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor,
          ),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_outlined,
              size: 18,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
            ),
            onPressed: widget.onBack ?? () => Navigator.pop(context),
          ),
          title: Text(
            'Add Money',
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
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: resolveThemeColor(context,
                dark: MyntColors.primaryDark,
                light: MyntColors.primary),
          ),
        ),
      );
    }
        return Scaffold(
          backgroundColor: resolveThemeColor(
            context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor,
          ),
          appBar: AppBar(
            centerTitle: false,
            leadingWidth: 48,
            titleSpacing: 6,
            backgroundColor: resolveThemeColor(
              context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor,
            ),
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_outlined,
                size: 18,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary,
                ),
              ),
              onPressed: widget.onBack ?? () => Navigator.pop(context),
            ),
            title: Text(
              'Add Money',
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
          ),
          body: GestureDetector(
            onTap: () => fund.focusNode.unfocus(),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top bar card ──────────────────────────────────
                    shadcn.Theme(
                      data: shadcn.Theme.of(context).copyWith(radius: () => 0.3),
                      child: shadcn.Card(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Available Balance",
                                    style: MyntWebTextStyles.bodySmall(
                                      context,
                                      fontWeight: MyntFonts.medium,
                                      darkColor: MyntColors.textSecondaryDark,
                                      lightColor: MyntColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ref.watch(privacyProvider).mask(
                                        formatIndianCurrency(
                                            funds.fundDetailModel?.avlMrg ??
                                                '0.00'),
                                        prefix: "₹ "),
                                    style: MyntWebTextStyles.head(
                                      context,
                                      color: resolveThemeColor(
                                        context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary,
                                      ),
                                      fontWeight: MyntFonts.medium,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // View All Transactions
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: widget.onViewTransactions,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.primaryDark,
                                              light: MyntColors.primary)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 16,
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.primaryDark,
                                              light: MyntColors.primary),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "View All Transactions",
                                          style: MyntWebTextStyles.bodySmall(
                                            context,
                                            fontWeight: MyntFonts.semiBold,
                                            color: resolveThemeColor(context,
                                                dark: MyntColors.primaryDark,
                                                light: MyntColors.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Main content card (two columns) ──────────────
                    Container(
                      decoration: BoxDecoration(
                        color: resolveThemeColor(context,
                            dark: MyntColors.transparent, light: MyntColors.card),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                            color: resolveThemeColor(context,
                                dark: MyntColors.cardBorderDark,
                                light: MyntColors.cardBorder)),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left column: Amount + Bank
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Enter Amount",
                                      style: MyntWebTextStyles.bodySmall(
                                        context,
                                        fontWeight: MyntFonts.medium,
                                        darkColor: MyntColors.textSecondaryDark,
                                        lightColor: MyntColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Amount input
                                    IgnorePointer(
                                      ignoring: !fund.hasActiveSegments,
                                      child: Opacity(
                                        opacity:
                                            fund.hasActiveSegments ? 1.0 : 0.5,
                                        child: MyntTextField(
                                          focusNode: fund.focusNode,
                                          controller: fund.amount,
                                          placeholder: "0.00",
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          leadingWidget: Center(
                                            widthFactor: 1,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 12),
                                              child: Text(
                                                "₹",
                                                style: MyntWebTextStyles.body(
                                                  context,
                                                  fontWeight: MyntFonts.medium,
                                                  darkColor: MyntColors
                                                      .textSecondaryDark,
                                                  lightColor:
                                                      MyntColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            fund.textFiledonChange(value);
                                          },
                                        ),
                                      ),
                                    ),
                                    if (!fund.hasActiveSegments) ...[
                                      const SizedBox(height: 12),
                                      _buildSegmentInactiveBanner(context),
                                    ],

                                    // Quick amount chips
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [500, 1000, 5000, 10000]
                                          .map((amt) {
                                            final isSelected = fund.amount.text == amt.toString();
                                            return ChoiceChip(
                                              label: Text(
                                                "₹${NumberFormat('#,##,###').format(amt)}",
                                              ),
                                              selected: isSelected,
                                              onSelected:  fund.hasActiveSegments
                                                  ?  (_) {
                                                fund.amount.text = amt.toString();
                                                fund.textFiledonChange(amt.toString());
                                              } : null,
                                              labelStyle: MyntWebTextStyles.bodySmall(
                                                context,
                                                color: isSelected
                                                    ? resolveThemeColor(context,
                                                        dark: MyntColors.primaryDark,
                                                        light: MyntColors.primary)
                                                    : resolveThemeColor(
                                                        context,
                                                        dark: MyntColors.textSecondaryDark,
                                                        light: MyntColors.textSecondary,
                                                      ),
                                                fontWeight: MyntFonts.medium,
                                              ),
                                              selectedColor: resolveThemeColor(
                                                context,
                                                dark: MyntColors.primaryDark.withValues(alpha: 0.1),
                                                light: MyntColors.primary.withValues(alpha: 0.1),
                                              ),
                                              backgroundColor: resolveThemeColor(
                                                context,
                                                dark: MyntColors.cardDark,
                                                light: MyntColors.inputBg,
                                              ),
                                              side: BorderSide(
                                                color: isSelected
                                                    ? resolveThemeColor(context,
                                                        dark: MyntColors.primaryDark,
                                                        light: MyntColors.primary)
                                                    : resolveThemeColor(
                                                        context,
                                                        dark: MyntColors.cardBorderDark,
                                                        light: MyntColors.cardBorder,
                                                      ),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              showCheckmark: false,
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize.shrinkWrap,
                                              visualDensity: VisualDensity.compact,
                                            );
                                          })
                                          .toList(),
                                    ),

                                    // Error text
                                    if (fund.amount.text.isNotEmpty && fund.intValue < 50)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          fund.funderror,
                                          style: MyntWebTextStyles.caption(
                                            context,
                                            color: resolveThemeColor(
                                              context,
                                              dark: MyntColors.errorDark,
                                              light: MyntColors.error,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (fund.intValue > 5000000)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          fund.maxfunderror,
                                          style: MyntWebTextStyles.caption(
                                            context,
                                            color: resolveThemeColor(
                                              context,
                                              dark: MyntColors.errorDark,
                                              light: MyntColors.error,
                                            ),
                                          ),
                                        ),
                                      ),

                                    const SizedBox(height: 20),

                                    // Segment selection
                                     if (fund.hasActiveSegments) ...[
                                    Text(
                                      "Segment",
                                      style: MyntWebTextStyles.bodySmall(
                                        context,
                                        fontWeight: MyntFonts.medium,
                                        darkColor: MyntColors.textSecondaryDark,
                                        lightColor: MyntColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _buildSegmentSelector(fund, context),
                                    const SizedBox(height: 20),
                                     ],
                                    // Bank account
                                    Text(
                                      "Bank account",
                                      style: MyntWebTextStyles.bodySmall(
                                        context,
                                        fontWeight: MyntFonts.medium,
                                        darkColor: MyntColors.textSecondaryDark,
                                        lightColor: MyntColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    InkWell(
                                      onTap: () {
                                        fund.focusNode.unfocus();
                                        showBottomSheetbank(fund, theme);
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: resolveThemeColor(
                                            context,
                                            dark: MyntColors.cardDark,
                                            light: MyntColors.card,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: resolveThemeColor(
                                              context,
                                              dark: MyntColors.cardBorderDark,
                                              light: MyntColors.cardBorder,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: resolveThemeColor(
                                                  context,
                                                  dark: MyntColors.backgroundColorDark,
                                                  light: MyntColors.inputBg,
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.account_balance_rounded,
                                                size: 18,
                                                color: resolveThemeColor(
                                                  context,
                                                  dark: MyntColors.iconSecondaryDark,
                                                  light: MyntColors.iconSecondary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    fund.bankname,
                                                    style: MyntWebTextStyles.body(
                                                      context,
                                                      color: resolveThemeColor(
                                                        context,
                                                        dark: MyntColors.textPrimaryDark,
                                                        light: MyntColors.textPrimary,
                                                      ),
                                                      fontWeight: MyntFonts.semiBold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    hideAccountNumber(fund.accno),
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
                                            Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              size: 20,
                                              color: resolveThemeColor(
                                                context,
                                                dark: MyntColors.iconSecondaryDark,
                                                light: MyntColors.iconSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Vertical divider
                            Container(
                              width: 1,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.cardBorderDark,
                                  light: MyntColors.cardBorder),
                            ),

                            // Right column: Payment methods
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Payment method",
                                      style: MyntWebTextStyles.bodySmall(
                                        context,
                                        fontWeight: MyntFonts.medium,
                                        darkColor: MyntColors.textSecondaryDark,
                                        lightColor: MyntColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Scan QR
                                    _buildPaymentMethodCard(
                                      fund: fund,
                                      theme: theme,
                                      index: 0,
                                      icon: SvgPicture.asset(assets.upiIcon, width: 32),
                                      title: "Scan QR",
                                      maxLimit: "₹1,00,000",
                                      badges: ["free", "recommended"],
                                      isDisabled: !_hasTradableSegments(fund) ||
                                          fund.intValue > 100000,
                                    ),
                                    const SizedBox(height: 10),

                                    // Enter UPI ID (with inline form inside card)
                                    IgnorePointer(
                                      ignoring: !_hasTradableSegments(fund),
                                      child: Opacity(
                                        opacity: _hasTradableSegments(fund) ? 1.0 : 0.5,
                                        child: _buildUpiIdCard(fund, theme, context),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Net Banking
                                    _buildPaymentMethodCard(
                                      fund: fund,
                                      theme: theme,
                                      index: 2,
                                      icon: SvgPicture.asset(
                                        assets.netbankingIcon,
                                        width: 32,
                                        color: resolveThemeColor(
                                          context,
                                          dark: MyntColors.iconSecondaryDark,
                                          light: MyntColors.iconSecondary,
                                        ),
                                      ),
                                      title: "Net Banking",
                                      maxLimit: "₹50,00,000",
                                      badges: ["free"],
                                      isDisabled: !_hasTradableSegments(fund),
                                    ),

                                    // Gateway selector (visible when Net Banking is selected)
                                    if (_selectedPaymentMethod == 2) ...[
                                      const SizedBox(height: 10),
                                      _buildGatewaySelector(context),
                                    ],

                                    const SizedBox(height: 20),

                                    // Pay button
                                    if (_selectedPaymentMethod >= 0)
                                      MyntPrimaryButton(
                                        label: "${_selectedPaymentMethod == 1 ? "Pay via UPI ID" : _selectedPaymentMethod == 0 ? "Pay via QR" : "Pay via Net Banking"}${fund.amount.text.isNotEmpty ? "  ·  ₹${fund.amount.text}" : ""}",
                                        isLoading: fund.fundLoading,
                                        onPressed: () => _onPayPressed(context, fund),
                                      ),
                                  ],
                                ),
                              ),
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
        );
      },
    );
  }

  String formatIndianCurrency(String amount) {
    final formatter = NumberFormat.currency(
      locale: "en_IN",
      symbol: '', // Or '₹'
      decimalDigits: 2, // Always show 2 decimals
    );
    return formatter.format(double.tryParse(amount) ?? 0.0);
  }

  // Old chip-style segment selection UI
  // Widget _buildSegmentChip(String label, bool isSelected, VoidCallback onTap, ThemesProvider theme) {
  //   return GestureDetector(
  //     onTap: onTap,
  //     child: Container(
  //       height: 44,
  //       decoration: BoxDecoration(
  //         color: isSelected
  //             ? (theme.isDarkMode ? colors.colorWhite : colors.colorBlack)
  //             : (theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8)),
  //         borderRadius: BorderRadius.circular(22),
  //         border: Border.all(
  //           color: isSelected
  //               ? (theme.isDarkMode ? colors.colorWhite : colors.colorBlack)
  //               : (theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8)),
  //           width: 1,
  //         ),
  //       ),
  //       child: Center(
  //         child: TextWidget.subText(
  //           text: label,
  //           theme: theme.isDarkMode,
  //           color: isSelected
  //               ? (theme.isDarkMode ? colors.colorBlack : colors.colorWhite)
  //               : (theme.isDarkMode ? colors.colorWhite : colors.colorBlack),
  //           fw: isSelected ? 2 : 1,
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildSegmentTab(
      String label, bool isSelected, VoidCallback onTap, ThemesProvider theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xffF1F3F8) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: TextWidget.paraText(
              text: label,
              theme: false,
              color: isSelected
                  ? (theme.isDarkMode
                      ? colors.textPrimaryDark
                      : colors.textPrimaryLight)
                  : const Color(0XFF777777),
              fw: isSelected ? 0 : null,
            ),
          ),
        ),
      ),
    );
  }

  void _selectSegment(String segmentCode, TranctionProvider fund) {
    if (fund.decryptclientcheck?.companyCode != null) {
      final index = fund.decryptclientcheck!.companyCode!.indexOf(segmentCode);
      fund.segmentselection(index);
    }
  }

  static const _segmentGroups = [
  {'label': 'Equity',    'codes': ['NSE_CASH', 'BSE_CASH']},
  {'label': 'F&O',       'codes': ['NSE_FNO', 'BSE_FNO']},
  {'label': 'Currency',  'codes': ['CD_NSE', 'CD_BSE']},
  {'label': 'Commodity', 'codes': ['MCX', 'NSE_COM', 'BSE_COM']},
];

  Widget _buildSegmentInactiveBanner(BuildContext context) {
    final borderColor = resolveThemeColor(
      context,
      dark: const Color(0xFFFFB74D),
      light: const Color(0xFFFFA726),
    );
    final textColor = resolveThemeColor(
      context,
      dark: MyntColors.textPrimaryDark,
      light: MyntColors.textPrimary,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA726).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: borderColor),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: textColor,
                ),
                children: [
                  const TextSpan(text: "Activate the "),
                  TextSpan(
                    text: "Segments",
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      color: borderColor,
                      fontWeight: MyntFonts.semiBold,
                    ),
                  ),
                  const TextSpan(
                     text: " on this account to add funds.",)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _availableSegments(TranctionProvider fund) {
    final codes = fund.companycodes;
    final available = <Map<String, String>>[];
    for (final group in _segmentGroups) {
      final groupCodes = group['codes'] as List<String>;
      final match = groupCodes.firstWhere(
        (c) => codes.contains(c),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        available.add({'label': group['label'] as String, 'code': match});
      }
    }
    return available;
  }

  bool _hasTradableSegments(TranctionProvider fund) =>
      fund.hasActiveSegments && _availableSegments(fund).isNotEmpty;

  Widget _buildSegmentSelector(TranctionProvider fund, BuildContext context) {
    final available = _availableSegments(fund);

    if (available.isEmpty) {
      return Text(
        "You have no active segments.",
        style: MyntWebTextStyles.bodySmall(
          context,
          color: resolveThemeColor(
            context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: available.map((seg) {
        final isSelected = fund.textValue == seg['code'];
        return ChoiceChip(
          label: Text(seg['label']!),
          selected: isSelected,
          onSelected: (_) => _selectSegment(seg['code']!, fund),
          labelStyle: MyntWebTextStyles.bodySmall(
            context,
            color: isSelected
                ? resolveThemeColor(context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary)
                : resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
            fontWeight: MyntFonts.medium,
          ),
          selectedColor: resolveThemeColor(
            context,
            dark: MyntColors.primaryDark.withValues(alpha: 0.1),
            light: MyntColors.primary.withValues(alpha: 0.1),
          ),
          backgroundColor: resolveThemeColor(
            context,
            dark: MyntColors.cardDark,
            light: MyntColors.inputBg,
          ),
          side: BorderSide(
            color: isSelected
                ? resolveThemeColor(context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary)
                : resolveThemeColor(context,
                    dark: MyntColors.cardBorderDark,
                    light: MyntColors.cardBorder),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildGatewaySelector(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(tooltip: "",
        onSelected: (value) {
          setState(() {
            _selectedGateway = value;
          });
        },
        offset: const Offset(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
        itemBuilder: (context) => [
          _buildGatewayMenuItem(
            context,
            value: 'RAZORPAY',
            label: 'Razorpay',
            logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/8/89/Razorpay_logo.svg',
            isSelected: _selectedGateway == 'RAZORPAY',
          ),
          // _buildGatewayMenuItem(
          //   context,
          //   value: 'ATOM',
          //   label: 'Atom',
          //   logoUrl: null,
          //   isSelected: _selectedGateway == 'ATOM',
          // ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: resolveThemeColor(context,
                  dark: MyntColors.cardBorderDark,
                  light: MyntColors.cardBorder),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Gateway : ",
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ),
              Text(
                _selectedGateway == 'RAZORPAY' ? 'Razorpay' : 'Atom',
                style: MyntWebTextStyles.bodySmall(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  color: resolveThemeColor(context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuEntry<String> _buildGatewayMenuItem(
    BuildContext context, {
    required String value,
    required String label,
    required bool isSelected,
    String? logoUrl,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? resolveThemeColor(context,
                      dark: MyntColors.transparent,
                      light: MyntColors.transparent)
                  
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight:
                      isSelected ? MyntFonts.semiBold : MyntFonts.semiBold,
                 color: isSelected ? resolveThemeColor(context,
                       dark: MyntColors.primaryDark,
                    light: MyntColors.primary) : resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                size: 18,
                color: resolveThemeColor(context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required TranctionProvider fund,
    required dynamic theme,
    required int index,
    required Widget icon,
    required String title,
    required String maxLimit,
    required List<String> badges,
    required bool isDisabled,
  }) {
    final bool isSelected = _selectedPaymentMethod == index;
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: isDisabled
            ? null
            : () {
                setState(() {
                  _selectedPaymentMethod = isSelected ? -1 : index;
                  // Reset gateway to default when switching away from Net Banking
                  if (_selectedPaymentMethod != 2) {
                    _selectedGateway = 'RAZORPAY';
                  }
                });
              },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: resolveThemeColor(
              context,
              dark: MyntColors.cardDark,
              light: MyntColors.card,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? resolveThemeColor(context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary)
                  : resolveThemeColor(
                      context,
                      dark: MyntColors.cardBorderDark,
                      light: MyntColors.cardBorder,
                    ),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 32, height: 32, child: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: MyntWebTextStyles.body(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                            fontWeight: MyntFonts.semiBold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ...badges.map((badge) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badge == "recommended"
                                      ? const Color(0xFF4CAF50)
                                          .withValues(alpha: 0.1)
                                      : const Color(0xFF4CAF50)
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          "Max limit: $maxLimit",
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message:
                              "It depends on your bank account transaction limit.",
                          child: Icon(
                            Icons.info_outline,
                            size: 13,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.iconSecondaryDark,
                              light: MyntColors.iconSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isDisabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Not available for amount above ₹1,00,000",
                          style: MyntWebTextStyles.caption(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.errorDark,
                              light: MyntColors.error,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  size: 22,
                  color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPayPressed(BuildContext context, TranctionProvider fund) {
    if (!fund.hasActiveSegments) {
      warningMessage(context,
          "Activate the Segments on my account for fund adding.");
      return;
    }
    if (fund.textValue.isEmpty) {
      warningMessage(context, "Please select a segment to add money.");
      return;
    }
    if (fund.textValue == "MF_NSE" || fund.textValue == "MF_BSE") {
      warningMessage(context,
          "Fund addition is not supported for Mutual Fund segments.");
      return;
    }
    if (fund.amount.text.isEmpty || fund.intValue < 50) {
      warningMessage(context, "Min amount ₹50");
      return;
    }

    switch (_selectedPaymentMethod) {
      case 0: // Scan QR
        if (fund.intValue > 100000) {
          warningMessage(context,
              "UPI payments are not allowed for amounts above ₹1,00,000. Please use Net Banking.");
          return;
        }
        _handleScanQrPayment(context, fund);
        break;
      case 1: // UPI ID
        if (fund.intValue > 100000) {
          warningMessage(context,
              "UPI payments are not allowed for amounts above ₹1,00,000. Please use Net Banking.");
          return;
        }
        fund.upiidOnchange(fund.upiid.text);
        fund.validateUPI(fund.upiid.text);
        if (fund.upiiderror == null || fund.upiiderror!.isEmpty) {
          _handleUpiIdPayment(context, fund);
        }
        break;
      case 2: // Net Banking
        if (fund.intValue > 5000000) {
          warningMessage(context, "Max amount ₹50,00,000");
          return;
        }
        if (_selectedGateway == 'ATOM') {
          _handleAtomPayment(context, fund);
        } else {
          _handleRazorpayPayment(context, fund);
        }
        break;
    }
  }

  Widget _buildUpiIdCard(
      TranctionProvider fund, dynamic theme, BuildContext context) {
    final bool isDisabled = fund.intValue > 100000;
    final bool isSelected = _selectedPaymentMethod == 1;
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: isDisabled
            ? null
            : () {
                setState(() {
                  _selectedPaymentMethod = isSelected ? -1 : 1;
                });
              },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: resolveThemeColor(
              context,
              dark: MyntColors.cardDark,
              light: MyntColors.card,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? resolveThemeColor(context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary)
                  : resolveThemeColor(
                      context,
                      dark: MyntColors.cardBorderDark,
                      light: MyntColors.cardBorder,
                    ),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    SvgPicture.asset(assets.upiIcon, width: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Enter UPI ID",
                                style: MyntWebTextStyles.body(
                                  context,
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary,
                                  ),
                                  fontWeight: MyntFonts.semiBold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "free",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                "Max limit: ₹1,00,000",
                                style: MyntWebTextStyles.bodySmall(
                                  context,
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Tooltip(
                                message:
                                    "It depends on your bank account transaction limit.",
                                child: Icon(
                                  Icons.info_outline,
                                  size: 13,
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.iconSecondaryDark,
                                    light: MyntColors.iconSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        size: 22,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
                        ),
                      ),
                  ],
                ),
              ),

              // Expanded UPI ID form + Pay button inside the card
              if (isSelected && !isDisabled) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Divider(
                    height: 1,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.cardBorderDark,
                      light: MyntColors.cardBorder,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Column(
                    children: [
                      MyntTextField(
                        controller: fund.upiid,
                        placeholder: "Enter UPI ID (e.g. name@upi)",
                        inputFormatters: [
                          NoEmojiInputFormatter(),
                          FilteringTextInputFormatter.deny(
                              RegExp('[π£•₹€℅™∆√¶/,]')),
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        onChanged: (value) {
                          fund.upiidOnchange(value);
                          fund.validateUPI(value);
                        },
                      ),
                      if (fund.upiiderror != null &&
                          fund.upiiderror!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "${fund.upiiderror}",
                              style: MyntWebTextStyles.caption(
                                context,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.errorDark,
                                  light: MyntColors.error,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpiIdPaymentCard(
      TranctionProvider fund, dynamic theme, BuildContext context) {
    final bool isDisabled = fund.intValue > 100000;
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: theme.isDarkMode
              ? const Color(0xFF1E1E1E)
              : colors.colorWhite,
          borderRadius: BorderRadius.circular(12),
          border: _isUpiIdExpanded
              ? Border.all(color: colors.colorBlue, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
          child: Column(
            children: [
              // Header row
              InkWell(
                onTap: () {
                  if (isDisabled) {
                    warningMessage(context,
                        "UPI payments are not allowed for amounts above ₹1,00,000. Please use Net Banking.");
                    return;
                  }
                  setState(() {
                    _isUpiIdExpanded = !_isUpiIdExpanded;
                  });
                },
                borderRadius: _isUpiIdExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(8))
                    : BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      SvgPicture.asset(assets.upiIcon, width: 36),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                TextWidget.subText(
                                  text: "Enter UPI ID",
                                  theme: theme.isDarkMode,
                                  color: theme.isDarkMode
                                      ? colors.textPrimaryDark
                                      : colors.textPrimaryLight,
                                  fw: 1,
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "free",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4CAF50),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                TextWidget.captionText(
                                  text: "Max limit: ₹1,00,000",
                                  theme: false,
                                  color: theme.isDarkMode
                                      ? colors.textSecondaryDark
                                      : colors.textSecondaryLight,
                                  fw: 0,
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message:
                                      "It depends on your bank account transaction limit.",
                                  child: Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: theme.isDarkMode
                                        ? colors.textSecondaryDark
                                        : colors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                            if (isDisabled)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: TextWidget.captionText(
                                  text:
                                      "Not available for amount above ₹1,00,000",
                                  theme: false,
                                  color: theme.isDarkMode
                                      ? colors.lossDark
                                      : colors.lossLight,
                                  fw: 0,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (fund.amount.text.isNotEmpty)
                        TextWidget.subText(
                          text: "₹${fund.amount.text}",
                          theme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? colors.textPrimaryDark
                              : colors.textPrimaryLight,
                          fw: 1,
                        ),
                    ],
                  ),
                ),
              ),

              // Expandable UPI ID form
              if (_isUpiIdExpanded && !isDisabled)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: fund.upiid,
                        style: TextWidget.textStyle(
                          fontSize: 14,
                          color: theme.isDarkMode
                              ? colors.textPrimaryDark
                              : colors.textPrimaryLight,
                          theme: theme.isDarkMode,
                          fw: 0,
                        ),
                        inputFormatters: [
                          NoEmojiInputFormatter(),
                          FilteringTextInputFormatter.deny(
                              RegExp('[π£•₹€℅™∆√¶/,]')),
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        decoration: InputDecoration(
                          hintText: "Enter UPI ID",
                          hintStyle: TextWidget.textStyle(
                            fontSize: 14,
                            theme: false,
                            color: (theme.isDarkMode
                                    ? colors.textSecondaryDark
                                    : colors.textSecondaryLight)
                                .withValues(alpha: 0.4),
                            fw: 0,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: theme.isDarkMode
                                    ? colors.textSecondaryDark
                                        .withValues(alpha: 0.3)
                                    : const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: colors.colorBlue),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          fillColor: theme.isDarkMode
                              ? colors.darkGrey
                              : const Color(0xffF1F3F8),
                          filled: true,
                        ),
                        onChanged: (value) {
                          fund.upiidOnchange(value);
                          fund.validateUPI(value);
                        },
                      ),
                      if (fund.upiiderror != null &&
                          fund.upiiderror!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextWidget.captionText(
                              text: "${fund.upiiderror}",
                              theme: false,
                              color: theme.isDarkMode
                                  ? colors.lossDark
                                  : colors.lossLight,
                              fw: 0,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            minimumSize: const Size(0, 45),
                            backgroundColor: theme.isDarkMode
                                ? colors.primaryDark
                                : colors.primaryLight,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () async {
                            if (fund.amount.text.isEmpty ||
                                fund.intValue < 50) {
                              warningMessage(context, "Min amount ₹50");
                              return;
                            }
                            fund.upiidOnchange(fund.upiid.text);
                            fund.validateUPI(fund.upiid.text);
                            if (fund.upiiderror == null ||
                                fund.upiiderror!.isEmpty) {
                              await _handleUpiIdPayment(context, fund);
                            }
                          },
                          child: fund.fundLoading
                              ? SizedBox(
                                  width: 18,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.colorWhite,
                                  ),
                                )
                              : TextWidget.subText(
                                  text: "Pay via UPI ID",
                                  theme: false,
                                  color: colors.colorWhite,
                                  fw: 2,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
    );
  }

  _showBottomSheet(TranctionProvider fund, ThemesProvider theme) {
    showModalBottomSheet(
      enableDrag: false,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      backgroundColor: const Color(0xffffffff),
      context: context,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
              boxShadow: const [
                BoxShadow(
                    color: Color(0xff999999),
                    blurRadius: 4.0,
                    offset: Offset(2.0, 0.0))
              ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const CustomDragHandler(),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: TextWidget.subText(
                  text: 'Choose an Segment:',
                  theme: false,
                  color: colors.colorGrey,
                  fw: 0,
                ),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                itemCount: fund.decryptclientcheck!.companyCode!.length,
                itemBuilder: (BuildContext context, int index) {
                  return InkWell(
                    onTap: () {
                      fund.segmentselection(index);
                      Navigator.pop(context);
                    },
                    child: Container(
                      color: fund.decryptclientcheck!.companyCode![index] ==
                              fund.textValue
                          ? const Color(0xff999999).withOpacity(0.2)
                          : Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 15),
                        child: Row(
                          children: [
                            TextWidget.titleText(
                              text:
                                  fund.decryptclientcheck!.companyCode![index],
                              theme: theme.isDarkMode,
                              fw: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(
                height: 10,
              )
            ],
          ),
        );
      },
    );
  }

  // Set default segment to Equity (NSE_CASH) when screen initializes
  // void _setDefaultSegment(TranctionProvider fund) {
  //   if (fund.textValue.isEmpty || fund.textValue != "NSE_CASH") {
  //     _selectSegment("NSE_CASH", fund);
  //   }
  // }

  Widget headerTitleText(String text) {
    return TextWidget.subText(
        text: text, theme: false, color: colors.colorGrey, fw: 0);
  }

  Widget contantTitleText(String text) {
    return TextWidget.titleText(
      text: text,
      theme: false,
      fw: 1,
    );
  }

  final List<Map<String, dynamic>> upiApptest = [
    {
      'icon': assets.biggpay,
      'name': 'Google Pay',
      'url': 'gpay://',
      'value': '0'
    },
    {
      'icon': assets.bigphnpay,
      'name': 'PhonePe',
      'url': 'phonepe://',
      'value': '1'
    },
    {'icon': assets.bigpaytm, 'name': 'Paytm', 'url': 'paytm://', 'value': '2'},
  ];

  List<Map<String, dynamic>> availableApps = [];

  Future<void> checkIosAvailableApps() async {
    List<Map<String, dynamic>> tempList = [];

    for (var app in upiApptest) {
      bool isInstalled = await canLaunch(app['url']!);
      if (isInstalled) {
        tempList.add(app);
      }
    }
    if (!_isDisposedIos) {
      setState(() {
        availableApps = tempList;
      });
    }

    setState(() {
      availableApps = tempList;
    });
  }

  showBottomSheetbank(TranctionProvider fund, ThemesProvider theme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          backgroundColor: resolveThemeColor(
            context,
            dark: MyntColors.cardDark,
            light: MyntColors.card,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextWidget.titleText(
                        text: 'Select Bank',
                        theme: false,
                        color: theme.isDarkMode
                            ? colors.textPrimaryDark
                            : colors.textPrimaryLight,
                        fw: 1,
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: theme.isDarkMode
                              ? colors.textSecondaryDark
                              : colors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: theme.isDarkMode
                      ? MyntColors.cardBorderDark
                      : MyntColors.cardBorder,
                ),
                ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: fund.bankdetails!.dATA!.length,
                  itemBuilder: (BuildContext context, int index) {
                    final isSelected =
                        fund.bankdetails!.dATA![index][1] == fund.bankname;
                    return InkWell(
                      onTap: () {
                        fund.bankselection(index);
                        fund.setAccountslist(
                            fund.bankdetails!.dATA![index][2].toString());
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        color: isSelected
                            ? (theme.isDarkMode
                                ? MyntColors.primaryDark.withValues(alpha: 0.15)
                                : const Color(0xFFE8F0FE))
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextWidget.subText(
                                    text: '${fund.bankdetails!.dATA![index][1]}',
                                    color: theme.isDarkMode
                                        ? colors.textPrimaryDark
                                        : colors.textPrimaryLight,
                                    theme: theme.isDarkMode,
                                    fw: isSelected ? 1 : 0,
                                  ),
                                  const SizedBox(height: 2),
                                  TextWidget.paraText(
                                    text: hideAccountNumber(
                                        fund.bankdetails!.dATA![index][2]),
                                    color: theme.isDarkMode
                                        ? colors.textSecondaryDark
                                        : colors.textSecondaryLight,
                                    theme: theme.isDarkMode,
                                    fw: 0,
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: theme.isDarkMode
                                    ? MyntColors.primaryDark
                                    : MyntColors.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleWebPaymentError() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: RazorpayFailedUi(
            amount: ref.read(transcationProvider).amount.text,
            upiAddress: ref.read(transcationProvider).upiid.text,
            orderId: ref.read(transcationProvider).hdfcUPIStatus?.data?.orderNumber,
            upiTransactionId: ref.read(transcationProvider).hdfcUPIStatus?.data?.upiTransactionNo,
            statusDescription: ref.read(transcationProvider).hdfcUPIStatus?.data?.statusDescription,
            status: ref.read(transcationProvider).hdfcUPIStatus?.data?.status,
          ),
        ),
      ),
    ).then((_) {
      ref.read(fundProvider).fetchFunds(context);
    });
  }

  Future<void> _handleWebPaymentSuccess(String paymentId) async {
    final capturedAmount = ref.read(transcationProvider).amount.text;
    if (paymentId.isNotEmpty) {
      await ref.read(transcationProvider).fetchrazorpayStatus(paymentId);
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: NetBankingSuccessUi(amount: capturedAmount),
        ),
      ),
    ).then((_) {
      ref.read(fundProvider).fetchFunds(context);
    });
  }
}

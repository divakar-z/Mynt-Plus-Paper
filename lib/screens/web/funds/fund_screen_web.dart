import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/screens/Mobile/profile_screen/fund_screen/razorpay/razorpay_failed_ui.dart';
import 'package:mynt_plus/screens/Mobile/profile_screen/fund_screen/razorpay/razorpay_success_ui.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import '../../../sharedWidget/mynt_loader.dart';
import '../../../provider/privacy_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/transcation_provider.dart';
import '../../../provider/fund_provider.dart';
import '../../../provider/mf_provider.dart';
import '../../../sharedWidget/payment_loader.dart';
import '../../../res/res.dart';
import '../../../res/web_colors.dart';
import '../../../res/global_font_web.dart';
import '../../../sharedWidget/list_divider.dart';
import '../../../sharedWidget/fund_function.dart';
import '../../../sharedWidget/functions.dart';
import '../../../sharedWidget/cust_text_formfield.dart';
import '../../../utils/no_emoji_inputformatter.dart';


class FundScreenWeb extends ConsumerStatefulWidget {
  final TranctionProvider dd;
  
  const FundScreenWeb({super.key, required this.dd});

  @override
  ConsumerState<FundScreenWeb> createState() => _FundScreenWebState();
}

class _FundScreenWebState extends ConsumerState<FundScreenWeb> {
  List<Map<String, dynamic>> availableApps = [];
  bool _isDisposedIos = false;

  // Helper function to convert Dart function to JS callback
  // This replaces js_util.allowInterop which is not available in Wasm builds
  // Uses js.context to create a proper JavaScript function wrapper
  dynamic _allowInterop(Function callback) {
    // Create a JS function that calls the Dart callback
    final jsFunc = js.context.callMethod('eval', [
      '(function(cb) { return function() { return cb.apply(null, Array.prototype.slice.call(arguments)); }; })'
    ]);
    return jsFunc.callMethod('call', [js.context, callback]);
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

  @override
  void initState() {
    super.initState();
    ref.read(transcationProvider).initialdata(context);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      checkIosAvailableApps();
    }
  }

  @override
  void dispose() {
    _isDisposedIos = true;
    super.dispose();
  }

  Future<void> checkIosAvailableApps() async {
    List<Map<String, dynamic>> tempList = [];

    for (var app in upiApptest) {
      bool isInstalled = await canLaunch(app['url']!);
      if (isInstalled) {
        tempList.add(app);
      }
    }
    
    if (!_isDisposedIos && mounted) {
      setState(() {
        availableApps = tempList;
      });
    }
  }

  Future<void> _handleAndroidUpiPayment(
      BuildContext context, TranctionProvider fund) async {
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
      TranctionProvider fund, dynamic theme) async {
    fund.resetBottomSheetState();
    if (availableApps.isEmpty) {
      // Show no UPI apps available message
      showResponsiveWarningMessage(context, "No UPI apps available");
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
      // Show UPI apps selection
      showResponsiveWarningMessage(context, "Please complete payment in UPI app");
    }
  }

  _showUpiIdForm(BuildContext context, TranctionProvider fund, dynamic theme,
      dynamic colors) {
    // Don't reset loading here - let the button handle it
    fund.clearerror();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor:
              theme.isDarkMode ? WebDarkColors.surface : WebColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.isDarkMode
                            ? WebDarkColors.divider
                            : WebColors.divider,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'UPI ID',
                        style: WebTextStyles.dialogTitle(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textPrimary
                              : WebColors.textPrimary,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          splashColor: theme.isDarkMode
                              ? Colors.white.withOpacity(.15)
                              : Colors.black.withOpacity(.15),
                          highlightColor: theme.isDarkMode
                              ? Colors.white.withOpacity(.08)
                              : Colors.black.withOpacity(.08),
                          onTap: () => Navigator.of(context).pop(),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: theme.isDarkMode
                                  ? WebDarkColors.iconSecondary
                                  : WebColors.iconSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 16, top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 40,
                            child: CustomTextFormField(
                              fillColor: theme.isDarkMode
                                  ? WebDarkColors.backgroundTertiary
                                  : WebColors.backgroundTertiary,
                              onChanged: (value) {
                                fund.upiidOnchange(value);
                                fund.validateUPI(value);
                              },
                              hintText: "Enter UPI ID",
                              hintStyle: WebTextStyles.formInput(
                                isDarkTheme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? WebDarkColors.textSecondary
                                    : WebColors.textSecondary,
                              ),
                              keyboardType: TextInputType.text,
                              style: WebTextStyles.formInput(
                                isDarkTheme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? WebDarkColors.textPrimary
                                    : WebColors.textPrimary,
                              ),
                              textCtrl: fund.upiid,
                              textAlign: TextAlign.start,
                              autofocus: true,
                              inputFormate: [
                                NoEmojiInputFormatter(),
                                FilteringTextInputFormatter.deny(RegExp('[π£•₹€℅™∆√¶/,]')),
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                            ),
                          ),
                          if (fund.upiiderror != null && fund.upiiderror!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                "${fund.upiiderror}",
                                style: WebTextStyles.helperText(
                                  isDarkTheme: theme.isDarkMode,
                                  color: theme.isDarkMode
                                      ? WebDarkColors.error
                                      : WebColors.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: Consumer(
                              builder: (context, ref, child) {
                                final fundState = ref.watch(transcationProvider);
                                return Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: theme.isDarkMode
                                        ? WebDarkColors.primary
                                        : WebColors.primary,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(5),
                                      splashColor: Colors.white.withOpacity(0.2),
                                      highlightColor: Colors.white.withOpacity(0.1),
                                      onTap: fundState.fundLoading ? null : () async {
                                        fund.upiidOnchange(fund.upiid.text);
                                        fund.validateUPI(fund.upiid.text);
                                        if (fund.upiiderror == null || fund.upiiderror!.isEmpty) {
                                          // Set loading immediately
                                          fund.togglefundLoading(true);
                                          await _handleUpiIdPayment(context, fund);
                                        }
                                      },
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: fundState.fundLoading
                                            ? MyntLoader.inline(
                                                color: Colors.white,
                                                strokeWidth: 2.0,
                                              )
                                            : Text(
                                                "Pay Via UPI ID",
                                                style: WebTextStyles.buttonMd(
                                                  isDarkTheme: theme.isDarkMode,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                );
                              },
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
        );
      },
    ).then((_) {
      fund.togglefundLoading(false);
    });
  }

  Future<void> _handleUpiIdPayment(
      BuildContext context, TranctionProvider fund) async {
    fund.resetBottomSheetState();
    fund.togglefundLoading(true); // Show loader in button

    try {
      await fund.fetcUPIIDPayment(
          context,
          fund.upiid.text,
          fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][0],
          fund.bankdetails!.dATA![fund.indexss][2]);

      if (fund.upiiderror != null && fund.upiiderror!.isNotEmpty) {
        fund.togglefundLoading(false); // Hide loader on error
        return;
      }
      
      await fund.fetchHdfctranction(
        context,
        fund.upiid.text,
        int.parse(fund.amount.text),
        fund.accno,
        fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][0],
      );

      if (fund.hdfcpaymentdata!.data!.verifiedVPAStatus1 == "Available" ||
          fund.hdfcpaymentdata!.data!.verifiedVPAStatus2 == "Available") {
        fund.togglefundLoading(false); // Hide loader before showing awaiting dialog
        Navigator.pop(context);
        fund.focusNode.unfocus();

        final currentTheme = ref.read(themeProvider);
        final currentColors = colors;

        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.transparent,
          builder: (BuildContext context) {
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
              },
              child: _buildWebUpiConfirmationDialog(context, fund, currentTheme, currentColors),
            );
          },
        );

        await fund.fetchHdfcpaymetstatus(
            context,
            '${fund.hdfctranction!.data!.orderNumber}',
            '${fund.hdfctranction!.data!.upiTransactionNo}');
      } else {
        fund.togglefundLoading(false); // Hide loader if VPA not available
      }
    } catch (e) {
      fund.togglefundLoading(false);
      rethrow;
    }
  }

  Widget _buildWebUpiConfirmationDialog(
      BuildContext context, TranctionProvider fund, dynamic theme, dynamic colors) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: _WebUpiConfirmationDialogContent(
        fund: fund,
        theme: theme,
        colors: colors,
        onStatusChanged: (BuildContext dialogContext) {
          // Show result dialog when status changes
          showDialog(
            context: dialogContext,
            barrierDismissible: false,
            barrierColor: Colors.transparent,
            builder: (BuildContext context) {
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                },
                child: _buildWebUpiResultDialog(context, fund, theme, colors),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWebUpiResultDialog(
      BuildContext context, TranctionProvider fund, dynamic theme, dynamic colors) {
    final isSuccess = fund.hdfcpaymentstatus?.upiId?.status == "SUCCESS";
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: theme.isDarkMode ? WebDarkColors.surface : WebColors.surface,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.isDarkMode
                        ? WebDarkColors.divider
                        : WebColors.divider,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isSuccess ? 'Transaction Success' : 'Transaction Failed',
                    style: WebTextStyles.dialogTitle(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? WebDarkColors.textPrimary
                          : WebColors.textPrimary,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      splashColor: theme.isDarkMode
                          ? Colors.white.withOpacity(.15)
                          : Colors.black.withOpacity(.15),
                      highlightColor: theme.isDarkMode
                          ? Colors.white.withOpacity(.08)
                          : Colors.black.withOpacity(.08),
                      onTap: () {
                        fund.amount.clear();
                        Navigator.pop(context);
                        fund.focusNode.unfocus();
                        ref.read(mfProvider).IsPaymentCalled(false);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: theme.isDarkMode
                              ? WebDarkColors.iconSecondary
                              : WebColors.iconSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, bottom: 16, top: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Status Icon
                      Icon(
                        isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isSuccess
                            ? (theme.isDarkMode ? WebDarkColors.profit : WebColors.profit)
                            : (theme.isDarkMode ? WebDarkColors.error : WebColors.error),
                        size: 70,
                      ),
                      const SizedBox(height: 16),
                      // Status Text
                      Text(
                        fund.hdfcpaymentstatus?.upiId?.status ?? '',
                        style: WebTextStyles.title(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textPrimary
                              : WebColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Status Description
                      Text(
                        isSuccess ? "Transaction Success" : "Transaction fail",
                        style: WebTextStyles.sub(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textSecondary
                              : WebColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Amount
                      Text(
                        "₹${fund.hdfcpaymentstatus?.upiId?.amount ?? '0.00'}",
                        style: WebTextStyles.hero(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textPrimary
                              : WebColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Date/Time
                      if (fund.hdfcpaymentstatus?.upiId?.transactionAuthDate != null)
                        Text(
                          formatDateTimepaymet(
                            value: "${fund.hdfcpaymentstatus!.upiId!.transactionAuthDate}",
                          ),
                          style: WebTextStyles.sub(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? WebDarkColors.textSecondary
                                : WebColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Transaction Details
                      if (fund.hdfcpaymentstatus?.upiId?.clientVPA != null)
                        _buildDetailRow(
                          "UPI Address",
                          "${fund.hdfcpaymentstatus!.upiId!.clientVPA}",
                          theme,
                          colors,
                        ),
                      if (fund.hdfcpaymentstatus?.upiId?.orderNumber != null)
                        _buildDetailRow(
                          "Order ID",
                          "${fund.hdfcpaymentstatus!.upiId!.orderNumber}",
                          theme,
                          colors,
                        ),
                      if (fund.hdfcpaymentstatus?.upiId?.upiTransactionNo != null)
                        _buildDetailRow(
                          "UPI Transaction ID",
                          "${fund.hdfcpaymentstatus!.upiId!.upiTransactionNo}",
                          theme,
                          colors,
                        ),
                      if (fund.hdfcpaymentstatus?.upiId?.statusDescription != null)
                        _buildDetailRow(
                          "Status Description",
                          "${fund.hdfcpaymentstatus!.upiId!.statusDescription}",
                          theme,
                          colors,
                        ),
                      const SizedBox(height: 24),
                      // Done Button
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.isDarkMode
                                ? WebDarkColors.primary
                                : WebColors.primary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(5),
                              splashColor: Colors.white.withOpacity(0.2),
                              highlightColor: Colors.white.withOpacity(0.1),
                              onTap: () {
                                fund.amount.clear();
                                Navigator.pop(context);
                                fund.focusNode.unfocus();
                                ref.read(mfProvider).IsPaymentCalled(false);
                              },
                              child: Container(
                                alignment: Alignment.center,
                                child: Text(
                                  "Done",
                                  style: WebTextStyles.buttonMd(
                                    isDarkTheme: theme.isDarkMode,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
    );
  }

  Widget _buildDetailRow(String label, String value, dynamic theme, dynamic colors) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: WebTextStyles.sub(
                isDarkTheme: theme.isDarkMode,
                color: theme.isDarkMode
                    ? WebDarkColors.textSecondary
                    : WebColors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                style: WebTextStyles.sub(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? WebDarkColors.textPrimary
                      : WebColors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(
          thickness: 0,
          color: theme.isDarkMode ? WebDarkColors.divider : WebColors.divider,
        ),
      ],
    );
  }

  Future<void> _handleRazorpayPayment(
      BuildContext context, TranctionProvider fund) async {
    try {
      fund.resetBottomSheetState();
      
      // Validate bank selection
      if (fund.accno.isEmpty || fund.bankname.isEmpty) {
        showResponsiveWarningMessage(context, "Please select a bank account first");
        return;
      }
      
      // On web, use Razorpay's JavaScript SDK directly
      if (kIsWeb) {
        // First, create the Razorpay order
        await fund.fetchrazorpay(
          context,
          int.parse(fund.amount.text).toString(),
          fund.accno,
          fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][2],
          fund.ifsc,
          Razorpay(), // Pass dummy instance, we won't use it
        );
        
        // Check if order was created
        if (fund.razorpay != null && fund.razorpay!.status == "created") {
          // Load Razorpay checkout script if not already loaded
          _loadRazorpayScript();
          
          // Wait a bit for script to load
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Open Razorpay checkout using JavaScript
          _openRazorpayCheckoutWeb(fund);
        } else {
          showResponsiveWarningMessage(context, "Failed to create payment order");
          fund.togglefundLoading(false);
        }
      } else {
        // Mobile: use standard Razorpay Flutter plugin
        Razorpay razorpay = Razorpay();
        razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentErrorResponse);
        razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccessResponse);
        
        await fund.fetchrazorpay(
          context,
          int.parse(fund.amount.text).toString(),
          fund.accno,
          fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][2],
          fund.ifsc,
          razorpay,
        );
      }
    } catch (e) {
      showResponsiveWarningMessage(context, "Error initiating Net Banking payment: ${e.toString()}");
      fund.togglefundLoading(false);
    }
  }

  void _loadRazorpayScript() {
    // Check if script is already loaded
    final existingScript = html.document.querySelector('script[src="https://checkout.razorpay.com/v1/checkout.js"]');
    if (existingScript != null) {
      return; // Script already loaded
    }
    
    // Create and add the Razorpay checkout script
    final script = html.ScriptElement()
      ..src = 'https://checkout.razorpay.com/v1/checkout.js'
      ..type = 'text/javascript';
    html.document.head!.append(script);
  }

  void _openRazorpayCheckoutWeb(TranctionProvider fund) {
    try {
      // Store fund reference for callback
      final fundRef = fund;
      final contextRef = context;
      final amountText = fund.amount.text;
      
      // Track if payment was manually cancelled to prevent error dialog
      final isCancelledRef = <bool>[false];
      // Track if dialog is already shown to prevent duplicates
      final dialogShownRef = <bool>[false];
      
      // Create JavaScript callback functions
      final handler = _allowInterop((dynamic response) async {
        // Payment success callback
        // Note: Razorpay modal closes automatically on success
        final responseMap = Map<String, dynamic>.from(response as Map);
        final paymentId = responseMap['razorpay_payment_id']?.toString() ?? '';
        if (paymentId.isNotEmpty) {
          // Await status fetch so razorpayTranstationRes is populated before dialog builds
          await fundRef.fetchrazorpayStatus(paymentId);
 // Show success dialog immediately after fetching status
          if (mounted) {
            final currentTheme = ref.read(themeProvider);
            final currentColors = colors;
            showDialog(
              context: contextRef,
              barrierDismissible: false,
              barrierColor: Colors.transparent,
              builder: (context) {
                return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop) return;
                  },
                  child: _buildWebRazorpaySuccessDialog(
                    contextRef,
                    fundRef,
                    currentTheme,
                    currentColors,
                    amountText,
                  ),
                );
              },
            );
            fundRef.amount.clear();
          }
        }
      });
      
      final onDismiss = _allowInterop(() {
        // Payment cancelled manually by user - Razorpay modal will close automatically
        isCancelledRef[0] = true; // Mark as manually cancelled
        fundRef.togglefundLoading(false);
        
        // Prevent duplicate dialogs
        if (dialogShownRef[0]) return;
        dialogShownRef[0] = true;
        
        // Show cancelled dialog immediately (no delay)
        if (mounted) {
          final currentTheme = ref.read(themeProvider);
          final currentColors = colors;
          showDialog(
            context: contextRef,
            barrierDismissible: false,
            barrierColor: Colors.transparent,
            builder: (context) {
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                },
                child: _buildWebRazorpayFailedDialog(
                  contextRef,
                  fundRef,
                  currentTheme,
                  currentColors,
                  amountText,
                  isCancelled: true, // Mark as manually cancelled
                ),
              );
            },
          );
        }
      });
      
      final errorHandler = _allowInterop((dynamic error) {
        // Payment error callback
        // Don't show error dialog if user manually cancelled (onDismiss already handled it)
        if (isCancelledRef[0]) {
          return; // User manually closed, don't show error dialog
        }
        
        // Check if this is a manual cancellation (user closed the modal)
        // When user manually closes Razorpay, error might be null, empty, or have specific codes
        bool isManualCancel = false;
        
        // If error is null or empty, treat as manual cancellation
        if (error == null) {
          isManualCancel = true;
        } else {
          try {
            final errorMap = Map<String, dynamic>.from(error as Map);
            final errorCode = errorMap['code']?.toString() ?? '';
            final errorDescription = errorMap['description']?.toString() ?? '';
            final errorReason = errorMap['reason']?.toString() ?? '';
            
            // Check if it's a cancellation - when user manually closes, Razorpay often sends:
            // - Empty error code
            // - Specific cancellation codes
            // - Description/reason containing cancel/dismiss/closed
            if (errorCode.isEmpty || 
                errorCode.contains('CANCEL') || 
                errorCode.contains('USER_CANCELLED') ||
                errorCode.contains('DISMISS') ||
                errorDescription.toLowerCase().contains('cancel') ||
                errorReason.toLowerCase().contains('cancel') ||
                errorDescription.toLowerCase().contains('dismiss') ||
                errorReason.toLowerCase().contains('dismiss') ||
                errorDescription.toLowerCase().contains('closed') ||
                errorDescription.toLowerCase().contains('user closed')) {
              isManualCancel = true;
            }
          } catch (e) {
            // If we can't parse the error, treat as manual cancellation to be safe
            isManualCancel = true;
          }
        }
        
        // If manually cancelled, show "Close" dialog
        if (isManualCancel) {
          isCancelledRef[0] = true; // Mark as cancelled
          fundRef.togglefundLoading(false);
          
          // Prevent duplicate dialogs
          if (dialogShownRef[0]) return;
          dialogShownRef[0] = true;
          
          // Show cancelled dialog immediately
          if (mounted) {
            final currentTheme = ref.read(themeProvider);
            final currentColors = colors;
            showDialog(
              context: contextRef,
              barrierDismissible: false,
              barrierColor: Colors.transparent,
              builder: (context) {
                return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop) return;
                  },
                  child: _buildWebRazorpayFailedDialog(
                    contextRef,
                    fundRef,
                    currentTheme,
                    currentColors,
                    amountText,
                    isCancelled: true, // Mark as manually cancelled
                  ),
                );
              },
            );
          }
          return;
        }
        
        // Actual payment failure - show "Try Again" dialog
        fundRef.togglefundLoading(false);
        
        // Extract error reason from error object
        String? extractedErrorReason;
        if (error != null) {
          try {
            // Razorpay error can be a Map or JsObject
            Map<String, dynamic> errorMap;
            if (error is Map) {
              errorMap = Map<String, dynamic>.from(error);
            } else {
              // Try to convert JsObject to Map
              final jsError = error as js.JsObject;
              errorMap = {
                'code': jsError['code']?.toString(),
                'description': jsError['description']?.toString(),
                'reason': jsError['reason']?.toString(),
                'source': jsError['source']?.toString(),
                'step': jsError['step']?.toString(),
                'metadata': jsError['metadata']?.toString(),
              };
            }
            
            // Try to get reason, description, or code
            extractedErrorReason = (errorMap['reason']?.toString() ?? '').trim().isNotEmpty 
                ? (errorMap['reason']?.toString() ?? '').trim()
                : (errorMap['description']?.toString() ?? '').trim().isNotEmpty
                    ? (errorMap['description']?.toString() ?? '').trim()
                    : (errorMap['code']?.toString() ?? '').trim().isNotEmpty
                        ? (errorMap['code']?.toString() ?? '').trim()
                        : null;
            
            // Log for debugging
            
            if (extractedErrorReason != null && extractedErrorReason.isEmpty) {
              extractedErrorReason = null;
            }
          } catch (e) {
            // Try to get string representation of error
            try {
              extractedErrorReason = error.toString();
            } catch (_) {}
          }
        }
        
        // Prevent duplicate dialogs
        if (dialogShownRef[0]) return;
        dialogShownRef[0] = true;
        
        // Show error dialog immediately (no delay)
        if (mounted && !isCancelledRef[0]) { // Double check it wasn't cancelled
          final currentTheme = ref.read(themeProvider);
          final currentColors = colors;
          showDialog(
            context: contextRef,
            barrierDismissible: false,
            barrierColor: Colors.transparent,
            builder: (context) {
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                },
                child: _buildWebRazorpayFailedDialog(
                  contextRef,
                  fundRef,
                  currentTheme,
                  currentColors,
                  amountText,
                  isCancelled: false, // Mark as actual failure
                  errorReason: extractedErrorReason, // Pass error reason
                ),
              );
            },
          );
        }
      });
      
      // Prepare options for Razorpay checkout
      final options = js.JsObject.jsify({
        'key': 'rzp_live_M3tazzVCcFf8Iq',
        'amount': int.parse("${fund.razorpay!.amount}").toString(),
        'currency': 'INR',
        'name': 'Zebu Fund',
        'description': "Fund add to ${fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][0]}",
        'order_id': fund.razorpay!.id,
        'prefill': {
          'name': fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][2],
          'email': fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][4],
          'contact': fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][5],
        },
        'method': 'netbanking',
        'bank': fund.bankname,
        'notes': {
          'clientcode': "${fund.decryptclientcheck!.clientCheck!.dATA![fund.indexss][0]}",
          'acc_no': fund.accno,
          'ifsc': fund.ifsc,
          'bankname': fund.bankname,
          'company_code': fund.textValue,
        },
        'theme': {
          'color': '#3399cc',
        },
        'handler': handler,
        'modal': {
          'ondismiss': onDismiss,
        }
      });
      
      // Callback for payment cancelled event
      final cancelledHandler = _allowInterop((dynamic response) {
        // Payment cancelled by user
        isCancelledRef[0] = true;
        fundRef.togglefundLoading(false);
        
        // Prevent duplicate dialogs
        if (dialogShownRef[0]) return;
        dialogShownRef[0] = true;
        
        // Show cancelled dialog immediately (no delay)
        if (mounted) {
          final currentTheme = ref.read(themeProvider);
          final currentColors = colors;
          showDialog(
            context: contextRef,
            barrierDismissible: false,
            barrierColor: Colors.transparent,
            builder: (context) {
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                },
                child: _buildWebRazorpayFailedDialog(
                  contextRef,
                  fundRef,
                  currentTheme,
                  currentColors,
                  amountText,
                  isCancelled: true, // Mark as manually cancelled
                ),
              );
            },
          );
        }
      });
      
      // Call Razorpay checkout using JavaScript
      final razorpayConstructor = js.context['Razorpay'];
      if (razorpayConstructor != null) {
        final checkoutInstance = js.JsObject(razorpayConstructor, [options]);
        
        // Set up error handler
        checkoutInstance.callMethod('on', ['payment.failed', errorHandler]);
        
        // Also listen for payment cancelled event (if available)
        try {
          checkoutInstance.callMethod('on', ['payment.cancelled', cancelledHandler]);
        } catch (e) {
          // payment.cancelled might not be available in all Razorpay versions
        }
        
        // Open checkout
        checkoutInstance.callMethod('open');
      } else {
        // Retry after a delay if Razorpay is not loaded yet
        Future.delayed(const Duration(seconds: 1), () {
          _openRazorpayCheckoutWeb(fund);
        });
      }
    } catch (e) {
      showResponsiveWarningMessage(context, "Error opening payment gateway: ${e.toString()}");
      fund.togglefundLoading(false);
    }
  }

  void handlePaymentErrorResponse(PaymentFailureResponse response) {
    // This is for mobile only - web uses JavaScript callbacks
    if (!kIsWeb) {
      final fund = ref.read(transcationProvider);
      showDialog(
        context: context,
        builder: (context) => RazorpayFailedUi(
          acco: widget.dd.accno,
          ifsc: widget.dd.ifsc,
          amount: fund.amount.text,
          bankname: widget.dd.bankname
        ),
      );
    }
  }

  void handlePaymentSuccessResponse(PaymentSuccessResponse response) {
    // This is for mobile only - web uses JavaScript callbacks
    if (!kIsWeb) {
      final fund = ref.read(transcationProvider);
      fund.fetchrazorpayStatus("${response.paymentId}");
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => RazorpaySuccessUi(amount: fund.amount.text),
      );
      fund.amount.clear();
    }
  }

  // Web-specific Razorpay Success Dialog
  Widget _buildWebRazorpaySuccessDialog(
    BuildContext context,
    TranctionProvider fund,
    dynamic theme,
    dynamic colors,
    String amountText,
  ) {
    final transactionRes = fund.razorpayTranstationRes;
    final amount = transactionRes?.amount != null 
        ? (transactionRes!.amount! / 100).toStringAsFixed(2) 
        : amountText;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: theme.isDarkMode ? WebDarkColors.surface : WebColors.surface,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.isDarkMode
                        ? WebDarkColors.divider
                        : WebColors.divider,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaction Success',
                    style: WebTextStyles.dialogTitle(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? WebDarkColors.textPrimary
                          : WebColors.textPrimary,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      splashColor: theme.isDarkMode
                          ? Colors.white.withOpacity(.15)
                          : Colors.black.withOpacity(.15),
                      highlightColor: theme.isDarkMode
                          ? Colors.white.withOpacity(.08)
                          : Colors.black.withOpacity(.08),
                      onTap: () {
                        fund.amount.clear();
                        Navigator.pop(context);
                        fund.focusNode.unfocus();
                        ref.read(mfProvider).IsPaymentCalled(false);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: theme.isDarkMode
                              ? WebDarkColors.iconSecondary
                              : WebColors.iconSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, bottom: 16, top: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: theme.isDarkMode ? WebDarkColors.profit : WebColors.profit,
                        size: 70,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "SUCCESS",
                        style: WebTextStyles.title(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textPrimary
                              : WebColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Transaction Success",
                        style: WebTextStyles.sub(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textSecondary
                              : WebColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "₹$amount",
                        style: WebTextStyles.hero(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textPrimary
                              : WebColors.textPrimary,
                        ),
                      ),
                      if (transactionRes?.createdAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('EEE MMM dd yyyy HH:mm:ss').format(
                              DateTime.fromMillisecondsSinceEpoch(transactionRes!.createdAt! * 1000),
                            ),
                            style: WebTextStyles.sub(
                              isDarkTheme: theme.isDarkMode,
                              color: theme.isDarkMode
                                  ? WebDarkColors.textSecondary
                                  : WebColors.textSecondary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (transactionRes?.method == "netbanking") ...[
                        if (transactionRes?.notes?.bankname != null && transactionRes!.notes!.bankname!.isNotEmpty)
                          _buildDetailRow("Bank Name", transactionRes.notes!.bankname!, theme, colors),
                        if (transactionRes?.notes?.accNo != null && transactionRes!.notes!.accNo!.isNotEmpty)
                          _buildDetailRow("A/c No", transactionRes.notes!.accNo!, theme, colors),
                        if (transactionRes?.id != null)
                          _buildDetailRow("Payment ID", transactionRes!.id!, theme, colors),
                        if (transactionRes?.acquirerData?.bankTransactionId != null)
                          _buildDetailRow("Bank Transaction ID", transactionRes!.acquirerData!.bankTransactionId!, theme, colors),
                      ] else ...[
                        if (transactionRes?.id != null)
                          _buildDetailRow("Payment ID", transactionRes!.id!, theme, colors),
                        if (transactionRes?.orderId != null)
                          _buildDetailRow("Order ID", transactionRes!.orderId!, theme, colors),
                        if (transactionRes?.bank != null)
                          _buildDetailRow("Bank", transactionRes!.bank!, theme, colors),
                        if (transactionRes?.method != null)
                          _buildDetailRow("Payment Method", transactionRes!.method!.toUpperCase(), theme, colors),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.isDarkMode
                                ? WebDarkColors.primary
                                : WebColors.primary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(5),
                              splashColor: Colors.white.withOpacity(0.2),
                              highlightColor: Colors.white.withOpacity(0.1),
                              onTap: () {
                                fund.amount.clear();
                                Navigator.pop(context);
                                fund.focusNode.unfocus();
                                ref.read(mfProvider).IsPaymentCalled(false);
                              },
                              child: Container(
                                alignment: Alignment.center,
                                child: Text(
                                  "Done",
                                  style: WebTextStyles.buttonMd(
                                    isDarkTheme: theme.isDarkMode,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
    );
  }

  // Web-specific Razorpay Failed Dialog
  Widget _buildWebRazorpayFailedDialog(
    BuildContext context,
    TranctionProvider fund,
    dynamic theme,
    dynamic colors,
    String amountText, {
    bool isCancelled = false, // Flag to indicate if manually cancelled
    String? errorReason, // Error reason to display
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: theme.isDarkMode ? WebDarkColors.surface : WebColors.surface,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.isDarkMode
                        ? WebDarkColors.divider
                        : WebColors.divider,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isCancelled ? 'Payment Cancelled' : 'Transaction Failed',
                    style: WebTextStyles.dialogTitle(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? WebDarkColors.textPrimary
                          : WebColors.textPrimary,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      splashColor: theme.isDarkMode
                          ? Colors.white.withOpacity(.15)
                          : Colors.black.withOpacity(.15),
                      highlightColor: theme.isDarkMode
                          ? Colors.white.withOpacity(.08)
                          : Colors.black.withOpacity(.08),
                      onTap: () {
                        Navigator.pop(context);
                        fund.focusNode.unfocus();
                        if (isCancelled) {
                          fund.amount.clear();
                          ref.read(mfProvider).IsPaymentCalled(false);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: theme.isDarkMode
                              ? WebDarkColors.iconSecondary
                              : WebColors.iconSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, bottom: 16, top: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cancel_rounded,
                        color: theme.isDarkMode ? WebDarkColors.error : WebColors.error,
                        size: 70,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isCancelled ? "CANCELLED" : "FAILED",
                        style: WebTextStyles.title(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textPrimary
                              : WebColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isCancelled ? "Payment Cancelled" : "Transaction Failed",
                        style: WebTextStyles.sub(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textSecondary
                              : WebColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "₹$amountText",
                        style: WebTextStyles.hero(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textPrimary
                              : WebColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (fund.accno.isNotEmpty)
                        _buildDetailRow("Account Number", fund.accno, theme, colors),
                      if (fund.ifsc.isNotEmpty)
                        _buildDetailRow("IFSC", fund.ifsc, theme, colors),
                      if (fund.bankname.isNotEmpty)
                        _buildDetailRow("Bank Name", fund.bankname, theme, colors),
                      if (errorReason != null && errorReason.isNotEmpty && !isCancelled)
                        _buildDetailRow("Reason", errorReason, theme, colors),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.isDarkMode
                                ? WebDarkColors.primary
                                : WebColors.primary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(5),
                              splashColor: Colors.white.withOpacity(0.2),
                              highlightColor: Colors.white.withOpacity(0.1),
                              onTap: () {
                                Navigator.pop(context);
                                fund.focusNode.unfocus();
                                
                                if (isCancelled) {
                                  // Close button - just close the dialog and reset state
                                  fund.amount.clear();
                                  ref.read(mfProvider).IsPaymentCalled(false);
                                } else {
                                  // Try Again button - retry the payment
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    _handleRazorpayPayment(context, fund);
                                  });
                                }
                              },
                              child: Container(
                                alignment: Alignment.center,
                                child: Text(
                                  isCancelled ? "Close" : "Try Again",
                                  style: WebTextStyles.buttonMd(
                                    isDarkTheme: theme.isDarkMode,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
    );
  }

  String formatIndianCurrency(String amount) {
    final formatter = NumberFormat.currency(
      locale: "en_IN",
      symbol: '',
      decimalDigits: 2,
    );
    return formatter.format(double.tryParse(amount) ?? 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final fund = ref.watch(transcationProvider);
    final funds = ref.watch(fundProvider);
    final colors = theme.isDarkMode ? WebDarkColors : WebColors;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.3,
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.isDarkMode ? WebDarkColors.surface : WebColors.surface,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(theme),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Available Amount
                    _buildAvailableAmountSection(funds, theme),
                    const SizedBox(height: 16),
                    
                    // Amount Input
                    _buildAmountInput(fund, theme),
                    const SizedBox(height: 8),
                    
                    // Error Messages
                    _buildErrorMessage(fund, theme),
                    const SizedBox(height: 16),
                    
                    // Bank Selection
                    _buildBankSelection(fund, theme),
                    const SizedBox(height: 16),
                    
                    // Payment Method
                    _buildPaymentMethods(fund, theme, colors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemesProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.isDarkMode ? WebDarkColors.divider : WebColors.divider,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Add Money',
            style: WebTextStyles.dialogTitle(
              isDarkTheme: theme.isDarkMode,
              color: theme.isDarkMode
                  ? WebDarkColors.textPrimary
                  : WebColors.textPrimary,
            ),
          ),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              splashColor: theme.isDarkMode
                  ? Colors.white.withOpacity(.15)
                  : Colors.black.withOpacity(.15),
              highlightColor: theme.isDarkMode
                  ? Colors.white.withOpacity(.08)
                  : Colors.black.withOpacity(.08),
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: theme.isDarkMode
                      ? WebDarkColors.iconSecondary
                      : WebColors.iconSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableAmountSection(dynamic funds, ThemesProvider theme) {
    return Row(
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          color: theme.isDarkMode ? WebDarkColors.textSecondary : WebColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Available",
                style: WebTextStyles.para(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode ? WebDarkColors.textSecondary : WebColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ref.watch(privacyProvider).mask(
                    formatIndianCurrency(
                        funds.fundDetailModel?.cash ?? "0.00"),
                    prefix: "₹ "),
                style: WebTextStyles.title(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textPrimary,
                  fontWeight: WebFonts.semiBold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput(TranctionProvider fund, ThemesProvider theme) {
    return TextFormField(
      focusNode: fund.focusNode,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      keyboardType: TextInputType.number,
      style: WebTextStyles.custom(
        fontSize: 20,
        isDarkTheme: theme.isDarkMode,
        color: theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textPrimary,
      ),
      controller: fund.amount,
      onChanged: (value) {
        fund.textFiledonChange(value);
      },
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: theme.isDarkMode ? WebDarkColors.primary : WebColors.primary,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        disabledBorder: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: theme.isDarkMode ? WebDarkColors.primary : WebColors.primary,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(8),
        ),
        fillColor: theme.isDarkMode
            ? WebDarkColors.surfaceVariant
            : WebColors.backgroundTertiary,
        filled: true,
        hintText: "0",
        hintStyle: WebTextStyles.custom(
          fontSize: 20,
          isDarkTheme: theme.isDarkMode,
          color: theme.isDarkMode ? WebDarkColors.textSecondary : WebColors.textSecondary,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SvgPicture.asset(
            assets.ruppeIcon,
            color: theme.isDarkMode ? WebDarkColors.textSecondary : WebColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(TranctionProvider fund, ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: fund.amount.text.isEmpty || fund.intValue < 50
          ? Text(
              fund.funderror,
              style: WebTextStyles.caption(
                isDarkTheme: theme.isDarkMode,
                color: theme.isDarkMode ? WebDarkColors.loss : WebColors.loss,
              ),
            )
          : fund.intValue > 5000000
              ? Text(
                  fund.maxfunderror,
                  style: WebTextStyles.caption(
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode ? WebDarkColors.loss : WebColors.loss,
                  ),
                )
              : const SizedBox.shrink(),
    );
  }

  Widget _buildBankSelection(TranctionProvider fund, ThemesProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListDivider(),
        InkWell(
          onTap: () async {
            await Future.delayed(const Duration(milliseconds: 150));
            fund.focusNode.unfocus();
            showBottomSheetbank(fund, theme);
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                fund.bankname,
                style: WebTextStyles.sub(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textPrimary,
                  fontWeight: WebFonts.semiBold,
                ),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                hideAccountNumber(fund.accno),
                style: WebTextStyles.para(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode ? WebDarkColors.textSecondary : WebColors.textSecondary,
                ),
              ),
            ),
            trailing: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                customBorder: const CircleBorder(),
                splashColor: theme.isDarkMode
                    ? Colors.white.withOpacity(.15)
                    : Colors.black.withOpacity(.15),
                highlightColor: theme.isDarkMode
                    ? Colors.white.withOpacity(.08)
                    : Colors.black.withOpacity(.08),
                onTap: () async {
                  await Future.delayed(const Duration(milliseconds: 150));
                  fund.focusNode.unfocus();
                  showBottomSheetbank(fund, theme);
                },
                child: SizedBox(
                  height: 32,
                  width: 32,
                  child: Center(
                    child: Icon(
                      Icons.more_vert,
                      size: 22,
                      color: theme.isDarkMode
                          ? WebDarkColors.textSecondary
                          : WebColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const ListDivider(),
      ],
    );
  }

  Widget _buildPaymentMethods(TranctionProvider fund, ThemesProvider theme, dynamic colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Payment method",
          style: WebTextStyles.sub(
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textPrimary,
            fontWeight: WebFonts.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          padding: const EdgeInsets.all(0),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: fund.defaultUpiapps.length,
          separatorBuilder: (context, index) => const ListDivider(),
          itemBuilder: (context, index) {
            bool isUpiPayment = index == 0 || index == 1;
            bool isAmountAbove1Lakh = fund.intValue > 100000;

            return InkWell(
              onTap: () {
                if (fund.amount.text.isEmpty || fund.intValue < 50) {
                  showResponsiveWarningMessage(context, "Min amount ₹50");
                  return;
                }
                if (isUpiPayment && isAmountAbove1Lakh) {
                  showResponsiveWarningMessage(context,
                      "UPI payments are not allowed for amounts above ₹1,00,000. Please use Net Banking.");
                  return;
                }
                if (index == 0) {
                  if (defaultTargetPlatform == TargetPlatform.android) {
                    _handleAndroidUpiPayment(context, fund);
                  } else {
                    _handleIosUpiPayment(context, fund, theme);
                  }
                } else if (index == 1) {
                   _showUpiIdForm(context, fund, theme, colors);
                 } else if (index == 2) {
                  // Net Banking
                  if (fund.intValue > 5000000) {
                    showResponsiveWarningMessage(context, "Max amount ₹5,000,000");
                  } else if (fund.accno.isEmpty || fund.bankname.isEmpty) {
                    showResponsiveWarningMessage(context, "Please select a bank account first");
                  } else {
                    _handleRazorpayPayment(context, fund);
                  }
                }
              },
              child: Opacity(
                opacity: (isUpiPayment && isAmountAbove1Lakh) ? 0.5 : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        '${fund.addfundIcons[index]['image']}',
                        width: 40,
                        color: index == 2
                            ? (theme.isDarkMode
                                ? WebDarkColors.textSecondary
                                : WebColors.textSecondary)
                            : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${fund.defaultUpiapps[index]['name']}',
                                  style: WebTextStyles.sub(
                                    isDarkTheme: theme.isDarkMode,
                                    color: theme.isDarkMode
                                        ? WebDarkColors.textPrimary
                                        : WebColors.textPrimary,
                                  ),
                                ),
                                SvgPicture.asset(
                                  assets.leftArrow,
                                  width: 16,
                                  height: 16,
                                  color: theme.isDarkMode
                                      ? WebDarkColors.textSecondary
                                      : WebColors.textSecondary,
                                )
                              ],
                            ),
                            if (isUpiPayment && isAmountAbove1Lakh)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  "Not available for amount above ₹1,00,000",
                                  style: WebTextStyles.caption(
                                    isDarkTheme: theme.isDarkMode,
                                    color: theme.isDarkMode
                                        ? WebDarkColors.loss
                                        : WebColors.loss,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  showBottomSheetbank(TranctionProvider fund, ThemesProvider theme) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.25,
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              color: theme.isDarkMode ? WebDarkColors.surface : WebColors.surface,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.isDarkMode
                            ? WebDarkColors.divider
                            : WebColors.divider,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Choose a bank',
                        style: WebTextStyles.dialogTitle(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textPrimary
                              : WebColors.textPrimary,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          splashColor: theme.isDarkMode
                              ? Colors.white.withOpacity(.15)
                              : Colors.black.withOpacity(.15),
                          highlightColor: theme.isDarkMode
                              ? Colors.white.withOpacity(.08)
                              : Colors.black.withOpacity(.08),
                          onTap: () => Navigator.pop(context),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: theme.isDarkMode
                                  ? WebDarkColors.iconSecondary
                                  : WebColors.iconSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bank List
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: fund.bankdetails!.dATA!.length,
                    itemBuilder: (BuildContext context, int index) {
                      return InkWell(
                        onTap: () {
                          fund.bankselection(index);
                          fund.setAccountslist(
                              fund.bankdetails!.dATA![index][2].toString());
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: fund.bankdetails!.dATA![index][1] == fund.bankname
                                ? theme.isDarkMode 
                                    ? WebDarkColors.backgroundTertiary 
                                    : WebColors.backgroundTertiary
                                : Colors.transparent,
                            border: index < fund.bankdetails!.dATA!.length - 1
                                ? Border(
                                    bottom: BorderSide(
                                      color: theme.isDarkMode 
                                          ? WebDarkColors.divider 
                                          : WebColors.divider,
                                      width: 0.5,
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${fund.bankdetails!.dATA![index][1]}',
                                      style: WebTextStyles.sub(
                                        isDarkTheme: theme.isDarkMode,
                                        color: theme.isDarkMode
                                            ? WebDarkColors.textPrimary
                                            : WebColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      hideAccountNumber(fund.bankdetails!.dATA![index][2]),
                                      style: WebTextStyles.para(
                                        isDarkTheme: theme.isDarkMode,
                                        color: theme.isDarkMode
                                            ? WebDarkColors.textSecondary
                                            : WebColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (fund.bankdetails!.dATA![index][1] == fund.bankname)
                                Icon(
                                  Icons.check_circle,
                                  color: theme.isDarkMode 
                                      ? WebDarkColors.primary 
                                      : WebColors.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Web-specific UPI confirmation dialog content with timer
class _WebUpiConfirmationDialogContent extends ConsumerStatefulWidget {
  final TranctionProvider fund;
  final dynamic theme;
  final dynamic colors;
  final Function(BuildContext) onStatusChanged;

  const _WebUpiConfirmationDialogContent({
    required this.fund,
    required this.theme,
    required this.colors,
    required this.onStatusChanged,
  });

  @override
  ConsumerState<_WebUpiConfirmationDialogContent> createState() =>
      _WebUpiConfirmationDialogContentState();
}

class _WebUpiConfirmationDialogContentState
    extends ConsumerState<_WebUpiConfirmationDialogContent> {
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    // Start polling for payment status
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      widget.fund.fetchHdfcpaymetstatus(
        context,
        '${widget.fund.hdfctranction!.data!.orderNumber}',
        '${widget.fund.hdfctranction!.data!.upiTransactionNo}',
      );
      
      // Check status after fetching
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final status = widget.fund.hdfcpaymentstatus?.upiId?.status;
        if (status == "REJECTED" || status == "SUCCESS") {
          timer.cancel();
          _statusTimer?.cancel();
          
          // Close awaiting dialog and show result dialog
          if (mounted) {
            Navigator.pop(context); // Close awaiting dialog
            
            // Show result dialog using callback
            widget.onStatusChanged(context);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 450,
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: widget.theme.isDarkMode
            ? WebDarkColors.surface
            : WebColors.surface,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with close button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: widget.theme.isDarkMode
                      ? WebDarkColors.divider
                      : WebColors.divider,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Awaiting UPI confirmation',
                  style: WebTextStyles.dialogTitle(
                    isDarkTheme: widget.theme.isDarkMode,
                    color: widget.theme.isDarkMode
                        ? WebDarkColors.textPrimary
                        : WebColors.textPrimary,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    splashColor: widget.theme.isDarkMode
                        ? Colors.white.withOpacity(.15)
                        : Colors.black.withOpacity(.15),
                    highlightColor: widget.theme.isDarkMode
                        ? Colors.white.withOpacity(.08)
                        : Colors.black.withOpacity(.08),
                    onTap: () {
                      _statusTimer?.cancel();
                      widget.fund.amount.clear();
                      Navigator.pop(context);
                      widget.fund.focusNode.unfocus();
                      ref.read(mfProvider).IsPaymentCalled(false);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: widget.theme.isDarkMode
                            ? WebDarkColors.iconSecondary
                            : WebColors.iconSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, bottom: 16, top: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    // Loading indicator
                    const ProgressiveDotsLoader(),
                    const SizedBox(height: 16),
                    // Instruction text
                    Text(
                      'This will take a few seconds.',
                      style: WebTextStyles.sub(
                        isDarkTheme: widget.theme.isDarkMode,
                        color: widget.theme.isDarkMode
                            ? WebDarkColors.textSecondary
                            : WebColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Cancel button
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.theme.isDarkMode
                              ? WebDarkColors.primary
                              : WebColors.primary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(5),
                            splashColor: Colors.white.withOpacity(0.2),
                            highlightColor: Colors.white.withOpacity(0.1),
                            onTap: () {
                              // Cancel timer
                              _statusTimer?.cancel();
                              // Clear the amount text field
                              widget.fund.amount.clear();
                              Navigator.pop(context);
                              widget.fund.focusNode.unfocus();
                              ref.read(mfProvider).IsPaymentCalled(false);
                            },
                            child: Container(
                              alignment: Alignment.center,
                              child: Text(
                                "Cancel Transaction",
                                style: WebTextStyles.buttonMd(
                                  isDarkTheme: widget.theme.isDarkMode,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


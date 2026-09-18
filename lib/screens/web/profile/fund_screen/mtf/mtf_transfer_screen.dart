import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/privacy_provider.dart';
import 'package:mynt_plus/provider/transcation_provider.dart';
import 'package:mynt_plus/utils/custom_navigator.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/list_divider.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../sharedWidget/common_buttons_web.dart';
import '../../../../../sharedWidget/common_text_fields_web.dart';
import '../../../../../sharedWidget/functions.dart';

class MtfTransferScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const MtfTransferScreen({super.key, this.onBack});

  @override
  ConsumerState<MtfTransferScreen> createState() => _MtfTransferScreenState();
}

class _MtfTransferScreenState extends ConsumerState<MtfTransferScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isInitialized = false;
  String _errorText = "";
  bool _disable = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _initializeData() async {
    final fund = ref.read(transcationProvider);
    await fund.fetchc(context);
    fund.checkMtfStatus();
    if (fund.mtfActive == true) {
      await fund.fetchMtfLimits();
    }
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fund = ref.watch(transcationProvider);

    if (!_isInitialized || fund.mtfLoading) {
      return Scaffold(
        backgroundColor: resolveThemeColor(
          context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor,
        ),
        appBar: _buildAppBar(context),
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
      appBar: _buildAppBar(context),
      body: fund.mtfActive == true
          ? _buildTransferBody(context, fund)
          : _buildMtfNotActive(context, fund),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: false,
      leadingWidth: 48,
      titleSpacing: 6,
       backgroundColor: resolveThemeColor(
        context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor,
      ),
      elevation: .2,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: CustomBackBtn(onBack: widget.onBack),
      ),
      title: Text(
        'Transfer to MTF',
        style: MyntWebTextStyles.title(
          context,
          fontWeight: MyntFonts.semiBold,
          darkColor: MyntColors.textPrimaryDark,
          lightColor: MyntColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildMtfNotActive(BuildContext context, TranctionProvider fund) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: MyntColors.errorDark.withOpacity(0.1),
              light: MyntColors.error.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: resolveThemeColor(
              context,
              dark: MyntColors.errorDark,
              light: MyntColors.error,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: resolveThemeColor(
                context,
                dark: MyntColors.errorDark,
                light: MyntColors.error,
              ),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          "MTF (Margin Trading Facility) is not active on your account. ",
                      style: MyntWebTextStyles.body(
                        context,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary,
                        ),
                        fontWeight: MyntFonts.regular,
                      ),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () {
                          WebNavigationHelper.navigateTo("mtfDetails");
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Text(
                            "Click here to activate",
                             style: MyntWebTextStyles.body(
                        context,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
                        ),
                        fontWeight: MyntFonts.semiBold,
                      ),
                          ),
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
    );
  }

  Widget _buildTransferBody(BuildContext context, TranctionProvider fund) {
    final clientName =
        fund.decryptclientcheck?.clientCheck?.dATA?[fund.indexss][2] ?? '';
    final clientCode =
        fund.decryptclientcheck?.clientCheck?.dATA?[fund.indexss][0] ?? '';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar card ──────────────────────────────────
              _buildTopBar(context, fund, clientName, clientCode),
              const SizedBox(height: 16),

              // ── Main content card (two columns) ──────────────
              _buildMainCard(context, fund),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar: Total Amount + MTF Amount + client info ───────────

  Widget _buildTopBar(BuildContext context, TranctionProvider fund,
      String clientName, String clientCode) {
    return shadcn.Theme(
      data: shadcn.Theme.of(context).copyWith(radius: () => 0.3),
      child: shadcn.Card(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
        children: [
          // Total Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Total Amount",
                style: MyntWebTextStyles.bodySmall(
                  context,
                  fontWeight: MyntFonts.medium,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Builder(
                builder: (context) {
                  // Privacy Mode: balance masked, colour neutralized.
                  final privacy = ref.watch(privacyProvider);
                  if (privacy.isPrivate) {
                    return Text(
                      kPrivacyMask,
                      style: MyntWebTextStyles.head(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                        fontWeight: MyntFonts.medium,
                      ),
                    );
                  }
                  final value = fund.mtfTotalAmount;
                  final Color color = value > 0
                      ? resolveThemeColor(context,
                          dark: MyntColors.profitDark,
                          light: MyntColors.profit)
                      : value < 0
                          ? resolveThemeColor(context,
                              dark: MyntColors.errorDark,
                              light: MyntColors.tertiary)
                          : resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary);
                  return Text(
                    getFormatter(
                        value: value, v4d: false, noDecimal: false),
                    style: MyntWebTextStyles.head(
                      context,
                      color: color,
                      fontWeight: MyntFonts.medium,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(width: 40),
          // MTF Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MTF Amount",
                style: MyntWebTextStyles.bodySmall(
                  context,
                  fontWeight: MyntFonts.medium,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ref.watch(privacyProvider).mask(getFormatter(
                    value: fund.mtfAmount, v4d: false, noDecimal: false)),
                style: MyntWebTextStyles.head(
                  context,
                  fontWeight: MyntFonts.medium,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Client info
        //   Row(
        //     children: [
        //       Text(
        //         clientName,
        //         style: MyntWebTextStyles.bodySmall(
        //           context,
        //           fontWeight: MyntFonts.medium,
        //           darkColor: MyntColors.textPrimaryDark,
        //           lightColor: MyntColors.textPrimary,
        //         ),
        //       ),
        //       const SizedBox(width: 8),
        //       Container(
        //         padding:
        //             const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        //         decoration: BoxDecoration(
        //           color: resolveThemeColor(context,
        //               dark: MyntColors.listItemBgDark,
        //               light: MyntColors.listItemBg),
        //           borderRadius: BorderRadius.circular(4),
        //         ),
        //         child: Text(
        //           clientCode,
        //           style: MyntWebTextStyles.caption(
        //             context,
        //             fontWeight: MyntFonts.bold,
        //             darkColor: MyntColors.textPrimaryDark,
        //             lightColor: MyntColors.textPrimary,
        //           ),
        //         ),
        //       ),
        //     ],
        //   ),
        ],
      ),
    ),
      ),
    );
  }

  // ── Main card: form (left) + summary (right) ───────────────────

  Widget _buildMainCard(BuildContext context, TranctionProvider fund) {
    return Container(
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
            // Left column: form
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildTransferForm(context, fund),
              ),
            ),
            // Vertical divider
            Container(
              width: 1,
              color: resolveThemeColor(context,
                  dark: MyntColors.cardBorderDark,
                  light: MyntColors.cardBorder),
            ),
            // Right column: summary
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildSummaryColumn(context, fund),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Left column: form ──────────────────────────────────────

  Widget _buildTransferForm(BuildContext context, TranctionProvider fund) {
    return Column(
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _buildAmountInput(context, fund)),
            const SizedBox(width: 12),
            _buildTransferButton(context, fund),
          ],
        ),
        if (_errorText.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _errorText,
              style: MyntWebTextStyles.caption(
                context,
                fontWeight: MyntFonts.medium,
                color: resolveThemeColor(context,
                    dark: MyntColors.errorDark,
                    light: MyntColors.error),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _buildInfoAlert(context),
      ],
    );
  }

  Widget _buildAmountInput(BuildContext context, TranctionProvider fund) {
    return MyntTextField(
      controller: _amountController,
      placeholder: "0",
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      leadingWidget: Center(
        widthFactor: 1,
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            "₹",
            style: MyntWebTextStyles.body(
              context,
              fontWeight: MyntFonts.medium,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
            ),
          ),
        ),
      ),
      onChanged: (value) {
                      setState(() {
                        if (value.isEmpty) {
                          _disable = true;
                          _errorText = "";
                        } else {
                          final entered = int.tryParse(value) ?? 0;
                          final maxCash = double.tryParse(
                                  fund.mtfLimits?.cash ?? '0') ??
                              0;
                          if (entered <= 0) {
                            _disable = true;
                            _errorText = "Amount must be greater than 0";
                          } else if (entered > maxCash) {
                            _disable = true;
                            // Privacy Mode: don't print the balance in the
                            // validation message.
                            _errorText = ref.read(privacyProvider).isPrivate
                                ? "Amount cannot exceed available cash"
                                : "Amount cannot exceed available cash ₹${maxCash.toStringAsFixed(2)}";
                          } else {
                            _disable = false;
                            _errorText = "";
                          }
                        }
                      });
                    },
    );
  }

  Widget _buildTransferButton(BuildContext context, TranctionProvider fund) {
    return MyntPrimaryButton(
      label: "Transfer",
      isFullWidth: false,
      isLoading: fund.mtfTransferLoading,
                    onPressed: _disable
                        ? () {
                            if (_amountController.text.isEmpty) {
                              showResponsiveWarningMessage(
                                  context, "Please enter amount");
                            } else {
                              showResponsiveWarningMessage(
                                  context, _errorText.isNotEmpty ? _errorText : "Please enter a valid amount");
              }
            }
          : () async {
              final amount = _amountController.text;
              final result = await fund.submitMtfTransfer(amount);
              if (!mounted) return;
              if (result?.pymtStatus == 'OK') {
                _amountController.clear();
                setState(() {
                  _disable = true;
                  _errorText = "";
                });
                showResponsiveSuccess(
                    context, "Fund Transfer Successful");
              } else if (result?.pymtStatus == 'NOT_OK') {
                showResponsiveWarningMessage(
                    context, result?.emsg ?? "Transfer failed");
              } else {
                showResponsiveWarningMessage(
                    context, "Transfer failed. Please try again.");
              }
            },
    );
  }

  // ── Right column: summary ──────────────────────────────────

  Widget _buildSummaryColumn(BuildContext context, TranctionProvider fund) {
    final cashValue =
        double.tryParse(fund.mtfLimits?.cash ?? '0') ?? 0;
    final mtfCashValue =
        double.tryParse(fund.mtfLimitsMTF?.cash ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Transfer Summary",
          style: MyntWebTextStyles.bodySmall(
            context,
            fontWeight: MyntFonts.medium,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ref.watch(privacyProvider).mask(getFormatter(
              value: fund.mtfTotalAmount, v4d: false, noDecimal: false)),
          style: MyntWebTextStyles.head(
            context,
            fontWeight: MyntFonts.medium,
            color: resolveThemeColor(context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary),
          ),
        ),
        const SizedBox(height: 12),
        const ListDivider(),
        _summaryRow(context, "Available Cash",
            getFormatter(value: cashValue, v4d: false, noDecimal: false)),
        const ListDivider(),
        // _summaryRow(context, "MTF Cash Component",
        //     getFormatter(value: mtfCashValue, v4d: false, noDecimal: false)),
        // const ListDivider(),
        _summaryRow(
            context,
            "MTF Amount",
            getFormatter(
                value: fund.mtfAmount, v4d: false, noDecimal: false)),
      ],
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: MyntWebTextStyles.bodySmall(
              context,
              fontWeight: MyntFonts.medium,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
            ),
          ),
          Text(
            ref.watch(privacyProvider).mask(value),
            style: MyntWebTextStyles.bodySmall(
              context,
              fontWeight: MyntFonts.semiBold,
              color: valueColor ??
                  resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Info alert ─────────────────────────────────────────────

  Widget _buildInfoAlert(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.listItemBgDark,
            light: MyntColors.listItemBg),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
            color: resolveThemeColor(context,
                dark: MyntColors.borderMutedDark,
                light: MyntColors.borderMuted)),
      ),
      child: Text(
        "Fund transfer to MTF will move the specified amount from your trading account to the Margin Trading Facility. This amount will be used as collateral for MTF positions.",
        style: MyntWebTextStyles.para(
          context,
          fontWeight: MyntFonts.medium,
          darkColor: MyntColors.textSecondaryDark,
          lightColor: MyntColors.textSecondary,
        ),
      ),
    );
  }
}

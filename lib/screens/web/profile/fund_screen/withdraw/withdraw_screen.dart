import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/privacy_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/transcation_provider.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/list_divider.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../sharedWidget/common_buttons_web.dart';
import '../../../../../sharedWidget/common_text_fields_web.dart';

class WithdrawScreen extends ConsumerStatefulWidget {
  final TranctionProvider withdarw;
  final FocusNode foucs;
  final ThemesProvider theme;
  final String segment;
  final VoidCallback? onBack;
  const WithdrawScreen({
    super.key,
    required this.withdarw,
    required this.foucs,
    required this.theme,
    required this.segment,
    this.onBack,
  });

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  String withdarwerror = "";
  late bool _isVisible;
  bool disable = false;
  bool isBreakUpExpanded = false;
  bool _withdrawLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    widget.withdarw.withdrawamount.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreenData();
    });
  }

  void _initializeScreenData() {
    final fund = ref.read(transcationProvider);
    if (fund.bankdetails?.dATA != null &&
        fund.bankdetails!.dATA!.isNotEmpty &&
        fund.decryptclientcheck != null &&
        fund.payoutdetails != null) {
      fund.initialdata(context);
      _isVisible = fund.withdrawstatus != null &&
          fund.withdrawstatus!.isNotEmpty &&
          fund.withdrawstatus![0].msg != "no data found";
      disable = (widget.withdarw.withdrawamount.text.isEmpty ||
          widget.withdarw.payoutdetails?.withdrawAmount == "0.00");
      widget.foucs.requestFocus();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _initializeScreenData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fund = ref.watch(transcationProvider);

    if (!_isInitialized ||
        fund.bankdetails == null ||
        fund.decryptclientcheck == null ||
        fund.payoutdetails == null) {
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

    final withdrawAmount =
        widget.withdarw.payoutdetails!.withdrawAmount ?? "0.00";
    final hasAmount = double.tryParse(withdrawAmount) != null &&
        double.parse(withdrawAmount) > 0;

    return Scaffold(
      backgroundColor: resolveThemeColor(
        context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor,
      ),
      appBar: _buildAppBar(context),
      body: GestureDetector(
        onTap: () => widget.foucs.unfocus(),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar card ──────────────────────────────────
                _buildTopBar(context, withdrawAmount, hasAmount),
                const SizedBox(height: 16),

                // ── Main content card (two columns) ──────────────
                _buildMainCard(context),

                if (_isVisible) ...[
                  const SizedBox(height: 16),
                  _buildOpenRequest(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    
    return AppBar(
      centerTitle: false,
      leadingWidth: 48,
      titleSpacing: 6,
      backgroundColor: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      elevation: .2,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: CustomBackBtn(onBack: widget.onBack),
      ),
      title: Text(
        'Withdraw Fund',
        style: MyntWebTextStyles.title(
          context,
          fontWeight: MyntFonts.semiBold,
          darkColor: MyntColors.textPrimaryDark,
          lightColor: MyntColors.textPrimary,
        ),
      ),
    );
  }

  // ── Top bar: Withdrawable amount + actions ─────────────────────

  Widget _buildTopBar(
      BuildContext context, String withdrawAmount, bool hasAmount) {
    return shadcn.Theme(
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
                "Withdrawable Amount",
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
                      "₹ $kPrivacyMask",
                      style: MyntWebTextStyles.head(
                        context,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary,
                        ),
                        fontWeight: MyntFonts.medium,
                      ),
                    );
                  }
                  final amountValue =
                      double.tryParse(withdrawAmount) ?? 0.00;
                  final Color amountColor = amountValue > 0
                      ? resolveThemeColor(
                          context,
                          dark: MyntColors.profitDark,
                          light: MyntColors.profit,
                        )
                      : amountValue < 0
                          ? resolveThemeColor(
                              context,
                              dark: MyntColors.errorDark,
                              light: MyntColors.tertiary,
                            )
                          : resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            );
                  return Text(
                    "₹ $withdrawAmount",
                    style: MyntWebTextStyles.head(
                      context,
                      color: amountColor,
                      fontWeight: MyntFonts.medium,
                    ),
                  );
                },
              ),
            ],
          ),
          const Spacer(),
          if (hasAmount)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  setState(() {
                    widget.withdarw.withdrawamount.text = withdrawAmount;
                    widget.withdarw.withdrawamount.selection =
                        TextSelection.fromPosition(
                      TextPosition(
                          offset:
                              widget.withdarw.withdrawamount.text.length),
                    );
                    disable = false;
                    withdarwerror = "";
                  });
                },
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
                  child: Text(
                    "Withdraw All",
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      fontWeight: MyntFonts.semiBold,
                      color: resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
      ),
    );
  }

  // ── Main card: form (left) + summary (right) ───────────────────

  Widget _buildMainCard(BuildContext context) {
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
                child: _buildWithdrawForm(context),
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
                child: _buildSummaryColumn(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Left column: form ──────────────────────────────────────

  Widget _buildWithdrawForm(BuildContext context) {
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
            Expanded(child: _buildAmountInput(context)),
            const SizedBox(width: 12),
            _buildWithdrawButton(context),
          ],
        ),
        if (withdarwerror.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              withdarwerror,
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

  Widget _buildAmountInput(BuildContext context) {
    return MyntTextField(
      controller: widget.withdarw.withdrawamount,
      focusNode: widget.foucs,
      enabled: widget.withdarw.payoutdetails!.withdrawAmount != '0.00',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        FilteringTextInputFormatter.deny(RegExp(r'^0$')),
      ],
      placeholder: "0.00",
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
          if (value.isNotEmpty) {
            double enteredAmount = double.tryParse(value) ?? 0;
            double availableAmount = double.parse(
                widget.withdarw.payoutdetails!.withdrawAmount.toString());
            if (enteredAmount <= 0) {
              disable = true;
              withdarwerror = "Amount must be greater than 0";
            } else if (enteredAmount > availableAmount) {
              disable = true;
              withdarwerror = "Insufficient fund";
            } else {
              disable = false;
              withdarwerror = "";
            }
          } else {
            disable = true;
            withdarwerror = "";
          }
        });
      },
    );
  }

  Widget _buildWithdrawButton(BuildContext context) {
    return MyntPrimaryButton(
      label: "Withdraw",
      isFullWidth: false,
      isLoading: _withdrawLoading,
      onPressed: disable
          ? () {
              if (widget.withdarw.payoutdetails!.withdrawAmount == "0.00") {
                showResponsiveWarningMessage(context, "Insufficient fund");
              } else if (widget.withdarw.withdrawamount.text.isEmpty) {
                showResponsiveWarningMessage(
                    context, "Please enter the amount");
              } else if (double.tryParse(
                          widget.withdarw.withdrawamount.text) !=
                      null &&
                  double.parse(widget.withdarw.withdrawamount.text) <= 0) {
                showResponsiveWarningMessage(
                    context, "Amount must be greater than 0");
              } else {
                showResponsiveWarningMessage(
                    context, "Please enter a valid amount");
              }
            }
          : () async {
              setState(() => _withdrawLoading = true);
              await widget.withdarw.fetchPaymentWithDraw(
                widget.withdarw.ipAddress,
                widget.withdarw.withdrawamount.text,
                widget.segment,
                context,
              );
              _isVisible = false;
              widget.withdarw.focusNode.unfocus();
              widget.withdarw.withdrawamount.clear();
              setState(() {
                disable = true;
                withdarwerror = "";
                _withdrawLoading = false;
              });
              showUIWithDelay();
            },
    );
  }

  // ── Right column: summary ──────────────────────────────────

  Widget _buildSummaryColumn(BuildContext context) {
    final payout = widget.withdarw.payoutdetails!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Withdraw Summary",
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
                  final amountValue =
                      double.tryParse(payout.withdrawAmount ?? '0') ?? 0.00;
                  return Text(
                     ref.watch(privacyProvider).mask(
                         payout.withdrawAmount ?? "0.00",
                         prefix: "₹ "),
                    style: MyntWebTextStyles.head(
                      context,
                      color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
                      fontWeight: MyntFonts.medium,
                    ),
                  );
                },
              ),
        const SizedBox(height: 12),
        const ListDivider(),
        _summaryRow(context, "Available Cash", payout.totalLedger ?? "0.00"),
        const ListDivider(),
        if (double.tryParse(payout.brkcollamt ?? '0') != null &&
            double.parse(payout.brkcollamt ?? '0') > 0) ...[
          _summaryRow(
              context, "Collateral Value", payout.brkcollamt ?? "0.00"),
          const ListDivider(),
        ],
        if (double.tryParse(payout.fD ?? '0') != null &&
            double.parse(payout.fD ?? '0') > 0) ...[
          _summaryRow(context, "Fixed Deposit", payout.fD ?? "0.00"),
          const ListDivider(),
        ],
        _summaryRow(context, "Margin Used", payout.margin ?? "0.00",
            valueColor: (payout.margin != null && payout.margin != "0.00")
                ? resolveThemeColor(context,
                    dark: MyntColors.errorDark,
                    light: MyntColors.error)
                : null),
      ],
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value,
      {Color? valueColor}) {
    // Privacy Mode: amount masked; any special colour (e.g. red Margin Used)
    // is dropped so nothing leaks through colour.
    final privacy = ref.watch(privacyProvider);
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
            privacy.mask(value),
            style: MyntWebTextStyles.bodySmall(
              context,
              fontWeight: MyntFonts.semiBold,
              color: (privacy.isPrivate ? null : valueColor) ??
                  resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Alerts & status ─────────────────────────────────────────────

  Widget _buildOpenRequest(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: const Color(0xFF2D2200),
            light: const Color(0xFFFFF8E1)),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: resolveThemeColor(context,
              dark: const Color(0xFF5C4400),
              light: const Color(0xFFFFE082)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pending Request",
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    fontWeight: MyntFonts.medium,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ref.watch(privacyProvider).mask(
                      "${widget.withdarw.withdrawstatus?[0].dUEAMT}",
                      prefix: "₹ "),
                  style: MyntWebTextStyles.title(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "${widget.withdarw.withdrawstatus?[0].eNTRYTIME}",
            style: MyntWebTextStyles.bodySmall(
              context,
              fontWeight: MyntFonts.medium,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

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
        "Payout requests submitted before 8:30 AM on any working day will be processed on the same day. Requests received after 8:30 AM will be processed on the next working day. In case of multiple requests, the latest one will be considered.",
        style: MyntWebTextStyles.para(
          context,
          fontWeight: MyntFonts.medium,
          darkColor: MyntColors.textSecondaryDark,
          lightColor: MyntColors.textSecondary,
        ),
      ),
    );
  }

  void showUIWithDelay() {
    Future.delayed(Duration.zero, () {
      setState(() {
        _isVisible = true;
      });
    });
  }
}

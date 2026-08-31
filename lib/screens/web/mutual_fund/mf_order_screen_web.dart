import 'package:flutter/material.dart' hide MenuController;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/models/mf_model/mutual_fundmodel.dart';
import '../../../models/mf_model/mf_lumpsum_order.dart';
import '../../../provider/mf_provider.dart';
import '../../../provider/transcation_provider.dart';
import '../../../provider/thems.dart';
import '../../../res/global_state_text.dart';
import '../../../res/res.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../sharedWidget/common_text_fields_web.dart';
import '../../../sharedWidget/snack_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'create_mandate_dialogue_web.dart';
import '../profile/fund_screen/upi_id_screens/mf_payment_resp_alert.dart';
import 'mf_order_bottomsheet_web.dart';

// Utility function to get the appropriate suffix for date numbers
String getDateSuffix(int day) {
  if (day >= 11 && day <= 13) {
    return 'th';
  }

  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

class MFOrderScreenWeb extends ConsumerStatefulWidget {
  final MutualFundList mfData;
  final bool isAdditional;
  const MFOrderScreenWeb(
      {super.key, required this.mfData, this.isAdditional = false});

  @override
  ConsumerState<MFOrderScreenWeb> createState() => _MFOrderScreenState();
}

class _MFOrderScreenState extends ConsumerState<MFOrderScreenWeb> {
  String _selectedSchemeType = "Growth";
  bool _firstInstallment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final mfProv = ref.read(mfProvider);
      // Only set invAmt if it's not already set from NFO screen
      if (mfProv.invAmt.text.isEmpty) {
        mfProv.invAmt.text = widget.mfData.minimumPurchaseAmount ?? '500';
      }

      // Fetch SIP data, mandate details, and bank details
      final isin = widget.mfData.iSIN;
      final schemeCode = widget.mfData.schemeCode;
      if (isin != null && schemeCode != null) {
        await mfProv.fetchMFSipData(isin, schemeCode);
        await mfProv.fetchMFMandateDetail();
      }
      // Fetch UPI details for payment UI
      await mfProv.fetchUpiDetail('', context);
      // Fetch bank_check API and set default bank
      final fundProv = ref.read(transcationProvider);
      await fundProv.fetchfundbank(context);
      // Clear any validation errors after data is loaded
      mfProv.resetmfordervalidation();
      // Ensure loader is reset after all fetches complete
      mfProv.setInvestLoader(false);
    });
  }

  String _formatDate(String input) {
    if (input.isEmpty) return "N/A";

    try {
      List<DateFormat> formats = [
        DateFormat('MMM d yyyy  h:mma'),
        DateFormat('MMM d yyyy h:mma'),
        DateFormat('MMM d yyyy H:mma'),
      ];

      DateTime? parsedDate;
      for (DateFormat format in formats) {
        try {
          parsedDate = format.parse(input);
          break;
        } catch (e) {
          continue;
        }
      }

      if (parsedDate != null) {
        final outputFormat = DateFormat('MMM dd yyyy h:mma');
        return outputFormat.format(parsedDate);
      } else {
        return input;
      }
    } catch (e) {
      return input;
    }
  }

  void _applySchemeSelection(String label) {
    final mfOrder = ref.read(mfProvider);
    String minAmt;
    if (label == "Divided Payout") {
      minAmt = widget.mfData.iDCWMinimumPurchaseAmount ??
          widget.mfData.minimumPurchaseAmount ??
          "0";
    } else if (label == "Divided Reinvest") {
      minAmt = widget.mfData.reinvMinimumPurchaseAmount ??
          widget.mfData.minimumPurchaseAmount ??
          "0";
    } else {
      minAmt = widget.mfData.minimumPurchaseAmount ?? "0";
    }
    if (mfOrder.mfOrderTpye == "One-time") {
      mfOrder.invAmt.text = minAmt.split('.').first;
    } else {
      mfOrder.installmentAmt.text = minAmt.split('.').first;
    }
    mfOrder.isValidUpiId(widget.mfData, '', schemeType: label);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final mfOrder = ref.watch(mfProvider);
    final isDark = theme.isDarkMode;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(isDark, mfOrder),

              // Main content
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order type toggle (Lumpsum / Monthly SIP)
                      _buildOrderTypeToggle(isDark, mfOrder),

                      // Scheme type selector
                      if (!widget.isAdditional) ...[
                        const SizedBox(height: 16),
                        _buildSchemeTypeSelector(isDark, mfOrder),
                      ],

                      const SizedBox(height: 24),

                      // Investment/Instalment amount field
                      _buildAmountField(isDark, mfOrder),

                      // First installment checkbox (SIP only)
                      if (mfOrder.mfOrderTpye == "SIP") ...[
                        const SizedBox(height: 12),
                        _buildFirstInstallmentCheckbox(isDark),
                      ],

                      // SIP specific fields
                      if (mfOrder.mfOrderTpye == "SIP") ...[
                        const SizedBox(height: 20),
                        _buildMandatesSection(isDark, mfOrder),
                      ],

                      // SIP date selector
                      if (mfOrder.mfOrderTpye == "SIP") ...[
                        const SizedBox(height: 20),
                        _buildSIPDateSelector(isDark, mfOrder),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer button
              _buildBottomButton(isDark, mfOrder),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, MFProvider mfOrder) {
    final fundName = _getFundName(mfOrder);

    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: fundName,
              waitDuration: const Duration(milliseconds: 300),
              child: Text(
                fundName,
                style: MyntWebTextStyles.title(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
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
    );
  }

  Widget _buildOrderTypeToggle(bool isDark, MFProvider mfOrder) {
    final isSIP = mfOrder.mfOrderTpye == "SIP";
    final sipEnabled = widget.mfData.sIPFLAG == "Y";

    Widget buildChip(String label, bool isSelected, VoidCallback onTap) {
      return TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          backgroundColor: isSelected
              ? (isDark ? colors.darkGrey : const Color(0xffF1F3F8))
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: isSelected
                ? BorderSide(
                    color: resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary),
                    width: 1,
                  )
                : BorderSide.none,
          ),
        ),
        child: Text(
          label,
          style: MyntWebTextStyles.body(
            context,
            color: isSelected
                ? resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary)
                : resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      );
    }

    return Row(
      children: [
        buildChip("One-Time", !isSIP, () {
          if (isSIP) _switchOrderType("One-time", mfOrder);
        }),
        const SizedBox(width: 8),
        buildChip("Monthly SIP", isSIP, () {
          if (!isSIP && sipEnabled) _switchOrderType("SIP", mfOrder);
        }),
      ],
    );
  }

  Widget _buildSchemeTypeSelector(bool isDark, MFProvider mfOrder) {
    final hasIDCW = widget.mfData.iDCWSchemeCode != null;
    final hasReinv = widget.mfData.reinvSchemeCode != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Scheme Type",
          style: MyntWebTextStyles.body(context,
              fontWeight: MyntFonts.semiBold,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _schemeTypeOption("Growth", isDark),
            if (hasIDCW) ...[
              const SizedBox(width: 16),
              _schemeTypeOption("Divided Payout", isDark),
            ],
            if (hasReinv) ...[
              const SizedBox(width: 16),
              _schemeTypeOption("Divided Reinvest", isDark),
            ],
          ],
        ),
      ],
    );
  }

  Widget _schemeTypeOption(String label, bool isDark) {
    final isSelected = _selectedSchemeType == label;
    return InkWell(
      onTap: () {
        setState(() => _selectedSchemeType = label);
        _applySchemeSelection(label);
      },
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark, light: MyntColors.primary)
                    : resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary),
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: resolveThemeColor(context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary),
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: MyntWebTextStyles.bodySmall(
              context,
              fontWeight: MyntFonts.medium,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _showMandatePopover(BuildContext btnContext, MFProvider mfOrder) {
    final btnWidth = (btnContext.findRenderObject() as RenderBox).size.width;

    shadcn.showPopover(
      context: btnContext,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 4),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(btnContext).borderRadiusLg,
      ),
      builder: (popoverContext) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(popoverContext).borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: shadcn.ModalContainer(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: btnWidth - 8,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: mfOrder.mandateData!.length,
                  itemBuilder: (context, index) {
                    final mandate = mfOrder.mandateData![index];
                    final isSelected = mandate.mandateId == mfOrder.mandateId;
                    final status = mandate.status?.toUpperCase() ?? '';

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          shadcn.closeOverlay(popoverContext);
                          mfOrder.chngMandate(mandate.mandateId ?? '');
                          setState(() {});
                        },
                        splashColor: resolveThemeColor(context,
                            dark: MyntColors.rippleDark,
                            light: MyntColors.rippleLight),
                        highlightColor: resolveThemeColor(context,
                            dark: MyntColors.highlightDark,
                            light: MyntColors.highlightLight),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? resolveThemeColor(context,
                                    dark: MyntColors.primary
                                        .withValues(alpha: 0.1),
                                    light: MyntColors.primary
                                        .withValues(alpha: 0.06))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              mandate.mandateId ?? '',
                                              style: MyntWebTextStyles.body(
                                                context,
                                                fontWeight: isSelected
                                                    ? MyntFonts.semiBold
                                                    : MyntFonts.medium,
                                                color: isSelected
                                                    ? resolveThemeColor(context,
                                                        dark: MyntColors
                                                            .primaryDark,
                                                        light:
                                                            MyntColors.primary)
                                                    : resolveThemeColor(context,
                                                        dark: MyntColors
                                                            .textPrimaryDark,
                                                        light: MyntColors
                                                            .textPrimary),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildStatusBadge(status),
                                          ],
                                        ),
                                        Text(
                                          "₹${double.parse(mandate.amount ?? '0').toStringAsFixed(0)}",
                                          style: MyntWebTextStyles.body(context,
                                              fontWeight: MyntFonts.medium,
                                              color: resolveThemeColor(context,
                                                  dark: MyntColors
                                                      .textPrimaryDark,
                                                  light:
                                                      MyntColors.textPrimary)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      mandate.bankName ?? 'Unknown Bank',
                                      style: MyntWebTextStyles.para(
                                        context,
                                        darkColor: MyntColors.textSecondaryDark,
                                        lightColor: MyntColors.textSecondary,
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMandatesSection(bool isDark, MFProvider mfOrder) {
    final hasMandates =
        mfOrder.mandateData != null && mfOrder.mandateData!.isNotEmpty;
    final isLoading = !mfOrder.mandateDataLoaded;
    final hasError =
        !isLoading && (!hasMandates || mfOrder.mandateStatus != "APPROVED");

    final selectedMandate = hasMandates
        ? mfOrder.mandateData!.firstWhere(
            (m) => m.mandateId == mfOrder.mandateId,
            orElse: () => mfOrder.mandateData!.first,
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Mandates",
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary)),
              ),
              MyntIconTextButton(
                label: 'New mandate',
                onPressed: () => _showCreateMandateDialog(),
              ),
            ],
          ),
        ),

        // Dropdown button
        Builder(
          builder: (btnContext) => GestureDetector(
            onTap: hasMandates
                ? () => _showMandatePopover(btnContext, mfOrder)
                : null,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: resolveThemeColor(context,
                    dark: MyntColors.transparent,
                    light: const Color(0xffF1F3F8)),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.outlinedBorder),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (hasError) ...[
                    Icon(Icons.error_outline,
                        size: 16,
                        color:
                            isDark ? MyntColors.lossDark : MyntColors.loss),
                    const SizedBox(width: 8),
                  ],
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: resolveThemeColor(context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: Text(
                        selectedMandate != null
                            ? "${selectedMandate.mandateId}  -  ₹ ${double.parse(selectedMandate.amount ?? '0').toStringAsFixed(0)}"
                            : "No mandates available",
                        style: MyntWebTextStyles.body(
                          context,
                          darkColor: hasMandates
                              ? MyntColors.textPrimaryDark
                              : MyntColors.textSecondaryDark,
                          lightColor: hasMandates
                              ? MyntColors.textPrimary
                              : MyntColors.textSecondary,
                          fontWeight: MyntFonts.medium,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasMandates)
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                        size: 20,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Inline error message
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(
            !hasMandates
                ? "Please create a mandate to proceed with SIP."
                : "Please select an approved mandate to proceed with SIP.",
            style: MyntWebTextStyles.para(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.lossDark, light: MyntColors.loss),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    if (status == 'APPROVED') {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
    } else if (status == 'REJECTED') {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
    } else {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status.isEmpty ? 'PENDING' : status,
        style: MyntWebTextStyles.caption(
          fontWeight: MyntFonts.medium,
          context,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildAmountField(bool isDark, MFProvider mfOrder) {
    final isLumpsum = mfOrder.mfOrderTpye == "One-time";
    final errorText =
        isLumpsum ? mfOrder.invAmtError : mfOrder.installmentAmtError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isLumpsum ? "Investment amount" : "Instalment amount",
           style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary)),
        ),
        const SizedBox(height: 10),
        MyntFormTextField(
          controller: isLumpsum ? mfOrder.invAmt : mfOrder.installmentAmt,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          placeholder: widget.mfData.minimumPurchaseAmount ?? '500',
          height: 40,
          textStyle: MyntWebTextStyles.title(
            context,
            fontWeight: MyntFonts.medium,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
          ),
          leadingWidget: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SvgPicture.asset(
              assets.ruppeIcon,
              colorFilter: ColorFilter.mode(
                resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
                BlendMode.srcIn,
              ),
            ),
          ),
          onChanged: (value) {
            mfOrder.isValidUpiId(widget.mfData, '');
          },
        ),

        // Error message
        if (errorText != null && errorText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            errorText,
            style: MyntWebTextStyles.para(
              context,
              color: isDark ? MyntColors.lossDark : MyntColors.loss,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFirstInstallmentCheckbox(bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _firstInstallment = !_firstInstallment;
        });
      },
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _firstInstallment,
              onChanged: (value) {
                setState(() {
                  _firstInstallment = value ?? false;
                });
              },
              activeColor: resolveThemeColor(context,
                  dark: MyntColors.primaryDark, light: MyntColors.primary),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "First installment",
            style: MyntWebTextStyles.body(
              context,
              fontWeight: MyntFonts.medium,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSIPDateSelector(bool isDark, MFProvider mfOrder) {
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return Center(
      child: MyntIconTextButton(
        onPressed: () =>
            _showCalendarDialog(context, ref.read(themeProvider), mfOrder),
        customIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Monthly on ${mfOrder.dates}${getDateSuffix(int.tryParse(mfOrder.dates) ?? 1)} ${_kMonthNames[mfOrder.sipMonth - 1]}",
              style: MyntWebTextStyles.buttonMd(context, color: primary),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, color: primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(bool isDark, MFProvider mfOrder) {
    final isSIP = mfOrder.mfOrderTpye == "SIP";
    final buttonText = isSIP ? "Place - SIP" : "Pay - One Time";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton(
          onPressed:
              mfOrder.investloader ? null : () => _handlePayment(mfOrder),
          style: ElevatedButton.styleFrom(
            backgroundColor: resolveThemeColor(context,
                dark: MyntColors.secondary, light: MyntColors.primary),
            disabledBackgroundColor: resolveThemeColor(context,
                dark: MyntColors.secondary.withOpacity(0.5),
                light: MyntColors.primary.withOpacity(0.5)),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: mfOrder.investloader
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  buttonText,
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  void _showCreateMandateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: MediaQuery.of(context).size.width >= 1100
                ? MediaQuery.of(context).size.width * 0.25
                : MediaQuery.of(context).size.width * 0.9,
            child: const CreateMandateDialogue(),
          ),
        );
      },
    );
  }

  void _switchOrderType(String orderType, MFProvider mfOrder) {
    // Pre-fill amount based on order type
    if (orderType == "One-time") {
      String amt = widget.mfData.minimumPurchaseAmount ?? "0";
      mfOrder.invAmt.text = amt.split('.').first;
    } else {
      String amt = widget.mfData.minimumPurchaseAmount ?? "0";
      mfOrder.installmentAmt.text = amt.split('.').first;
    }

    // Just switch the order type - data was already loaded in initState
    mfOrder.chngOrderType(orderType);
    mfOrder.orderchangetitle(orderType);

    if (mfOrder.orderpagetitle != "NFO") {
      mfOrder.orderpagetite("SDS");
    }
  }

  void _handlePayment(MFProvider mfOrder) async {
    if (mfOrder.investloader) return;

    final isLumpsum = mfOrder.mfOrderTpye == "One-time";

    if (isLumpsum && mfOrder.invAmtError == "") {
      // Place order first
      await mfPlaceorder(widget.mfData, mfOrder, context,
          schemeType: _selectedSchemeType, isAdditional: widget.isAdditional);

      // Only proceed to payment if order was successful
      if (mfOrder.mfPlaceOrderResponces?.stat == 'Ok') {
        Navigator.pop(context);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => mfOrder.ispaymentcalled != true,
            child: Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: MediaQuery.of(context).size.width >= 1100
                    ? MediaQuery.of(context).size.width * 0.30
                    : MediaQuery.of(context).size.width >= 800
                        ? MediaQuery.of(context).size.width * 0.50
                        : MediaQuery.of(context).size.width * 0.90,
                child: MfOrderBottomsheetWeb(
                  data: widget.mfData,
                  condval: 'reinit',
                ),
              ),
            ),
          ),
        );
      }
    } else if (!isLumpsum && mfOrder.installmentAmtError == "") {
      // SIP order - validate mandate and place order directly
      if (mfOrder.mandateData == null || mfOrder.mandateData!.isEmpty) {
        warningMessage(context, "Please create a mandate to proceed with SIP.");
        return;
      }

      if (mfOrder.mandateStatus != "APPROVED") {
        warningMessage(context, "Selected mandate is not approved.");
        return;
      }

      // Resolve scheme code based on scheme type
      String sipBaseCode;
      String? sipL1Code;
      if (_selectedSchemeType == "Divided Payout" &&
          widget.mfData.iDCWSchemeCode != null) {
        sipBaseCode = widget.mfData.iDCWSchemeCode!;
        sipL1Code = widget.mfData.iDCWL1SchemeCode;
      } else if (_selectedSchemeType == "Divided Reinvest" &&
          widget.mfData.reinvSchemeCode != null) {
        sipBaseCode = widget.mfData.reinvSchemeCode!;
        sipL1Code = widget.mfData.reinvL1SchemeCode;
      } else {
        sipBaseCode = widget.mfData.schemeCode ?? '';
        sipL1Code = widget.mfData.l1SchemeCode;
      }
      final double sipAmt = double.tryParse(mfOrder.installmentAmt.text) ?? 0;

      // Validate: if amount >= 2L but L1 scheme not available, block the order
      if (sipAmt >= 200000 && sipL1Code == null) {
        final fundName = widget.mfData.fSchemeName ??
            widget.mfData.name ??
            widget.mfData.schemeName ??
            '';
        warningMessage(context,
            "₹2,00,000+ not available for $_selectedSchemeType in $fundName");
        return;
      }

      final String sipResolvedCode =
          sipAmt >= 200000 ? sipL1Code! : sipBaseCode;


      // Place SIP order directly
      await mfOrder.fetchXsipPlaceOrder(
        context,
        sipResolvedCode,
        mfOrder.freqName == "Daily" ? "0" : mfOrder.startDate,
        mfOrder.freqName,
        mfOrder.installmentAmt.text,
        mfOrder.invDuration.text,
        mfOrder.freqName == "Daily" ? "0" : mfOrder.endDate,
        mfOrder.mandateId,
        widget.isAdditional,
        _firstInstallment,
      );

      // Close all dialogs, then show response cleanly
      if (!mounted) return;

      // If first installment is checked and we got a valid First_order_no,
      // trigger payment flow like lumpsum
      final firstOrderNo = mfOrder.xsipOrderResponces?.firstOrderNo;
      if (_firstInstallment &&
          mfOrder.xsipOrderResponces?.stat == "Ok" &&
          firstOrderNo != null &&
          firstOrderNo != "0" &&
          firstOrderNo.isNotEmpty) {
        // Set mfPlaceOrderResponces so the payment bottomsheet can use it
        mfOrder.setMfPlaceOrderFromSip(
          firstOrderNo,
          mfOrder.installmentAmt.text,
        );

        Navigator.pop(context);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => mfOrder.ispaymentcalled != true,
            child: Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: MediaQuery.of(context).size.width >= 1100
                    ? MediaQuery.of(context).size.width * 0.30
                    : MediaQuery.of(context).size.width >= 800
                        ? MediaQuery.of(context).size.width * 0.50
                        : MediaQuery.of(context).size.width * 0.90,
                child: MfOrderBottomsheetWeb(
                  data: widget.mfData,
                  condval: 'sipfirstorder',
                ),
              ),
            ),
          ),
        );
      } else if (mfOrder.xsipOrderResponces?.stat == "Ok" ||
          mfOrder.xsipOrderResponces?.stat == "Not_Ok") {
        // Pop all dialog routes to get back to the base page
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);

        // Show response on the root
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final rootContext =
              Navigator.of(context, rootNavigator: true).context;
          showDialog(
            context: rootContext,
            barrierDismissible: false,
            builder: (dialogContext) => MfPaymentRespAlert(
              upiData: mfOrder.xsipOrderResponces?.toJson(),
              conditionval: '',
            ),
          );
        });
      }
    } else {
      if (isLumpsum) {
        warningMessage(context, "Enter a valid investment amount.");
      } else {
        warningMessage(context, "Enter a valid installment amount.");
      }
    }
  }

  String _getFundName(MFProvider mfOrder) {
    if (mfOrder.orderpagetitle == "SDS" &&
        mfOrder.factSheetDataModel?.data?.name != null) {
      return mfOrder.factSheetDataModel!.data!.name!
          .replaceAll(RegExp(r'(Reg \(G\)|\(G\))$'), ' ');
    } else if (mfOrder.orderpagetitle == "NFO") {
      return widget.mfData.name ?? '';
    }
    return widget.mfData.fSchemeName ??
        widget.mfData.schemeName ??
        'Unknown Fund';
  }

  String _getSelectedMandateAmount(MFProvider mfOrder) {
    if (mfOrder.mandateData == null || mfOrder.mandateData!.isEmpty) {
      return "0.00";
    }
    final selectedMandate = mfOrder.mandateData!.firstWhere(
      (mandate) => mandate.mandateId == mfOrder.mandateId,
      orElse: () => mfOrder.mandateData!.first,
    );
    return double.parse(selectedMandate.amount ?? "0").toStringAsFixed(2);
  }
}

mfPlaceorder(
  MutualFundList mfData,
  MFProvider mfOrder,
  BuildContext context, {
  String schemeType = "Growth",
  bool isAdditional = false,
}) async {
  // Resolve base scheme code based on selected scheme type
  String baseCode;
  String? l1Code;
  if (schemeType == "Divided Payout" && mfData.iDCWSchemeCode != null) {
    // IDCW Payout scheme; above 2L uses IDCW.L1
    baseCode = mfData.iDCWSchemeCode!;
    l1Code = mfData.iDCWL1SchemeCode;
  } else if (schemeType == "Divided Reinvest" &&
      mfData.reinvSchemeCode != null) {
    // Reinvestment scheme; above 2L uses Reinv.L1
    baseCode = mfData.reinvSchemeCode!;
    l1Code = mfData.reinvL1SchemeCode;
  } else {
    // Growth scheme; above 2L uses root L1
    baseCode = mfData.schemeCode ?? "";
    l1Code = mfData.l1SchemeCode;
  }
  final double orderAmt = double.tryParse(mfOrder.mfOrderTpye == "One-time"
          ? mfOrder.invAmt.text
          : mfOrder.installmentAmt.text) ??
      0;

  // Validate: if amount >= 2L but L1 scheme not available, block the order
  if (orderAmt >= 200000 && l1Code == null) {
    final fundName =
        mfData.fSchemeName ?? mfData.name ?? mfData.schemeName ?? '';
    warningMessage(
        context, "₹2,00,000+ not available for $schemeType in $fundName");
    return;
  }

  final String resolvedCode = orderAmt >= 200000 ? l1Code! : baseCode;

  MfPlaceOrderInput input = MfPlaceOrderInput(
    transcode: "NEW", //NEW/CXL
    schemecode: resolvedCode,
    buysell: "P",
    buyselltype: "FRESH",
    dptxn: "C",
    amount: orderAmt.toInt().toString(),
    allredeem: "N",
    kycstatus: "Y",
    qty: "0",
    euinflag: "Y",
    minredeem: "N",
    dpc: "Y",
  );
  // if (mfOrder.paymentName == "UPI") {
  // mfOrder.fetchVerifyUpi(context, mfOrder.upiId.text, input);
  await mfOrder.placeordermftemp(
      context, mfOrder.upiId.text, input, resolvedCode, orderAmt, isAdditional);
  // }
  // else {
  //   print("netttttelse");
  //   mfOrder.fetchVerifyUpi(context, "", input);
  // }

}

_showBottomSheet(BuildContext context, Widget bottomSheet) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width >= 1100
            ? MediaQuery.of(context).size.width * 0.25
            : MediaQuery.of(context).size.width * 0.90,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: bottomSheet,
      ),
    ),
  );
}

const List<String> _kMonthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

void _showCalendarDialog(
    BuildContext context, dynamic theme, MFProvider mfOrder) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: theme.isDarkMode
            ? MyntColors.overlayBgDark
            : MyntColors.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox(
          width: 380,
          child: _SIPCalendar(
            theme: theme,
            mfOrder: mfOrder,
            onConfirm: (int day, int month, int year) {
              mfOrder.changeInstallmentDate(day, month, year);
              Navigator.pop(context);
            },
          ),
        ),
      );
    },
  );
}

class _SIPCalendar extends StatefulWidget {
  final dynamic theme;
  final MFProvider mfOrder;
  final void Function(int day, int month, int year) onConfirm;

  const _SIPCalendar({
    required this.theme,
    required this.mfOrder,
    required this.onConfirm,
  });

  @override
  State<_SIPCalendar> createState() => _SIPCalendarState();
}

class _SIPCalendarState extends State<_SIPCalendar> {
  int? selectedDate;
  late int selectedMonth;
  late int selectedYear;

  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = widget.mfOrder.sipMonth;
    selectedYear = now.year;

    int? initialDate = int.tryParse(widget.mfOrder.dates);
    if (initialDate != null &&
        widget.mfOrder.dateList.contains(initialDate.toString()) &&
        !_isPastDate(initialDate)) {
      selectedDate = initialDate;
    } else {
      selectedDate = _firstAvailableDate();
    }
  }

  int _daysInMonth() {
    return DateTime(selectedYear, selectedMonth + 1, 0).day;
  }

  int _firstWeekdayOffset() {
    return DateTime(selectedYear, selectedMonth, 1).weekday - 1;
  }

  bool _isPastDate(int day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(selectedYear, selectedMonth, day);
    // Date must be after 2 full working days from today
    // e.g., if today is Mon 7th, 2 working days = Tue 8th & Wed 9th, so first allowed = Thu 10th
    final minDate = _addWorkingDays(today, 2);
    return !date.isAfter(minDate);
  }

  bool _isWeekend(int day) {
    final date = DateTime(selectedYear, selectedMonth, day);
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  /// Returns the date that is [days] working days after [from],
  /// skipping weekends (Saturday & Sunday).
  DateTime _addWorkingDays(DateTime from, int days) {
    int added = 0;
    DateTime current = from;
    while (added < days) {
      current = current.add(const Duration(days: 1));
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        added++;
      }
    }
    return current;
  }

  bool isDateAvailable(int day) {
    return widget.mfOrder.dateList.contains(day.toString());
  }

  int? _firstAvailableDate() {
    final sorted = widget.mfOrder.dateList
        .map((d) => int.tryParse(d))
        .whereType<int>()
        .toList()
      ..sort();
    for (final day in sorted) {
      if (!_isPastDate(day) && !_isWeekend(day)) return day;
    }
    return null;
  }

  void _showMonthPopover(BuildContext btnContext) {
    final btnWidth = (btnContext.findRenderObject() as RenderBox).size.width;
    shadcn.showPopover(
      context: btnContext,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 4),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(btnContext).borderRadiusLg,
      ),
      builder: (popoverContext) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(popoverContext).borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: shadcn.ModalContainer(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: btnWidth - 8,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final isSelected = month == selectedMonth;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          shadcn.closeOverlay(popoverContext);
                          setState(() {
                            selectedMonth = month;
                            if (selectedDate != null &&
                                (_isPastDate(selectedDate!) ||
                                    _isWeekend(selectedDate!) ||
                                    !isDateAvailable(selectedDate!) ||
                                    selectedDate! > _daysInMonth())) {
                              selectedDate = _firstAvailableDate();
                            }
                          });
                        },
                        splashColor: resolveThemeColor(context,
                            dark: MyntColors.rippleDark,
                            light: MyntColors.rippleLight),
                        highlightColor: resolveThemeColor(context,
                            dark: MyntColors.highlightDark,
                            light: MyntColors.highlightLight),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Text(
                            _kMonthNames[index],
                            style: MyntWebTextStyles.body(
                              context,
                              fontWeight: isSelected
                                  ? MyntFonts.semiBold
                                  : MyntFonts.medium,
                              color: isSelected
                                  ? resolveThemeColor(context,
                                      dark: MyntColors.primaryDark,
                                      light: MyntColors.primary)
                                  : resolveThemeColor(context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showYearPopover(BuildContext btnContext) {
    final btnWidth = (btnContext.findRenderObject() as RenderBox).size.width;
    final currentYear = DateTime.now().year;
    final years = List.generate(3, (i) => currentYear + i);
    shadcn.showPopover(
      context: btnContext,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 4),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(btnContext).borderRadiusLg,
      ),
      builder: (popoverContext) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(popoverContext).borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: shadcn.ModalContainer(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: btnWidth - 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: years.map((year) {
                  final isSelected = year == selectedYear;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        shadcn.closeOverlay(popoverContext);
                        setState(() {
                          selectedYear = year;
                          if (selectedDate != null &&
                              (_isPastDate(selectedDate!) ||
                                  _isWeekend(selectedDate!) ||
                                  !isDateAvailable(selectedDate!) ||
                                  selectedDate! > _daysInMonth())) {
                            selectedDate = _firstAvailableDate();
                          }
                        });
                      },
                      splashColor: resolveThemeColor(context,
                          dark: MyntColors.rippleDark,
                          light: MyntColors.rippleLight),
                      highlightColor: resolveThemeColor(context,
                          dark: MyntColors.highlightDark,
                          light: MyntColors.highlightLight),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Text(
                          year.toString(),
                          style: MyntWebTextStyles.body(
                            context,
                            fontWeight: isSelected
                                ? MyntFonts.semiBold
                                : MyntFonts.medium,
                            color: isSelected
                                ? resolveThemeColor(context,
                                    dark: MyntColors.primaryDark,
                                    light: MyntColors.primary)
                                : resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final offset = _firstWeekdayOffset();
    final daysInMonth = _daysInMonth();
    final totalCells = offset + daysInMonth;
    final bool isDark = widget.theme.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: resolveThemeColor(context,
              dark: MyntColors.dividerDark, light: MyntColors.divider),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
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
                    "Select SIP Installment Date",
                    style: MyntWebTextStyles.title(
                      context,
                      fontWeight: MyntFonts.semiBold,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
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

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month + Year dropdowns
                  Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (btnContext) => GestureDetector(
                            onTap: () => _showMonthPopover(btnContext),
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: resolveThemeColor(context,
                                    dark: MyntColors.transparent,
                                    light: const Color(0xffF1F3F8)),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.outlinedBorder),
                                ),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _kMonthNames[selectedMonth - 1],
                                      style: MyntWebTextStyles.body(
                                        context,
                                        darkColor: MyntColors.textPrimaryDark,
                                        lightColor: MyntColors.textPrimary,
                                        fontWeight: MyntFonts.medium,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Builder(
                          builder: (btnContext) => GestureDetector(
                            onTap: () => _showYearPopover(btnContext),
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: resolveThemeColor(context,
                                    dark: MyntColors.transparent,
                                    light: const Color(0xffF1F3F8)),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.outlinedBorder),
                                ),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      selectedYear.toString(),
                                      style: MyntWebTextStyles.body(
                                        context,
                                        darkColor: MyntColors.textPrimaryDark,
                                        lightColor: MyntColors.textPrimary,
                                        fontWeight: MyntFonts.medium,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Weekday header
                  Row(
                    children: _weekDays
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: MyntWebTextStyles.caption(
                                    context,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 4),

                  // Calendar grid (max 6 rows needed)
                  SizedBox(
                    height: 300,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: totalCells,
                      itemBuilder: (context, index) {
                        if (index < offset) return const SizedBox.shrink();
                        final day = index - offset + 1;
                        return _buildDayBox(context, day);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendDot(
                          context,
                          isDark
                              ? MyntColors.listItemBgDark
                              : const Color(0xffF1F3F8),
                          "Available"),
                      const SizedBox(width: 12),
                      _legendDot(
                          context,
                          isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFE0E0E0),
                          "Unavailable"),
                      const SizedBox(width: 12),
                      _legendDot(
                          context,
                          isDark
                              ? const Color(0xFF3A2222)
                              : const Color(0xFFFCE4E4),
                          "Past"),
                    ],
                  ),
                ],
              ),
            ), // end Body Padding

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  onPressed: selectedDate != null
                      ? () => widget.onConfirm(
                          selectedDate!, selectedMonth, selectedYear)
                      : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: resolveThemeColor(context,
                        dark: MyntColors.secondary, light: MyntColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: Text(
                    "Confirm",
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      fontWeight: MyntFonts.semiBold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: MyntWebTextStyles.caption(
            context,
            color: resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildDayBox(BuildContext context, int day) {
    final bool isAvailable = isDateAvailable(day);
    final bool isPast = _isPastDate(day);
    final bool isWeekend = _isWeekend(day);
    final bool isSelected = selectedDate == day;
    final bool isSelectable = isAvailable && !isPast && !isWeekend;
    final bool isDark = widget.theme.isDarkMode;

    Color bgColor;
    Color textColor;

    if (isSelected) {
      bgColor = resolveThemeColor(context,
          dark: MyntColors.secondary, light: MyntColors.primary);
      textColor = Colors.white;
    } else if (isSelectable) {
      bgColor = isDark ? MyntColors.listItemBgDark : const Color(0xffF1F3F8);
      textColor = isDark ? colors.textPrimaryDark : colors.colorBlack;
    } else if (isPast) {
      bgColor = isDark ? const Color(0xFF3A2222) : const Color(0xFFFCE4E4);
      textColor = isDark ? const Color(0xFF8B5555) : const Color(0xFFD48A8A);
    } else {
      bgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
      textColor = isDark ? const Color(0xFF555555) : const Color(0xFFBDBDBD);
    }

    return GestureDetector(
      onTap: isSelectable ? () => setState(() => selectedDate = day) : null,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            day.toString(),
            style: MyntWebTextStyles.para(
              context,
              fontWeight: MyntFonts.medium,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

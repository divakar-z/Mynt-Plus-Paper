import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/provider/profile_all_details_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/res/global_state_text.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/common_text_fields_web.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import 'package:mynt_plus/utils/digio_esign.dart';
import 'package:mynt_plus/routes/route_names.dart';
import 'package:mynt_plus/utils/custom_navigator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class ProfileSectionScreenWeb extends ConsumerStatefulWidget {
  final String sectionTitle;
  final VoidCallback? onBack;

  const ProfileSectionScreenWeb({
    super.key,
    required this.sectionTitle,
    this.onBack,
  });

  @override
  ConsumerState<ProfileSectionScreenWeb> createState() =>
      _ProfileSectionScreenWebState();
}

class _ProfileSectionScreenWebState
    extends ConsumerState<ProfileSectionScreenWeb> {
  bool _mtfSubmitLoading = false;
  bool _mtfCancelLoading = false;
  bool _ddpiActivateLoading = false;
  bool _ddpiCancelLoading = false;
  bool _ddpiEsignLoading = false;
  bool _closureEsignLoading = false;
  bool _closureCancelLoading = false;
  bool _closureInitiateLoading = false;
  bool _mtfEsignLoading = false;
  bool _bankEsignLoading = false;
  bool _bankCancelLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(profileAllDetailsProvider).fetchClientProfileAllDetails();
      ref.read(profileAllDetailsProvider).fetchPendingstatus();
      ref.read(profileAllDetailsProvider).fetchMobEmailStatus();
    });
  }

  // ─── Personal-info edit gate (closed → non-individual → inactive → 7-day).
  // Used by DDPI activation. Re-KYC is intentionally skipped here per spec.
  // `checkLast7Days` opts out of the post-activation 7-day block: the rule
  // covers mobile/email/primary bank/bank deletion/nominee modification only,
  // so activities like DDPI must stay available inside that window.
  String? _personalInfoEditBlockReason({
    required bool checkRekyc,
    bool checkLast7Days = true,
  }) {
    final provider = ref.read(profileAllDetailsProvider);
    final clientData = provider.clientAllDetails.clientData;
    final mobStatus = provider.mobEmailStatus;
    if (clientData == null || mobStatus == null) return null;

    if (clientData.isClientClosed) {
      return 'Your trading account is closed.';
    }
    if (!clientData.isIndividual) {
      return "Non-individual accounts can't modify data here. "
          "Please contact support at (+91) 93 8010 8010 for help.";
    }
    if ((mobStatus.accSgtAtveSts ?? '').toLowerCase() != 'active') {
      return 'Modification not allowed for inactive client codes. '
          'Please reactivate the account.';
    }
    if (checkLast7Days && mobStatus.last7DaysCheck != true) {
      return 'Modification request not allowed within 7 days of activation';
    }
    if (checkRekyc && provider.rekycStatus.toLowerCase() == 'yes') {
      return 'Modification not allowed while Re-KYC is in progress.';
    }
    return null;
  }

  // ─── Bank logo URL ───
  // The logo is keyed by the 4-character bank code that prefixes the IFSC.
  // Guarded because a malformed/short IFSC would otherwise throw a RangeError
  // and take the whole bank list down.
  String _bankLogoUrl(String? ifsc) {
    final code = (ifsc ?? '').trim();
    final bank = (code.length >= 4 ? code.substring(0, 4) : code).toLowerCase();
    return 'https://rekycbe.mynt.in/static/logos/$bank/symbol.svg';
  }

  // ─── Pending status helpers ───

  List<String> _getPendingStatusesForSection(
      String sectionTitle, WidgetRef ref) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    if (profileDetails.pendingStatusList.isEmpty ||
        profileDetails.pendingStatusList[0].data == null ||
        profileDetails.pendingStatusList[0].data!.isEmpty) {
      return [];
    }

    final pendingStatuses = profileDetails.pendingStatusList[0].data!;

    switch (sectionTitle) {
      case 'Bank':
        return pendingStatuses
            .where((status) => status == 'bank_change_pending')
            .toList();
      case 'Depository':
        return pendingStatuses
            .where((status) => status == 'ddpicre_pending')
            .toList();
      case 'Margin Trading Facility (MTF)':
        return pendingStatuses
            .where((status) => status == 'mtf_pending')
            .toList();
      case 'Trading Preferences':
        return pendingStatuses
            .where((status) => status == 'segments_change_pending')
            .toList();
      case 'Nominee':
        return pendingStatuses
            .where((status) => status == 'nominee_pending')
            .toList();
      case 'Closure':
        return pendingStatuses
            .where((status) => status == 'closure_pending')
            .toList();
      case 'Form Download':
        return [];
      default:
        return [];
    }
  }

  String _getPendingStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'address_change_pending':
        return 'Address Change';
      case 'bank_change_pending':
        return 'Bank Change';
      case 'closure_pending':
        return 'Account Closure';
      case 'ddpicre_pending':
        return 'DPICRE';
      case 'email_change_pending':
        return 'Email Change';
      case 'income_change_pending':
        return 'Income Change';
      case 'mobile_change_pending':
        return 'Mobile Change';
      case 'mtf_pending':
        return 'MTF';
      case 'nominee_pending':
        return 'Nominee';
      case 'segments_change_pending':
        return 'Segments Change';
      default:
        return status
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                : word)
            .join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final bgColor = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 28, 20),
            child: Row(
              children: [
                if (widget.onBack != null) ...[
                  CustomBackBtn(onBack: widget.onBack),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.sectionTitle,
                    style: MyntWebTextStyles.title(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.semiBold,
                    ).copyWith(decoration: TextDecoration.none),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _buildSectionContent(ref, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent(WidgetRef ref, ThemesProvider theme) {
    switch (widget.sectionTitle) {
      case 'Bank':
        return _buildBankDetailsContent(ref, theme);
      case 'Depository':
        return _buildDepositoryContent(ref, theme);
      case 'Margin Trading Facility (MTF)':
        return _buildMTFContent(ref, theme);
      case 'Trading Preferences':
        return _buildTradingPreferencesContent(ref, theme);
      case 'Nominee':
        return _buildNomineeContent(ref, theme);
      case 'Form Download':
        return _buildFormDownloadContent(ref, theme);
      case 'Closure':
        return _buildClosureContent(ref, theme);
      default:
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextWidget.paraText(
            text: 'Details for ${widget.sectionTitle} will be shown here.',
            color: colors.colorGrey,
            theme: theme.isDarkMode,
          ),
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  BANK SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBankDetailsContent(WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final bankData = profileDetails.clientAllDetails.bankData;
    final clientData = profileDetails.clientAllDetails.clientData;
    final mobStatus = profileDetails.mobEmailStatus;
    final statusLoading = profileDetails.mobEmailStatusLoading;
    final bankStatus = mobStatus?.bankStatus ?? '';
    final isPending = bankStatus == 'e-signed pending';
    final isInProcess = bankStatus == 'e-signed completed';
    final actionsDisabled = isPending || isInProcess;
    // Account-level gates from mobEmailStatus / clientData payload.
    final isAccountActive =
        (mobStatus?.accSgtAtveSts ?? '').toLowerCase() == 'active';
    final isPast7Days = mobStatus?.last7DaysCheck == true;
    final bool isClientClosed = clientData?.isClientClosed ?? false;
    final bool isIndividual = clientData?.isIndividual ?? true;

    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final cardBorder = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Add Bank button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Bank Accounts",
                style: MyntWebTextStyles.title(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium,
                ).copyWith(decoration: TextDecoration.none),
              ),
              if (statusLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                )
              else if (!actionsDisabled)
                Builder(builder: (context) {
                  final atMaxBanks = bankData != null && bankData.length >= 5;
                  // Adding a bank is a secondary-bank addition (nothing here
                  // sets defaultAc), so it is exempt from the 7-day
                  // post-activation block — only primary-bank changes and
                  // deletions are restricted.
                  final addDisabled = atMaxBanks ||
                      isClientClosed ||
                      !isIndividual ||
                      !isAccountActive;
                  final addTooltip = atMaxBanks
                      ? "Maximum bank accounts reached."
                      : isClientClosed
                          ? "Your trading account is closed."
                          : !isAccountActive
                              ? "Modification not allowed for inactive client codes. "
                                  "Please reactivate the account."
                              : !isIndividual
                                  ? "Non-individual accounts can't modify data here. "
                                      "Please contact support at (+91) 93 8010 8010 for help."
                                  : "";
                  final addButton = Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: addDisabled
                          ? null
                          : () => _showAddEditBankDialog(theme),
                      borderRadius: BorderRadius.circular(3),
                      child: Opacity(
                        opacity: addDisabled ? 0.5 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: resolveThemeColor(context,
                                dark: MyntColors.secondary,
                                light: MyntColors.primary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 15, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                "Add Bank",
                                style: MyntWebTextStyles.bodySmall(context,
                                  color: Colors.white,
                                  fontWeight: MyntFonts.semiBold,
                                ).copyWith(decoration: TextDecoration.none),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                  return addDisabled
                      ? Tooltip(message: addTooltip, child: addButton)
                      : addButton;
                }),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "View bank details and manage linked accounts",
            style: MyntWebTextStyles.para(context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
              fontWeight: MyntFonts.regular,
            ).copyWith(decoration: TextDecoration.none),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, thickness: 1, color: dividerColor),

          // Bank list — hidden entirely when account is closed.
          if (isClientClosed)
            const SizedBox.shrink()
          else if (bankData == null || bankData.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.account_balance_outlined, size: 40,
                        color: subtitleColor),
                    const SizedBox(height: 12),
                    Text(
                      "No bank accounts found",
                      style: MyntWebTextStyles.body(context,
                        color: subtitleColor,
                        fontWeight: MyntFonts.medium,
                      ).copyWith(decoration: TextDecoration.none),
                    ),
                  ],
                ),
              ),
            )
          else
            ...bankData.asMap().entries.map((entry) {
              final index = entry.key;
              final bank = entry.value;
              final bankIsPrimary = bank.defaultAc == "Yes";

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bank Logo
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: resolveThemeColor(context,
                                dark: MyntColors.cardHoverDark,
                                light: MyntColors.cardHover),
                            border: Border.all(color: dividerColor),
                          ),
                          child: ClipOval(
                            child: SvgPicture.network(
                              _bankLogoUrl(bank.iFSCCode),
                              fit: BoxFit.contain,
                              height: 22,
                              width: 22,
                              placeholderBuilder: (context) => Icon(
                                Icons.account_balance,
                                color: subtitleColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Bank details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bank name + PRIMARY badge
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      bank.bankName ?? "Unknown Bank",
                                      style: MyntWebTextStyles.body(context,
                                        darkColor: MyntColors.textPrimaryDark,
                                        lightColor: MyntColors.textPrimary,
                                        fontWeight: MyntFonts.semiBold,
                                      ).copyWith(decoration: TextDecoration.none),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (bankIsPrimary) ...[
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "PRIMARY",
                                        style: MyntWebTextStyles.caption(context,
                                          color: primaryColor,
                                          fontWeight: MyntFonts.semiBold,
                                        ).copyWith(
                                          decoration: TextDecoration.none,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Account details in flat columns
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final fields = [
                                    ['ACCOUNT NUMBER', bank.bankAcNo ?? 'N/A'],
                                    ['IFSC CODE', bank.iFSCCode ?? 'N/A'],
                                    ['ACCOUNT TYPE', bank.bANKACCTYPE ?? 'N/A'],
                                  ];

                                  if (constraints.maxWidth < 300) {
                                    return Column(
                                      children: fields
                                          .map((f) => Padding(
                                                padding: const EdgeInsets.only(bottom: 12),
                                                child: _buildBankFieldFlat(
                                                    f[0], f[1], subtitleColor,
                                                    textColor, dividerColor),
                                              ))
                                          .toList(),
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (int i = 0; i < fields.length; i++) ...[
                                        Expanded(
                                          child: _buildBankFieldFlat(
                                            fields[i][0], fields[i][1],
                                            subtitleColor, textColor, dividerColor,
                                          ),
                                        ),
                                        if (i < fields.length - 1)
                                          const SizedBox(width: 24),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Action buttons
                        if (statusLoading)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryColor,
                              ),
                            ),
                          )
                        else if (!actionsDisabled)
                          Builder(builder: (context) {
                            final editDisabled = isClientClosed ||
                                !isIndividual ||
                                !isAccountActive ||
                                !isPast7Days;
                            final editTooltip = !isAccountActive
                                ? "Modification not allowed for inactive client codes. "
                                    "Please reactivate the account."
                                : !isIndividual
                                    ? "Non-individual accounts can't modify data here. "
                                        "Please contact support at (+91) 93 8010 8010 for help."
                                    : !isPast7Days
                                        ? "Modification request not allowed within 7 days of activation."
                                        : "Edit";
                            final setPrimaryDisabled =
                                isClientClosed || !isPast7Days;
                            final setPrimaryTooltip = !isPast7Days
                                ? "Modification request not allowed within 7 days of activation."
                                : "";
                            // Bank deletion is restricted within 7 days of
                            // activation/reactivation, same as Set as Primary.
                            final deleteDisabled =
                                isClientClosed || !isPast7Days;
                            final deleteTooltip = !isPast7Days
                                ? "Modification request not allowed within 7 days of activation."
                                : "";
                            final editIcon = InkWell(
                              onTap: editDisabled
                                  ? null
                                  : () => _showAddEditBankDialog(theme,
                                      editingBank: bank),
                              borderRadius: BorderRadius.circular(16),
                              child: Opacity(
                                opacity: editDisabled ? 0.4 : 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined,
                                          size: 16, color: primaryColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        "EDIT",
                                        style: MyntWebTextStyles.caption(
                                          context,
                                          color: primaryColor,
                                          fontWeight: MyntFonts.semiBold,
                                        ).copyWith(
                                          letterSpacing: 0.5,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            return Column(
                              children: [
                                // Edit icon
                                Tooltip(
                                  message: editTooltip,
                                  child: editIcon,
                                ),
                                // More options for non-primary
                                if (!bankIsPrimary) ...[
                                  const SizedBox(height: 4),
                                  PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  constraints:
                                      const BoxConstraints(minWidth: 160),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  color: cardBg,
                                  onSelected: (value) {
                                    if (value == 'set_primary') {
                                      if (setPrimaryDisabled) return;
                                      _showSetPrimaryDialog(bank, theme);
                                    } else if (value == 'delete') {
                                      if (deleteDisabled) return;
                                      _showDeleteBankDialog(bank, theme,
                                          isIndividual: isIndividual,
                                          isPast7Days: isPast7Days);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem<String>(
                                      value: 'set_primary',
                                      enabled: !setPrimaryDisabled,
                                      child: Tooltip(
                                        message: setPrimaryTooltip,
                                        child: Text("Set as Primary",
                                          style: MyntWebTextStyles.bodySmall(
                                              context,
                                            darkColor: MyntColors.textPrimaryDark,
                                            lightColor: MyntColors.textPrimary,
                                            fontWeight: MyntFonts.medium,
                                          ).copyWith(
                                              decoration: TextDecoration.none),
                                        ),
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      enabled: !deleteDisabled,
                                      child: Tooltip(
                                        message: deleteTooltip,
                                        child: Text("Delete",
                                          style: MyntWebTextStyles.bodySmall(
                                              context,
                                            color: Colors.red,
                                            fontWeight: MyntFonts.medium,
                                          ).copyWith(
                                              decoration: TextDecoration.none),
                                        ),
                                      ),
                                    ),
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(Icons.more_horiz, size: 16,
                                        color: subtitleColor),
                                  ),
                                ),
                              ],
                            ],
                          );
                          }),
                      ],
                    ),
                  ),
                  if (index < bankData.length - 1)
                    Divider(height: 1, thickness: 1, color: dividerColor),
                ],
              );
            }),

          // Status banners
          if (isPending) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final warningBg = resolveThemeColor(context,
                  dark: const Color(0xFF3D2E00), light: const Color(0xFFFCEFD4));
              final warningText = resolveThemeColor(context,
                  dark: const Color(0xFFFFD780), light: Colors.brown[800]!);
              final warningIcon = resolveThemeColor(context,
                  dark: MyntColors.warningDark, light: MyntColors.warning);
              final errorColor = resolveThemeColor(context,
                  dark: MyntColors.errorDark, light: MyntColors.error);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: warningIcon, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Esign Pending - Click here to complete',
                            style: MyntWebTextStyles.bodySmall(context,
                                color: warningText, fontWeight: MyntFonts.medium)
                                .copyWith(decoration: TextDecoration.none),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _bankEsignLoading
                            ? SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: primaryColor))
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _openBankEsign(),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Text('Click here E-sign',
                                        style: MyntWebTextStyles.bodySmall(context,
                                            color: primaryColor,
                                            fontWeight: MyntFonts.semiBold)
                                            .copyWith(decoration: TextDecoration.none)),
                                  ),
                                ),
                              ),
                        const SizedBox(width: 4),
                        _bankCancelLoading
                            ? SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: errorColor))
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showCancelBankRequestDialog(theme),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Text('Cancel request',
                                        style: MyntWebTextStyles.bodySmall(context,
                                            color: errorColor,
                                            fontWeight: MyntFonts.semiBold)
                                            .copyWith(decoration: TextDecoration.none)),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],

          if (isInProcess) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final successBg = resolveThemeColor(context,
                  dark: const Color(0xFF0A3D1E), light: const Color(0xFFE6F9ED));
              final successText = resolveThemeColor(context,
                  dark: MyntColors.successDark, light: MyntColors.success);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, size: 20,
                        color: successText),
                    const SizedBox(width: 12),
                    Text(
                      "Your Bank Change request is in process",
                      style: MyntWebTextStyles.bodySmall(context,
                        color: successText,
                        fontWeight: MyntFonts.medium,
                      ).copyWith(decoration: TextDecoration.none),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 16),

          // Regulation note / max-reached warning
          Builder(builder: (context) {
            final atMaxBanks = bankData != null && bankData.length >= 5;
            if (atMaxBanks) {
              final warningColor = resolveThemeColor(context,
                  dark: MyntColors.errorDark, light: MyntColors.error);
              return Text(
                "You have reached the maximum of 5 linked bank accounts.",
                style: MyntWebTextStyles.caption(context,
                  color: warningColor,
                  fontWeight: MyntFonts.medium,
                ).copyWith(
                  decoration: TextDecoration.none,
                  fontStyle: FontStyle.italic,
                ),
              );
            }
            return Text(
              "*As per the regulation, you can have up to 5 bank a/c linked to trading a/c",
              style: MyntWebTextStyles.caption(context,
                darkColor: MyntColors.textTertiaryDark,
                lightColor: MyntColors.textTertiary,
                fontWeight: MyntFonts.regular,
              ).copyWith(
                decoration: TextDecoration.none,
                fontStyle: FontStyle.italic,
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Flat field row for bank details: label + value + underline
  Widget _buildBankFieldFlat(String label, String value,
      Color subtitleColor, Color textColor, Color dividerColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MyntWebTextStyles.caption(context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
            fontWeight: MyntFonts.semiBold,
          ).copyWith(
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value.isNotEmpty ? value : "N/A",
          style: MyntWebTextStyles.body(context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.medium,
          ).copyWith(decoration: TextDecoration.none),
        ),
        const SizedBox(height: 10),
        Divider(height: 1, thickness: 1, color: dividerColor),
      ],
    );
  }

  // ─── Bank E-Sign via Digio ───
  Future<void> _openBankEsign() async {
    final provider = ref.read(profileAllDetailsProvider);
    final mobStatus = provider.mobEmailStatus;
    final fileId = mobStatus?.bankFileId ?? '';
    final email = (mobStatus?.bankClientEmail ?? '').toLowerCase();
    final session = mobStatus?.bankSession ?? '';

    if (fileId.isEmpty || email.isEmpty) {
      warningMessage(context, 'E-Sign details not available');
      return;
    }

    setState(() => _bankEsignLoading = true);

    try {
      final result = await startDigioEsign(
        fileId: fileId,
        email: email,
        session: session,
      );

      if (fileId.isNotEmpty) {
        provider.reportFiledownload(
          fileId: fileId,
          response: result,
          type: 'bank_change',
        );
      }

      provider.fetchClientProfileAllDetails();
      provider.fetchMobEmailStatus();

      if (mounted) {
        if (result == 'success') {
          successMessage(context, 'E-Sign completed successfully');
        } else {
          warningMessage(context, 'E-Sign was cancelled');
        }
      }
    } finally {
      if (mounted) setState(() => _bankEsignLoading = false);
    }
  }

  // ─── Cancel Bank Request Dialog ───
  void _showCancelBankRequestDialog(ThemesProvider theme) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.dialogDark, light: MyntColors.dialog),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with divider
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: resolveThemeColor(context,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cancel request?',
                      style: MyntWebTextStyles.title(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Are you sure you want to cancel your "Bank Change" request?',
                      textAlign: TextAlign.center,
                      style: MyntWebTextStyles.body(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _cancelBankRequest();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: resolveThemeColor(context,
                              dark: MyntColors.errorDark,
                              light: MyntColors.tertiary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: MyntWebTextStyles.buttonMd(
                            context,
                            color: Colors.white,
                          ),
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
  }

  // ─── Cancel Bank Request ───
  Future<void> _cancelBankRequest() async {
    final provider = ref.read(profileAllDetailsProvider);
    setState(() => _bankCancelLoading = true);
    try {
      provider.cancelPendingloader(true);
      final fileid = await provider.api.fetctfileidapi('bank_change');
      final response =
          await provider.api.cancelPendingStatusApi('bank_change', fileid ?? '');
      if (response == 'Cancel Success') {
        await provider.fetchMobEmailStatus();
        await provider.fetchPendingstatus();
        if (mounted) successMessage(context, 'Esign Cancellation Success');
      } else {
        if (mounted) warningMessage(context, 'Esign Cancellation Failed');
      }
    } catch (e) {
      if (mounted) warningMessage(context, 'Something Went Wrong');
    } finally {
      provider.cancelPendingloader(false);
      if (mounted) setState(() => _bankCancelLoading = false);
    }
  }

  // ─── Delete Bank Confirmation Dialog ───
  void _showDeleteBankDialog(dynamic bank, ThemesProvider theme,
      {bool isIndividual = true, bool isPast7Days = true}) {
    final deleteCtaDisabled = !isIndividual || !isPast7Days;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: Container(
              width: 400,
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: resolveThemeColor(ctx,
                    dark: MyntColors.dialogDark, light: MyntColors.dialog),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: shadcn.Theme.of(ctx).colorScheme.border),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Delete Bank',
                          style: MyntWebTextStyles.title(
                            ctx,
                            color: resolveThemeColor(
                              ctx,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                        ),
                        MyntCloseButton(onPressed: () => Navigator.of(ctx).pop()),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Are you sure you want to delete "${bank.bankName ?? ''} (${bank.bankAcNo ?? ''})"?',
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.body(
                              ctx,
                              fontWeight: FontWeight.w500,
                              color: resolveThemeColor(
                                ctx,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Opacity(
                            opacity: deleteCtaDisabled ? 0.5 : 1.0,
                            child: MyntButton(
                              type: MyntButtonType.primary,
                              size: MyntButtonSize.large,
                              label: 'Delete',
                              isFullWidth: true,
                              backgroundColor: resolveThemeColor(
                                ctx,
                                dark: MyntColors.errorDark,
                                light: MyntColors.tertiary,
                              ),
                              onPressed: deleteCtaDisabled
                                  ? null
                                  : () {
                                      Navigator.of(ctx).pop();
                                      _deleteBankAction(bank);
                                    },
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
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
            parent: animation, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _deleteBankAction(dynamic bank) async {
    final provider = ref.read(profileAllDetailsProvider);
    final result = await provider.addBankWeb(
      option: 'delete',
      accountNo: bank.bankAcNo ?? '',
      bankName: bank.bankName ?? '',
      ifsc: bank.iFSCCode ?? '',
      branch: '',
      bankAccountType: bank.bANKACCTYPE ?? 'Saving',
      setDefault: bank.defaultAc == 'Yes' ? 'Yes' : 'No',
      micr: bank.micrCode ?? '',
    );
    if (result != null && !result.containsKey('msg')) {
      _showBankEsignConfirmationDialog(ref.read(themeProvider));
    } else {
      if (mounted) {
        warningMessage(
            context, result?['msg']?.toString() ?? 'Delete failed');
      }
    }
  }

  // ─── Set as Primary Confirmation Dialog ───
  void _showSetPrimaryDialog(dynamic bank, ThemesProvider theme) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: Container(
              width: 400,
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: resolveThemeColor(ctx,
                    dark: MyntColors.dialogDark, light: MyntColors.dialog),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: shadcn.Theme.of(ctx).colorScheme.border),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Set as Primary',
                          style: MyntWebTextStyles.title(
                            ctx,
                            color: resolveThemeColor(
                              ctx,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                        ),
                        MyntCloseButton(onPressed: () => Navigator.of(ctx).pop()),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Are you sure you want to set "${bank.bankName ?? ''} (${bank.bankAcNo ?? ''})" as primary?',
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.body(
                              ctx,
                              fontWeight: FontWeight.w500,
                              color: resolveThemeColor(
                                ctx,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          MyntPrimaryButton(
                            size: MyntButtonSize.large,
                            label: 'Set as Primary',
                            isFullWidth: true,
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _setPrimaryBankAction(bank);
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
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
            parent: animation, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _setPrimaryBankAction(dynamic bank) async {
    final provider = ref.read(profileAllDetailsProvider);
    final result = await provider.addBankWeb(
      option: 'modify',
      accountNo: bank.bankAcNo ?? '',
      bankName: bank.bankName ?? '',
      ifsc: bank.iFSCCode ?? '',
      branch: '',
      bankAccountType: bank.bANKACCTYPE ?? 'Saving',
      setDefault: 'Yes',
      micr: bank.micrCode ?? '',
    );
    if (result != null && !result.containsKey('msg')) {
      _showBankEsignConfirmationDialog(ref.read(themeProvider));
    } else {
      if (mounted) {
        warningMessage(
            context, result?['msg']?.toString() ?? 'Set primary failed');
      }
    }
  }

  // ─── E-Sign Confirmation Dialog (after add/edit/delete/set-primary) ───
  void _showBankEsignConfirmationDialog(ThemesProvider theme) {
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with divider
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: dividerColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('E-Sign Is Pending!',
                        style: MyntWebTextStyles.title(context, color: textColor)),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          Navigator.pop(ctx);
                          ref.read(profileAllDetailsProvider).fetchMobEmailStatus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(Icons.close, size: 20, color: subtitleColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Your Bank request is not yet Completed.',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.body(context, color: textColor)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openBankEsign();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: resolveThemeColor(context,
                              dark: MyntColors.secondary, light: MyntColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text('Click here E-sign',
                            style: MyntWebTextStyles.buttonMd(context,
                                color: Colors.white)),
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
  }

  // ─── Add / Edit Bank Dialog ───
  void _showAddEditBankDialog(ThemesProvider theme, {dynamic editingBank}) {
    final isDark = theme.isDarkMode;
    final isEdit = editingBank != null;
    final provider = ref.read(profileAllDetailsProvider);
    final bankData = provider.clientAllDetails.bankData;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _BankChangeDialog(
              isDark: isDark,
              isEdit: isEdit,
              editingBank: editingBank,
              bankCount: bankData?.length ?? 0,
              onSubmit: (
                  {required String acType,
                  required String acNo,
                  required String ifsc,
                  required String proof,
                  required bool primary,
                  List<int>? fileBytes,
                  String? fileName,
                  String? password,
                  bool? passwordRequired,
                  String? bankName,
                  String? branch,
                  String? micr}) async {
                final result = await provider.addBankWeb(
                  option: isEdit ? 'modify' : 'add',
                  accountNo: acNo,
                  bankName: bankName ?? '',
                  ifsc: ifsc,
                  branch: branch ?? '',
                  bankAccountType: acType,
                  setDefault: primary ? 'Yes' : 'No',
                  micr: micr ?? '',
                  proffType: proof.isNotEmpty ? proof : null,
                  proofBytes: fileBytes,
                  proofFileName: fileName,
                  passwordRequired:
                      (passwordRequired == true) ? 'true' : null,
                  password: password,
                );
                return result;
              },
              onDone: () {
                Navigator.pop(ctx);
                _showBankEsignConfirmationDialog(theme);
              },
              provider: provider,
            );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DEPOSITORY SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDepositoryContent(WidgetRef ref, ThemesProvider theme) {
    final profileprovider = ref.watch(profileAllDetailsProvider);
    final themeVal = ref.watch(themeProvider);
    final mobStatus = profileprovider.mobEmailStatus;
    final clientData = profileprovider.clientAllDetails.clientData;
    final ddpiActive = clientData?.dDPI == 'Y';
    final poaActive = clientData?.pOA == 'Y';
    final ddpiStatus = mobStatus?.dDPIStatus ?? '';
    // Account-level gates for the Activate DDPI button.
    final bool isClientClosed = clientData?.isClientClosed ?? false;
    final bool isIndividual = clientData?.isIndividual ?? true;
    final bool isAccountActive =
        (mobStatus?.accSgtAtveSts ?? '').toLowerCase() == 'active';

    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final cardBorder = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    final dpCode = profileprovider
            .clientAllDetails.clientData?.cLIENTDPCODE ?? '';
    final dpId = dpCode.length >= 8 ? dpCode.substring(0, 8) : dpCode;
    final boId = dpCode.length > 8 ? dpCode.substring(8) : '';
    final dpName =
        profileprovider.clientAllDetails.clientData?.dPNAME ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      decoration: BoxDecoration(
      color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row with DDPI/POA status chips ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Depository Details",
                style: MyntWebTextStyles.title(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium,
                ).copyWith(decoration: TextDecoration.none),
              ),
              Row(
                children: [
                  _buildStatusChipDepository(
                      "DDPI", ddpiActive, primaryColor),
                  const SizedBox(width: 8),
                  _buildStatusChipDepository(
                      "POA", poaActive, primaryColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "CDSL depository participant information",
            style: MyntWebTextStyles.para(context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
              fontWeight: MyntFonts.regular,
            ).copyWith(decoration: TextDecoration.none),
          ),
          const SizedBox(height: 24),

          // ── Flat fields in 3-column layout ──
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                ['DP ID', dpId],
                ['BO ID', boId],
                ['DP NAME', dpName],
              ];

              if (constraints.maxWidth < 500) {
                return Column(
                  children: fields
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildDepositoryField(
                                f[0], f[1], dividerColor),
                          ))
                      .toList(),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < fields.length; i++) ...[
                    Expanded(
                      child: _buildDepositoryField(
                          fields[i][0], fields[i][1], dividerColor),
                    ),
                    if (i < fields.length - 1)
                      const SizedBox(width: 32),
                  ],
                ],
              );
            },
          ),

          // ── DDPI Pending Banner ──
          if (ddpiStatus == 'e-signed pending') ...[
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final warningBg = resolveThemeColor(context,
                  dark: const Color(0xFF3D2E00), light: const Color(0xFFFCEFD4));
              final warningText = resolveThemeColor(context,
                  dark: const Color(0xFFFFD780), light: Colors.brown[800]!);
              final warningIcon = resolveThemeColor(context,
                  dark: MyntColors.warningDark, light: MyntColors.warning);
              final errorColor = resolveThemeColor(context,
                  dark: MyntColors.errorDark, light: MyntColors.error);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: warningIcon, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Esign Pending - Click here to complete',
                            style: MyntWebTextStyles.bodySmall(context,
                                color: warningText, fontWeight: MyntFonts.medium)
                                .copyWith(decoration: TextDecoration.none),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _ddpiEsignLoading
                            ? SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: primaryColor))
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _openDdpiEsign(
                                    fileId: mobStatus?.dDPIFileid ?? '',
                                    email: (mobStatus?.dDPIClientEmail ?? '').toLowerCase(),
                                    session: mobStatus?.dDPISession ?? '',
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Text('Click here E-sign',
                                        style: MyntWebTextStyles.bodySmall(context,
                                            color: primaryColor,
                                            fontWeight: MyntFonts.semiBold)
                                            .copyWith(decoration: TextDecoration.none)),
                                  ),
                                ),
                              ),
                        const SizedBox(width: 4),
                        _ddpiCancelLoading
                            ? SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: errorColor))
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _cancelDdpiRequest(),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Text('Cancel request',
                                        style: MyntWebTextStyles.bodySmall(context,
                                            color: errorColor,
                                            fontWeight: MyntFonts.semiBold)
                                            .copyWith(decoration: TextDecoration.none)),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],

          // ── DDPI In Process Banner ──
          if (ddpiStatus == 'e-signed completed') ...[
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final successBg = resolveThemeColor(context,
                  dark: const Color(0xFF0A3D1E), light: const Color(0xFFE6F9ED));
              final successText = resolveThemeColor(context,
                  dark: MyntColors.successDark, light: MyntColors.success);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, size: 20, color: successText),
                    const SizedBox(width: 12),
                    Text(
                      "Your DDPI request is in process",
                      style: MyntWebTextStyles.bodySmall(context,
                        color: successText,
                        fontWeight: MyntFonts.medium,
                      ).copyWith(decoration: TextDecoration.none),
                    ),
                  ],
                ),
              );
            }),
          ],

          // ── Activate DDPI Section ──
          if (!ddpiActive && !poaActive) ...[
            const SizedBox(height: 28),
            Divider(height: 1, thickness: 1, color: dividerColor),
            const SizedBox(height: 24),

            Text(
              "Demat Debit and Pledge Instruction (DDPI)",
              style: MyntWebTextStyles.title(context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.semiBold,
              ).copyWith(decoration: TextDecoration.none),
            ),
            const SizedBox(height: 8),
            Text(
              "DDPI is a document that allows a broker to debit the securities from the client's demat account and deliver them to the exchange.",
              style: MyntWebTextStyles.body(context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
                fontWeight: MyntFonts.regular,
              ).copyWith(decoration: TextDecoration.none),
            ),
            const SizedBox(height: 24),

            // Question + button
            Text(
              "Do you want to sell your stocks without CDSL T-PIN",
              style: MyntWebTextStyles.body(context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.medium,
              ).copyWith(decoration: TextDecoration.none),
            ),
            const SizedBox(height: 18),
            Builder(builder: (context) {
              final ddpiBusy = _ddpiActivateLoading ||
                  ddpiStatus == 'e-signed pending' ||
                  ddpiStatus == 'e-signed completed';
              // Visual disable per spec: closed account, non-individual, inactive.
              final ddpiDisabled = ddpiBusy ||
                  isClientClosed ||
                  !isIndividual ||
                  !isAccountActive;
              // Tooltip priority per spec: non-individual → inactive.
              final ddpiTooltip = !isIndividual
                  ? "Non-individual accounts can't modify data here. "
                      "Please contact support at (+91) 93 8010 8010 for help."
                  : !isAccountActive
                      ? "Modification not allowed for inactive client codes. "
                          "Please reactivate the account."
                      : isClientClosed
                          ? "Your trading account is closed."
                          : "";
              final ddpiButton = Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: ddpiDisabled
                    ? null
                    : () async {
                        // Personal-info gates: closed → non-individual →
                        // inactive. Re-KYC is intentionally skipped, and DDPI
                        // is exempt from the 7-day post-activation block.
                        final blockReason = _personalInfoEditBlockReason(
                            checkRekyc: false, checkLast7Days: false);
                        if (blockReason != null) {
                          warningMessage(context, blockReason);
                          return;
                        }
                        // Equity segment precondition (BSE_CASH / NSE_CASH
                        // active). MF segments are intentionally excluded.
                        final segments = ref
                            .read(profileAllDetailsProvider)
                            .clientAllDetails
                            .clientData
                            ?.segmentsData;
                        final hasActiveEquityCheck = segments != null &&
                            segments.any((s) =>
                                (s.cOMPANYCODE == 'BSE_CASH' ||
                                    s.cOMPANYCODE == 'NSE_CASH') &&
                                s.exchangeACTIVEINACTIVE == 'A');
                        if (!hasActiveEquityCheck) {
                          warningMessage(context,
                              'You need to enable the Equity segment before activating DDPI.');
                          return;
                        }
                        final pendingStatuses = ref
                            .read(profileAllDetailsProvider)
                            .pendingStatusList;
                        if (pendingStatuses.isNotEmpty &&
                            pendingStatuses[0].data != null) {
                          final hasPendingChanges =
                              pendingStatuses[0].data!.any(
                                  (status) =>
                                      status == 'ddpicre_pending');
                          if (hasPendingChanges) {
                            warningMessage(context,
                                'You have pending request. Click on the E-Sign to proceed.');
                            return;
                          }
                        }
                        setState(() => _ddpiActivateLoading = true);
                        await _showDdpiConfirmDialog(themeVal);
                        if (mounted) {
                          setState(
                              () => _ddpiActivateLoading = false);
                        }
                      },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                 padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_ddpiActivateLoading ||
                            ddpiStatus == 'e-signed pending' ||
                            ddpiStatus == 'e-signed completed')
                        ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary).withValues(alpha: 0.4)
                        : resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _ddpiActivateLoading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : Text(
                          "Activate DDPI",
                          style: MyntWebTextStyles.body(context,
                            color: Colors.white,
                            fontWeight: MyntFonts.semiBold,
                          ).copyWith(
                              decoration: TextDecoration.none),
                        ),
                ),
              ),
            );
              return Opacity(
                opacity: ddpiDisabled && !ddpiBusy ? 0.5 : 1.0,
                child: ddpiTooltip.isNotEmpty
                    ? Tooltip(message: ddpiTooltip, child: ddpiButton)
                    : ddpiButton,
              );
            }),
            const SizedBox(height: 14),
            Text(
              "*As per the regulation, DDPI activation will be one time process.",
              style: MyntWebTextStyles.caption(context,
                darkColor: MyntColors.textTertiaryDark,
                lightColor: MyntColors.textTertiary,
                fontWeight: MyntFonts.regular,
              ).copyWith(
                decoration: TextDecoration.none,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Status chip for DDPI/POA
  Widget _buildStatusChipDepository(
      String label, bool isActive, Color primaryColor) {
    final activeColor = isActive ? primaryColor : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: MyntWebTextStyles.bodySmall(context,
              color: activeColor,
              fontWeight: MyntFonts.semiBold,
            ).copyWith(
              decoration: TextDecoration.none,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Flat field for depository: label + value + underline
  Widget _buildDepositoryField(
      String label, String value, Color dividerColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MyntWebTextStyles.caption(context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
            fontWeight: MyntFonts.semiBold,
          ).copyWith(
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value.isNotEmpty ? value : "N/A",
          style: MyntWebTextStyles.body(context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.medium,
          ).copyWith(decoration: TextDecoration.none),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, thickness: 1, color: dividerColor),
      ],
    );
  }

  // ─── DDPI E-Sign via Digio JS SDK (inline) ───
  Future<void> _openDdpiEsign({
    required String fileId,
    required String email,
    required String session,
  }) async {
    final provider = ref.read(profileAllDetailsProvider);

    if (fileId.isEmpty || email.isEmpty) {
      warningMessage(context, 'E-Sign details not available');
      return;
    }

    setState(() => _ddpiEsignLoading = true);


    try {
      final result = await startDigioEsign(
        fileId: fileId,
        email: email,
        session: session,
      );

      if (fileId.isNotEmpty) {
        provider.reportFiledownload(
          fileId: fileId,
          response: result,
          type: 'DDPI',
        );
      }

      provider.fetchClientProfileAllDetails();
      provider.fetchMobEmailStatus();

      if (mounted) {
        if (result == 'success') {
          successMessage(context, 'E-Sign completed successfully');
        } else {
          warningMessage(context, 'E-Sign was cancelled');
        }
      }
    } finally {
      if (mounted) setState(() => _ddpiEsignLoading = false);
    }
  }

  // ─── Cancel DDPI Request ───
  Future<void> _cancelDdpiRequest() async {
    final provider = ref.read(profileAllDetailsProvider);
    setState(() => _ddpiCancelLoading = true);
    try {
      provider.cancelPendingloader(true);
      final fileid = await provider.api.fetctfileidapi('DDPI');
      final response = await provider.api
          .cancelPendingStatusApi('DDPI', fileid ?? '');
      if (response == 'Cancel Success') {
        await provider.fetchMobEmailStatus();
        await provider.fetchPendingstatus();
        if (mounted) successMessage(context, 'Esign Cancellation Success');
      } else {
        if (mounted) warningMessage(context, 'Esign Cancellation Failed');
      }
    } catch (e) {
      if (mounted) warningMessage(context, 'Something Went Wrong');
    } finally {
      provider.cancelPendingloader(false);
      if (mounted) setState(() => _ddpiCancelLoading = false);
    }
  }

  // ─── DDPI Confirm Dialog (₹250 charge + ledger balance) ───
  Future<void> _showDdpiConfirmDialog(ThemesProvider themeVal) async {
    final provider = ref.read(profileAllDetailsProvider);
    dynamic ledgerBal = await provider.ddpiledgerbaapi();
    double balance = 0;
    if (ledgerBal is num) {
      balance = ledgerBal.toDouble();
    } else if (ledgerBal is String) {
      balance = double.tryParse(ledgerBal) ?? 0;
    }

    if (!mounted) return;

    bool ddpiSubmitLoading = false;
    bool acknowledged = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cardBg = resolveThemeColor(ctx,
              dark: MyntColors.cardDark, light: MyntColors.card);
          final textColor = resolveThemeColor(ctx,
              dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
          final subtitleColor = resolveThemeColor(ctx,
              dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
          final dividerColor = resolveThemeColor(ctx,
              dark: MyntColors.dividerDark, light: MyntColors.divider);
          final primaryColor = resolveThemeColor(ctx,
              dark: MyntColors.primaryDark, light: MyntColors.primary);
          final errorColor = resolveThemeColor(ctx,
              dark: MyntColors.errorDark, light: MyntColors.error);
          final chipBg = resolveThemeColor(ctx,
              dark: MyntColors.overlayBgDark, light: MyntColors.overlayBg);
          final cardBorderColor = resolveThemeColor(ctx,
              dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

          final successColor = resolveThemeColor(ctx,
              dark: MyntColors.successDark, light: MyntColors.success);

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 400,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorderColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top accent bar
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      // gradient: LinearGradient(
                      //   colors: [primaryColor, primaryColor.withValues(alpha: 0.4)],
                      // ),
                    ),
                  ),
                  // Close button row
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, right: 8),
                      child: MyntCloseButton(
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ),
                  // Icon + Title
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.receipt_long_rounded,
                        size: 28, color: primaryColor),
                  ),
                  const SizedBox(height: 12),
                  Text("DDPI Activation",
                      style: MyntWebTextStyles.title(ctx,
                          color: textColor,
                          fontWeight: MyntFonts.semiBold)),
                  const SizedBox(height: 4),
                  Text("One-time processing fee",
                      style: MyntWebTextStyles.caption(ctx,
                          color: subtitleColor,
                          fontWeight: MyntFonts.medium)),
                  const SizedBox(height: 20),
                  // Amount display
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cardBorderColor),
                    ),
                    child: Row(
                      children: [
                        // Charge amount
                        Expanded(
                          child: Column(
                            children: [
                              Text("Charge",
                                  style: MyntWebTextStyles.caption(ctx,
                                      color: subtitleColor,
                                      fontWeight: MyntFonts.medium)),
                              const SizedBox(height: 6),
                              Text("₹250",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  )),
                            ],
                          ),
                        ),
                        // Vertical divider
                        Container(
                          width: 1,
                          height: 40,
                          color: dividerColor,
                        ),
                        // Available balance
                        Expanded(
                          child: Column(
                            children: [
                              Text("Balance",
                                  style: MyntWebTextStyles.caption(ctx,
                                      color: subtitleColor,
                                      fontWeight: MyntFonts.medium)),
                              const SizedBox(height: 6),
                              Text("₹${balance.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: balance >= 250
                                        ? successColor
                                        : errorColor,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (balance >= 250) ...[
                    // Acknowledge checkbox
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: InkWell(
                        onTap: () {
                          setDialogState(() {
                            acknowledged = !acknowledged;
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: acknowledged ? primaryColor : Colors.transparent,
                                border: Border.all(
                                  color: acknowledged ? primaryColor : subtitleColor,
                                  width: 1.5,
                                ),
                              ),
                              child: acknowledged
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "I authorize debiting ₹250 from my ledger balance for DDPI activation.",
                                style: MyntWebTextStyles.caption(ctx,
                                    color: subtitleColor,
                                    fontWeight: MyntFonts.medium),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Submit button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: MyntPrimaryButton(
                        label: 'Confirm & Activate',
                        size: MyntButtonSize.large,
                        isFullWidth: true,
                        isLoading: ddpiSubmitLoading,
                        onPressed: !acknowledged
                            ? null
                            : () async {
                                setDialogState(() {
                                  ddpiSubmitLoading = true;
                                });
                                await _submitDdpiActivation(ctx);
                                setDialogState(() {
                                  ddpiSubmitLoading = false;
                                });
                              },
                      ),
                    ),
                  ] else ...[
                    // Insufficient balance
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: errorColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: errorColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 18, color: errorColor),
                            const SizedBox(width: 8),
                            Text("Insufficient balance. Please add funds.",
                                style: MyntWebTextStyles.bodySmall(ctx,
                                    color: errorColor,
                                    fontWeight: MyntFonts.medium)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Submit DDPI Activation ───
  Future<void> _submitDdpiActivation(BuildContext dialogCtx) async {
    final provider = ref.read(profileAllDetailsProvider);
    final clientData = provider.clientAllDetails.clientData;

    if (clientData == null) {
      warningMessage(context, 'Profile data not available');
      return;
    }

    final response = await provider.api.finalddpisubmitapi(clientData);

    if (response is Map<String, dynamic> &&
        response['fileid'] != null &&
        response['session'] != null) {
      Navigator.pop(dialogCtx);
      await provider.fetchMobEmailStatus();
      if (mounted) {
        _showDdpiEsignConfirmationDialog();
      }
    } else {
      final msg = response is Map ? (response['msg'] ?? 'DDPI activation failed') : 'DDPI activation failed';
      if (mounted) warningMessage(context, msg.toString());
    }
  }

  // ─── DDPI E-Sign Confirmation Dialog ───
  void _showDdpiEsignConfirmationDialog() {
    final mobStatus = ref.read(profileAllDetailsProvider).mobEmailStatus;
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('E-Sign Is Pending!',
                        style: MyntWebTextStyles.body(context,
                            fontWeight: MyntFonts.semiBold, color: textColor)),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(profileAllDetailsProvider).fetchMobEmailStatus();
                    },
                    icon: Icon(Icons.close, size: 20, color: subtitleColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Your DDPI Request is not yet Completed.',
                  style: MyntWebTextStyles.bodySmall(context,
                      fontWeight: MyntFonts.medium, color: textColor)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openDdpiEsign(
                      fileId: mobStatus?.dDPIFileid ?? '',
                      email:
                          (mobStatus?.dDPIClientEmail ?? '').toLowerCase(),
                      session: mobStatus?.dDPISession ?? '',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Click here E-sign',
                      style: MyntWebTextStyles.body(context,
                          fontWeight: MyntFonts.semiBold,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MTF SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMTFContent(WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final clientData = profileDetails.clientAllDetails.clientData;
    final mobStatus = profileDetails.mobEmailStatus;
    final mtfStatus = mobStatus?.mtfStatus;

    bool DDPIActive = clientData?.dDPI == 'Y';
    bool POAActive = clientData?.pOA == 'Y';
    bool mtfCl = clientData?.mTFCl == 'Y';
    bool mtfClAuto = clientData?.mTFClAuto == "Y";

    // gates: accountstatus != 'client_close' -> button visible
    //            CATEGORY != 'I' || !atve_sts || client_close -> button disabled
    // MTF is exempt from the 7-day post-activation block, so last7days is
    // deliberately not part of these gates.
    final bool isClientClosed = clientData?.isClientClosed ?? false;
    final bool isIndividual = clientData?.isIndividual ?? false;
    final bool accSgtAtveSts =
        (mobStatus?.accSgtAtveSts ?? '').toLowerCase() == 'active';
    final bool mtfActionDisabled =
        !isIndividual || !accSgtAtveSts || isClientClosed;

    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final cardBorder = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      decoration: BoxDecoration(
color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row with MTF status chip ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Margin Trading Facility",
                style: MyntWebTextStyles.title(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium,
                ).copyWith(decoration: TextDecoration.none),
              ),
              if (mtfCl && mtfClAuto)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "MTF Enabled",
                        style: MyntWebTextStyles.bodySmall(context,
                          color: primaryColor,
                          fontWeight: MyntFonts.medium,
                        ).copyWith(decoration: TextDecoration.none),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Margin Trading Facility allows you to buy stocks by paying only a fraction of the total value",
            style: MyntWebTextStyles.para(context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
              fontWeight: MyntFonts.regular,
            ).copyWith(decoration: TextDecoration.none),
          ),

          // ── MTF e-signed pending banner ──
          if (mtfStatus == 'e-signed pending') ...[
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final warningBg = resolveThemeColor(context,
                  dark: const Color(0xFF3D2E00), light: const Color(0xFFFCEFD4));
              final warningText = resolveThemeColor(context,
                  dark: const Color(0xFFFFD780), light: Colors.brown[800]!);
              final warningIcon = resolveThemeColor(context,
                  dark: MyntColors.warningDark, light: MyntColors.warning);
              final errorColor = resolveThemeColor(context,
                  dark: MyntColors.errorDark, light: MyntColors.error);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: warningIcon, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Esign Pending - Click here to complete',
                            style: MyntWebTextStyles.bodySmall(context,
                                color: warningText, fontWeight: MyntFonts.medium)
                                .copyWith(decoration: TextDecoration.none),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _mtfEsignLoading
                            ? SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: primaryColor))
                            : Builder(builder: (context) {
                                // Resume E-sign link: disabled only when
                                // !atve_sts. The 7-day block does not apply to
                                // MTF, so an in-flight request stays signable.
                                final esignDisabled = !accSgtAtveSts;
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: esignDisabled
                                        ? null
                                        : () => _openMtfEsign(
                                              fileId: mobStatus?.mtfFileid ?? '',
                                              email: (mobStatus?.mtfClientEmail ?? '')
                                                  .toLowerCase(),
                                              session: mobStatus?.mtfSession ?? '',
                                            ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Opacity(
                                      opacity: esignDisabled ? 0.5 : 1.0,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        child: Text('Click here E-sign',
                                            style: MyntWebTextStyles.bodySmall(context,
                                                color: primaryColor,
                                                fontWeight: MyntFonts.semiBold)
                                                .copyWith(decoration: TextDecoration.none)),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                        const SizedBox(width: 4),
                        _mtfCancelLoading
                            ? SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: errorColor))
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _cancelMtfRequest(),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Text('Cancel request',
                                        style: MyntWebTextStyles.bodySmall(context,
                                            color: errorColor,
                                            fontWeight: MyntFonts.semiBold)
                                            .copyWith(decoration: TextDecoration.none)),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],

          // ── MTF e-signed completed (in process) banner ──
          if (mtfStatus == 'e-signed completed') ...[
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final successBg = resolveThemeColor(context,
                  dark: const Color(0xFF0A3D1E), light: const Color(0xFFE6F9ED));
              final successText = resolveThemeColor(context,
                  dark: MyntColors.successDark, light: MyntColors.success);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, size: 20, color: successText),
                    const SizedBox(width: 12),
                    Text(
                      "Your MTF request is in process",
                      style: MyntWebTextStyles.bodySmall(context,
                        color: successText,
                        fontWeight: MyntFonts.medium,
                      ).copyWith(decoration: TextDecoration.none),
                    ),
                  ],
                ),
              );
            }),
          ],

          // ── DDPI not active: warning ──
          if (!DDPIActive && !POAActive) ...[
            const SizedBox(height: 24),
            Text(
              "You need to enable DDPI before you can proceed with processing MTF (Margin Trading Facility).",
              style: MyntWebTextStyles.body(context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
                fontWeight: MyntFonts.regular,
              ).copyWith(
                decoration: TextDecoration.none,
                color: resolveThemeColor(context,
                    dark: MyntColors.errorDark, light: MyntColors.error)
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: resolveThemeColor(context,
                    dark: MyntColors.cardBorderDark,
                    light: MyntColors.cardBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "Enable MTF",
                style: MyntWebTextStyles.body(context,
                  darkColor: MyntColors.textTertiaryDark,
                  lightColor: MyntColors.textTertiary,
                  fontWeight: MyntFonts.semiBold,
                ).copyWith(decoration: TextDecoration.none),
              ),
            ),
          ],

          // ── MTF already active: description ──
          if (mtfCl && mtfClAuto) ...[
            const SizedBox(height: 24),
            Text(
              "You have activated the Margin Trading Facility (MTF) on your account.",
              style: MyntWebTextStyles.body(context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.regular,
              ).copyWith(decoration: TextDecoration.none),
            ),
          ],

          // ── DDPI active but MTF not active: activation section ──
          // Hidden entirely when an MTF e-sign request is in flight
          // (status card above is shown instead, per spec).
          if ((DDPIActive || POAActive) &&
              !(mtfCl && mtfClAuto) &&
              mtfStatus != 'e-signed pending' &&
              mtfStatus != 'e-signed completed') ...[
            const SizedBox(height: 24),
            Text(
              "Would you like to activate Margin Trading Facility (MTF) on your account?",
              style: MyntWebTextStyles.body(context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.medium,
              ).copyWith(decoration: TextDecoration.none),
            ),
            const SizedBox(height: 18),
            Builder(builder: (context) {
              // Tooltip priority per spec (desktop active branch):
              // closed → !atve_sts → CATEGORY != 'I' → "".
              final mtfTooltip = isClientClosed
                  ? "Your trading account is closed"
                  : !accSgtAtveSts
                      ? "Modification not allowed for inactive client codes. "
                          "Please reactivate the account."
                      : !isIndividual
                          ? "Non-individual accounts can't modify data here. "
                              "Please contact support at (+91) 93 8010 8010 for help."
                          : "";
              final mtfButton = Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _mtfSubmitLoading ||
                        mtfActionDisabled ||
                        mtfStatus == 'e-signed pending' ||
                        mtfStatus == 'e-signed completed'
                    ? null
                    : () {
                        final pendingStatuses = ref
                            .watch(profileAllDetailsProvider)
                            .pendingStatusList;
                        if (pendingStatuses.isNotEmpty &&
                            pendingStatuses[0].data != null) {
                          final hasPendingChanges = pendingStatuses[0]
                              .data!
                              .any((status) => status == 'mtf_pending');
                          if (hasPendingChanges) {
                            warningMessage(context,
                                'You have pending request. Click on the E-Sign to proceed.');
                            return;
                          }
                        }
                        _submitMtfActivation();
                      },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: (_mtfSubmitLoading ||
                            mtfActionDisabled ||
                            mtfStatus == 'e-signed pending' ||
                            mtfStatus == 'e-signed completed')
                        ? primaryColor.withValues(alpha: 0.4)
                        : primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _mtfSubmitLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          "Enable MTF",
                          style: MyntWebTextStyles.body(context,
                            color: Colors.white,
                            fontWeight: MyntFonts.semiBold,
                          ).copyWith(decoration: TextDecoration.none),
                        ),
                ),
              ),
            );
              return mtfTooltip.isNotEmpty
                  ? Tooltip(message: mtfTooltip, child: mtfButton)
                  : mtfButton;
            }),
          ],
        ],
      ),
    );
  }

  // ─── MTF E-Sign via Digio JS SDK (inline) ───
  Future<void> _openMtfEsign({
    required String fileId,
    required String email,
    required String session,
  }) async {
    final provider = ref.read(profileAllDetailsProvider);

    if (fileId.isEmpty || email.isEmpty) {
      warningMessage(context, 'E-Sign details not available');
      return;
    }

    setState(() => _mtfEsignLoading = true);


    try {
      final result = await startDigioEsign(
        fileId: fileId,
        email: email,
        session: session,
      );

      if (fileId.isNotEmpty) {
        provider.reportFiledownload(
          fileId: fileId,
          response: result,
          type: 'mtf',
        );
      }

      provider.fetchClientProfileAllDetails();
      provider.fetchMobEmailStatus();

      if (mounted) {
        if (result == 'success') {
          successMessage(context, 'E-Sign completed successfully');
        } else {
          warningMessage(context, 'E-Sign was cancelled');
        }
      }
    } finally {
      if (mounted) setState(() => _mtfEsignLoading = false);
    }
  }

  // ─── Cancel MTF Request ───
  Future<void> _cancelMtfRequest() async {
    final provider = ref.read(profileAllDetailsProvider);
    setState(() => _mtfCancelLoading = true);
    try {
      provider.cancelPendingloader(true);
      final fileid = await provider.api.fetctfileidapi('mtf');
      final response = await provider.api
          .cancelPendingStatusApi('mtf', fileid ?? '');
      if (response == 'Cancel Success') {
        await provider.fetchMobEmailStatus();
        await provider.fetchPendingstatus();
        if (mounted) successMessage(context, 'Esign Cancellation Success');
      } else {
        if (mounted) warningMessage(context, 'Esign Cancellation Failed');
      }
    } catch (e) {
      if (mounted) warningMessage(context, 'Something Went Wrong');
    } finally {
      provider.cancelPendingloader(false);
      if (mounted) setState(() => _mtfCancelLoading = false);
    }
  }

  // ─── Submit MTF Activation ───
  Future<void> _submitMtfActivation() async {
    final provider = ref.read(profileAllDetailsProvider);
    final clientData = provider.clientAllDetails.clientData;

    if (clientData == null) {
      warningMessage(context, 'Profile data not available');
      return;
    }

    setState(() => _mtfSubmitLoading = true);

    try {
      final response = await provider.mtfenbprovi(clientData);

      if (response is Map<String, dynamic> && response['msg'] == 'Success') {
        await provider.fetchMobEmailStatus();
        if (mounted) {
          _showMtfEsignConfirmationDialog();
        }
      } else {
        final msg = response is Map
            ? (response['msg'] ?? 'MTF activation failed')
            : 'MTF activation failed';
        if (mounted) warningMessage(context, msg.toString());
      }
    } finally {
      if (mounted) setState(() => _mtfSubmitLoading = false);
    }
  }

  // ─── MTF E-Sign Confirmation Dialog ───
  void _showMtfEsignConfirmationDialog() {
    final provider = ref.read(profileAllDetailsProvider);
    final mobStatus = provider.mobEmailStatus;
    final clientData = provider.clientAllDetails.clientData;
    final ddpiActive = clientData?.dDPI == 'Y';
    final poaActive = clientData?.pOA == 'Y';
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    Widget statusChip(String label, bool active) {
      final bg = active
          ? Colors.green.withValues(alpha: 0.12)
          : Colors.red.withValues(alpha: 0.12);
      final fg = active ? Colors.green.shade700 : Colors.red.shade700;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fg.withValues(alpha: 0.4)),
        ),
        child: Text(
          '$label: ${active ? 'Y' : 'N'}',
          style: MyntWebTextStyles.bodySmall(context,
              fontWeight: MyntFonts.semiBold, color: fg),
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('E-Sign Is Pending!',
                        style: MyntWebTextStyles.body(context,
                            fontWeight: MyntFonts.semiBold, color: textColor)),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(profileAllDetailsProvider).fetchMobEmailStatus();
                    },
                    icon: Icon(Icons.close, size: 20, color: subtitleColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Your MTF Request is not yet Completed.',
                  style: MyntWebTextStyles.bodySmall(context,
                      fontWeight: MyntFonts.medium, color: textColor)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  statusChip('DDPI', ddpiActive),
                  statusChip('POA', poaActive),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openMtfEsign(
                      fileId: mobStatus?.mtfFileid ?? '',
                      email:
                          (mobStatus?.mtfClientEmail ?? '').toLowerCase(),
                      session: mobStatus?.mtfSession ?? '',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Click here E-sign',
                      style: MyntWebTextStyles.body(context,
                          fontWeight: MyntFonts.semiBold,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TRADING PREFERENCES SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTradingPreferencesContent(
      WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final segmentsData =
        profileDetails.clientAllDetails.clientData?.segmentsData;

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextWidget.subText(
                  text: "Segments",
                  theme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? colors.textPrimaryDark
                      : colors.textPrimaryLight,
                  fw: 0),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final pendingStatuses = ref
                        .watch(profileAllDetailsProvider)
                        .pendingStatusList;
                    if (pendingStatuses.isNotEmpty &&
                        pendingStatuses[0].data != null) {
                      final hasPendingChanges = pendingStatuses[0]
                          .data!
                          .any((status) =>
                              status == 'segments_change_pending');
                      if (hasPendingChanges) {
                        warningMessage(context,
                            'You have pending request.click on the E-Sign to proceed.');
                        return;
                      }
                    }

                    await Future.delayed(
                        const Duration(milliseconds: 150));
                    profileDetails.openInWebURLk(
                        context, "segment", "segment");
                  },
                  borderRadius: BorderRadius.circular(20),
                  splashColor: theme.isDarkMode
                      ? colors.splashColorDark
                      : colors.splashColorLight,
                  highlightColor: theme.isDarkMode
                      ? colors.highlightDark
                      : colors.highlightLight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.edit_outlined,
                      color: theme.isDarkMode
                          ? colors.textSecondaryDark
                          : colors.textSecondaryLight,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (segmentsData != null) ...[
            _buildSegmentRow(
                "Equities",
                segmentsData.where((s) =>
                    ['BSE_CASH', 'NSE_CASH'].contains(s.cOMPANYCODE)),
                theme),
            _buildSegmentRow(
                "F&O",
                segmentsData.where((s) =>
                    ['NSE_FNO', 'BSE_FNO'].contains(s.cOMPANYCODE)),
                theme),
            _buildSegmentRow(
                "Currency",
                segmentsData.where((s) =>
                    ['CD_NSE', 'CD_BSE'].contains(s.cOMPANYCODE)),
                theme),
            _buildSegmentRow(
                "Commodities",
                segmentsData.where((s) =>
                    ['MCX', 'NSE_COM', 'BSE_COM']
                        .contains(s.cOMPANYCODE)),
                theme),
          ] else
            TextWidget.paraText(
              text: "No segment data available",
              theme: theme.isDarkMode,
            ),

          // Show pending statuses for Trading Preferences section
          _buildSectionPendingStatuses(
              'Trading Preferences', ref, theme, () {
            profileDetails.openInWebURLk(
                context, "segment", "segment");
          }, () {
            profileDetails.cancelPendingStatus(
                "segment_change", context);
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  NOMINEE SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildNomineeContent(WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final clientData = profileDetails.clientAllDetails.clientData;

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (clientData?.nomineeName == null ||
              clientData?.nomineeName == "") ...[
            TextWidget.subText(
              text: "No nominee details found",
              color: theme.isDarkMode
                  ? colors.textSecondaryDark
                  : colors.textSecondaryLight,
              theme: theme.isDarkMode,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await Future.delayed(
                        const Duration(milliseconds: 150));
                    profileDetails.openInWebURLk(
                        context, "nominee", "nominee");
                  },
                  style: ElevatedButton.styleFrom(
                      elevation: 0,
                      minimumSize: const Size(100, 45),
                      backgroundColor: theme.isDarkMode
                          ? colors.primaryDark
                          : colors.primaryLight,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4))),
                  child: TextWidget.subText(
                    text: "Add Nominee",
                    color: colors.colorWhite,
                    theme: theme.isDarkMode,
                    fw: 2,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget.subText(
                  text: "Nominee Details",
                  theme: theme.isDarkMode,
                  fw: 0,
                  color: theme.isDarkMode
                      ? colors.textPrimaryDark
                      : colors.textPrimaryLight,
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final pendingStatuses = ref
                          .watch(profileAllDetailsProvider)
                          .pendingStatusList;
                      if (pendingStatuses.isNotEmpty &&
                          pendingStatuses[0].data != null) {
                        final hasPendingChanges = pendingStatuses[0]
                            .data!
                            .any((status) =>
                                status == 'nominee_pending');
                        if (hasPendingChanges) {
                          warningMessage(context,
                              'You have pending request.click on the E-Sign to proceed.');
                          return;
                        }
                      }

                      await Future.delayed(
                          const Duration(milliseconds: 150));
                      profileDetails.openInWebURLk(
                          context, "nominee", "nominee");
                    },
                    borderRadius: BorderRadius.circular(20),
                    splashColor: theme.isDarkMode
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.15),
                    highlightColor: theme.isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.edit_outlined,
                        color: theme.isDarkMode
                            ? colors.textSecondaryDark
                            : colors.textSecondaryLight,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            _buildDetailRow("Nominee Name",
                clientData?.nomineeName ?? "", theme, ref),
            _buildDetailRow("Nominee Relation",
                clientData?.nomineeRelation ?? "", theme, ref),
            if (clientData?.nomineeDOB != null)
              _buildDetailRow(
                  "Nominee DOB",
                  formatNomineeDOB(
                      clientData!.nomineeDOB! ?? ""),
                  theme,
                  ref),
          ],

          // Show pending statuses for Nominee section
          _buildSectionPendingStatuses('Nominee', ref, theme, () {
            profileDetails.openInWebURLk(
                context, "nominee", "nominee");
          }, () {
            profileDetails.cancelPendingStatus("nominee", context);
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FORM DOWNLOAD SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFormDownloadContent(WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget.subText(
            text: "Download various forms and documents",
            theme: theme.isDarkMode,
            color: theme.isDarkMode
                ? colors.textPrimaryDark
                : colors.textPrimaryLight,
            fw: 0,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  await Future.delayed(
                      const Duration(milliseconds: 150));
                  profileDetails.openInWebURL(
                      context, "formdownload");
                },
                style: ElevatedButton.styleFrom(
                    elevation: 0,
                    minimumSize: const Size(100, 45),
                    backgroundColor: theme.isDarkMode
                        ? colors.primaryDark
                        : colors.primaryLight,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5))),
                child: TextWidget.subText(
                    text: "Download Forms",
                    theme: false,
                    color: colors.colorWhite,
                    fw: 2),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CLOSURE SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildClosureContent(WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final mobStatus = profileDetails.mobEmailStatus;
    final closureStatus = mobStatus?.closureStatus;
    final clientData = profileDetails.clientAllDetails.clientData;

    //   accountstatus == 'client_close' || CATEGORY != 'I' -> disable initiate
    final bool isClientClosed = clientData?.isClientClosed ?? false;
    final bool isIndividual = clientData?.isIndividual ?? false;
    final bool initiateDisabled = isClientClosed || !isIndividual;
    final String? initiateDisabledTooltip = isClientClosed
        ? 'Your trading account is closed'
        : (!isIndividual
            ? "Non-individual accounts can't modify data here. "
                "Please contact support at (+91) 93 8010 8010 for help."
            : null);

    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final cardBorder = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        decoration: BoxDecoration(
         color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──
            Text(
              "Account Closure",
              style: MyntWebTextStyles.title(context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.medium,
              ).copyWith(decoration: TextDecoration.none),
            ),
            const SizedBox(height: 8),
            Text(
              "If you close your account, you won't be able to trade with Zebu.",
              style: MyntWebTextStyles.body(context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
                fontWeight: MyntFonts.regular,
              ).copyWith(decoration: TextDecoration.none),
            ),

            // ── Pending banner ──
            if (closureStatus == 'e-signed pending') ...[
              const SizedBox(height: 16),
              Builder(builder: (context) {
                final warningBg = resolveThemeColor(context,
                    dark: const Color(0xFF3D2E00), light: const Color(0xFFFCEFD4));
                final warningText = resolveThemeColor(context,
                    dark: const Color(0xFFFFD780), light: Colors.brown[800]!);
                final warningIcon = resolveThemeColor(context,
                    dark: MyntColors.warningDark, light: MyntColors.warning);
                final errorColor = resolveThemeColor(context,
                    dark: MyntColors.errorDark, light: MyntColors.error);
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: warningBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: warningIcon, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Esign Pending - Click here to complete',
                              style: MyntWebTextStyles.bodySmall(context,
                                  color: warningText, fontWeight: MyntFonts.medium)
                                  .copyWith(decoration: TextDecoration.none),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _closureEsignLoading
                              ? SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: primaryColor))
                              : Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _openClosureEsign(
                                      fileId: mobStatus?.closureFileid ?? '',
                                      email: (mobStatus?.closureClientEmail ?? '').toLowerCase(),
                                      session: mobStatus?.closureSession ?? '',
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      child: Text('Click here E-sign',
                                          style: MyntWebTextStyles.bodySmall(context,
                                              color: primaryColor,
                                              fontWeight: MyntFonts.semiBold)
                                              .copyWith(decoration: TextDecoration.none)),
                                    ),
                                  ),
                                ),
                          const SizedBox(width: 4),
                          _closureCancelLoading
                              ? SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: errorColor))
                              : Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _cancelClosureRequest(),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      child: Text('Cancel request',
                                          style: MyntWebTextStyles.bodySmall(context,
                                              color: errorColor,
                                              fontWeight: MyntFonts.semiBold)
                                              .copyWith(decoration: TextDecoration.none)),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],

            // ── In process banner ──
            if (closureStatus == 'e-signed completed') ...[
              const SizedBox(height: 16),
              Builder(builder: (context) {
                final successBg = resolveThemeColor(context,
                    dark: const Color(0xFF0A3D1E), light: const Color(0xFFE6F9ED));
                final successText = resolveThemeColor(context,
                    dark: MyntColors.successDark, light: MyntColors.success);
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: successBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded, size: 20, color: successText),
                      const SizedBox(width: 12),
                      Text(
                        "Your account closure request is in process",
                        style: MyntWebTextStyles.bodySmall(context,
                          color: successText,
                          fontWeight: MyntFonts.medium,
                        ).copyWith(decoration: TextDecoration.none),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // ── Initiate closure ──
            if (closureStatus != 'e-signed pending' &&
                closureStatus != 'e-signed completed') ...[
              const SizedBox(height: 24),
              Text(
                "Would you like to close your account?",
                style: MyntWebTextStyles.body(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium,
                ).copyWith(decoration: TextDecoration.none),
              ),
              const SizedBox(height: 18),
              Builder(builder: (context) {
                final bool busy = _closureInitiateLoading;
                final bool disabled = initiateDisabled || busy;
                final btn = Opacity(
                  opacity: disabled ? 0.5 : 1.0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: disabled
                          ? null
                          : () => _showClosureConfirmDialog(theme),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: resolveThemeColor(context,
                              dark: MyntColors.secondary,
                              light: MyntColors.primary),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                "Initiate Closure",
                                style: MyntWebTextStyles.body(context,
                                  color: Colors.white,
                                  fontWeight: MyntFonts.semiBold,
                                ).copyWith(decoration: TextDecoration.none),
                              ),
                      ),
                    ),
                  ),
                );
                return Align(
                  alignment: Alignment.centerLeft,
                  child: initiateDisabledTooltip == null
                      ? btn
                      : Tooltip(message: initiateDisabledTooltip, child: btn),
                );
              }),
            ],

            const SizedBox(height: 16),
            Text(
              "*Clear your ledger debit if any to proceed with the account closure",
              style: MyntWebTextStyles.caption(context,
                darkColor: MyntColors.textTertiaryDark,
                lightColor: MyntColors.textTertiary,
                fontWeight: MyntFonts.regular,
              ).copyWith(decoration: TextDecoration.none),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Closure E-Sign via Digio JS SDK (inline) ───
  Future<void> _openClosureEsign({
    required String fileId,
    required String email,
    required String session,
  }) async {
    final provider = ref.read(profileAllDetailsProvider);

    if (fileId.isEmpty || email.isEmpty) {
      warningMessage(context, 'E-Sign details not available');
      return;
    }

    setState(() => _closureEsignLoading = true);

    try {
      final result = await startDigioEsign(
        fileId: fileId,
        email: email,
        session: session,
      );

      if (fileId.isNotEmpty) {
        provider.reportFiledownload(
          fileId: fileId,
          response: result,
          type: 'closure',
        );
      }

      provider.fetchClientProfileAllDetails();
      provider.fetchMobEmailStatus();

      if (mounted) {
        if (result == 'success') {
          successMessage(context, 'E-Sign completed successfully');
        } else {
          warningMessage(context, 'E-Sign was cancelled');
        }
      }
    } finally {
      if (mounted) setState(() => _closureEsignLoading = false);
    }
  }

  // ─── Cancel Closure Request ───
  Future<void> _cancelClosureRequest() async {
    final provider = ref.read(profileAllDetailsProvider);
    setState(() => _closureCancelLoading = true);
    try {
      provider.cancelPendingloader(true);
      final fileid = await provider.api.fetctfileidapi('closure');
      final response = await provider.api
          .cancelPendingStatusApi('closure', fileid ?? '');
      if (response == 'Cancel Success') {
        await provider.fetchMobEmailStatus();
        await provider.fetchPendingstatus();
        if (mounted) successMessage(context, 'Esign Cancellation Success');
      } else {
        if (mounted) warningMessage(context, 'Esign Cancellation Failed');
      }
    } catch (e) {
      if (mounted) warningMessage(context, 'Something Went Wrong');
    } finally {
      provider.cancelPendingloader(false);
      if (mounted) setState(() => _closureCancelLoading = false);
    }
  }

  // ─── Closure Confirm Dialog (reason selection → balance check → submit) ───
  void _showClosureConfirmDialog(ThemesProvider themeVal) {
    final provider = ref.read(profileAllDetailsProvider);
    final clientData = provider.clientAllDetails.clientData;
    String closureReason = '';
    bool submitLoading = false;

    final reasons = [
      'High brokerage and charges',
      'Annual maintenance charges',
      'Faced losses',
      'No time to focus on trading',
      'Moving to other broker',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cardBg = resolveThemeColor(ctx,
              dark: MyntColors.cardDark, light: MyntColors.card);
          final textColor = resolveThemeColor(ctx,
              dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
          final subtitleColor = resolveThemeColor(ctx,
              dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
          final dividerColor = resolveThemeColor(ctx,
              dark: MyntColors.dividerDark, light: MyntColors.divider);
          final cardBorderColor = resolveThemeColor(ctx,
              dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 420,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: dividerColor),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Account Closure",
                            style: MyntWebTextStyles.title(ctx, color: textColor)),
                        MyntCloseButton(
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: MyntWebTextStyles.bodySmall(ctx,
                                color: subtitleColor,
                                fontWeight: MyntFonts.medium),
                            children: [
                              const TextSpan(
                                  text: 'Are you sure you want to deactivate your account '),
                              TextSpan(
                                text: '"${clientData?.cLIENTID ?? ''}"',
                                style: MyntWebTextStyles.bodySmall(ctx,
                                    color: textColor,
                                    fontWeight: MyntFonts.semiBold),
                              ),
                              const TextSpan(text: '?'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Reason',
                            style: MyntWebTextStyles.caption(ctx,
                                color: subtitleColor,
                                fontWeight: MyntFonts.medium)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: closureReason.isEmpty ? null : closureReason,
                          hint: Text('Select Reason',
                              style: MyntWebTextStyles.bodySmall(ctx,
                                  color: subtitleColor,
                                  fontWeight: MyntFonts.medium)),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: cardBorderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: resolveThemeColor(ctx,
                                    dark: MyntColors.primaryDark,
                                    light: MyntColors.primary),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          dropdownColor: cardBg,
                          style: MyntWebTextStyles.bodySmall(ctx,
                              color: textColor,
                              fontWeight: MyntFonts.medium),
                          items: reasons
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (val) {
                            setDialogState(() => closureReason = val ?? '');
                          },
                        ),
                        const SizedBox(height: 20),
                        MyntPrimaryButton(
                          label: 'Submit',
                          size: MyntButtonSize.large,
                          isFullWidth: true,
                          isLoading: submitLoading,
                          onPressed: closureReason.isEmpty
                              ? null
                              : () async {
                                  setDialogState(() => submitLoading = true);
                                  try {
                                    await _submitClosureRequest(
                                        ctx, closureReason, themeVal);
                                  } catch (e) {
                                    if (mounted) {
                                      warningMessage(context,
                                          'Something went wrong. Please try again.');
                                    }
                                  } finally {
                                    if (Navigator.canPop(ctx)) {
                                      setDialogState(
                                          () => submitLoading = false);
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Negative Balance Dialog (shown when check_closure returns negative balance) ───
  void _showNegativeBalanceDialog(double balance, String clientId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cardBg = resolveThemeColor(ctx,
            dark: MyntColors.cardDark, light: MyntColors.card);
        final textColor = resolveThemeColor(ctx,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
        final subtitleColor = resolveThemeColor(ctx,
            dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
        final dividerColor = resolveThemeColor(ctx,
            dark: MyntColors.dividerDark, light: MyntColors.divider);
        final primaryColor = resolveThemeColor(ctx,
            dark: MyntColors.primaryDark, light: MyntColors.primary);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 420,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: dividerColor),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Account Closure ?',
                          style: MyntWebTextStyles.title(ctx, color: textColor)),
                      MyntCloseButton(
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: MyntWebTextStyles.bodySmall(ctx,
                              color: subtitleColor,
                              fontWeight: MyntFonts.regular),
                          children: [
                            const TextSpan(
                                text: 'You have a ledger balance of '),
                            TextSpan(
                              text: 'Rs ${balance.toStringAsFixed(2)}',
                              style: MyntWebTextStyles.bodySmall(ctx,
                                  color: textColor,
                                  fontWeight: MyntFonts.semiBold),
                            ),
                            const TextSpan(text: ' in your '),
                            TextSpan(
                              text: '"$clientId"',
                              style: MyntWebTextStyles.bodySmall(ctx,
                                  color: textColor,
                                  fontWeight: MyntFonts.semiBold),
                            ),
                            const TextSpan(
                                text:
                                    '. Please settle the outstanding amount so we can proceed further.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Insufficient balance link row
                      RichText(
                        text: TextSpan(
                          style: MyntWebTextStyles.bodySmall(ctx,
                              color: subtitleColor,
                              fontWeight: MyntFonts.regular),
                          children: [
                            const TextSpan(text: 'Insufficient balance, Add fund '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    WebNavigationHelper.navigateTo(Routes.fundscreen);
                                  },
                                  child: Text(
                                    'Click here',
                                    style: MyntWebTextStyles.bodySmall(ctx,
                                        color: primaryColor,
                                        fontWeight: MyntFonts.semiBold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Close button
                      MyntPrimaryButton(
                        label: 'Close',
                        size: MyntButtonSize.large,
                        isFullWidth: true,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Marginposive Dialog Router ───
  // Branch A — Withdraw flow:
  //   holdingres != 'yes' OR blatranyesno != 'zero ledger balance'
  // Branch B — Holdings transfer (CMR upload):
  //   holdingres == 'yes' AND zerobal == 'some holdings'
  //                       AND blatranyesno == 'zero ledger balance'
  void _openMarginposiveDialog({
    required String holdingres,
    required String zerobal,
    required String blatranyesno,
    required double balance,
    required String reason,
    required dynamic clientData,
  }) {
    final bool branchB = holdingres == 'yes' &&
        zerobal == 'some holdings' &&
        blatranyesno == 'zero ledger balance';

    if (branchB) {
      _showHoldingsTransferDialog(reason: reason, clientData: clientData);
    } else {
      _showWithdrawBalanceDialog(balance);
    }
  }

  // ─── Withdraw Balance Dialog (marginposive Branch A) ───
  void _showWithdrawBalanceDialog(double balance) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cardBg = resolveThemeColor(ctx,
            dark: MyntColors.cardDark, light: MyntColors.card);
        final textColor = resolveThemeColor(ctx,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
        final subtitleColor = resolveThemeColor(ctx,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary);
        final dividerColor = resolveThemeColor(ctx,
            dark: MyntColors.dividerDark, light: MyntColors.divider);
        final primaryColor = resolveThemeColor(ctx,
            dark: MyntColors.primaryDark, light: MyntColors.primary);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 420,
            decoration: BoxDecoration(
                color: cardBg, borderRadius: BorderRadius.circular(8)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: dividerColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Account Closer?',
                          style:
                              MyntWebTextStyles.title(ctx, color: textColor)),
                      MyntCloseButton(onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: MyntWebTextStyles.bodySmall(ctx,
                              color: subtitleColor,
                              fontWeight: MyntFonts.regular),
                          children: [
                            const TextSpan(
                                text:
                                    'Please withdraw your available balance of '),
                            TextSpan(
                              text: 'Rs ${balance.toStringAsFixed(2)}',
                              style: MyntWebTextStyles.bodySmall(ctx,
                                  color: textColor,
                                  fontWeight: MyntFonts.semiBold),
                            ),
                            const TextSpan(
                                text:
                                    ' before submitting your closure request'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            WebNavigationHelper.navigateTo(Routes.fundscreen);
                          },
                          child: Text(
                            'Click here to withdraw Your Amount',
                            style: MyntWebTextStyles.bodySmall(ctx,
                                color: primaryColor,
                                fontWeight: MyntFonts.semiBold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      MyntPrimaryButton(
                        label: 'Close',
                        size: MyntButtonSize.large,
                        isFullWidth: true,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Holdings Transfer Dialog (CMR upload for transferring stocks) ───
  void _showHoldingsTransferDialog({
    required String reason,
    required dynamic clientData,
  }) {
    final dpIdController = TextEditingController();
    final boIdController = TextEditingController();
    Uint8List? cmrBytes;
    String? cmrFileName;
    bool submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          final cardBg = resolveThemeColor(ctx,
              dark: MyntColors.cardDark, light: MyntColors.card);
          final textColor = resolveThemeColor(ctx,
              dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
          final subtitleColor = resolveThemeColor(ctx,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.textSecondary);
          final dividerColor = resolveThemeColor(ctx,
              dark: MyntColors.dividerDark, light: MyntColors.divider);
          final primaryColor = resolveThemeColor(ctx,
              dark: MyntColors.primaryDark, light: MyntColors.primary);
          final errorColor = resolveThemeColor(ctx,
              dark: MyntColors.errorDark, light: MyntColors.error);
          final dropBg = resolveThemeColor(ctx,
              dark: const Color(0xff1A1F2A),
              light: const Color(0xFFF6F7F7));

          final bool canSubmit = dpIdController.text.trim().length >= 4 &&
              boIdController.text.trim().length >= 4 &&
              cmrBytes != null &&
              !submitting;

          Future<void> pickCmrFile() async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf'],
              withData: true,
            );
            if (result != null && result.files.isNotEmpty) {
              final file = result.files.first;
              if (file.bytes != null) {
                setDialogState(() {
                  cmrBytes = file.bytes;
                  cmrFileName = file.name;
                });
              }
            }
          }

          Future<void> onSubmit() async {
            setDialogState(() => submitting = true);
            try {
              final segmentsData = clientData.segmentsData;
              final bankDataJson = segmentsData != null
                  ? jsonEncode(
                      segmentsData.map((s) => s.toJson()).toList())
                  : '[]';

              final closureResp = await ref
                  .read(profileAllDetailsProvider)
                  .closeaccfinalspro(
                    dpIdController.text.trim(),
                    boIdController.text.trim(),
                    '',
                    reason,
                    clientData,
                    bankDataJson,
                    hasHoldings: true,
                    fileBytes: cmrBytes,
                    fileName: cmrFileName,
                  );

              if (closureResp is Map &&
                  closureResp['closure_fileid'] != null &&
                  closureResp['closure_mailid'] != null) {
                await ref
                    .read(profileAllDetailsProvider)
                    .fetchMobEmailStatus();
                if (mounted) Navigator.pop(ctx);
                if (mounted) _showClosureEsignConfirmationDialog();
              } else {
                final msg = closureResp is Map
                    ? (closureResp['msg'] ?? 'Closure request failed')
                    : 'Closure request failed';
                if (mounted) warningMessage(context, msg.toString());
              }
            } finally {
              if (mounted) setDialogState(() => submitting = false);
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 460,
              decoration: BoxDecoration(
                  color: cardBg, borderRadius: BorderRadius.circular(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: dividerColor)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Account Closure?',
                            style: MyntWebTextStyles.title(ctx,
                                color: textColor)),
                        MyntCloseButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kindly transfer your stocks to another demat account according to your wish',
                          style: MyntWebTextStyles.bodySmall(ctx,
                              color: textColor,
                              fontWeight: MyntFonts.semiBold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please enter your another Demat account details',
                          style: MyntWebTextStyles.bodySmall(ctx,
                              color: subtitleColor,
                              fontWeight: MyntFonts.regular),
                        ),
                        const SizedBox(height: 16),
                        Text('DP ID',
                            style: MyntWebTextStyles.caption(ctx,
                                color: subtitleColor,
                                fontWeight: MyntFonts.medium)),
                        const SizedBox(height: 6),
                        MyntTextField(
                          controller: dpIdController,
                          placeholder: 'Enter DP ID',
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(8),
                          ],
                          onChanged: (val) {
                            // Reject the user's own DP code (legacy:
                            // dpcode == profileData.CLIENT_DP_CODE.slice(-8))
                            final entered = val.trim();
                            final ownDpCode =
                                (clientData?.cLIENTDPCODE ?? '').toString();
                            final ownTail = ownDpCode.length >= 8
                                ? ownDpCode.substring(ownDpCode.length - 8)
                                : ownDpCode;
                            if (entered.length == 8 &&
                                ownTail.isNotEmpty &&
                                entered == ownTail) {
                              dpIdController.clear();
                              warningMessage(context,
                                  'Please use a different DP ID. You can\'t transfer holdings to the same demat account.');
                            }
                            setDialogState(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        Text('BO ID',
                            style: MyntWebTextStyles.caption(ctx,
                                color: subtitleColor,
                                fontWeight: MyntFonts.medium)),
                        const SizedBox(height: 6),
                        MyntTextField(
                          controller: boIdController,
                          placeholder: 'Enter BO ID',
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(8),
                          ],
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 16),
                        RichText(
                          text: TextSpan(
                            style: MyntWebTextStyles.bodySmall(ctx,
                                color: textColor,
                                fontWeight: MyntFonts.semiBold),
                            children: [
                              const TextSpan(text: 'Attach Your CMR Copy. '),
                              TextSpan(
                                text: '*',
                                style: MyntWebTextStyles.bodySmall(ctx,
                                    color: errorColor,
                                    fontWeight: MyntFonts.semiBold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Attach a copy of the CMR that is either digitally signed or sealed, and physically signed by the respective DP',
                          style: MyntWebTextStyles.caption(ctx,
                              color: subtitleColor,
                              fontWeight: MyntFonts.regular),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: dropBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: dividerColor,
                                style: BorderStyle.solid),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Upload your CMR Copy',
                                style: MyntWebTextStyles.body(ctx,
                                    color: primaryColor,
                                    fontWeight: MyntFonts.semiBold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select a file or drag it into the box below.',
                                style: MyntWebTextStyles.bodySmall(ctx,
                                    color: subtitleColor,
                                    fontWeight: MyntFonts.regular),
                              ),
                              const SizedBox(height: 12),
                              MyntPrimaryButton(
                                label: cmrBytes == null
                                    ? 'Choose File'
                                    : 'Replace File',
                                icon: Icons.upload,
                                size: MyntButtonSize.medium,
                                onPressed:
                                    submitting ? null : pickCmrFile,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Accepted formats: .pdf',
                                style: MyntWebTextStyles.caption(ctx,
                                    color: subtitleColor,
                                    fontWeight: MyntFonts.regular),
                              ),
                            ],
                          ),
                        ),
                        if (cmrFileName != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 16, color: Colors.green),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  cmrFileName!,
                                  overflow: TextOverflow.ellipsis,
                                  style: MyntWebTextStyles.bodySmall(ctx,
                                      color: textColor,
                                      fontWeight: MyntFonts.regular),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        MyntPrimaryButton(
                          label: 'Submit',
                          size: MyntButtonSize.large,
                          isFullWidth: true,
                          isLoading: submitting,
                          onPressed: canSubmit ? onSubmit : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ─── Positive Balance Dialog (shown when user needs to withdraw before closing) ───
  // ignore: unused_element
  void _showPositiveBalanceDialog(double balance) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cardBg = resolveThemeColor(ctx,
            dark: MyntColors.cardDark, light: MyntColors.card);
        final textColor = resolveThemeColor(ctx,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
        final subtitleColor = resolveThemeColor(ctx,
            dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
        final dividerColor = resolveThemeColor(ctx,
            dark: MyntColors.dividerDark, light: MyntColors.divider);
        final primaryColor = resolveThemeColor(ctx,
            dark: MyntColors.primaryDark, light: MyntColors.primary);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 420,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: dividerColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Account Closure ?',
                          style: MyntWebTextStyles.title(ctx, color: textColor)),
                      MyntCloseButton(onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: MyntWebTextStyles.bodySmall(ctx,
                              color: subtitleColor,
                              fontWeight: MyntFonts.regular),
                          children: [
                            const TextSpan(
                                text: 'Please withdraw your available balance of '),
                            TextSpan(
                              text: 'Rs ${balance.toStringAsFixed(2)}',
                              style: MyntWebTextStyles.bodySmall(ctx,
                                  color: textColor,
                                  fontWeight: MyntFonts.semiBold),
                            ),
                            const TextSpan(
                                text: ' before submitting your closure request.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Withdraw link row
                      RichText(
                        text: TextSpan(
                          style: MyntWebTextStyles.bodySmall(ctx,
                              color: subtitleColor,
                              fontWeight: MyntFonts.regular),
                          children: [
                            const TextSpan(text: 'Click here to '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  WebNavigationHelper.navigateTo(Routes.fundscreen);
                                },
                                child: Text(
                                  'Withdraw Your Amount',
                                  style: MyntWebTextStyles.bodySmall(ctx,
                                      color: primaryColor,
                                      fontWeight: MyntFonts.semiBold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      MyntPrimaryButton(
                        label: 'Close',
                        size: MyntButtonSize.large,
                        isFullWidth: true,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Submit Closure Request (balance check → closure API) ───
  Future<void> _submitClosureRequest(
      BuildContext dialogCtx, String reason, ThemesProvider themeVal) async {
    final provider = ref.read(profileAllDetailsProvider);
    final clientData = provider.clientAllDetails.clientData;

    if (clientData == null) {
      warningMessage(context, 'Profile data not available');
      return;
    }

    if (mounted) setState(() => _closureInitiateLoading = true);
    try {
    // Step 1: Run balance check + holdings check in parallel
    final results = await Future.wait([
      provider.closeaccnalprov(reason, clientData),
      provider.checkHoldingsForClosure(),
    ]);
    final balCheck = results[0];
    final holdingCheck = results[1] as Map<String, dynamic>?;

    if (balCheck == null) {
      if (mounted) warningMessage(context, 'Failed to check balance');
      return;
    }

    final String msg1 = (balCheck['msg1'] ?? '').toString().toLowerCase();
    final String msg2 = (balCheck['msg2'] ?? '').toString().toLowerCase();
    final String stat = (balCheck['stat'] ?? '').toString();
    final double balance = (balCheck['balance'] is num)
        ? (balCheck['balance'] as num).toDouble()
        : 0;

    final String holdingres =
        (holdingCheck?['holdings'] ?? '').toString().toLowerCase();
    final String zerobal = msg2;
    final String blatranyesno = msg2;
    final bool negativeLedger = msg1 == 'negative legeder balance' ||
        msg1.contains('negative');
    final bool positiveLedger = msg1 == 'postive ledger balance' ||
        msg1.contains('postive') ||
        msg1.contains('positive');

    // FIX 3 — 5-branch decision tree (order matters)
    // Branch 1: negative ledger + Not Ok → settle outstanding dialog
    if (negativeLedger && stat == 'Not Ok') {
      Navigator.pop(dialogCtx);
      if (mounted) {
        _showNegativeBalanceDialog(balance, clientData.cLIENTID ?? '');
      }
      return;
    }

    // Branch 2: stat == 'Ok' → clean account, fall through to closure submit
    if (stat == 'Ok') {
      // fall through to Step 2 below
    }
    // Branch 3: holdings present or zero-ledger msg2 → marginposive dialog
    else if (msg2 == 'some holdings' || msg2 == 'zero ledger balance') {
      Navigator.pop(dialogCtx);
      if (mounted) {
        _openMarginposiveDialog(
          holdingres: holdingres,
          zerobal: zerobal,
          blatranyesno: blatranyesno,
          balance: balance,
          reason: reason,
          clientData: clientData,
        );
      }
      return;
    }
    // Branch 4: positive ledger + Not Ok → marginposive (withdraw)
    else if (positiveLedger && stat == 'Not Ok') {
      Navigator.pop(dialogCtx);
      if (mounted) {
        _openMarginposiveDialog(
          holdingres: holdingres,
          zerobal: zerobal,
          blatranyesno: blatranyesno,
          balance: balance,
          reason: reason,
          clientData: clientData,
        );
      }
      return;
    }
    // Branch 5: unrecognized → surface backend message
    else {
      Navigator.pop(dialogCtx);
      if (mounted) {
        final String errtext =
            (balCheck['msg'] ?? balCheck['emsg'] ?? '').toString().trim();
        warningMessage(
          context,
          errtext.isNotEmpty
              ? errtext
              : 'Unable to process closure. Please try again.',
        );
      }
      return;
    }

    // Step 2: Submit closure API (no holdings here — handled above).
    final segmentsData = clientData.segmentsData;
    final bankDataJson =
        segmentsData != null ? jsonEncode(segmentsData.map((s) => s.toJson()).toList()) : '[]';

    final closureResp = await provider.closeaccfinalspro(
      '', // dpid (no transfer)
      '', // boid (no transfer)
      '', // filepath (no CMR)
      reason,
      clientData,
      bankDataJson,
      hasHoldings: false,
    );

    if (closureResp is Map &&
        closureResp['closure_fileid'] != null &&
        closureResp['closure_mailid'] != null) {
      Navigator.pop(dialogCtx);
      await provider.fetchMobEmailStatus();
      if (mounted) {
        _showClosureEsignConfirmationDialog();
      }
    } else {
      Navigator.pop(dialogCtx);
      final msg = closureResp is Map
          ? (closureResp['msg'] ?? 'Closure request failed')
          : 'Closure request failed';
      if (mounted) warningMessage(context, msg.toString());
    }
    } finally {
      if (mounted) setState(() => _closureInitiateLoading = false);
    }
  }

  // ─── Closure E-Sign Confirmation Dialog ───
  void _showClosureEsignConfirmationDialog() {
    final mobStatus = ref.read(profileAllDetailsProvider).mobEmailStatus;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.dialogDark, light: MyntColors.dialog),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with divider
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: resolveThemeColor(context,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'E-Sign Is Pending!',
                      style: MyntWebTextStyles.title(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ref
                              .read(profileAllDetailsProvider)
                              .fetchMobEmailStatus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Your Account Closure request is not yet Completed.',
                      textAlign: TextAlign.center,
                      style: MyntWebTextStyles.body(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _openClosureEsign(
                            fileId: mobStatus?.closureFileid ?? '',
                            email: (mobStatus?.closureClientEmail ?? '')
                                .toLowerCase(),
                            session: mobStatus?.closureSession ?? '',
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: resolveThemeColor(context,
                              dark: MyntColors.secondary,
                              light: MyntColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Click here E-sign',
                          style: MyntWebTextStyles.buttonMd(
                            context,
                            color: Colors.white,
                          ),
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
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHARED HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════

  /// Builds pending statuses display for a specific section
  Widget _buildSectionPendingStatuses(String sectionTitle, WidgetRef ref,
      ThemesProvider theme, VoidCallback onTap, VoidCallback onTapCancel) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final pendingStatuses =
        _getPendingStatusesForSection(sectionTitle, ref);

    if (pendingStatuses.isEmpty) {
      return const SizedBox.shrink();
    }

    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final errorColor = resolveThemeColor(context,
        dark: MyntColors.errorDark, light: MyntColors.error);
    final warningBg = resolveThemeColor(context,
        dark: const Color(0xFF3D2E00), light: const Color(0xFFFCEFD4));
    final warningText = resolveThemeColor(context,
        dark: const Color(0xFFFFD780), light: Colors.brown[800]!);
    final warningIcon = resolveThemeColor(context,
        dark: MyntColors.warningDark, light: MyntColors.warning);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: warningIcon, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Esign Pending - Click here to complete',
                  style: MyntWebTextStyles.bodySmall(context,
                      color: warningText, fontWeight: MyntFonts.medium)
                      .copyWith(decoration: TextDecoration.none),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Text('Click here E-sign',
                        style: MyntWebTextStyles.bodySmall(context,
                            color: primaryColor,
                            fontWeight: MyntFonts.semiBold)
                            .copyWith(decoration: TextDecoration.none)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              profileDetails.cancelpendingloader
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: errorColor))
                  : Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) {
                              final cardBg = resolveThemeColor(ctx,
                                  dark: MyntColors.cardDark, light: MyntColors.card);
                              final textColor = resolveThemeColor(ctx,
                                  dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
                              final subtitleColor = resolveThemeColor(ctx,
                                  dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
                              return Dialog(
                                backgroundColor: Colors.transparent,
                                child: Container(
                                  width: 420,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          InkWell(
                                            onTap: () => Navigator.pop(ctx),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Icon(Icons.close_rounded,
                                                size: 22, color: subtitleColor),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Are you sure want to cancel the Esign?',
                                        style: MyntWebTextStyles.body(ctx,
                                            color: textColor,
                                            fontWeight: MyntFonts.medium)
                                            .copyWith(decoration: TextDecoration.none),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: onTapCancel,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            minimumSize: const Size(0, 44),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: profileDetails.cancelpendingloader
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white))
                                              : Text('Yes',
                                                  style: MyntWebTextStyles.body(ctx,
                                                      color: Colors.white,
                                                      fontWeight: MyntFonts.semiBold)
                                                      .copyWith(decoration: TextDecoration.none)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Text('Cancel request',
                              style: MyntWebTextStyles.bodySmall(context,
                                  color: errorColor,
                                  fontWeight: MyntFonts.semiBold)
                                  .copyWith(decoration: TextDecoration.none)),
                        ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 12),

          /// Pending Status as Chips
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: pendingStatuses.map((status) {
              final displayName =
                  _getPendingStatusDisplayName(status);
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: warningIcon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: warningIcon.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  displayName,
                  style: MyntWebTextStyles.caption(context,
                      color: warningText, fontWeight: MyntFonts.medium)
                      .copyWith(decoration: TextDecoration.none),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Helper for consistent styling of profile detail rows
  Widget _buildDetailRow(
      String label, String value, ThemesProvider theme, WidgetRef ref) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.20,
              child: TextWidget.subText(
                text: label,
                theme: false,
                color: theme.isDarkMode
                    ? colors.textSecondaryDark
                    : colors.textSecondaryLight,
                fw: 0,
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: TextWidget.subText(
                text: value,
                theme: false,
                color: theme.isDarkMode
                    ? colors.textPrimaryDark
                    : colors.textPrimaryLight,
                softWrap: true,
                align: TextAlign.right,
                textOverflow: TextOverflow.ellipsis,
                maxLines: 4,
                fw: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(
          thickness: 0,
          color:
              theme.isDarkMode ? colors.dividerDark : colors.dividerLight,
        )
      ],
    );
  }

  /// Helper method to build data widget
  Widget _buildDataWidget(
      String label, String value, ThemesProvider theme) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextWidget.subText(
              text: label,
              theme: false,
              color: theme.isDarkMode
                  ? colors.textSecondaryDark
                  : colors.textSecondaryLight,
              fw: 0,
            ),
            SizedBox(
              width: 250,
              child: TextWidget.subText(
                text: value,
                theme: false,
                color: theme.isDarkMode
                    ? colors.textPrimaryDark
                    : colors.textPrimaryLight,
                align: TextAlign.right,
                fw: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(
          thickness: 1,
          color:
              theme.isDarkMode ? colors.dividerDark : colors.dividerLight,
        )
      ],
    );
  }

  /// Helper method to build segment rows
  Widget _buildSegmentRow(
      String label, Iterable segments, ThemesProvider theme) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextWidget.subText(
              text: label,
              theme: false,
              color: theme.isDarkMode
                  ? colors.textSecondaryDark
                  : colors.textSecondaryLight,
              fw: 0,
            ),
            Row(
              children: segments.map<Widget>((segment) {
                bool isActive = segment.aCTIVEINACTIVE == "A";
                String displayName =
                    ['CD_BSE', 'CD_NSE'].contains(segment.cOMPANYCODE)
                        ? segment.cOMPANYCODE.split("_")[1]
                        : segment.cOMPANYCODE.split("_")[0];

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isActive
                        ? theme.isDarkMode
                            ? colors.primaryDark
                            : colors.primaryLight
                        : null,
                    border: !isActive
                        ? Border(
                            bottom: BorderSide(
                              color: theme.isDarkMode
                                  ? colors.lossDark
                                  : colors.lossLight,
                              width: 1,
                            ),
                          )
                        : null,
                  ),
                  child: TextWidget.subText(
                    text: displayName,
                    theme: theme.isDarkMode,
                    color: isActive
                        ? colors.colorWhite
                        : theme.isDarkMode
                            ? colors.lossDark
                            : colors.lossLight,
                    fw: 0,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(
          thickness: 1,
          color:
              theme.isDarkMode ? colors.dividerDark : colors.dividerLight,
        )
      ],
    );
  }

  /// Formats nominee DOB from 'October, 07 1983 00:00:00 +0530' to '07/10/1983'
  String formatNomineeDOB(String rawDate) {
    try {
      DateTime date =
          DateFormat("MMMM, dd yyyy HH:mm:ss Z").parse(rawDate);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return rawDate;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  BANK CHANGE DIALOG (Add / Edit)
// ═══════════════════════════════════════════════════════════════
class _BankChangeDialog extends StatefulWidget {
  final bool isDark;
  final bool isEdit;
  final dynamic editingBank;
  final int bankCount;
  final Future<Map<String, dynamic>?> Function({
    required String acType,
    required String acNo,
    required String ifsc,
    required String proof,
    required bool primary,
    List<int>? fileBytes,
    String? fileName,
    String? password,
    bool? passwordRequired,
    String? bankName,
    String? branch,
    String? micr,
  }) onSubmit;
  final VoidCallback onDone;
  final dynamic provider;

  const _BankChangeDialog({
    required this.isDark,
    required this.isEdit,
    required this.editingBank,
    required this.bankCount,
    required this.onSubmit,
    required this.onDone,
    required this.provider,
  });

  @override
  State<_BankChangeDialog> createState() => _BankChangeDialogState();
}

class _BankChangeDialogState extends State<_BankChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _accountType;
  late TextEditingController _accountNoCtrl;
  late TextEditingController _ifscCtrl;
  late TextEditingController _manualBankNameCtrl;
  late TextEditingController _pdfPasswordCtrl;
  String _proofType = '';
  bool _setDefault = false;
  List<int>? _proofBytes;
  String? _proofFileName;
  bool _passwordField = false;
  Map<String, dynamic>? _ifscInfo;
  bool _isSubmitting = false;
  bool _isIfscLoading = false;
  bool _ifscNotFound = false;
  Timer? _ifscDebounce;

  Color get _textPrimary => resolveThemeColor(context,
      dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
  Color get _textSecondary => resolveThemeColor(context,
      dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
  Color get _cardBg => resolveThemeColor(context,
      dark: MyntColors.dialogDark, light: MyntColors.dialog);
  Color get _borderColor => resolveThemeColor(context,
      dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
  Color get _inputFillColor => resolveThemeColor(context,
      dark: MyntColors.inputBgDark, light: MyntColors.inputBg);

  final List<String> _proofTypes = [
    'Passbook',
    'Latest Statement',
    'Cancelled Cheque',
  ];

  @override
  void initState() {
    super.initState();
    _accountType =
        widget.isEdit ? (widget.editingBank?.bANKACCTYPE ?? 'Saving') : 'Saving';
    _accountNoCtrl = TextEditingController(
        text: widget.isEdit ? (widget.editingBank?.bankAcNo ?? '') : '');
    _ifscCtrl = TextEditingController(
        text: widget.isEdit ? (widget.editingBank?.iFSCCode ?? '') : '');
    _manualBankNameCtrl = TextEditingController();
    _pdfPasswordCtrl = TextEditingController();
    _setDefault = widget.isEdit
        ? (widget.editingBank?.defaultAc == 'Yes')
        : false;

    if (widget.isEdit && _ifscCtrl.text.length == 11) {
      _fetchIfsc(_ifscCtrl.text);
    }
  }

  @override
  void dispose() {
    _accountNoCtrl.dispose();
    _ifscCtrl.dispose();
    _manualBankNameCtrl.dispose();
    _pdfPasswordCtrl.dispose();
    _ifscDebounce?.cancel();
    super.dispose();
  }

  void _fetchIfsc(String code) async {
    if (code.length < 11) {
      setState(() {
        _ifscInfo = null;
        _ifscNotFound = false;
      });
      return;
    }
    setState(() {
      _isIfscLoading = true;
      _ifscNotFound = false;
    });
    final data = await widget.provider.ifscLookup(code);
    if (mounted) {
      setState(() {
        _ifscInfo = data;
        _isIfscLoading = false;
        _ifscNotFound = data == null;
      });
      if (data == null) {
        error(context, 'Invalid IFSC code. Please check and try again.');
      }
    }
  }

  void _onIfscChanged(String val) {
    _ifscDebounce?.cancel();
    _ifscDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchIfsc(val.toUpperCase());
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        setState(() {
          _proofBytes = file.bytes!.toList();
          _proofFileName = file.name;
        });
        // Check if PDF is locked
        final lockResult = await widget.provider.pdfLockCheck(
          fileBytes: _proofBytes!,
          fileName: _proofFileName!,
        );
        if (lockResult != null && lockResult.toString().contains('locked')) {
          setState(() => _passwordField = true);
        } else {
          setState(() => _passwordField = false);
        }
      }
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ifscInfo == null || _ifscNotFound) {
      error(context, 'Please enter a valid IFSC code');
      return;
    }
    if (_isIfscLoading) {
      error(context, 'Please wait while IFSC code is being verified');
      return;
    }
    if (!widget.isEdit && _proofType.isEmpty) {
      error(context, 'Please select a proof type');
      return;
    }
    if (_proofBytes == null || _proofFileName == null) {
      error(context, 'Please upload bank proof');
      return;
    }
    if (_passwordField && _pdfPasswordCtrl.text.isEmpty) {
      error(context, 'Please enter PDF password');
      return;
    }

    // If password required, verify
    if (_passwordField) {
      final passResult = await widget.provider.pdfPasswordCheck(
        fileBytes: _proofBytes!,
        fileName: _proofFileName!,
        password: _pdfPasswordCtrl.text,
      );
      if (passResult == null ||
          passResult.toString().contains('incorrect')) {
        if (mounted) {
          error(context, 'Incorrect PDF password');
        }
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final bankName = _ifscInfo?['BANK'] ?? _manualBankNameCtrl.text;
    final branch = _ifscInfo?['BRANCH'] ?? '';
    final micr = _ifscInfo?['MICR'] ?? '';

    final result = await widget.onSubmit(
      acType: _accountType,
      acNo: _accountNoCtrl.text.trim(),
      ifsc: _ifscCtrl.text.trim().toUpperCase(),
      proof: _proofType,
      primary: _setDefault,
      fileBytes: _proofBytes,
      fileName: _proofFileName,
      password: _passwordField ? _pdfPasswordCtrl.text : null,
      passwordRequired: _passwordField,
      bankName: bankName,
      branch: branch,
      micr: micr,
    );

    if (mounted) setState(() => _isSubmitting = false);

    if (result != null && !result.containsKey('msg')) {
      widget.onDone();
    } else if (result != null && mounted) {
      error(context, result['msg']?.toString() ?? 'Operation failed');
    }
  }

  InputDecoration _themedInputDecoration(String hint) {
    final focusBorderColor = resolveThemeColor(context,
        dark: MyntColors.outlinedBorderDark, light: MyntColors.outlinedBorder);
    return InputDecoration(
      hintText: hint,
      hintStyle: MyntWebTextStyles.placeholder(context, color: _textSecondary),
      filled: true,
      fillColor: _inputFillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: focusBorderColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialogBg = resolveThemeColor(context,
        dark: MyntColors.dialogDark, light: MyntColors.dialog);
    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final shadow = isDarkMode(context) ? MyntShadows.modalDark : MyntShadows.modal;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
          boxShadow: shadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: dividerColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.isEdit
                          ? 'Edit Your Bank Details Here'
                          : 'Bank change request',
                      style: MyntWebTextStyles.title(context, color: _textPrimary),
                    ),
                  ),
                  MyntCloseButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                // Account Type chips
                Row(
                  children: ['Saving', 'Current'].map((type) {
                    final selected = _accountType == type;
                    final primaryColor = resolveThemeColor(context,
                        dark: MyntColors.secondary, light: MyntColors.primary);
                    final chipBorderColor = resolveThemeColor(context,
                        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
                    final textColor = resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 100,
                        child: ChoiceChip(
                          label: SizedBox(
                            width: double.infinity,
                            child: Center(child: Text(type)),
                          ),
                          showCheckmark: false,
                          selected: selected,
                          selectedColor: primaryColor,
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(
                              color: selected ? primaryColor : chipBorderColor,
                            ),
                          ),
                          labelStyle: MyntWebTextStyles.bodySmall(context,
                            color: selected ? Colors.white : textColor,
                            fontWeight: selected ? MyntFonts.semiBold : MyntFonts.regular,
                          ).copyWith(decoration: TextDecoration.none),
                          labelPadding: EdgeInsets.zero,
                          onSelected: (_) {
                            setState(() => _accountType = type);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Bank A/C No
                _buildLabel('Bank A/C No'),
                const SizedBox(height: 6),
                MyntFormTextField(
                  controller: _accountNoCtrl,
                  readOnly: widget.isEdit,
                  enabled: !widget.isEdit,
                  keyboardType: TextInputType.number,
                  placeholder: 'Enter Bank A/C No',
                ),
                const SizedBox(height: 16),

                // IFSC Code
                _buildLabel('IFSC CODE'),
                const SizedBox(height: 6),
                SizedBox(
                  height: 45,
                  child: TextField(
                    controller: _ifscCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    onChanged: _onIfscChanged,
                    style: MyntWebTextStyles.bodyMedium(context),
                    decoration: InputDecoration(
                      hintText: 'Enter IFSC Code',
                      hintStyle: MyntWebTextStyles.placeholder(context),
                      filled: true,
                      fillColor: resolveThemeColor(
                        context,
                        dark: const Color(0xffB5C0CF).withOpacity(.15),
                        light: const Color(0xffF1F3F8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      suffixIcon: _isIfscLoading
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary)),
                              ),
                            )
                          : _ifscNotFound && _ifscCtrl.text.length >= 11
                              ? Icon(Icons.error_outline,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.errorDark,
                                      light: MyntColors.error),
                                  size: 20)
                              : _ifscInfo != null
                                  ? Icon(Icons.check_circle,
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.successDark,
                                          light: MyntColors.success),
                                      size: 20)
                                  : null,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.primary),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.primary),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.primary),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.primary),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),

                if (_ifscNotFound && _ifscCtrl.text.length >= 11) ...[
                  const SizedBox(height: 4),
                  Text(
                    'IFSC code not found. Please enter a valid IFSC code.',
                    style: MyntWebTextStyles.para(context,
                      color: resolveThemeColor(context,
                        dark: MyntColors.errorDark, light: MyntColors.error)
                    ),
                  ),
                ],

                // IFSC info display
                if (_ifscInfo != null && _ifscInfo!['BRANCH'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _inputFillColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ifscInfo!['BANK'] ?? '',
                          style: MyntWebTextStyles.body(context,
                            color: _textPrimary,
                            fontWeight: MyntFonts.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_ifscInfo!['BRANCH'] ?? ''}, ${_ifscInfo!['CITY'] ?? ''}, ${_ifscInfo!['STATE'] ?? ''} | ${_ifscInfo!['MICR'] ?? ''}',
                          style: MyntWebTextStyles.para(context,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Proof Type (hidden when editing an existing bank)
                if (!widget.isEdit) ...[
                  _buildLabel('Proof Type'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _inputFillColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _proofType.isEmpty ? null : _proofType,
                        hint: Text('Proof type',
                            style: MyntWebTextStyles.placeholder(context,
                              color: _textSecondary)),
                        isExpanded: true,
                        dropdownColor: _cardBg,
                        style: MyntWebTextStyles.body(context, color: _textPrimary),
                        items: _proofTypes.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(t),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _proofType = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Bank Proof Upload
                _buildLabel('Bank Proof'),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickFile,
                  child: Container(
                    width: double.infinity,
                    height: 130,
                    decoration: BoxDecoration(
                      color: _inputFillColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _borderColor,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Upload your Bank Proof',
                          style: MyntWebTextStyles.body(context,
                            fontWeight: MyntFonts.bold,
                            darkColor: MyntColors.primaryDark,
                            lightColor: MyntColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select a file or drag it into the box below.',
                          style: MyntWebTextStyles.para(context,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.upload,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'Choose File',
                                style: MyntWebTextStyles.para(context,
                                  color: Colors.white,
                                  fontWeight: MyntFonts.medium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Accepted formats: .pdf',
                          style: MyntWebTextStyles.caption(context,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Selected file indicator
                if (_proofFileName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check, size: 16,
                        color: resolveThemeColor(context,
                          dark: MyntColors.profitDark, light: MyntColors.profit)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _proofFileName!,
                          style: MyntWebTextStyles.bodySmall(context,
                            color: _textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // PDF Password
                if (_passwordField) ...[
                  const SizedBox(height: 16),
                  _buildLabel('Password'),
                  const SizedBox(height: 6),
                  MyntFormTextField(
                    controller: _pdfPasswordCtrl,
                    placeholder: 'Pdf Password',
                    obscureText: true,
                  ),
                ],

                // Set as primary checkbox
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _setDefault,
                      onChanged: (widget.isEdit && widget.bankCount == 1)
                          ? null
                          : (v) {
                              setState(() => _setDefault = v ?? false);
                            },
                      shape: const CircleBorder(),
                      activeColor: resolveThemeColor(context,
                        dark: MyntColors.primaryDark, light: MyntColors.primary),
                    ),
                    Text(
                      'Set as primary',
                      style: MyntWebTextStyles.body(context,
                        color: _textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Submit button
                const SizedBox(height: 8),
                MyntPrimaryButton(
                  label: 'Submit',
                  size: MyntButtonSize.large,
                  isFullWidth: true,
                  isLoading: _isSubmitting,
                  onPressed: (_passwordField && _pdfPasswordCtrl.text.isEmpty)
                      ? null
                      : _onSubmit,
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

  Widget _buildLabel(String text) {
    final errorColor = resolveThemeColor(context,
        dark: MyntColors.errorDark, light: MyntColors.error);
    return RichText(
      text: TextSpan(
        text: text,
        style: MyntWebTextStyles.body(context,
          color: _textPrimary,
          fontWeight: MyntFonts.medium,
        ),
        children: [
          TextSpan(
            text: ' *',
            style: TextStyle(color: errorColor),
          ),
        ],
      ),
    );
  }
}

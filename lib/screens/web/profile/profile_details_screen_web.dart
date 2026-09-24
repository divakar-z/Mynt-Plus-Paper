import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/models/client_profile_all_details/profile_all_details_model.dart';
import 'package:mynt_plus/provider/profile_all_details_provider.dart';
import 'package:mynt_plus/provider/user_profile_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import 'package:mynt_plus/utils/digio_esign.dart';

class ProfileDetailsScreenWeb extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  /// Digilocker callback params (from same-window redirect)
  final String? digilockerCode;
  final String? digilockerState;

  const ProfileDetailsScreenWeb({
    super.key,
    this.onBack,
    this.digilockerCode,
    this.digilockerState,
  });

  @override
  ConsumerState<ProfileDetailsScreenWeb> createState() =>
      _ProfileDetailsScreenWebState();
}

class _ProfileDetailsScreenWebState
    extends ConsumerState<ProfileDetailsScreenWeb> {
  bool _mobileEsignLoading = false;
  bool _emailEsignLoading = false;
  bool _addressEsignLoading = false;
  bool _cancelLoading = false;
  bool _kraProcessLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(profileAllDetailsProvider).fetchClientProfileAllDetails();
      ref.read(profileAllDetailsProvider).fetchPendingstatus();
      ref.read(profileAllDetailsProvider).fetchMobEmailStatus();
      ref.read(profileAllDetailsProvider).fetchRekycStatus();

      // Auto-trigger Digilocker address change if callback params present
      _checkDigilockerCallback();
    });
  }

  /// Check if we returned from Digilocker OAuth redirect with code/state params.
  /// If so, clear URL params and trigger the address change flow automatically.
  Future<void> _checkDigilockerCallback() async {
    final code = widget.digilockerCode;
    final state = widget.digilockerState;
    if (code != null && code.isNotEmpty && state != null && state.isNotEmpty) {
      // Clear code/state from URL so refresh doesn't re-trigger
      clearDigilockerCallbackParams();
      setState(() => _kraProcessLoading = true);
      await _handleDigilockerAddressChange(code, state);
    }
  }

  Future<void> _handleDigilockerAddressChange(String code, String state) async {
    final provider = ref.read(profileAllDetailsProvider);

    // Step 1: KRA image check
    final kraResult = await provider.kraImageCheck();
    if (!kraResult) {
      if (!mounted) return;
      setState(() => _kraProcessLoading = false);
      final selfieBytes = await showDialog<List<int>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _KraSelfieDialog(
          isDarkMode: ref.read(themeProvider).isDarkMode,
        ),
      );
      if (selfieBytes == null || selfieBytes.isEmpty) {
        return;
      }
      setState(() => _kraProcessLoading = true);
      final uploadResult =
          await provider.uploadKraSelfie(imageBytes: selfieBytes);
      if (uploadResult != 'image saved') {
        if (mounted) {
          setState(() => _kraProcessLoading = false);
          warningMessage(context, uploadResult ?? 'Image upload failed');
        }
        return;
      }
    }

    // Step 2: Submit Digilocker address change
    final result = await provider.addressChangeDigilocker(
      code: code,
      state: state,
    );

    if (mounted) setState(() => _kraProcessLoading = false);

    if (result != null && result['fileid'] != null) {
      // Fetch status and show esign dialog
      await provider.fetchMobEmailStatus();
      if (mounted) _showEsignPendingDialog('address');
    } else if (mounted) {
      warningMessage(context, 'Error in Server, please try again later');
    }
  }

  // ─── Digio Inline E-Sign ───
  Future<void> _openDigioEsign({
    required String fileId,
    required String email,
    required String session,
    required String type,
  }) async {
    final provider = ref.read(profileAllDetailsProvider);

    if (fileId.isEmpty || email.isEmpty) {
      warningMessage(context, 'E-Sign details not available');
      return;
    }

    setState(() {
      if (type == 'mobile_change') _mobileEsignLoading = true;
      if (type == 'email_change') _emailEsignLoading = true;
      if (type == 'address_change') _addressEsignLoading = true;
    });

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
          type: type,
        );
      }

      provider.fetchClientProfileAllDetails();
      provider.fetchMobEmailStatus();
      provider.fetchPendingstatus();

      if (mounted) {
        if (result == 'success') {
          successMessage(context, 'E-Sign completed successfully');
        } else {
          warningMessage(context, 'E-Sign was cancelled');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _mobileEsignLoading = false;
          _emailEsignLoading = false;
          _addressEsignLoading = false;
        });
      }
    }
  }

  // ─── Cancel Request ───
  Future<void> _cancelRequest(String type) async {
    final provider = ref.read(profileAllDetailsProvider);
    setState(() => _cancelLoading = true);
    try {
      provider.cancelPendingloader(true);
      final fileid = await provider.api.fetctfileidapi(type);
      final response =
          await provider.api.cancelPendingStatusApi(type, fileid ?? '');
      if (response == 'Cancel Success') {
        await provider.fetchMobEmailStatus();
        await provider.fetchPendingstatus();
        if (mounted) successMessage(context, 'Cancellation Success');
      } else {
        if (mounted) warningMessage(context, 'Cancellation Failed');
      }
    } catch (e) {
      if (mounted) warningMessage(context, 'Something Went Wrong');
    } finally {
      provider.cancelPendingloader(false);
      if (mounted) setState(() => _cancelLoading = false);
    }
  }

  // ─── Cancel Request Confirmation Dialog ───
  void _showCancelRequestDialog(String type, String displayName) {
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
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.dividerDark,
                        light: MyntColors.divider,
                      ),
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
                      'Are you sure you want to cancel your "$displayName" request?',
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
                          _cancelRequest(type);
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

  // ─── E-Sign Pending Confirmation Dialog (after OTP verify) ───
  void _showEsignPendingDialog(String type) {
    String displayName = '';
    if (type == 'mobile') {
      displayName = 'Mobile';
    } else if (type == 'email') {
      displayName = 'Email';
    } else if (type == 'address') {
      displayName = 'Address';
    } else if (type == 'income') {
      displayName = 'Income';
    }

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
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.dividerDark,
                        light: MyntColors.divider,
                      ),
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
                      'Your $displayName Change request is not yet Completed.',
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
                          final freshStatus = ref.read(profileAllDetailsProvider).mobEmailStatus;
                          String fId = '';
                          String em = '';
                          String sess = '';
                          if (type == 'mobile') {
                            fId = freshStatus?.mobileFileId ?? '';
                            em = (freshStatus?.mobClientEmail ?? '').toUpperCase();
                            sess = freshStatus?.mobSession ?? '';
                          } else if (type == 'email') {
                            fId = freshStatus?.emailFileId ?? '';
                            em = (freshStatus?.emailNewEmailId ?? '').toLowerCase();
                            sess = freshStatus?.emailSession ?? '';
                          } else if (type == 'address') {
                            fId = freshStatus?.addressFileId ?? '';
                            em = (freshStatus?.addressClientEmail ?? '').toLowerCase();
                            sess = freshStatus?.addressSession ?? '';
                          }
                          _openDigioEsign(fileId: fId, email: em, session: sess, type: '${type}_change');
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

  // ─── KRA Image Check + File Write Flow ───
  Future<void> _handleKraCheckAndProceed(String type) async {
    final profileProvider = ref.read(profileAllDetailsProvider);
    final clientData = profileProvider.clientAllDetails.clientData;

    setState(() => _kraProcessLoading = true);

    try {
      // Step 1: Check KRA image
      final kraResult = await profileProvider.kraImageCheck();

      if (kraResult) {
        // Step 2a: Image exists → proceed with file write
        await _proceedFileWrite(type, profileProvider, clientData!);
      } else {
        // Step 2b: No image → hide loader, show selfie capture dialog
        if (!mounted) return;
        setState(() => _kraProcessLoading = false);
        final selfieBytes = await showDialog<List<int>>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _KraSelfieDialog(
            isDarkMode: ref.read(themeProvider).isDarkMode,
          ),
        );
        if (selfieBytes != null && selfieBytes.isNotEmpty) {
          if (!mounted) return;
          setState(() => _kraProcessLoading = true);
          // Step 3: Upload selfie
          final uploadResult =
              await profileProvider.uploadKraSelfie(imageBytes: selfieBytes);
          if (uploadResult == 'image saved') {
            // Step 4: Proceed with file write
            if (!mounted) return;
            await _proceedFileWrite(type, profileProvider, clientData!);
          } else {
            if (mounted) {
              warningMessage(context, uploadResult ?? 'Image upload failed');
            }
          }
        }
      }
    } finally {
      if (mounted) setState(() => _kraProcessLoading = false);
    }
  }

  Future<void> _proceedFileWrite(
      String type, ProfileProvider profileProvider, ClientData clientData) async {
    Map<String, dynamic>? result;
    if (type == 'mobile') {
      result = await profileProvider.mobileFileWriteWeb(
        profileProvider.newMobController.text,
        clientData,
      );
    } else if (type == 'email') {
      result = await profileProvider.emailFileWriteWeb(
        profileProvider.newEmailController.text,
        clientData.cLIENTIDMAIL ?? '',
        clientData.cLIENTDPCODE ?? '',
      );
    } else if (type == 'address') {
      // Address already submitted via addressChangeWeb; just refresh + show esign
      await profileProvider.fetchMobEmailStatus();
      if (mounted) _showEsignPendingDialog(type);
      return;
    }

    if (result != null && result['fileid'] != null) {
      await profileProvider.fetchMobEmailStatus();
      if (mounted) _showEsignPendingDialog(type);
    } else {
      if (mounted) {
        warningMessage(
            context, result?['msg']?.toString() ?? 'Request failed');
      }
    }
  }

  // ─── Personal-info edit-gate (email / mobile / address)
  // Returns null when edit is
  // allowed, otherwise an _EditBlock describing the disabled state.
  // `checkRekyc` adds the mid-Re-KYC block which only applies to email &
  // mobile per the spec. The Re-KYC case is intentionally a "silent disable":
  // button visible & disabled, no tooltip
  _EditBlock? _personalInfoEditBlock({
    required bool checkRekyc,
    bool checkActive = true,
  }) {
    final provider = ref.read(profileAllDetailsProvider);
    final clientData = provider.clientAllDetails.clientData;
    final mobStatus = provider.mobEmailStatus;
    if (clientData == null || mobStatus == null) return null;

    if (clientData.isClientClosed) {
      const closedTooltip = 'Your trading account is closed.';
      // Spec: when closed, individual users without an active Re-KYC keep a
      // clickable EDIT button (showing the closed tooltip); the click is
      // effectively a no-op because the dialog handler re-checks and toasts.
      if (!clientData.isIndividual) {
        return const _EditBlock(tooltip: closedTooltip);
      }
      if (checkRekyc && provider.rekycStatus.toLowerCase() == 'yes') {
        return const _EditBlock(tooltip: closedTooltip);
      }
      return const _EditBlock(tooltip: closedTooltip, clickable: true);
    }
    if (!clientData.isIndividual) {
      return const _EditBlock(
          tooltip: "Non-individual accounts can't modify data here. "
              "Please contact support at (+91) 93 8010 8010 for help.");
    }
    if (checkActive &&
        (mobStatus.accSgtAtveSts ?? '').toLowerCase() != 'active') {
      return const _EditBlock(
          tooltip: 'Modification not allowed for inactive client codes. '
              'Please reactivate the account.');
    }
    if (mobStatus.last7DaysCheck != true) {
      return const _EditBlock(
          tooltip:
              'Modification request not allowed within 7 days of activation');
    }
    // Re-KYC gate: source of truth is /checkrekyc (provider.rekycStatus),
    // The rekyc_status field returned by /add_mob_email_stat is intentionally ignored here.
    if (checkRekyc && provider.rekycStatus.toLowerCase() == 'yes') {
      return const _EditBlock(tooltip: null);
    }
    return null;
  }

  // ─── Email Change Dialog ───
  void _showEmailChangeDialog() {
    final block =
        _personalInfoEditBlock(checkRekyc: true, checkActive: false);
    if (block != null) {
      if (block.tooltip != null) warningMessage(context, block.tooltip!);
      return;
    }
    final profileProvider = ref.read(profileAllDetailsProvider);
    final clientData = profileProvider.clientAllDetails.clientData;
    profileProvider.newEmailController.clear();
    profileProvider.newEmailOTPController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _EmailChangeDialog(
          profileProvider: profileProvider,
          clientData: clientData!,
          onEsign: () {
            Navigator.of(ctx).pop();
            _handleKraCheckAndProceed('email');
          },
        );
      },
    );
  }

  // ─── Mobile Change Dialog ───
  void _showMobileChangeDialog() {
    final block =
        _personalInfoEditBlock(checkRekyc: true, checkActive: false);
    if (block != null) {
      if (block.tooltip != null) warningMessage(context, block.tooltip!);
      return;
    }
    final profileProvider = ref.read(profileAllDetailsProvider);
    final clientData = profileProvider.clientAllDetails.clientData;
    profileProvider.newMobController.clear();
    profileProvider.newMobOTPController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _MobileChangeDialog(
          profileProvider: profileProvider,
          clientData: clientData!,
          onEsign: () {
            Navigator.of(ctx).pop();
            _handleKraCheckAndProceed('mobile');
          },
        );
      },
    );
  }

  // ─── Address Change ───
  // Address modification is handled by the profile portal. The portal
  // auto-logs-in from the uid + session token passed on the query string.
  void _showAddressChangeDialog() {
    final block = _personalInfoEditBlock(checkRekyc: false);
    if (block != null) {
      if (block.tooltip != null) warningMessage(context, block.tooltip!);
      return;
    }
    final pref = locator<Preferences>();
    final clientData = ref.read(profileAllDetailsProvider).clientAllDetails.clientData;
    final uid = (clientData?.cLIENTID ?? pref.clientId ?? '').trim();
    final token = (pref.clientSession ?? '').trim();
    if (uid.isEmpty || token.isEmpty) {
      warningMessage(context, 'Session expired, please login again');
      return;
    }
    // page=app tells the portal the request originated from app.mynt.in.
    final url = Uri.https('profile.mynt.in', '/',
        {'uid': uid, 'token': token, 'page': 'app'}).toString();
    html.window.open(url, '_blank');
  }

  // ─── Annual Income edit-gate
  //   !atve_sts        → "Modification not allowed for inactive client code…"
  //   !CATEGORY=='I'   → "Non-individual accounts can't modify data here…"
  // Income modification is exempt from the 7-day post-activation block, so
  // last7days is deliberately not checked here.
  // Returns null when edit is allowed, otherwise a user-facing reason string.
  // The yearlyIncomeDisable gate (e-sign pending/completed) is handled at the call site via incomeStatus
  _EditBlock? _annualIncomeEditBlock() {
    final provider = ref.read(profileAllDetailsProvider);
    final clientData = provider.clientAllDetails.clientData;
    final mobStatus = provider.mobEmailStatus;
    if (clientData == null || mobStatus == null) return null;

    // client_close: takes precedence over atve_sts/CATEGORY. Individual users
    // keep a clickable EDIT button (the dialog handler re-checks and toasts);
    // non-individuals are fully disabled. Both show the closed tooltip.
    if (clientData.isClientClosed) {
      const closedTooltip = 'Your trading account is closed.';
      if (!clientData.isIndividual) {
        return const _EditBlock(tooltip: closedTooltip);
      }
      return const _EditBlock(tooltip: closedTooltip, clickable: true);
    }
    // atve_sts (Annual Income: precedence flipped — checked before CATEGORY)
    if ((mobStatus.accSgtAtveSts ?? '').toLowerCase() != 'active') {
      return const _EditBlock(
          tooltip: 'Modification not allowed for inactive client code. '
              'Please reactivate the account');
    }
    // CATEGORY == 'I'
    if (!clientData.isIndividual) {
      return const _EditBlock(
          tooltip: "Non-individual accounts can't modify data here. "
              "Please contact support at (+91) 93 8010 8010 for help.");
    }
    return null;
  }

  // ─── Income Change Dialog ───
  void _showIncomeChangeDialog() {
    final block = _annualIncomeEditBlock();
    if (block != null) {
      if (block.tooltip != null) warningMessage(context, block.tooltip!);
      return;
    }
    final profileProvider = ref.read(profileAllDetailsProvider);
    final clientData = profileProvider.clientAllDetails.clientData;
    final themeVal = ref.watch(themeProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _IncomeChangeDialog(
          profileProvider: profileProvider,
          clientData: clientData!,
          isDarkMode: themeVal.isDarkMode,
          onDone: () {
            Navigator.of(ctx).pop();
            // Refresh data after income change
            profileProvider.fetchClientProfileAllDetails();
            profileProvider.fetchMobEmailStatus();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = ref.watch(profileAllDetailsProvider);
    final clientData = profileProvider.clientAllDetails.clientData;

    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final cardBorder = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    return Stack(
      children: [
        Scaffold(
      backgroundColor: Colors.transparent,
      body: clientData == null
          ? const Center(child: MyntLoader())
          : SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Page Title with back ---
                  Row(
                    children: [
                      CustomBackBtn(onBack: widget.onBack),
                      const SizedBox(width: 4),
                      Text(
                        "Profile Details",
                        style: MyntWebTextStyles.title(context,
                          color: textColor, fontWeight: MyntFonts.semiBold,
                        ).copyWith(decoration: TextDecoration.none),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- Personal Information ---
                  _buildPersonalInfoSection(clientData, profileProvider, cardBg,
                      cardBorder, textColor, subtitleColor),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    ),
        // Loading overlay
        if (_kraProcessLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: Center(
              child: CircularProgressIndicator(
                color: resolveThemeColor(context,
                    dark: MyntColors.primaryDark, light: MyntColors.primary),
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  USER HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildUserHeader(ClientData clientData, Color textColor,
      Color subtitleColor, Color cardBg, Color cardBorder) {
    final profileImage = ref.watch(userProfileProvider).getprofileImage;
    final initial = (clientData.panName != null && clientData.panName!.isNotEmpty)
        ? clientData.panName![0]
        : "";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          // Profile image or initial
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: resolveThemeColor(context,
                dark: MyntColors.cardHoverDark,
                light: MyntColors.cardHover),
              border: Border.all(
                color: resolveThemeColor(context,
                  dark: MyntColors.cardBorderDark,
                  light: MyntColors.cardBorder),
                width: 2,
              ),
              image: profileImage != null
                  ? DecorationImage(
                      image: MemoryImage(profileImage),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: profileImage == null
                ? Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          // Name, UCC, PAN
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientData.panName ?? "",
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.title(context,
                    color: textColor, fontWeight: MyntFonts.semiBold,
                  ).copyWith(decoration: TextDecoration.none),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildInfoChip("UCC: ${clientData.cLIENTID ?? ''}"),
                    const SizedBox(width: 8),
                    _buildInfoChip("PAN: ${clientData.pANNO ?? ''}"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
          dark: MyntColors.cardHoverDark,
          light: MyntColors.cardHover),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: MyntWebTextStyles.caption(context,
          darkColor: MyntColors.textSecondaryDark,
          lightColor: MyntColors.textSecondary,
          fontWeight: MyntFonts.medium,
        ).copyWith(decoration: TextDecoration.none),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PENDING STATUS SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPendingStatusSection(ProfileProvider profileProvider,
      Color textColor, Color subtitleColor, Color cardBg, Color dividerColor) {
    if (profileProvider.pendingStatusList.isEmpty ||
        profileProvider.pendingStatusList[0].data == null ||
        profileProvider.pendingStatusList[0].data!.isEmpty) {
      return const SizedBox.shrink();
    }

    final pendingStatuses = profileProvider.pendingStatusList[0].data!;

    final warningBg = resolveThemeColor(context,
        dark: const Color(0xFF3D2E00), light: const Color(0xFFFCEFD4));
    final warningText = resolveThemeColor(context,
        dark: const Color(0xFFFFD780), light: Colors.brown[800]!);
    final warningIcon = resolveThemeColor(context,
        dark: MyntColors.warningDark, light: MyntColors.warning);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final errorColor = resolveThemeColor(context,
        dark: MyntColors.errorDark, light: MyntColors.error);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  onTap: () async {
                    var mobStatus = profileProvider.mobEmailStatus;
                    if (mobStatus == null ||
                        ((mobStatus.emailFileId ?? '').isEmpty &&
                            (mobStatus.mobileFileId ?? '').isEmpty &&
                            (mobStatus.addressFileId ?? '').isEmpty)) {
                      await profileProvider.fetchMobEmailStatus();
                      mobStatus = profileProvider.mobEmailStatus;
                    }
                    if (!mounted) return;
                    if (pendingStatuses
                        .any((s) => s == 'email_change_pending')) {
                      _openDigioEsign(
                        fileId: mobStatus?.emailFileId ?? '',
                        email: (mobStatus?.emailNewEmailId ?? '').toLowerCase(),
                        session: mobStatus?.emailSession ?? '',
                        type: 'email_change',
                      );
                    } else if (pendingStatuses
                        .any((s) => s == 'mobile_change_pending')) {
                      _openDigioEsign(
                        fileId: mobStatus?.mobileFileId ?? '',
                        email: (mobStatus?.mobClientEmail ?? '').toUpperCase(),
                        session: mobStatus?.mobSession ?? '',
                        type: 'mobile_change',
                      );
                    } else if (pendingStatuses
                        .any((s) => s == 'address_change_pending')) {
                      _openDigioEsign(
                        fileId: mobStatus?.addressFileId ?? '',
                        email:
                            (mobStatus?.addressClientEmail ?? '').toLowerCase(),
                        session: mobStatus?.addressSession ?? '',
                        type: 'address_change',
                      );
                    }
                  },
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showCancelRequestDialog(
                      'pending_status', 'Pending E-Sign'),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pendingStatuses.map((status) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: warningIcon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: warningIcon.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _getPendingDisplayName(status),
                  style: MyntWebTextStyles.caption(context,
                          color: warningText,
                          fontWeight: MyntFonts.semiBold)
                      .copyWith(decoration: TextDecoration.none),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getPendingDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'email_change_pending':
        return 'Email Change';
      case 'mobile_change_pending':
        return 'Mobile Change';
      case 'address_change_pending':
        return 'Address Change';
      case 'bank_change_pending':
        return 'Bank Change';
      case 'ddpicre_pending':
        return 'DDPI';
      case 'mtf_pending':
        return 'MTF';
      case 'closure_pending':
        return 'Account Closure';
      case 'nominee_pending':
        return 'Nominee';
      case 'segments_change_pending':
        return 'Segments Change';
      case 'income_change_pending':
        return 'Income Change';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  PERSONAL INFO SECTION (with inline edit buttons)
  // ═══════════════════════════════════════════════════════════════
  // ─── Status Banner Widget ───
  Widget _buildStatusBanner({
    required String status,
    required String label,
    required String esignType,
    required String cancelType,
    required String fileId,
    required String email,
    required String session,
    required bool esignLoading,
  }) {
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
    final successBg = resolveThemeColor(context,
        dark: const Color(0xFF0A3D1E), light: const Color(0xFFE6F9ED));
    final successText = resolveThemeColor(context,
        dark: MyntColors.successDark, light: MyntColors.success);

    if (status == 'e-signed pending') {
      return Align(
        alignment: Alignment.centerLeft,
        child: IntrinsicWidth(
          child: Container(
        margin: const EdgeInsets.only(top: 10),
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
                Flexible(
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
                esignLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: primaryColor))
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final provider = ref.read(profileAllDetailsProvider);
                            if (fileId.isEmpty || email.isEmpty) {
                              await provider.fetchMobEmailStatus();
                              if (!mounted) return;
                              final fresh = provider.mobEmailStatus;
                              String fId = '';
                              String em = '';
                              String sess = '';
                              if (esignType == 'mobile_change') {
                                fId = fresh?.mobileFileId ?? '';
                                em = (fresh?.mobClientEmail ?? '').toUpperCase();
                                sess = fresh?.mobSession ?? '';
                              } else if (esignType == 'email_change') {
                                fId = fresh?.emailFileId ?? '';
                                em = (fresh?.emailNewEmailId ?? '').toLowerCase();
                                sess = fresh?.emailSession ?? '';
                              } else if (esignType == 'address_change') {
                                fId = fresh?.addressFileId ?? '';
                                em = (fresh?.addressClientEmail ?? '').toLowerCase();
                                sess = fresh?.addressSession ?? '';
                              }
                              _openDigioEsign(fileId: fId, email: em, session: sess, type: esignType);
                            } else {
                              _openDigioEsign(fileId: fileId, email: email, session: session, type: esignType);
                            }
                          },
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
                _cancelLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: errorColor))
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              _showCancelRequestDialog(cancelType, '$label Change'),
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
      ),
        ),
      );
    } else if (status == 'e-signed completed') {
      return Align(
        alignment: Alignment.centerLeft,
        child: IntrinsicWidth(
          child: Container(
            margin: const EdgeInsets.only(top: 10),
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
                  "$label change in process",
                  style: MyntWebTextStyles.bodySmall(context,
                    color: successText,
                    fontWeight: MyntFonts.medium,
                  ).copyWith(decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPersonalInfoSection(
      ClientData clientData,
      ProfileProvider profileProvider,
      Color cardBg,
      Color cardBorder,
      Color textColor,
      Color subtitleColor) {
    final mobStatus = profileProvider.mobEmailStatus;
    final statusLoading = profileProvider.mobEmailStatusLoading;
    final mobileStatus = mobStatus?.mobileStatus ?? '';
    final emailStatus = mobStatus?.emailStatus ?? '';
    final addressStatus = mobStatus?.addressStatus ?? '';
    final incomeStatus = mobStatus?.incomeStatus ?? '';
    final mobilePendingOrDone =
        mobileStatus == 'e-signed pending' || mobileStatus == 'e-signed completed';
    final emailPendingOrDone =
        emailStatus == 'e-signed pending' || emailStatus == 'e-signed completed';
    final addressPendingOrDone =
        addressStatus == 'e-signed pending' || addressStatus == 'e-signed completed';
    // Account-level gates (closed / non-individual / inactive / within 7
    // days / mid Re-KYC). Re-KYC only blocks email & mobile per spec.
    final emailMobileBlock =
        _personalInfoEditBlock(checkRekyc: true, checkActive: false);
    final addressBlock = _personalInfoEditBlock(checkRekyc: false);
    // yearlyIncomeDisable equivalent: while an income e-sign is pending or
    // completed, the EDIT button is hidden entirely (no tooltip rendered), v-else-if="!yearlyIncomeDisable" gate.
    final incomePendingOrDone = incomeStatus == 'e-signed pending' ||
        incomeStatus == 'e-signed completed';
    final incomeBlock =
        incomePendingOrDone ? null : _annualIncomeEditBlock();

    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    // Build list of field data
    final fields = <_FlatFieldData>[
      _FlatFieldData(
        label: "Name as per PAN",
        value: clientData.panName ?? "N/A",
      ),
      _FlatFieldData(
        label: "Birth Date",
        value: clientData.bIRTHDATE ?? "N/A",
      ),
      _FlatFieldData(
        label: "Marital Status",
        value: clientData.maritalStatus ?? "N/A",
      ),
      _FlatFieldData(
        label: "PAN Number",
        value: profileProvider.formateDataToDisplay(
            clientData.pANNO ?? "", 0, 3),
      ),
      _FlatFieldData(
        label: "Email",
        value: clientData.cLIENTIDMAIL ?? "N/A",
        onEdit: emailPendingOrDone
            ? null
            : (emailMobileBlock == null || emailMobileBlock.clickable)
                ? _showEmailChangeDialog
                : null,
        disabledEditTooltip:
            emailPendingOrDone ? null : emailMobileBlock?.tooltip,
        showDisabledEditNoTooltip: !emailPendingOrDone &&
            emailMobileBlock != null &&
            !emailMobileBlock.clickable &&
            emailMobileBlock.tooltip == null,
        loading: statusLoading,
      ),
      _FlatFieldData(
        label: "Mobile",
        value: clientData.mOBILENO ?? "N/A",
        onEdit: mobilePendingOrDone
            ? null
            : (emailMobileBlock == null || emailMobileBlock.clickable)
                ? _showMobileChangeDialog
                : null,
        disabledEditTooltip:
            mobilePendingOrDone ? null : emailMobileBlock?.tooltip,
        showDisabledEditNoTooltip: !mobilePendingOrDone &&
            emailMobileBlock != null &&
            !emailMobileBlock.clickable &&
            emailMobileBlock.tooltip == null,
        loading: statusLoading,
      ),
      _FlatFieldData(
        label: "Address",
        value: "${clientData.cLRESIADD1 ?? ''}  ${clientData.cLRESIADD2 ?? ''}  ${clientData.cLRESIADD3 ?? ''}"
            .toUpperCase(),
        onEdit: addressPendingOrDone
            ? null
            : (addressBlock == null || addressBlock.clickable)
                ? _showAddressChangeDialog
                : null,
        disabledEditTooltip:
            addressPendingOrDone ? null : addressBlock?.tooltip,
        loading: statusLoading,
      ),
      _FlatFieldData(
        label: "Annual Income",
        value: clientData.aNNUALINCOME ?? "N/A",
        onEdit: incomePendingOrDone
            ? null
            : (incomeBlock == null || incomeBlock.clickable)
                ? _showIncomeChangeDialog
                : null,
        disabledEditTooltip:
            incomePendingOrDone ? null : incomeBlock?.tooltip,
        loading: statusLoading,
        statusBanner: incomeStatus == 'e-signed completed'
            ? Builder(builder: (context) {
                final successBg = resolveThemeColor(context,
                    dark: const Color(0xFF0A3D1E), light: const Color(0xFFE6F9ED));
                final successText = resolveThemeColor(context,
                    dark: MyntColors.successDark, light: MyntColors.success);
                return Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: successBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top_rounded, size: 14, color: successText),
                      const SizedBox(width: 6),
                      Text(
                        "Income change request is in process",
                        style: MyntWebTextStyles.caption(context,
                          color: successText,
                          fontWeight: MyntFonts.medium,
                        ).copyWith(decoration: TextDecoration.none),
                      ),
                    ],
                  ),
                );
              })
            : null,
      ),
    ];

    // Collect all esign pending/completed banners for consolidated display
    final List<Widget> esignBanners = [
      if (emailStatus == 'e-signed pending' || emailStatus == 'e-signed completed')
        _buildStatusBanner(
          status: emailStatus,
          label: 'Email',
          esignType: 'email_change',
          cancelType: 'email_change',
          fileId: mobStatus?.emailFileId ?? '',
          email: (mobStatus?.emailNewEmailId ?? '').toLowerCase(),
          session: mobStatus?.emailSession ?? '',
          esignLoading: _emailEsignLoading,
        ),
      if (mobileStatus == 'e-signed pending' || mobileStatus == 'e-signed completed')
        _buildStatusBanner(
          status: mobileStatus,
          label: 'Mobile',
          esignType: 'mobile_change',
          cancelType: 'mobile_change',
          fileId: mobStatus?.mobileFileId ?? '',
          email: (mobStatus?.mobClientEmail ?? '').toUpperCase(),
          session: mobStatus?.mobSession ?? '',
          esignLoading: _mobileEsignLoading,
        ),
      if (addressStatus == 'e-signed pending' || addressStatus == 'e-signed completed')
        _buildStatusBanner(
          status: addressStatus,
          label: 'Address',
          esignType: 'address_change',
          cancelType: 'address_change',
          fileId: mobStatus?.addressFileId ?? '',
          email: (mobStatus?.addressClientEmail ?? '').toLowerCase(),
          session: mobStatus?.addressSession ?? '',
          esignLoading: _addressEsignLoading,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width > 900 ? 3 : width > 500 ? 2 : 1;

        // Chunk fields into rows
        final List<List<_FlatFieldData>> rows = [];
        for (int i = 0; i < fields.length; i += cols) {
          rows.add(fields.sublist(i, (i + cols).clamp(0, fields.length)));
        }

        final fieldGrid = Container(
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
              // Title inside container
              Text(
                "Personal Details",
                style: MyntWebTextStyles.title(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium,
                ).copyWith(decoration: TextDecoration.none),
              ),
              const SizedBox(height: 32),

              // Rows of fields
              for (int r = 0; r < rows.length; r++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int c = 0; c < cols; c++) ...[
                      Expanded(
                        child: c < rows[r].length
                            ? _buildFlatField(
                                field: rows[r][c],
                                textColor: textColor,
                                subtitleColor: subtitleColor,
                                dividerColor: dividerColor,
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (c < cols - 1) const SizedBox(width: 40),
                    ],
                  ],
                ),
                if (r < rows.length - 1) const SizedBox(height: 32),
              ],
            ],
          ),
        );

        if (esignBanners.isEmpty) return fieldGrid;

        return Column(
          children: [
            fieldGrid,
            const SizedBox(height: 12),
            ...esignBanners,
          ],
        );
      },
    );
  }

  /// Flat field: uppercase label, bold value, underline, optional EDIT pill
  Widget _buildFlatField({
    required _FlatFieldData field,
    required Color textColor,
    required Color subtitleColor,
    required Color dividerColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          field.label.toUpperCase(),
          style: MyntWebTextStyles.caption(context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
            fontWeight: MyntFonts.semiBold,
          ).copyWith(
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 10),
        // Value + Edit button row
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                field.value.isNotEmpty ? field.value : "N/A",
                style: MyntWebTextStyles.body(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium,
                ).copyWith(decoration: TextDecoration.none),
              ),
            ),
            if (field.loading) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary),
                  ),
                ),
              ),
            ] else if (field.onEdit != null ||
                (field.disabledEditTooltip != null &&
                    field.disabledEditTooltip!.isNotEmpty) ||
                field.showDisabledEditNoTooltip) ...[
              const SizedBox(width: 8),
              Builder(builder: (context) {
                final bool disabled = field.onEdit == null;
                final editButton = InkWell(
                  onTap: field.onEdit,
                  borderRadius: BorderRadius.circular(16),
                  child: Opacity(
                    opacity: disabled ? 0.4 : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 16,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.primaryDark,
                                  light: MyntColors.primary)),
                          const SizedBox(width: 4),
                          Text(
                            "EDIT",
                            style: MyntWebTextStyles.caption(context,
                              darkColor: MyntColors.primaryDark,
                              lightColor: MyntColors.primary,
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
                if (field.disabledEditTooltip != null &&
                    field.disabledEditTooltip!.isNotEmpty) {
                  return Tooltip(
                    message: field.disabledEditTooltip!,
                    child: editButton,
                  );
                }
                return editButton;
              }),
            ],
          ],
        ),
        const SizedBox(height: 14),
        // Underline
        Divider(height: 1, thickness: 1, color: dividerColor),
        // Status banner
        if (field.statusBanner != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: field.statusBanner!,
          ),
      ],
    );
  }

}

/// Simple data holder for flat field rows
class _FlatFieldData {
  final String label;
  final String value;
  final VoidCallback? onEdit;
  final Widget? statusBanner;
  final String? disabledEditTooltip;
  // Render a disabled EDIT button with NO tooltip
  final bool showDisabledEditNoTooltip;
  // While true, render a small spinner where the EDIT button would otherwise appear
  final bool loading;

  const _FlatFieldData({
    required this.label,
    required this.value,
    this.onEdit,
    this.statusBanner,
    this.disabledEditTooltip,
    this.showDisabledEditNoTooltip = false,
    this.loading = false,
  });
}

/// Result of the personal-info edit gate.
/// `tooltip == null` means "blocked but render with no tooltip" (Re-KYC case).
/// `clickable == true` means the button stays clickable (with tooltip) and
/// the dialog handler will show the same warning on click — the
/// "clickable but ineffective" closed-account case.
class _EditBlock {
  final String? tooltip;
  final bool clickable;
  const _EditBlock({this.tooltip, this.clickable = false});
}

/// True when an OTP-send response says the OTP actually went out.
///
/// Both the email and mobile endpoints answer with a free-text `msg` for
/// success and failure alike, so this matches on the "sent" token instead of an
/// exact string. Rejections such as "This mail already linked to another
/// account" fall through to false and get shown to the user, rather than
/// silently advancing the dialog to the OTP field.
bool _otpSendSucceeded(String? msg) {
  if (msg == null || msg.trim().isEmpty) return false;
  final m = msg.toLowerCase();
  const failureHints = [
    'not sent', 'not send', 'fail', 'error', 'invalid', 'already',
  ];
  if (failureHints.any(m.contains)) return false;
  return m.contains('sent') || m.contains('send');
}

// ═══════════════════════════════════════════════════════════════════════
//  EMAIL CHANGE DIALOG (inline OTP flow)
// ═══════════════════════════════════════════════════════════════════════
class _EmailChangeDialog extends StatefulWidget {
  final ProfileProvider profileProvider;
  final ClientData clientData;
  final VoidCallback onEsign;

  const _EmailChangeDialog({
    required this.profileProvider,
    required this.clientData,
    required this.onEsign,
  });

  @override
  State<_EmailChangeDialog> createState() => _EmailChangeDialogState();
}

class _EmailChangeDialogState extends State<_EmailChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _otpSent = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final inputFillColor = resolveThemeColor(context,
        dark: const Color(0xFF1C2333), light: const Color(0xFFF6F7F9));
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);

    InputDecoration emailInputDecoration(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14, color: subtitleColor),
          filled: true,
          fillColor: inputFillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: resolveThemeColor(context,
                dark: MyntColors.primaryDark, light: MyntColors.primary)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: resolveThemeColor(context,
                dark: MyntColors.errorDark, light: MyntColors.error)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: resolveThemeColor(context,
                dark: MyntColors.errorDark, light: MyntColors.error)),
          ),
        );

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
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
                  Text("Change Email",
                      style: MyntWebTextStyles.title(context, color: textColor)),
                  MyntCloseButton(
                    onPressed: () {
                      widget.profileProvider.clearProfilePop(context, 'email');
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Current Email",
                          style: MyntWebTextStyles.caption(context,
                              color: subtitleColor,
                              fontWeight: MyntFonts.medium)),
                      const SizedBox(height: 4),
                      Text(widget.clientData.cLIENTIDMAIL ?? "",
                          style: MyntWebTextStyles.body(context,
                              color: textColor,
                              fontWeight: MyntFonts.medium)),
                      const SizedBox(height: 16),
                      Text("New Email *",
                          style: MyntWebTextStyles.bodySmall(context,
                              color: textColor,
                              fontWeight: MyntFonts.medium)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: widget.profileProvider.newEmailController,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        style: TextStyle(fontSize: 14, color: textColor),
                        decoration: emailInputDecoration('Enter new email'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'E-mail is required';
                          if (v.startsWith(' ')) return 'E-mail cannot start with spaces';
                          if (v.contains(' ')) return 'Email cannot contain spaces';
                          if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$').hasMatch(v)) return 'E-mail must be valid';
                          return null;
                        },
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 16),
                        Text("Enter OTP *",
                            style: MyntWebTextStyles.bodySmall(context,
                                color: textColor,
                                fontWeight: MyntFonts.medium)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: widget.profileProvider.newEmailOTPController,
                          keyboardType: TextInputType.number,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 4,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(fontSize: 14, color: textColor),
                          decoration: emailInputDecoration('Enter 4-digit OTP')
                              .copyWith(counterText: ''),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'OTP Required';
                            if (!RegExp(r'^\d{4}$').hasMatch(v)) return 'Must be exactly 4 digits';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (!_otpSent)
                        MyntPrimaryButton(
                          label: 'Send OTP',
                          size: MyntButtonSize.large,
                          isFullWidth: true,
                          isLoading: _isLoading,
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            setState(() => _isLoading = true);
                            final msg = await widget.profileProvider
                                .emaileotpfun(
                              widget.profileProvider.newEmailController.text,
                              widget.clientData.cLIENTIDMAIL ?? "",
                              widget.clientData.cLIENTNAME ?? "",
                              widget.clientData.cLIENTDPCODE ?? "",
                            );
                            setState(() => _isLoading = false);
                            if (!mounted) return;
                            if (_otpSendSucceeded(msg)) {
                              setState(() => _otpSent = true);
                            } else {
                              error(context,
                                  msg ?? 'Failed to send OTP. Please try again.');
                            }
                          },
                        ),
                      if (_otpSent)
                        MyntPrimaryButton(
                          label: 'Verify & E-Sign',
                          size: MyntButtonSize.large,
                          isFullWidth: true,
                          isLoading: _isLoading,
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            setState(() => _isLoading = true);
                            final result = await widget.profileProvider
                                .emailOtpVerifyWeb(
                              widget.profileProvider.newEmailOTPController.text,
                              widget.profileProvider.newEmailController.text,
                            );
                            setState(() => _isLoading = false);
                            if (result == 'otp valid') {
                              widget.onEsign();
                            } else {
                              if (mounted) {
                                error(context, result ?? 'OTP verification failed');
                              }
                            }
                          },
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
}

// ═══════════════════════════════════════════════════════════════════════
//  MOBILE CHANGE DIALOG (inline OTP flow)
// ═══════════════════════════════════════════════════════════════════════
class _MobileChangeDialog extends StatefulWidget {
  final ProfileProvider profileProvider;
  final ClientData clientData;
  final VoidCallback onEsign;

  const _MobileChangeDialog({
    required this.profileProvider,
    required this.clientData,
    required this.onEsign,
  });

  @override
  State<_MobileChangeDialog> createState() => _MobileChangeDialogState();
}

class _MobileChangeDialogState extends State<_MobileChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _otpSent = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final inputFillColor = resolveThemeColor(context,
        dark: const Color(0xFF1C2333), light: const Color(0xFFF6F7F9));
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);

    InputDecoration mobileInputDecoration(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14, color: subtitleColor),
          filled: true,
          fillColor: inputFillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: resolveThemeColor(context,
                dark: MyntColors.primaryDark, light: MyntColors.primary)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: resolveThemeColor(context,
                dark: MyntColors.errorDark, light: MyntColors.error)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: resolveThemeColor(context,
                dark: MyntColors.errorDark, light: MyntColors.error)),
          ),
        );

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
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
                  Text("Change Mobile",
                      style: MyntWebTextStyles.title(context, color: textColor)),
                  MyntCloseButton(
                    onPressed: () {
                      widget.profileProvider.clearProfilePop(context, 'mobile');
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Current Mobile",
                          style: MyntWebTextStyles.caption(context,
                              color: subtitleColor,
                              fontWeight: MyntFonts.medium)),
                      const SizedBox(height: 4),
                      Text(widget.clientData.mOBILENO ?? "",
                          style: MyntWebTextStyles.body(context,
                              color: textColor,
                              fontWeight: MyntFonts.medium)),
                      const SizedBox(height: 16),
                      Text("New Mobile Number *",
                          style: MyntWebTextStyles.bodySmall(context,
                              color: textColor,
                              fontWeight: MyntFonts.medium)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: widget.profileProvider.newMobController,
                        keyboardType: TextInputType.phone,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(fontSize: 14, color: textColor),
                        decoration: mobileInputDecoration('Enter new mobile number')
                            .copyWith(counterText: ''),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Mobile is required';
                          if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) return 'Enter a valid mobile number';
                          return null;
                        },
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 16),
                        Text("Enter OTP *",
                            style: MyntWebTextStyles.bodySmall(context,
                                color: textColor,
                                fontWeight: MyntFonts.medium)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: widget.profileProvider.newMobOTPController,
                          keyboardType: TextInputType.number,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 4,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(fontSize: 14, color: textColor),
                          decoration: mobileInputDecoration('Enter OTP')
                              .copyWith(counterText: ''),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'OTP Required';
                            if (!RegExp(r'^\d{4}$').hasMatch(v)) return 'Must be exactly 4 digits';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (!_otpSent)
                        MyntPrimaryButton(
                          label: 'Send OTP',
                          size: MyntButtonSize.large,
                          isFullWidth: true,
                          isLoading: _isLoading,
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            setState(() => _isLoading = true);
                            final msg = await widget.profileProvider.mobileotpfun(
                              widget.profileProvider.newMobController.text,
                              widget.clientData.cLIENTIDMAIL ?? "",
                              widget.clientData.mOBILENO ?? "",
                              widget.clientData,
                            );
                            setState(() => _isLoading = false);
                            if (!mounted) return;
                            if (_otpSendSucceeded(msg)) {
                              setState(() => _otpSent = true);
                            } else {
                              error(context, msg ?? 'Failed to send OTP. Please try again.');
                            }
                          },
                        ),
                      if (_otpSent)
                        MyntPrimaryButton(
                          label: 'Verify & E-Sign',
                          size: MyntButtonSize.large,
                          isFullWidth: true,
                          isLoading: _isLoading,
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            setState(() => _isLoading = true);
                            final result = await widget.profileProvider
                                .mobileOtpVerifyWeb(
                              widget.profileProvider.newMobController.text,
                              widget.profileProvider.newMobOTPController.text,
                              widget.clientData,
                            );
                            setState(() => _isLoading = false);
                            if (result == 'otp valid') {
                              widget.onEsign();
                            } else {
                              if (mounted) {
                                error(context, result ?? 'OTP verification failed');
                              }
                            }
                          },
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
}

// ═══════════════════════════════════════════════════════════════════════
//  INCOME CHANGE DIALOG
// ═══════════════════════════════════════════════════════════════════════
class _IncomeChangeDialog extends StatefulWidget {
  final ProfileProvider profileProvider;
  final ClientData clientData;
  final bool isDarkMode;
  final VoidCallback onDone;

  const _IncomeChangeDialog({
    required this.profileProvider,
    required this.clientData,
    required this.isDarkMode,
    required this.onDone,
  });

  @override
  State<_IncomeChangeDialog> createState() => _IncomeChangeDialogState();
}

class _IncomeChangeDialogState extends State<_IncomeChangeDialog> {
  final _otpFormKey = GlobalKey<FormState>();
  String? _selectedRange;
  bool _otpSent = false;
  bool _isLoading = false;
  bool _showProofUpload = false;
  String _selectedDocType = 'bs';
  List<int>? _fileBytes;
  String? _fileName;
  bool _passwordRequired = false;
  bool _showPasswordField = false;
  final _passwordController = TextEditingController();
  int _currentIncomeIndex = -1;

  final _incomeRanges = [
    'Below 1L',
    '1L to 5L',
    '5L to 10L',
    '10L to 25L',
    'Above 25L',
  ];

  final _docTypes = {
    'bs': 'Bank Statement',
    'pc': 'Latest ITR Copy',
    'bp': 'Latest 6 months salary slip',
    'dp': 'DP holding statement as on date',
    'nc': 'Net worth Certificate',
    'sif': 'Copy of Form 16 in case of salary income',
  };

  // Theme helpers
  bool get _isDark => widget.isDarkMode;
  Color get _textPrimary => _isDark ? colors.textPrimaryDark : colors.textPrimaryLight;
  Color get _textSecondary => _isDark ? colors.textSecondaryDark : colors.textSecondaryLight;
  Color get _dialogBg => _isDark ? const Color(0xFF121212) : colors.colorWhite;
  Color get _cardBg => _isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF5F7FA);
  Color get _borderColor => _isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFE0E0E0);
  Color get _inputFillColor => _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;

  @override
  void initState() {
    super.initState();
    _resolveCurrentIncomeIndex();
  }

  void _resolveCurrentIncomeIndex() {
    final income = widget.clientData.aNNUALINCOME ?? '';
    if (income.contains('Less') || income.contains('Below')) {
      _currentIncomeIndex = 0;
    } else if (income.contains('One To Five') || income.contains('1L to 5L')) {
      _currentIncomeIndex = 1;
    } else if (income.contains('Five To Ten') || income.contains('5L to 10L')) {
      _currentIncomeIndex = 2;
    } else if (income.contains('Ten To Twenty') || income.contains('10L to 25L')) {
      _currentIncomeIndex = 3;
    } else if (income.contains('TwentyFive') || income.contains('Above') || income.contains('Crore')) {
      _currentIncomeIndex = 4;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() {
        _fileBytes = file.bytes!.toList();
        _fileName = file.name;
      });

      // Check if PDF is password protected
      final lockResult = await widget.profileProvider.pdfLockCheck(
        fileBytes: _fileBytes!,
        fileName: _fileName!,
      );
      if (lockResult != null && lockResult['password required'] == 'True') {
        setState(() {
          _passwordRequired = true;
          _showPasswordField = true;
        });
      } else {
        setState(() {
          _passwordRequired = false;
          _showPasswordField = false;
        });
      }
    }
  }

  Future<void> _onSubmit() async {
    if (_selectedRange == null) return;

    final rangeIndex = _incomeRanges.indexOf(_selectedRange!);

    // For "Above 25L", proof file is required
    if (rangeIndex == 4 && _fileBytes == null) {
      error(context, "Please upload proof document");
      return;
    }

    // If password required, verify it first
    if (_passwordRequired && _showPasswordField) {
      setState(() => _isLoading = true);
      final result = await widget.profileProvider.pdfPasswordCheck(
        fileBytes: _fileBytes!,
        fileName: _fileName!,
        password: _passwordController.text,
      );
      if (result != null && result['password required'] == 'In-Correct') {
        setState(() => _isLoading = false);
        _passwordController.clear();
        if (mounted) {
          error(context, "Incorrect Password");
        }
        return;
      }
      setState(() => _isLoading = false);
    }

    // Send OTP
    setState(() => _isLoading = true);
    final otpResult = await widget.profileProvider.incomeotpsenpro(
      widget.clientData.mOBILENO ?? "",
    );
    setState(() {
      _isLoading = false;
      if (otpResult == "otp send") {
        _otpSent = true;
      }
    });
  }

  Future<void> _onVerifyOtp() async {
    if (!(_otpFormKey.currentState?.validate() ?? false)) return;
    final otp = widget.profileProvider.newIncomeOTPController.text.trim();

    setState(() => _isLoading = true);
    final result = await widget.profileProvider.incomeotpverpro(
      otp,
      widget.clientData,
      _selectedRange ?? "",
      fileBytes: _fileBytes,
      fileName: _fileName,
      proftye: _selectedDocType,
    );
    setState(() => _isLoading = false);

    if (result == "otp valid" || result == "success") {
      widget.onDone();
    } else if (result != null) {
      if (mounted) {
        error(context, result);
      }
      widget.profileProvider.newIncomeOTPController.clear();
    }
  }

  InputDecoration _themedInputDecoration({String? hintText, String? counterText}) {
    final errorColor = _isDark ? MyntColors.errorDark : MyntColors.error;
    return InputDecoration(
      hintText: hintText,
      counterText: counterText,
      hintStyle: TextStyle(color: _textSecondary, fontSize: 13),
      filled: true,
      fillColor: _inputFillColor,
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
        borderSide: BorderSide(color: resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
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
                  Text(
                    _otpSent ? "Verify Your OTP" : "Income change request",
                    style: MyntWebTextStyles.title(context, color: textColor),
                  ),
                  MyntCloseButton(
                    onPressed: () => Navigator.of(context).pop(),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: _otpSent
                          ? _buildOtpView()
                          : _buildIncomeSelectionView(),
                    ),
                    const SizedBox(height: 24),
                    MyntPrimaryButton(
                      label: _otpSent ? 'Verify OTP' : 'Submit',
                      size: MyntButtonSize.large,
                      isFullWidth: true,
                      isLoading: _isLoading,
                      onPressed: (!_otpSent && _selectedRange == null)
                          ? null
                          : (_otpSent ? _onVerifyOtp : _onSubmit),
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

  Widget _buildIncomeSelectionView() {
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final chipBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: const Color(0xFFF5F7FA));
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select Income per annum",
              style: MyntWebTextStyles.bodySmall(context,
                  color: textColor, fontWeight: MyntFonts.medium)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_incomeRanges.length, (index) {
              final range = _incomeRanges[index];
              final isSelected = _selectedRange == range;
              final isDisabled = _currentIncomeIndex > index;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(range),
                  ],
                ),
                showCheckmark: false,
                selected: isSelected,
                onSelected: isDisabled
                    ? null
                    : (selected) {
                        setState(() {
                          _selectedRange = selected ? range : null;
                          _showProofUpload = selected && index == 4;
                          if (!_showProofUpload) {
                            _fileBytes = null;
                            _fileName = null;
                            _passwordRequired = false;
                            _showPasswordField = false;
                          }
                        });
                      },
                selectedColor: resolveThemeColor(context,
            dark: MyntColors.secondary, light: MyntColors.primary),
                disabledColor: chipBg,
                backgroundColor: chipBg,
                side: BorderSide(
                  color: isSelected ? resolveThemeColor(context,
            dark: MyntColors.secondary, light: MyntColors.primary) : borderColor,
                ),
                labelStyle: MyntWebTextStyles.bodySmall(context,
                  color: isDisabled
                      ? subtitleColor
                      : isSelected
                          ? Colors.white
                          : textColor,
                  fontWeight: isSelected ? MyntFonts.semiBold : MyntFonts.regular,
                ).copyWith(decoration: TextDecoration.none),
              );
            }),
          ),
          if (_showProofUpload) ...[
            const SizedBox(height: 20),
            Text("Document type *",
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            ..._docTypes.entries.map((entry) {
              final isRadioSelected = _selectedDocType == entry.key;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isRadioSelected
                        ? (_isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFBBBBBB))
                        : _borderColor,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: isRadioSelected ? _cardBg : Colors.transparent,
                ),
                child: RadioListTile<String>(
                  value: entry.key,
                  groupValue: _selectedDocType,
                  onChanged: (val) =>
                      setState(() => _selectedDocType = val!),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(entry.value,
                            style: TextStyle(
                                color: _textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ),
                      if (entry.key == 'bs')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF66BB6A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text("Recommended",
                              style: TextStyle(
                                  color: Colors.white, fontSize: 10)),
                        ),
                    ],
                  ),
                  activeColor: _isDark ? Colors.white : Colors.black,
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8),
                ),
              );
            }),
            const SizedBox(height: 12),
            Text("Upload proof *",
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                    color: _borderColor,
                    style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(10),
                color: _cardBg,
              ),
              child: Column(
                children: [
                  Text("Upload your Bank Proof",
                      style: TextStyle(
                          color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      "Select a file or drag it into the box below.",
                      style: TextStyle(
                          color: _textSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload, size: 16,
                        color: Colors.white),
                    label: const Text("Choose File",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyntColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Accepted formats: .pdf",
                      style: TextStyle(
                          color: _textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_fileName!,
                        style: TextStyle(
                            color: _textPrimary, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
            if (_showPasswordField) ...[
              const SizedBox(height: 16),
              Text("Password *",
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration:
                    _themedInputDecoration(hintText: 'PDF password'),
                style: TextStyle(color: _textPrimary, fontSize: 14),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOtpView() {
    return Form(
      key: _otpFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Mobile number",
              style: TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: widget.clientData.mOBILENO ?? "",
            readOnly: true,
            decoration: _themedInputDecoration(),
            style: TextStyle(color: _textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Text("Enter OTP *",
              style: MyntWebTextStyles.bodySmall(context,
                  color: _textPrimary, fontWeight: MyntFonts.medium)),
          const SizedBox(height: 6),
          TextFormField(
            controller: widget.profileProvider.newIncomeOTPController,
            keyboardType: TextInputType.number,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _themedInputDecoration(
                hintText: 'Enter 4-digit OTP', counterText: ''),
            style: TextStyle(color: _textPrimary, fontSize: 14),
            validator: (v) {
              if (v == null || v.isEmpty) return 'OTP Required';
              if (!RegExp(r'^\d{4}$').hasMatch(v)) {
                return 'Must be exactly 4 digits';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  ADDRESS CHANGE DIALOG
// ═══════════════════════════════════════════════════════════════════════
class _AddressChangeDialog extends StatefulWidget {
  final ProfileProvider profileProvider;
  final ClientData clientData;
  final bool isDarkMode;
  final VoidCallback onDone;
  final bool startWithManual;

  const _AddressChangeDialog({
    required this.profileProvider,
    required this.clientData,
    required this.isDarkMode,
    required this.onDone,
    this.startWithManual = false,
  });

  @override
  State<_AddressChangeDialog> createState() => _AddressChangeDialogState();
}

class _AddressChangeDialogState extends State<_AddressChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _pinLoading = false;
  late bool _showManualForm;

  late TextEditingController _addressCtrl;
  late TextEditingController _pincodeCtrl;
  late TextEditingController _districtCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _countryCtrl;
  String _proofType = '';
  List<int>? _proofBytes;
  String? _proofFileName;
  Timer? _pincodeDebounce;

  Color get _textPrimary =>
      widget.isDarkMode ? colors.textPrimaryDark : colors.textPrimaryLight;
  Color get _textSecondary =>
      widget.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight;
  Color get _dialogBg =>
      widget.isDarkMode ? MyntColors.cardDark : MyntColors.card;
  Color get _inputFillColor =>
      widget.isDarkMode ? const Color(0xFF1C2333) : const Color(0xFFF6F7F9);
  Color get _borderColor =>
      widget.isDarkMode ? MyntColors.dividerDark : MyntColors.divider;

  final _proofTypes = [
    'Aadhar Card',
    'Passport',
    'Voter ID',
    'Driving Licence',
    'Latest Bank Statement',
    'Utility Bill',
  ];

  @override
  void initState() {
    super.initState();
    _showManualForm = widget.startWithManual;
    _addressCtrl = TextEditingController();
    _pincodeCtrl = TextEditingController();
    _districtCtrl = TextEditingController();
    _stateCtrl = TextEditingController();
    _countryCtrl = TextEditingController(text: 'India');
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    _pincodeDebounce?.cancel();
    super.dispose();
  }

  void _onPincodeChanged(String val) {
    _pincodeDebounce?.cancel();
    _pincodeDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchPincode(val);
    });
  }

  Future<void> _fetchPincode(String pincode) async {
    if (pincode.length < 6) return;
    setState(() => _pinLoading = true);
    final data = await widget.profileProvider.pincodeLookup(pincode);
    if (data != null && mounted) {
      setState(() {
        _stateCtrl.text = data['State'] ?? '';
        _districtCtrl.text = data['District'] ?? '';
        _countryCtrl.text = data['Country'] ?? 'India';
        _pinLoading = false;
      });
    } else {
      if (mounted) setState(() => _pinLoading = false);
    }
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
      }
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_proofType.isEmpty) {
      error(context, 'Please select a proof type');
      return;
    }
    if (_proofBytes == null) {
      error(context, 'Please upload address proof');
      return;
    }

    setState(() => _isLoading = true);

    // Step 1: KRA image check before address change
    final kraResult = await widget.profileProvider.kraImageCheck();
    if (!kraResult) {
      // Show selfie capture dialog
      if (!mounted) return;
      final selfieBytes = await showDialog<List<int>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _KraSelfieDialog(isDarkMode: widget.isDarkMode),
      );
      if (selfieBytes == null || selfieBytes.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final uploadResult =
          await widget.profileProvider.uploadKraSelfie(imageBytes: selfieBytes);
      if (uploadResult != 'image saved') {
        if (mounted) {
          setState(() => _isLoading = false);
          error(context, uploadResult ?? 'Image upload failed');
        }
        return;
      }
    }

    // Step 2: Submit address change
    final result = await widget.profileProvider.addressChangeWeb(
      newAddress: _addressCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
      proofType: _proofType,
      proofBytes: _proofBytes,
      proofFileName: _proofFileName,
    );

    if (mounted) setState(() => _isLoading = false);

    if (result != null) {
      widget.onDone();
    } else if (mounted) {
      error(context, 'Address change request failed');
    }
  }

  InputDecoration _themedInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: _textSecondary),
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
        borderSide: const BorderSide(color: Color(0xFF0037B7)),
      ),
    );
  }

  Widget _buildLabel(String text, {bool required_ = true}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _textPrimary,
        ),
        children: required_
            ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final oldAddress =
        '${widget.clientData.cLRESIADD1 ?? ''} ${widget.clientData.cLRESIADD2 ?? ''} ${widget.clientData.cLRESIADD3 ?? ''}';

    return Dialog(
      backgroundColor: _dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _borderColor,
          width: 0.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _borderColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Address change request',
                    style: MyntWebTextStyles.title(context,
                        color: _textPrimary,
                    )
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      splashColor: (widget.isDarkMode
                              ? MyntColors.primaryDark
                              : MyntColors.primary)
                          .withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded,
                            size: 20, color: _textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

              // Options view: Aadhaar (Digilocker) / Type manually
              if (!_showManualForm) ...[
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      launchDigilockerAuth();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: resolveThemeColor(context,
                          dark: MyntColors.secondary,
                          light: MyntColors.primary),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'Aadhar (Digilocker)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
            //     SizedBox(
            //       width: double.infinity,
            //       height: 44,
            //       child: OutlinedButton(
            //         onPressed: () {
            //           setState(() => _showManualForm = true);
            //         },
            //         style: OutlinedButton.styleFrom(
            //           side:  BorderSide(color:resolveThemeColor(context,
            // dark: MyntColors.secondary, light: MyntColors.primary)),
            //           shape: RoundedRectangleBorder(
            //             borderRadius: BorderRadius.circular(8),
            //           ),
            //         ),
            //         child:  Text(
            //           'Type manually',
            //           style: TextStyle(
            //             color: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
            //             fontSize: 14,
            //             fontWeight: FontWeight.w600,
            //           ),
            //         ),
            //       ),
            //     ),
              ],

              // Manual form
              if (_showManualForm)
                Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // Old Address
                Text(
                  'Old Address',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: oldAddress,
                  readOnly: true,
                  style: TextStyle(fontSize: 14, color: _textPrimary),
                  decoration: _themedInputDecoration(''),
                ),
                const SizedBox(height: 16),

                // New Address
                _buildLabel('New Address'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressCtrl,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  style: TextStyle(fontSize: 14, color: _textPrimary),
                  decoration: _themedInputDecoration('New Address'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Address is required';
                    if (v.startsWith(' ')) return 'Address cannot start with spaces';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Pincode & District row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Pincode'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _pincodeCtrl,
                            keyboardType: TextInputType.number,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            style:
                                TextStyle(fontSize: 14, color: _textPrimary),
                            decoration: _themedInputDecoration('Pincode')
                                .copyWith(
                              suffixIcon: _pinLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2)),
                                    )
                                  : null,
                            ),
                            onChanged: _onPincodeChanged,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Pincode is required';
                              if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'Enter a valid 6-digit pincode';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('District'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _districtCtrl,
                            style:
                                TextStyle(fontSize: 14, color: _textPrimary),
                            decoration: _themedInputDecoration('District'),
                            validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // State & Country row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('State'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _stateCtrl,
                            style:
                                TextStyle(fontSize: 14, color: _textPrimary),
                            decoration: _themedInputDecoration('State'),
                            validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Country'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _countryCtrl,
                            style:
                                TextStyle(fontSize: 14, color: _textPrimary),
                            decoration: _themedInputDecoration('Country'),
                            validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Proof Type
                _buildLabel('Proof type'),
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
                          style:
                              TextStyle(fontSize: 14, color: _textSecondary)),
                      isExpanded: true,
                      dropdownColor: widget.isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      style: TextStyle(fontSize: 14, color: _textPrimary),
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

                // Upload proof
                _buildLabel('Upload proof'),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickFile,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _inputFillColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _borderColor,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Upload your Address Proof',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0037B7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select a file or drag it into the box below.',
                          style:
                              TextStyle(fontSize: 13, color: _textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0037B7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.upload,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'Choose File',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Accepted formats: .pdf',
                          style:
                              TextStyle(fontSize: 12, color: _textSecondary),
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
                      const Icon(Icons.check, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _proofFileName!,
                          style:
                              TextStyle(fontSize: 13, color: _textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0037B7),
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  KRA SELFIE CAPTURE DIALOG
// ═══════════════════════════════════════════════════════════════════════
enum _CameraState { idle, requesting, active }
class _KraSelfieDialog extends StatefulWidget {
  final bool isDarkMode;
  const _KraSelfieDialog({required this.isDarkMode});

  @override
  State<_KraSelfieDialog> createState() => _KraSelfieDialogState();
}

class _KraSelfieDialogState extends State<_KraSelfieDialog> {
  List<int>? _imageBytes;

  // Camera state
  _CameraState _cameraState = _CameraState.idle;
  String? _cameraError;
  html.MediaStream? _mediaStream;
  html.VideoElement? _videoElement;
  String? _viewId;

  // Preview dimensions (center-cropped to this aspect ratio)
  static const double _canvasW = 475;
  static const double _canvasH = 520;

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  void _stopCamera() {
    _mediaStream?.getTracks().forEach((t) => t.stop());
    _mediaStream = null;
    _videoElement = null;
  }

  void _resetState() {
    _stopCamera();
    setState(() {
      _imageBytes = null;
      _cameraState = _CameraState.idle;
      _viewId = null;
      _cameraError = null;
    });
  }

  Future<void> _openCamera() async {
    setState(() {
      _cameraState = _CameraState.requesting;
      _cameraError = null;
    });

    try {
      final stream =
          await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'user'},
        'audio': false,
      });

      _mediaStream = stream;
      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..srcObject = stream
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)'; // mirror for selfie feel
      _videoElement = video;

      final viewId =
          'kra-selfie-${DateTime.now().microsecondsSinceEpoch}';
      ui_web.platformViewRegistry.registerViewFactory(viewId, (_) => video);
      _viewId = viewId;

      setState(() => _cameraState = _CameraState.active);
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      String msg;
      if (errorStr.contains('notallowed') ||
          errorStr.contains('permission denied') ||
          errorStr.contains('permissiondenied')) {
        msg =
            'Camera access denied. Click the camera or lock icon in your browser address bar, allow camera access, then tap "Open Camera" again.';
      } else if (errorStr.contains('notfound') ||
          errorStr.contains('devicesnotfound')) {
        msg = 'No camera found on this device. Please upload a photo instead.';
      } else {
        msg = 'Unable to access camera. Please upload a photo instead.';
      }
      setState(() {
        _cameraState = _CameraState.idle;
        _cameraError = msg;
      });
    }
  }

  Future<void> _capturePhoto() async {
    final video = _videoElement;
    if (video == null) return;

    final w = video.videoWidth;
    final h = video.videoHeight;
    if (w == 0 || h == 0) return;

    // Target dimensions matching the gallery picker (475×520 portrait)
    const targetW = 475;
    const targetH = 520;
    const targetAspect = targetW / targetH; // ~0.913

    // Compute center-crop source rect from the video frame
    final srcAspect = w / h;
    int srcX, srcY, srcW, srcH;
    if (srcAspect > targetAspect) {
      // Video is wider than target — crop sides
      srcH = h;
      srcW = (h * targetAspect).round();
      srcX = ((w - srcW) / 2).round();
      srcY = 0;
    } else {
      // Video is taller than target — crop top/bottom
      srcW = w;
      srcH = (w / targetAspect).round();
      srcX = 0;
      srcY = ((h - srcH) / 2).round();
    }

    // Draw cropped frame onto a 475×520 canvas (not mirrored — standard for KYC)
    final canvas = html.CanvasElement(width: targetW, height: targetH);
    canvas.context2D.drawImageScaledFromSource(
      video, srcX, srcY, srcW, srcH, 0, 0, targetW, targetH,
    );

    // 80% quality to match gallery picker imageQuality: 80
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.80);
    final bytes = base64Decode(dataUrl.split(',')[1]);

    _stopCamera();
    setState(() {
      _imageBytes = bytes.toList();
      _cameraState = _CameraState.idle;
      _viewId = null;
    });
  }

  Future<void> _uploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    // Validate file type
    final ext = file.extension?.toLowerCase() ?? '';
    if (!['jpg', 'jpeg', 'png'].contains(ext)) {
      if (mounted) {
        error(context, 'Invalid file type. Please upload JPG, JPEG, or PNG only.');
      }
      return;
    }

    final bytes = file.bytes;
    if (bytes == null) return;

    // Center-crop uploaded image to 475×520 (same as camera capture)
    final completer = Completer<void>();
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final img = html.ImageElement()..src = url;

    img.onLoad.first.then((_) {
      final w = img.naturalWidth;
      final h = img.naturalHeight;
      html.Url.revokeObjectUrl(url);

      final targetW = _canvasW.toInt();
      final targetH = _canvasH.toInt();
      const targetAspect = _canvasW / _canvasH;
      final srcAspect = w / h;

      int srcX, srcY, srcW, srcH;
      if (srcAspect > targetAspect) {
        srcH = h;
        srcW = (h * targetAspect).round();
        srcX = ((w - srcW) / 2).round();
        srcY = 0;
      } else {
        srcW = w;
        srcH = (w / targetAspect).round();
        srcX = 0;
        srcY = ((h - srcH) / 2).round();
      }

      final canvas = html.CanvasElement(width: targetW, height: targetH);
      canvas.context2D.drawImageScaledFromSource(
        img, srcX, srcY, srcW, srcH, 0, 0, targetW, targetH,
      );

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.80);
      final croppedBytes = base64Decode(dataUrl.split(',')[1]);

      if (!mounted) return;
      setState(() {
        _imageBytes = croppedBytes.toList();
      });
      completer.complete();
    });

    img.onError.first.then((_) {
      html.Url.revokeObjectUrl(url);
      if (mounted) {
        error(context, 'Failed to load image. Please try another file.');
      }
      completer.complete();
    });

    await completer.future;
  }

  /// Scales the captured/uploaded image (already 475×520) to final 350×260 output.
  Future<void> _submitPhoto() async {
    if (_imageBytes == null) return;

    const outputW = 350;
    const outputH = 260;

    final completer = Completer<List<int>?>();
    final blob = html.Blob([Uint8List.fromList(_imageBytes!)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final img = html.ImageElement()..src = url;

    img.onLoad.first.then((_) {
      html.Url.revokeObjectUrl(url);
      final canvas = html.CanvasElement(width: outputW, height: outputH);
      canvas.context2D.drawImageScaled(img, 0, 0, outputW, outputH);
      final dataUrl = canvas.toDataUrl('image/jpeg', 0.80);
      final bytes = base64Decode(dataUrl.split(',')[1]);
      completer.complete(bytes.toList());
    });

    img.onError.first.then((_) {
      html.Url.revokeObjectUrl(url);
      completer.complete(null);
    });

    final result = await completer.future;
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCameraActive = _cameraState == _CameraState.active;
    final isRequesting = _cameraState == _CameraState.requesting;

    return Dialog(
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
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    "Let's take a selfie",
                    style: MyntWebTextStyles.title(context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary)),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        _stopCamera();
                        Navigator.pop(context, null);
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
                  // Description (hide when camera is streaming)
                  if (!isCameraActive) ...[
                    Text(
                      'Click a selfie for your Re-KYC verification. Please make sure you are in a well-lit area.',
                      textAlign: TextAlign.center,
                      style: MyntWebTextStyles.body(context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary)),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Captured / uploaded image preview ──
                  if (_imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: _canvasW / _canvasH,
                        child: Image.memory(
                          Uint8List.fromList(_imageBytes!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _resetState,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Change Photo'),
                    ),
                  ]

                  // ── Live camera preview ──
                  else if (isCameraActive && _viewId != null) ...[
                    // Preview uses 475:520 aspect ratio — matches the captured output
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 475 / 520,
                        child: HtmlElementView(viewType: _viewId!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextButton(
                              onPressed: () {
                                _stopCamera();
                                setState(() {
                                  _cameraState = _CameraState.idle;
                                  _viewId = null;
                                });
                              },
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.dividerDark,
                                        light: MyntColors.divider),
                                  ),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: MyntWebTextStyles.buttonMd(context,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextButton.icon(
                              onPressed: _capturePhoto,
                              icon: const Icon(Icons.camera,
                                  size: 18, color: Colors.white),
                              label: Text(
                                'Capture',
                                style: MyntWebTextStyles.buttonMd(context,
                                    color: Colors.white),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: resolveThemeColor(context,
                                    dark: MyntColors.secondary,
                                    light: MyntColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ]

                  // ── Buttons (idle / requesting / error) ──
                  else ...[
                    // Permission error banner
                    if (_cameraError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _cameraError!,
                                style: MyntWebTextStyles.bodySmall(context,
                                    color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Open Camera button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton.icon(
                        onPressed: isRequesting ? null : _openCamera,
                        icon: isRequesting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : Icon(Icons.camera_alt,
                                size: 18,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.primaryDark,
                                    light: MyntColors.primary)),
                        label: Text(
                          isRequesting
                              ? 'Requesting permission...'
                              : 'Open Camera',
                          style: MyntWebTextStyles.buttonMd(context,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.primaryDark,
                                  light: MyntColors.primary)),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: resolveThemeColor(context,
                                  dark: MyntColors.primaryDark,
                                  light: MyntColors.primary)
                              .withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(
                              color: resolveThemeColor(context,
                                  dark: MyntColors.primaryDark,
                                  light: MyntColors.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('OR',
                        style: MyntWebTextStyles.bodySmall(context,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary))),
                    const SizedBox(height: 10),
                    // Upload Photo button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton.icon(
                        onPressed: _uploadPhoto,
                        icon: Icon(Icons.upload,
                            size: 18,
                            color: resolveThemeColor(context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary)),
                        label: Text(
                          'Upload Photo',
                          style: MyntWebTextStyles.buttonMd(context,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.primaryDark,
                                  light: MyntColors.primary)),
                        ),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(
                              color: resolveThemeColor(context,
                                  dark: MyntColors.dividerDark,
                                  light: MyntColors.divider),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  // Submit button (hidden while camera is live)
                  if (!isCameraActive)
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: _imageBytes == null
                            ? null
                            : _submitPhoto,
                        style: TextButton.styleFrom(
                          backgroundColor: _imageBytes == null
                              ? resolveThemeColor(context,
                                      dark: MyntColors.dividerDark,
                                      light: MyntColors.textTertiaryDark)
                                  .withValues(alpha: 0.5)
                              : resolveThemeColor(context,
                                  dark: MyntColors.secondary,
                                  light: MyntColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text('Submit',
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
    );
  }
}

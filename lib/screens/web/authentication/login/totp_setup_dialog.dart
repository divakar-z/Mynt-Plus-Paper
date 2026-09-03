import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../provider/auth_provider.dart';
import '../../../../provider/web_auth_provider.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../utils/responsive_snackbar.dart';

/// TOTP enrollment, run as a self-contained modal over the login screen.
///
/// Why a dialog: enrollment used to take over the login card itself, launched
/// from a link inside the code field's suffix — the same slot that otherwise
/// holds "Resend OTP". Users read it as a login helper, and it ended by dumping
/// them back at the password step. A dialog frames it as the separate errand it
/// is: the login screen stays mounted and visible behind it, and closing returns
/// the user to the waiting TOTP field with the client ID intact.
///
/// Two steps only — verify an OTP, then scan the QR. The user's return to the
/// login screen is deliberately NOT a third step in the indicator: the dialog
/// cannot perform it, and showing an unreachable step is what made the old flow
/// confusing. The closing button's wording carries it instead.
///
/// Messaging follows the same split as the login screen: backend `emsg` goes to
/// the toast (visible over the dialog — Navigator inserts a pushed route's
/// overlay entries above the previous route's, not above the toast entry), and
/// the inline red line is reserved for client-side validation. The OTP field is
/// a copy of the login screen's, resend suffix included, so the two never look
/// like two different products.
Future<void> showTotpSetupDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: resolveThemeColor(context,
        dark: MyntColors.modalBarrierDark, light: MyntColors.modalBarrierLight),
    builder: (_) => const TotpSetupDialog(),
  );
}

/// Which half of the flow the dialog is showing. The spec's State C ("no key
/// yet") is a variant of [scanQr], not a step of its own — it occupies the same
/// frame and must not advance the indicator.
enum _SetupStep { verifyOtp, scanQr }

class TotpSetupDialog extends ConsumerStatefulWidget {
  const TotpSetupDialog({super.key});

  @override
  ConsumerState<TotpSetupDialog> createState() => _TotpSetupDialogState();
}

class _TotpSetupDialogState extends ConsumerState<TotpSetupDialog> {
  _SetupStep _step = _SetupStep.verifyOtp;

  final TextEditingController _otpCtrl = TextEditingController();

  bool _busy = false;

  /// The dialog's own validation message. Deliberately NOT `webAuth.otpError`:
  /// that is a single shared field, so writing to it painted this dialog's
  /// "Please enter 4 digit OTP" under the login screen's TOTP field at the same
  /// time. Client-side validation stays local; backend failures still toast.
  String? _otpError;

  // Resend countdown — the same 89s budget the login screen uses, shown mm.ss.
  Timer? _countdownTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    // Kick the flow off once the dialog is on screen: enabling topflow switches
    // the provider into OTP mode, then the OTP goes out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFlow());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- flow ---

  Future<void> _startFlow() async {
    final webAuth = ref.read(webAuthProvider);
    final auth = ref.read(authProvider);

    // The setup call keys off the client ID; make sure it is populated even if
    // the user reached the TOTP step through a restored session.
    if (webAuth.loginController.text.isEmpty) {
      webAuth.loginController.text =
          auth.loginMethCtrl.text.trim().toUpperCase();
    }

    webAuth.enableGenerateTotpFlow();
    await _sendOtp();
  }

  Future<void> _sendOtp() async {
    final webAuth = ref.read(webAuthProvider);
    // A resend must not leave the previous attempt's validation error behind.
    setState(() {
      _otpError = null;
      _busy = true;
    });
    try {
      // Not silenced: the "code sent" confirmation is a toast here exactly as it
      // is on the login screen.
      final ok = await webAuth.sendOtp(context);
      if (!mounted) return;
      if (ok) _startCountdown();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final webAuth = ref.read(webAuthProvider);
    if (_busy) return;

    final code = _otpCtrl.text.trim();
    // Length check runs here rather than through validateOtp(), which would
    // write the message into the provider's shared otpError.
    if (code.length != 4) {
      setState(() => _otpError = 'Please enter 4 digit OTP');
      return;
    }

    webAuth.otpController.text = code;
    setState(() {
      _otpError = null;
      _busy = true;
    });
    try {
      final ok = await webAuth.verifyOtp(context);
      if (!mounted) return;
      if (ok) {
        _countdownTimer?.cancel();
        _otpCtrl.clear();
        webAuth.otpController.clear();
        setState(() {
          _step = _SetupStep.scanQr;
          _secondsLeft = 0;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateKey() async {
    final webAuth = ref.read(webAuthProvider);
    setState(() => _busy = true);
    try {
      final ok = await webAuth.generateNewTotpKey(context);
      if (!mounted) return;
      // The provider swallows this failure, so the user used to see nothing
      // happen at all. Report it the way every other API failure is reported.
      if (!ok) {
        ResponsiveSnackBar.showError(
            context, "Couldn't generate a key. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Closing is safe in every state — a provisioned key stays on the account and
  /// setup can simply be re-entered. Resetting the setup flags leaves the login
  /// screen sitting on its TOTP field once the dialog goes away.
  void _close() {
    ref.read(webAuthProvider).backToLogin();
    Navigator.of(context).pop();
  }

  // ----------------------------------------------------------- countdown ---

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = 89);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  /// Mirrors the login screen's formattedTime so both countdowns read alike.
  String get _countdownText {
    final int sec = _secondsLeft % 60;
    final int min = (_secondsLeft / 60).floor();
    final String minute = min.toString().length <= 1 ? "0$min" : "$min";
    final String second = sec.toString().length <= 1 ? "0$sec" : "$sec";
    return "$minute : $second";
  }

  void _copyKey(String key) {
    Clipboard.setData(ClipboardData(text: key));
    // Same toast, same wording as the panel this replaced.
    ResponsiveSnackBar.showSuccess(context, "Auth Key is copied to Clipboard");
  }

  // -------------------------------------------------------------- colours ---

  Color get _cardColor => resolveThemeColor(context,
      dark: MyntColors.dialogDark, light: MyntColors.dialog);

  /// Buttons follow the login screen's own pairing (light primary / dark
  /// secondary) so the dialog's primary never reads as a different blue from
  /// the Verify button sitting directly behind it.
  Color get _buttonColor => resolveThemeColor(context,
      dark: MyntColors.secondary, light: MyntColors.primary);

  /// Links use the other pairing already established on the login screen.
  Color get _linkColor => resolveThemeColor(context,
      dark: MyntColors.secondaryDark, light: MyntColors.secondary);

  Color get _textPrimary => resolveThemeColor(context,
      dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

  Color get _textSecondary => resolveThemeColor(context,
      dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

  Color get _textHint => resolveThemeColor(context,
      dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

  /// The login field's focused underline uses the primary pair, which differs
  /// from the button pair in dark mode — keep them distinct here too.
  Color get _focusColor => resolveThemeColor(context,
      dark: MyntColors.primaryDark, light: MyntColors.primary);

  Color get _divider => resolveThemeColor(context,
      dark: MyntColors.dividerDark, light: MyntColors.divider);

  /// The login screen reports errors with the loss pair, not error/errorDark.
  Color get _errorColor => resolveThemeColor(context,
      dark: MyntColors.lossDark, light: MyntColors.loss);

  Color get _successColor => resolveThemeColor(context,
      dark: MyntColors.successDark, light: MyntColors.success);

  /// listItemBgDark is the same value as dialogDark, so a panel tinted with it
  /// would vanish in dark mode — cardHoverDark actually reads against the card.
  Color get _surfaceAlt => resolveThemeColor(context,
      dark: MyntColors.cardHoverDark, light: MyntColors.listItemBg);

  // --------------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    final webAuth = ref.watch(webAuthProvider);

    return Dialog(
      backgroundColor: _cardColor,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: resolveThemeColor(context,
              dark: MyntColors.dividerDark, light: Colors.transparent),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              _stepper(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: _step == _SetupStep.verifyOtp
                    ? _verifyOtpBody(webAuth)
                    : _scanQrBody(webAuth),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- header ---

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Set up TOTP',
              style: MyntWebTextStyles.title(
                context,
                fontWeight: MyntFonts.semiBold,
                color: _textPrimary,
              ),
            ),
          ),
          InkWell(
            onTap: _close,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(Icons.close, size: 18, color: _textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- stepper ---

  Widget _stepper() {
    final onStepTwo = _step == _SetupStep.scanQr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _stepMarker(index: 1, label: 'Verify OTP', done: onStepTwo, active: !onStepTwo),
          Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: onStepTwo ? _buttonColor : _divider,
            ),
          ),
          _stepMarker(index: 2, label: 'Scan QR', done: false, active: onStepTwo),
        ],
      ),
    );
  }

  Widget _stepMarker({
    required int index,
    required String label,
    required bool done,
    required bool active,
  }) {
    final Color circleColor =
        done ? _successColor : (active ? _buttonColor : _surfaceAlt);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
          child: done
              ? const Icon(Icons.check, size: 13, color: Colors.white)
              : Text(
                  '$index',
                  style: MyntWebTextStyles.caption(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    color: active ? Colors.white : _textHint,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: MyntWebTextStyles.para(
            context,
            fontWeight: active ? MyntFonts.semiBold : MyntFonts.regular,
            color: active ? _textPrimary : (done ? _textSecondary : _textHint),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------ step 1 · verify ---

  Widget _verifyOtpBody(WebAuthProvider webAuth) {
    final error = _otpError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "We've sent a 4-digit OTP to your registered mobile number. "
          "Verifying it confirms it's you before we create your authenticator key.",
          style: MyntWebTextStyles.para(
            context,
            fontWeight: MyntFonts.regular,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 16),

        // Deliberately a copy of the login screen's code field — same underline,
        // same auto-floating label, same in-field resend suffix. The two sit one
        // on top of the other, so any difference reads as a different product.
        TextFormField(
          controller: _otpCtrl,
          autofocus: true,
          readOnly: _busy,
          maxLength: 4,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: MyntWebTextStyles.title(
            context,
            fontWeight: MyntFonts.medium,
            color: _textPrimary,
          ),
          decoration: InputDecoration(
            filled: false,
            labelText: "Enter 4 digit OTP",
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: MyntWebTextStyles.body(
              context,
              fontWeight: MyntFonts.regular,
              color: _textSecondary,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _divider, width: 1),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _focusColor, width: 1),
            ),
            counterText: "",
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            suffix: _secondsLeft > 0
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Resend",
                          style: MyntWebTextStyles.caption(context,
                              color: _textSecondary)),
                      Text("in $_countdownText",
                          style: MyntWebTextStyles.caption(context,
                              color: _textSecondary,
                              fontWeight: FontWeight.bold)),
                    ],
                  )
                : InkWell(
                    onTap: () {
                      if (!mounted || _busy) return;
                      _sendOtp();
                    },
                    child: Text("Resend OTP",
                        style: MyntWebTextStyles.caption(context,
                            color: _linkColor, fontWeight: FontWeight.bold)),
                  ),
          ),
          onChanged: (v) {
            if (_otpError != null) setState(() => _otpError = null);
            if (v.length == 4 && !_busy) _verifyOtp();
          },
          onFieldSubmitted: (_) => _verifyOtp(),
        ),

        const SizedBox(height: 5),
        // Client-side validation only, same as the login screen. Backend
        // failures arrive as a toast over the dialog.
        if (error != null && error.isNotEmpty)
          Text(
            error,
            style: MyntWebTextStyles.para(context, color: _errorColor),
          ),

        const SizedBox(height: 26),
        _primaryButton(
          label: 'Verify',
          onPressed: _busy ? null : _verifyOtp,
          loading: _busy,
        ),
      ],
    );
  }

  // -------------------------------------------------------- step 2 · QR ---

  Widget _scanQrBody(WebAuthProvider webAuth) {
    final totp = webAuth.totpData;
    // A null totpData means the fetch itself failed; offer the same recovery as
    // "no key on the account" rather than rendering nothing, which is what the
    // old inline panel did when getOrGenerateTotp came back empty.
    final hasKey = totp?.isValid == true;

    if (!hasKey) return _noKeyBody();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
       
        Text(
          'Scan the QR code on authenticator app',
          style: MyntWebTextStyles.para(
            context,
            fontWeight: MyntFonts.regular,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 18),

        // White in both themes — scanners need the contrast.
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _divider),
            ),
            child: QrImageView(
              data: totp!.getQrUri(),
              size: 200,
              version: QrVersions.auto,
              backgroundColor: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 20),
        Text(
          'Authenticator Key',
          style: MyntWebTextStyles.para(
            context,
            fontWeight: MyntFonts.regular,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _surfaceAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  _groupedKey(totp.pwd ?? ''),
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    fontWeight: MyntFonts.medium,
                    color: _textPrimary,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _copyKey(totp.pwd ?? ''),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.copy_rounded, size: 16, color: _linkColor),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Text(
          'Next time you sign in, enter the 6-digit code from your authenticator app.',
          style: MyntWebTextStyles.caption  (
            context,
            fontWeight: MyntFonts.regular,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 18),
        _primaryButton(
          label: 'Back to sign in',
          onPressed: _close,
          loading: false,
        ),
      ],
    );
  }

  /// State C — a variant of step 2, in the same frame. The stepper does not
  /// advance for it; generating resolves into the QR in place.
  Widget _noKeyBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _surfaceAlt, shape: BoxShape.circle),
            child: Icon(Icons.lock_outline, size: 20, color: _textSecondary),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'No authenticator key found. Generate a new key to set up TOTP.',
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.body(
            context,
            fontWeight: MyntFonts.regular,
            color: _textSecondary,
          ),
        ),
        // Generate failures surface as a toast, like every other API error.
        const SizedBox(height: 18),
        _primaryButton(
          label: _busy ? 'Generating key...' : 'Generate New Key',
          onPressed: _busy ? null : _generateKey,
          loading: _busy,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ------------------------------------------------------------- shared ---

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    required bool loading,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _buttonColor,
          disabledBackgroundColor: _buttonColor.withOpacity(0.6),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: MyntWebTextStyles.titlesub(
                context,
                fontWeight: MyntFonts.semiBold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Groups the secret in fours so it can be read aloud or typed by hand.
  String _groupedKey(String key) {
    final clean = key.replaceAll(' ', '');
    if (clean.isEmpty) return '';
    final buf = StringBuffer();
    for (var i = 0; i < clean.length; i++) {
      if (i != 0 && i % 4 == 0) buf.write(' ');
      buf.write(clean[i]);
    }
    return buf.toString();
  }
}

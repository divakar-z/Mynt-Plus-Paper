import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mynt_plus/sharedWidget/custom_text_form_field.dart';
import 'package:mynt_plus/sharedWidget/accessibility/accessibility_panel.dart';
// import 'package:remove_emoji_input_formatter/remove_emoji_input_formatter.dart';
import '../../../../locator/preference.dart';
import '../../../../provider/accessibility_provider.dart';
import '../../../../provider/auth_provider.dart';
import '../../../../provider/change_password_provider.dart';
import '../../../../provider/index_list_provider.dart';
import '../../../../provider/ledger_provider.dart';
import '../../../../provider/web_auth_provider.dart';


import '../../../../provider/thems.dart';
import '../../../../provider/user_profile_provider.dart';
import '../../../../provider/version_provider.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../../res/res.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../routes/route_names.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import '../../../../utils/no_emoji_inputformatter.dart';
import '../../../../utils/responsive_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';

// JS interop binding to window.fetch — used by the beforeunload handler to
// fire a keepalive POST that survives page unload (replacement for the older
// sendBeacon approach, which forced credentials mode 'include' and tripped
// the backend's wildcard CORS config).
@JS('fetch')
external JSPromise<JSAny?> _jsFetch(JSString input, JSObject init);


class LoginScreenWeb extends ConsumerStatefulWidget {
  const LoginScreenWeb({super.key});

  @override
  ConsumerState<LoginScreenWeb> createState() => _LoginScreenWebState();
}

class _LoginScreenWebState extends ConsumerState<LoginScreenWeb> {
  // Short version shown in the login footer. Hovering it reveals the full
  // build/release details (_appVersionLabel) in a tooltip.
  static const String _appVersionShort = "Version 3.0.2";

  // Full build/release details — surfaced only in the hover tooltip. Update
  // this single string on each release.
  static const String _appVersionLabel =
      "Version 3.0.2 Build 1.0.523 Released on 29 Jul";

  bool _isProcessing = false;
  bool _isInitializing = true; // True until auto-login check completes
  late FocusNode focusNode;
  late FocusNode focusNode1;
  bool _showForgotPassword = false;
  // OTP-gated forgot-password screen — shown between identifier entry and
  // the Change Password screen. User enters the 4-digit OTP sent to their
  // registered mobile/email; on verify success the backend has already
  // dispatched the temp password and we jump straight to Change Password.
  bool _showForgotPasswordOtp = false;
  bool _showOtpScreen = false;
  bool _showQrScreen = false;
  bool _showChangePassword = false;
  bool _isPasswordExpired = false; // Tracks if change password was triggered by password expiry
  
  // OTP Timer Logic
  Timer? _timer;
  int _start = 89;
  String resendTime = "01.29";

  // Accessibility dropdown anchor + overlay
  final GlobalKey _a11yAnchorKey = GlobalKey();
  OverlayEntry? _a11yOverlay;

  // QR Countdown Timer — visible on the QR login screen. Independent of the
  // provider's internal poll timer.
  // On expiry the QR auto-refreshes (fresh UUID + fresh image + fresh timer)
  // for up to [_qrMaxRefreshCycles] cycles. After the budget is exhausted, an
  // explicit "Reload" icon is shown (WhatsApp Web pattern) so the user can
  // restart the cycle on demand — total visible QRs before reload prompt =
  // 1 initial + [_qrMaxRefreshCycles] auto-refreshes.
  Timer? _qrCountdownTimer;
  static const int _qrCountdownStart = 89;
  static const int _qrMaxRefreshCycles = 2;
  int _qrStart = _qrCountdownStart;
  int _qrRefreshCount = 0;
  bool _qrExpired = false;
  bool _qrImageLoaded = false;

  // New Password — transient max-length error.
  // Fired only when the user actually attempts to type/paste beyond 12 chars
  // (caught by the custom inputFormatter). Auto-hides after 2 seconds so the
  // field doesn't carry a permanent error after the user stops trying.
  bool _showNewPwdMaxLengthError = false;
  Timer? _newPwdMaxLengthHideTimer;

  // Browser unload subscription — fires invalidate-QR + clears the pending
  // UUID from localStorage when the user refreshes the page or closes the
  // tab while a QR session is active. Uses sendBeacon for delivery
  // reliability since regular http.post calls often get killed mid-flight
  // when the page unloads.
  StreamSubscription<html.Event>? _qrBeforeUnloadSub;

  void startTimer() {
    _timer?.cancel();
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_start == 0) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _timer = null;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _start--;
              resendTime = formattedTime(timeInSecond: _start);
            });
          }
        }
      },
    );
  }

  formattedTime({required int timeInSecond}) {
    int sec = timeInSecond % 60;
    int min = (timeInSecond / 60).floor();
    String minute = min.toString().length <= 1 ? "0$min" : "$min";
    String second = sec.toString().length <= 1 ? "0$sec" : "$sec";
    return "$minute : $second";
  }

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
    focusNode.addListener(_onFocusChange);
    focusNode1 = FocusNode();
    focusNode1.addListener(_onFocusChange);

    // When arriving from the OAuth flow (URL carries ?client_id=...), skip the
    // saved-account view and show fresh credential fields — the URL's client_id
    // may be a different user from the one stored in prefs, so showing the last
    // logged-in user's profile would be misleading.
    final oauthClientId = Uri.base.queryParameters['client_id'];
    if (oauthClientId != null && oauthClientId.isNotEmpty) {
      Preferences().setLogout(false);
    }

    // Browser-refresh / tab-close handler — invalidates any pending QR
    // session UUID on the backend via sendBeacon (the only reliable way
    // to fire a network call as the page unloads) and then clears the
    // localStorage entry so the next page load starts fresh.
    _qrBeforeUnloadSub = html.window.onBeforeUnload.listen((event) {
      final pendingUuid = Preferences().pendingQrUuid;
      if (pendingUuid != null && pendingUuid.isNotEmpty) {
        // Backend expects only { unique_id } in the body — no source/imei.
        // Response is { "detail": "QR invalid" } but Beacon is fire-and-forget,
        // we don't read it.
        final body = jsonEncode({
          'unique_id': pendingUuid,
        });
        // fetch + keepalive replaces sendBeacon. keepalive: true lets the
        // request survive page unload (same property sendBeacon gave us).
        // credentials: 'omit' sidesteps the backend's wildcard+credentials
        // CORS combo — without credentials the browser stops enforcing the
        // "Allow-Origin must not be *" rule, so the existing live CORS
        // config works as-is.
        final init = <String, Object>{
          'method': 'POST',
          'body': body,
          'headers': <String, String>{'Content-Type': 'application/json'},
          'keepalive': true,
          'credentials': 'omit',
          'mode': 'cors',
        }.jsify() as JSObject;
        _jsFetch('https://ws.mynt.in/login/QRInvalidate'.toJS, init);
        Preferences().clearPendingQrUuid();
      }
    });

    // Defer context-dependent operations to avoid holding context reference
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        ref.read(versionProvider).checkVersion(context);
        ref.read(authProvider).setChangetotp(true);
        ref.read(webAuthProvider).init(); // Initialize web auth provider

        // Defensive cleanup for any stale QR UUID left in localStorage
        // from a previous session that ended without beforeunload firing
        // (e.g., browser crash). Safe no-op when nothing is pending.
        ref.read(webAuthProvider).cleanupStaleQrSession();

        // Set up QR login success listener
        _setupQrLoginListener();

        // Auto-login check — skipped when arriving from the OAuth flow (a
        // client_id is present in the URL). There the user must see the login
        // form to re-auth as the account that owns the app_key; auto-login would
        // silently bounce a still-valid session to the dashboard and abandon the
        // OAuth authorization.
        final fromOAuth =
            (Uri.base.queryParameters['client_id'] ?? '').trim().isNotEmpty;
        if (!fromOAuth) {
          await ref.read(webAuthProvider).checkAutoLogin(context);
        }

        // Mark initialization complete (show login form if no auto-login)
        if (mounted) {
          setState(() => _isInitializing = false);
        }
      }
    });
  }

  /// Setup QR Login Success Listener (called once in initState)
  void _setupQrLoginListener() {
    ref.listenManual<WebAuthProvider>(webAuthProvider, (previous, next) {
      if (_showQrScreen && next.mobileOtp?.stat == 'Ok' && next.mobileOtp?.apitoken != null) {
        // Login Successful via QR — kill the visible countdown so it doesn't
        // tick down to expiry and try to navigate after we've already left.
        // Navigation and initialLoadMethods are handled by web_auth_provider.
        _stopQrCountdown();
      }
    });
  }

  void _onFocusChange() {
    // setState removed to prevent synchronous rebuilds during focus changes
    // which was causing MouseTracker assertions.
  }

  @override
  void dispose() {
    // Remove listeners before disposing
    focusNode.removeListener(_onFocusChange);
    focusNode1.removeListener(_onFocusChange);
    focusNode.dispose();
    focusNode1.dispose();
    _timer?.cancel();
    _a11yOverlay?.remove();
    _a11yOverlay = null;
    _qrCountdownTimer?.cancel();
    _newPwdMaxLengthHideTimer?.cancel();
    _qrBeforeUnloadSub?.cancel();
    super.dispose();
  }

  void _toggleAccessibilityDropdown(bool isDarkMode) {
    if (_a11yOverlay != null) {
      _closeAccessibilityDropdown();
      return;
    }
    if (_a11yAnchorKey.currentContext == null) return;
    _a11yOverlay = buildAccessibilityOverlay(
      context: context,
      anchorKey: _a11yAnchorKey,
      isDarkMode: isDarkMode,
      onClose: _closeAccessibilityDropdown,
    );
    Overlay.of(context, rootOverlay: true).insert(_a11yOverlay!);
  }

  void _closeAccessibilityDropdown() {
    _a11yOverlay?.remove();
    _a11yOverlay = null;
  }

  /// Triggered by the New Password field's custom inputFormatter when the
  /// user attempts to type/paste beyond 12 chars. Shows the inline red
  /// "Maximum 12 characters allowed" error briefly, then auto-hides after
  /// 2 seconds so the message disappears once the user stops trying.
  void _triggerNewPwdMaxLengthError() {
    if (!mounted) return;
    _newPwdMaxLengthHideTimer?.cancel();
    setState(() => _showNewPwdMaxLengthError = true);
    _newPwdMaxLengthHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showNewPwdMaxLengthError = false);
    });
  }

  /// Helper method for consistent Mobile/Client ID input decoration
  InputDecoration _mobileInputDecoration(BuildContext context) {
    return InputDecoration(
      filled: false,
      labelText: "Mobile / Client ID",
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: MyntWebTextStyles.body(
        context,
        fontWeight: MyntFonts.regular,
        color: resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark,
                light: MyntColors.divider),
            width: 1),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.primaryDark,
                light: MyntColors.primary),
            width: 1),
      ),
      counterText: "",
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  Future<void> _handleContinue() async {
    final auth = ref.read(authProvider);
    final ledgerprovider = ref.read(ledgerProvider);
    auth.validateLogin();
    auth.validatePass();

    if (_isProcessing ||
        auth.loginMethCtrl.text.isEmpty ||
        auth.passCtrl.text.isEmpty) return;
    if (auth.loginMethError != "" || auth.passError != "") return;

    setState(() => _isProcessing = true);

    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.click);

      auth.optError = "";
      
      // Pass preventNavigation: true so we can handle the UI switch locally
      await auth.submitLogin(context, false, preventNavigation: true);
      
      // If the API call was successful and we have a mobile login response that indicates success/OTP sent
      if (auth.mobileLogin != null && 
          auth.mobileLogin!.stat == "Ok" && 
          (auth.mobileLogin!.msg == "otp sended" || 
           auth.mobileLogin!.msg == "otp sended, already logged in another device" ||
           // If TOTP is enabled, msg might differ or be null, but stat is Ok
           (auth.totp && (auth.mobileLogin!.msg != null || auth.mobileLogin!.msg == null)))) {
            
        if (mounted) {
           setState(() {
             _showOtpScreen = true;
             _start = 89;
             resendTime = "01.29";
           });
           startTimer();
        }
      }
      
      ledgerprovider.setterfornullallSwitch = null;
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// New Web Login - Uses webAuthProvider with source="WEB" and separate OTP flow
  Future<void> _handleWebLogin() async {
    final webAuth = ref.read(webAuthProvider);
    final ledgerprovider = ref.read(ledgerProvider);

    // Copy values from existing auth controllers to web auth controllers
    webAuth.loginController.text = ref.read(authProvider).loginMethCtrl.text;
    webAuth.passwordController.text = ref.read(authProvider).passCtrl.text;

    // Validate inputs and show appropriate messages
    if (_isProcessing) return;

    // Field-level validation → inline errors only (no toast)
    final auth = ref.read(authProvider);
    auth.validateLogin();
    auth.validatePass();
    if ((auth.loginMethError ?? '').isNotEmpty ||
        (auth.passError ?? '').isNotEmpty) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.click);

      // Submit web login with source="WEB"
      final success = await webAuth.submitWebLogin(context);

      if (success && mounted) {
        ref.read(authProvider).passCtrl.clear();
        webAuth.passwordController.clear();
        // Check if we need OTP verification
        if (webAuth.mobileLogin?.stat == 'Ok' &&
            webAuth.mobileLogin?.apitoken == null) {
          // OTP/TOTP flow needed - clear previous OTP before showing
          ref.read(authProvider).otpCtrl.clear();
          webAuth.otpController.clear();
          setState(() {
            _showOtpScreen = true;
            _start = 89;
            resendTime = "01.29";
          });

          if (!webAuth.isTotp) {
            startTimer();
          }
        } else if (webAuth.mobileLogin?.apitoken != null) {
          // Direct login success - navigation and data loading handled by web_auth_provider
          // No action needed here to avoid duplicate API calls
        }
      } else if (!success && mounted) {
        // Handle specific error cases from login response
        final emsg = webAuth.mobileLogin?.msg;
        final forpass = ref.read(changePasswordProvider);

        if (emsg == "Invalid Input : User Blocked due to multiple wrong attempts") {
          // User blocked - show forgot password inline form after delay
          forpass.forGetloginMethCtrl.text = webAuth.loginController.text.trim().toUpperCase();
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _showForgotPassword = true;
                forpass.clearError();
              });
            }
          });
        } else if (emsg == "Invalid Input : Change Password" ||
            emsg == "Invalid Input : Password Expired") {
          // Password expired or forced change - show change password inline form
          forpass.userIdController.text = "${webAuth.mobileLogin?.clientid}";
          if (emsg == "Invalid Input : Password Expired") {
            forpass.oldPassword.text = webAuth.passwordController.text;
          }
          setState(() {
            _isPasswordExpired = emsg == "Invalid Input : Password Expired";
            _showChangePassword = true;
          });
        }
      }

      ledgerprovider.setterfornullallSwitch = null;
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Web OTP Verify - Uses webAuthProvider
  Future<void> _handleWebOtpVerify(String otp) async {
    // Delay to let gesture settle before altering focus/state
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) FocusScope.of(context).unfocus();
    final webAuth = ref.read(webAuthProvider);
    webAuth.otpController.text = otp;

    if (_isProcessing) return;

    // Validate OTP length → inline error (no toast)
    if (!webAuth.validateOtp()) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final success = await webAuth.verifyOtp(context);

      if (success && mounted) {
        // If in Generate TOTP flow (topflow) and showing setup, don't navigate
        if (webAuth.topflow && webAuth.showTotpSetup) {
          ref.read(authProvider).otpCtrl.clear();
          webAuth.otpController.clear();
          setState(() {}); // Updates UI to show QR code
          return;
        }

        // OTP verification successful - navigation and data loading handled by web_auth_provider
        ref.read(authProvider).otpCtrl.clear();
        webAuth.otpController.clear();
        // Note: No need to navigate or call initialLoadMethods here to avoid duplicate API calls
      } else if (!success && mounted && webAuth.requiresPasswordChange) {
        // Password change required after OTP verification
        final forpass = ref.read(changePasswordProvider);
        final isExpired = webAuth.isPasswordExpiredFlag;
        forpass.userIdController.text = webAuth.mobileLogin?.clientid ?? '';
        if (isExpired) {
          forpass.oldPassword.text = webAuth.passwordController.text;
        }
        webAuth.clearPasswordChangeFlags();
        setState(() {
          _isPasswordExpired = isExpired;
          _showOtpScreen = false;
          _showChangePassword = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Toggle between OTP and TOTP mode using webAuthProvider
  void _toggleWebTotpMode() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) FocusScope.of(context).unfocus();
    final webAuth = ref.read(webAuthProvider);
    final auth = ref.read(authProvider);

    // Ensure loginController has the client ID
    if (webAuth.loginController.text.isEmpty) {
      webAuth.loginController.text = auth.loginMethCtrl.text.trim().toUpperCase();
    }

    // Clear OTP field and errors before switching mode
    auth.otpCtrl.clear();
    auth.optError = ''; // Clear old auth error

    // Set processing to prevent full-screen loader during toggle
    setState(() => _isProcessing = true);
    try {
      webAuth.toggleTotpMode(); // This also clears webAuth.otpError

      // If switching to OTP mode, send OTP
      if (!webAuth.isTotp) {
        final success = await webAuth.sendOtp(context);
        if (success && mounted) {
          setState(() {
            _start = 89;
            resendTime = "01.29";
          });
          startTimer();
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Resend OTP using webAuthProvider
  Future<void> _handleWebResendOtp() async {
    final webAuth = ref.read(webAuthProvider);
    final auth = ref.read(authProvider);
    
    // Ensure loginController has the client ID
    if (webAuth.loginController.text.isEmpty) {
      webAuth.loginController.text = auth.loginMethCtrl.text.trim().toUpperCase();
    }

    setState(() => _isProcessing = true);
    try {
      final success = await webAuth.sendOtp(context);
      if (success && mounted) {
        setState(() {
          _start = 89;
          resendTime = "01.29";
        });
        startTimer();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }



  /// Handle "Scan QR" Login - Switch to Inline QR Screen
  /// [resetRefreshCount] is true when the user explicitly enters the QR screen
  /// (so the auto-refresh budget starts fresh) and false when called from the
  /// countdown expiry path (so consecutive auto-refreshes count toward the cap).
  void _handleQrLogin({bool resetRefreshCount = true}) {
    if (resetRefreshCount) _qrRefreshCount = 0;
    final webAuth = ref.read(webAuthProvider);

    // Clear any prior QR session state before starting fresh — guarantees a
    // newly generated QR every time the user enters the screen.
    webAuth.cancelQrLogin();

    // Start QR polling (regenerates _deviceUuid → fresh QR image)
    webAuth.startQrLogin(context);

    setState(() {
      _showQrScreen = true;
      _showOtpScreen = false;
      _showForgotPassword = false; // Ensure other screens are hidden
      _qrExpired = false;
      _qrImageLoaded = false;
    });

    // Countdown is started by the Image.network frameBuilder once the QR
    // PNG is actually decoded — so slow networks don't eat into the timer.
    _qrCountdownTimer?.cancel();
    _qrCountdownTimer = null;
  }

  /// Cancel QR Login - Back to Login Form
  void _handleCancelQrLogin() {
    final webAuth = ref.read(webAuthProvider);
    final auth = ref.read(authProvider);

    _stopQrCountdown();
    _qrRefreshCount = 0;
    _qrExpired = false;
    webAuth.cancelQrLogin(); // Use cancelQrLogin to clear mobileOtp and prevent stale data

    // Returning to the login form should be a clean slate — clear any
    // stale inline validation errors left over from the previous attempt.
    // Otherwise the empty Mobile/Password fields show "required" errors
    // immediately on return, which is confusing UX.
    auth.clearError();

    if (!mounted) return;
    setState(() {
      _showQrScreen = false;
    });
  }

  /// Start the visible QR countdown. Resets to [_qrCountdownStart] each call.
  /// On expiry, auto-refreshes with a new QR + new timer for up to
  /// [_qrMaxRefreshCycles] cycles; after that, surfaces a Reload icon
  /// (WhatsApp pattern) so the user can re-fetch on demand instead of
  /// being kicked back to the login form.
  void _startQrCountdown() {
    _qrCountdownTimer?.cancel();
    _qrStart = _qrCountdownStart;
    if (mounted) setState(() {});
    _qrCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_qrStart <= 1) {
        timer.cancel();
        _qrCountdownTimer = null;
        if (_qrRefreshCount < _qrMaxRefreshCycles) {
          // Within budget → auto-refresh in place: fresh QR + fresh timer.
          _qrRefreshCount++;
          _handleQrLogin(resetRefreshCount: false);
        } else {
          // Budget exhausted → stop polling, clear QR image, switch UI to
          // a Reload icon. User stays on the QR screen and can tap Reload
          // to start a fresh cycle (counter resets via _handleQrLogin).
          ref.read(webAuthProvider).cancelQrLogin();
          if (mounted) {
            setState(() {
              _qrExpired = true;
              _qrImageLoaded = false;
            });
          }
        }
      } else {
        setState(() => _qrStart--);
      }
    });
  }

  /// Stop and clear the visible QR countdown without navigating.
  void _stopQrCountdown() {
    _qrCountdownTimer?.cancel();
    _qrCountdownTimer = null;
  }

  /// Handle "Generate TOTP" button click
  /// This initiates the flow where user needs to verify via OTP first to get their TOTP secret
  Future<void> _handleGenerateTotpFlow() async {
    // Delay to let gesture settle before altering focus/state
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) FocusScope.of(context).unfocus();

    final webAuth = ref.read(webAuthProvider);  
    final auth = ref.read(authProvider);
 
    // Ensure loginController has the client ID
    if (webAuth.loginController.text.isEmpty) {
      webAuth.loginController.text = auth.loginMethCtrl.text.trim().toUpperCase();
    }

    // Clear OTP field and errors to prevent stale state
    auth.otpCtrl.clear();
    auth.optError = ''; // Clear old auth error

    // Enable the Generate TOTP flow (sets topflow = true, switches to OTP mode, clears errors)
    webAuth.enableGenerateTotpFlow();
    
    // Send OTP for verification
    setState(() => _isProcessing = true);
    try {
      final success = await webAuth.sendOtp(context);
      if (success && mounted) {
        setState(() {
          _start = 89;
          resendTime = "01.29";
        });
        startTimer();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleBackNavigation(BuildContext context, Preferences pref,
      AuthProvider auth, UserProfileProvider userProfile, WidgetRef ref) async {
    if (!mounted) return;
    
    final theme = ref.watch(themeProvider);
    if (pref.islogOut! ||
        auth.switchback == true &&
            (pref.clientId!.isEmpty ||
                pref.clientId!.isNotEmpty ||
                pref.clientMob!.isEmpty ||
                pref.clientMob!.isNotEmpty)) {
      // This path is for logged out users with saved credentials
      if (mounted) {
        theme.removeUsermatrial(context);
        Navigator.pushNamedAndRemoveUntil(
            context, Routes.loginScreenBanner, (route) => false);
      }
    } else {
      // This path is for when we need to switch between accounts
      // Note: Previous issue was caused by inconsistent navigation stack between app bar back button
      // and system back button in the OTP screen
      int activeIndex = auth.loggedMobile
          .indexWhere((element) => element.clientId == pref.clientId);
      if (activeIndex == -1) return;

      // Show loading indicator
      userProfile.profilePageloader(true);

      try {
        // Set client information
        await pref.setClientId(auth.loggedMobile[activeIndex].clientId);
        await pref.setClientMob(auth.loggedMobile[activeIndex].mobile);
        await pref.setClientSession(auth.loggedMobile[activeIndex].sesstion);
        await pref.setClientName(auth.loggedMobile[activeIndex].userName);
        await pref.setImei(auth.loggedMobile[activeIndex].imei);
        await pref.setMobileLogin(true);

        // Calendar PnL cache cleared automatically when switching accounts
        ref.read(ledgerProvider).clearCalendarPnLData();

        // Fetch account data
        await ref.read(authProvider).fetchMobileLogin(
            context,
            "",
            auth.loggedMobile[activeIndex].clientId,
            "switchAc",
            auth.loggedMobile[activeIndex].imei,
            true);

        // Reset and restart websocket connection
        ref.read(websocketProvider).closeSocket(true);
        ref.read(websocketProvider).changeconnectioncount();

        // Navigate to profile tab
        ref.read(indexListProvider).bottomMenu(4, context);

        // Wait for a short time to ensure data is loaded
        await Future.delayed(const Duration(milliseconds: 200));

        // Remove loading indicator after everything is done
        if (mounted && context.mounted) {
          userProfile.profilePageloader(false);
        }
      } catch (e) {
        // Handle any errors during the process
        if (mounted && context.mounted) {
          userProfile.profilePageloader(false);
        }
      }
    }
  }

  /// Reset click on the Forgot Password screen — fires the OTP send call.
  /// On success, switches the inline UI to the OTP entry screen and starts
  /// the resend-cooldown timer. The backend dispatches the temp password
  /// only after OTP verify, not here.
  Future<void> _handleForgotPasswordSubmit() async {
    final forpass = ref.read(changePasswordProvider);
    final success = await forpass.submitForgetPasswordOtpSend(context);
    if (success && mounted) {
      setState(() {
        _showForgotPassword = false;
        _showForgotPasswordOtp = true;
        _start = 89;
        resendTime = formattedTime(timeInSecond: _start);
      });
      startTimer();
    }
  }

  /// Submit on the Forgot Password OTP screen — verifies the OTP. On
  /// success the backend has already generated and sent the temp password
  /// to the user's registered mobile/email, so we jump straight to the
  /// Change Password screen.
  Future<void> _handleForgotPasswordOtpSubmit() async {
    final forpass = ref.read(changePasswordProvider);
    final success = await forpass.submitForgetPasswordOtpVerify(context);
    if (success && mounted) {
      setState(() {
        _showForgotPasswordOtp = false;
        _showChangePassword = true;
      });
    }
  }

  /// Handle change password submission for web
  Future<void> _handleChangePasswordSubmit() async {
    final forpass = ref.read(changePasswordProvider);

    // Validate both fields
    forpass.validateOldPassword(isPasswordExpired: _isPasswordExpired);
    forpass.validateNewPassword();

    if (forpass.oldPasswordError == "" && forpass.newPasswordError == "") {
      await forpass.fetchChangePassword(
        forpass.userIdController.text.toUpperCase(),
        forpass.oldPassword.text,
        forpass.newPassword.text,
        context,
        preventNavigation: true,
        // Forgot-password flow labels the field "Generated Password" — tell
        // the provider to relabel the API's "Old Password" wording in errors.
        isGeneratedPasswordFlow: !_isPasswordExpired,
      );

      // Check if change password was successful
      if (forpass.changepasswordmodel?.stat == "Ok") {
        // Success! Go back to login form
        if (mounted) {
          setState(() {
            _showChangePassword = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Preferences pref = Preferences();
    return Consumer(builder: ((context, WidgetRef ref, _) {
      final auth = ref.watch(authProvider);
      final forpass = ref.watch(changePasswordProvider);
      final userProfile = ref.watch(userProfileProvider);

      final webAuth = ref.watch(webAuthProvider);

      // Show full-screen loader during:
      // 1. Initial page load (_isInitializing) - prevents login form flash on refresh
      // 2. Auth initial load (auth.initLoad)
      // 3. Auto-login session check (webAuth.loading) - but NOT during manual login (_isProcessing)
      if (_isInitializing || auth.initLoad || (webAuth.loading && !_isProcessing)) {
        return Scaffold(
          backgroundColor: resolveThemeColor(context,
              dark: MyntColors.searchBgDark, light: MyntColors.searchBg),
          body: Center(child: MyntLoader.branded()),
        );
      }

      return GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          backgroundColor: resolveThemeColor(context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          body: Center(
            child: Container(
              decoration: BoxDecoration(
                color: resolveThemeColor(context,
                    dark: MyntColors.dialogDark,
                    light: MyntColors.backgroundColor),
                // borderRadius: BorderRadius.circular(12),
              ),
              height: MediaQuery.of(context).size.height - 40,
              margin: const EdgeInsets.symmetric(vertical: 20),
              width: getResponsiveWidth(context),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height - 40,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                     color: resolveThemeColor(context,
                    dark: MyntColors.backgroundColorDark,
                    light: MyntColors.backgroundColor),
                        // borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: resolveThemeColor(context,
                                dark: MyntColors.dividerDark,
                                light: Colors.grey.shade300),
                            width: 0.3),
                        // boxShadow: [
                        //   BoxShadow(
                        //     color: Colors.black.withOpacity(0.1),
                        //     blurRadius: 4,
                        //     offset: const Offset(0, 4),
                        //   ),
                        // ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Consumer(
                              builder: (context, ref, _) {
                                final a11y = ref.watch(accessibilityProvider);
                                return A11yIconButton(
                                  key: const ValueKey('a11y_icon_btn_login'),
                                  anchorKey: _a11yAnchorKey,
                                  isDarkMode: isDarkMode(context),
                                  active: a11y.screenReaderEnabled,
                                  onTap: () => _toggleAccessibilityDropdown(
                                      isDarkMode(context)),
                                );
                              },
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          // Logo
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SvgPicture.asset(
                              assets.appLogoIcon,
                              width: 100,
                              height: 40,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Main Heading

                          if (!(pref.islogOut == true &&
                              (pref.clientId?.isNotEmpty == true ||
                                  pref.clientMob?.isNotEmpty == true)))
                          Text(
                            _showChangePassword
                                ? "Change Your Password"
                                : _showForgotPasswordOtp
                                    ? "Enter the 4-digit OTP"
                                    : _showForgotPassword
                                        ? "Forgot Password"
                                        : _showOtpScreen
                                            ? (webAuth.isTotp
                                                ? "Enter the 6-digit TOTP"
                                                : (webAuth.topflow
                                                    ? "Enter OTP to set up TOTP"
                                                    : "Enter the 4-digit OTP"))
                                            : "Sign in with MYNT",
                            style: webText(
                              context,
                              size: MediaQuery.of(context).size.width < 600 ? 18 : 22,
                             
                              weight: FontWeight.w700,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // QR Login Screen
                          if (_showQrScreen)
                            Consumer(
                              builder: (context, ref, _) {
                                final wa = ref.watch(webAuthProvider);
                                return Column(
                                  children: [
                                    Container(
                                      height: 295,
                                      width: 295,
                                      alignment: Alignment.center,
                                      // When expired, frame the empty area
                                      // with a subtle border so the reload
                                      // icon doesn't float in blank space —
                                      // matches the visual presence of the
                                      // QR image when active.
                                      decoration: _qrExpired
                                          ? BoxDecoration(
                                              border: Border.all(
                                                color: resolveThemeColor(
                                                  context,
                                                  dark: MyntColors.dividerDark,
                                                  light: MyntColors.divider,
                                                ),
                                                width: 1,
                                              ),
                                              // borderRadius: BorderRadius.circular(8),
                                            )
                                          : null,
                                      child: _qrExpired
                                          // Budget exhausted → centered Reload
                                          // icon. Tapping fetches a fresh QR
                                          // and restarts the cycle (counter
                                          // and timer both reset via
                                          // _handleQrLogin).
                                          ? InkWell(
                                              onTap: _handleQrLogin,
                                              borderRadius: BorderRadius.circular(60),
                                              child: Container(
                                                width: 96,
                                                height: 96,
                                                alignment: Alignment.center,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.refresh,
                                                  size: 60,
                                                  color: resolveThemeColor(context,
                                                      dark: MyntColors.textPrimaryDark,
                                                      light: MyntColors.textPrimary),
                                                ),
                                              ),
                                            )
                                          : (wa.qrLoginImageUrl != null
                                               ? Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    MyntLoader.simple(size: MyntLoaderSize.medium),
                                                    Image.network(
                                                      wa.qrLoginImageUrl!,
                                                      frameBuilder: (context, child, frame, wasSyncLoaded) {
                                                        if (wasSyncLoaded || frame != null) {
                                                          if (!_qrImageLoaded) {
                                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                                              if (mounted && !_qrImageLoaded) {
                                                                setState(() => _qrImageLoaded = true);
                                                                _startQrCountdown();
                                                              }
                                                            });
                                                          }
                                                          return child;
                                                        }
                                                        return const SizedBox.shrink();
                                                      },
                                                    ),
                                                  ],
                                                )
                                              : MyntLoader.simple(size: MyntLoaderSize.medium)),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _qrExpired
                                          ? "Click to refresh QR code"
                                          : "Scan QR code from profile tab top appbar of MYNT to login.",
                                      textAlign: TextAlign.center,
                                      style: MyntWebTextStyles.body(context, color: resolveThemeColor(context,
                                          dark: MyntColors.textSecondaryDark,
                                          light: MyntColors.textSecondary)),
                                    ),
                                    if (!_qrExpired && _qrImageLoaded) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        "QR expires in ${formattedTime(timeInSecond: _qrStart)}",
                                        textAlign: TextAlign.center,
                                        style: MyntWebTextStyles.body(
                                          context,
                                          fontWeight: MyntFonts.semiBold,
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.textPrimaryDark,
                                              light: MyntColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(right: 12.0),
                                          child: InkWell(
                                            onTap: _handleCancelQrLogin,
                                            child: Text("Back to login", style: MyntWebTextStyles.body(context, fontWeight: FontWeight.bold, color:resolveThemeColor(context, dark:  MyntColors.secondaryDark, light:  MyntColors.primary))),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              }
                            ),

                          // Form Fields
                          // Check for TOTP Setup screen first (shown after OTP verify in Generate TOTP flow)
                          Consumer(
                            builder: (context, ref, child) {
                              if (_showQrScreen) return const SizedBox.shrink(); // Hide if showing QR Login
                              final webAuth = ref.watch(webAuthProvider);
                              
                              if (webAuth.showTotpSetup && webAuth.totpData != null) {
                                final hasKey = webAuth.totpData?.isValid == true;
                                // TOTP Setup Screen - Show QR code and secret
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title / subtitle vary based on whether a key exists
                                    Text(
                                      hasKey ? "Scan QR" : "Set up TOTP",
                                      style: MyntWebTextStyles.title(
                                        context,
                                        fontWeight: MyntFonts.bold,
                                      ),
                                    ),
                                    if (hasKey) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        "Scan the QR code on authenticator app",
                                        style: MyntWebTextStyles.body(
                                          context,
                                          color: resolveThemeColor(context,
                                            dark: MyntColors.textPrimaryDark,
                                            light: MyntColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),

                                    // If a TOTP key already exists for the user show the QR + key.
                                    // Otherwise show a "Generate New Key" button so they can create one.
                                    if (hasKey) ...[
                                      // QR Code - Centered
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: QrImageView(
                                            data: webAuth.totpData!.getQrUri(),
                                            size: 200,
                                            version: QrVersions.auto,
                                            backgroundColor: Colors.white,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 24),

                                      // Authenticator Key Section
                                      Center(
                                        child: Column(
                                          children: [
                                            Text(
                                              "Authenticator Key",
                                              style: MyntWebTextStyles.body(
                                                context,
                                                fontWeight: MyntFonts.medium,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  webAuth.totpData?.pwd ?? "**********************",
                                                  style: MyntWebTextStyles.body(
                                                    context,
                                                    fontWeight: MyntFonts.medium,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.copy, size: 20),
                                                  onPressed: () {
                                                    Clipboard.setData(ClipboardData(text: webAuth.totpData?.pwd ?? ""));
                                                    ResponsiveSnackBar.showSuccess(
                                                      context,
                                                      "Auth Key is copied to Clipboard",
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 40),
                                      Center(
                                        child: Text(
                                          "No authenticator key found.\nGenerate a new key to set up TOTP.",
                                          textAlign: TextAlign.center,
                                          style: MyntWebTextStyles.body(
                                            context,
                                            color:resolveThemeColor(context,
                                              dark: MyntColors.textPrimaryDark,
                                              light: MyntColors.textPrimary
                                          ),)
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      Center(
                                        child: ElevatedButton(
                                          onPressed: webAuth.loading
                                              ? null
                                              : () => webAuth.generateNewTotpKey(context),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
                                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: webAuth.loading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                              : Text(
                                                  "Generate New Key",
                                                  style: MyntWebTextStyles.titlesub(
                                                    context,
                                                    fontWeight: MyntFonts.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 70),
                                    ],

                                    SizedBox(height: hasKey ? 32 : 8),
                                    
                                    // Back to Login Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          webAuth.backToLogin();
                                          setState(() {
                                            _showOtpScreen = false;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        child: Text(
                                          "Back to Login",
                                          style: MyntWebTextStyles.title(
                                            context,
                                            fontWeight: MyntFonts.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              
                              // Return empty container, the actual form is rendered below
                              return const SizedBox.shrink();
                            },
                          ),
                          
                          // Show OTP screen only if TOTP setup is not showing
                          Consumer(
                            builder: (context, ref, child) {
                              final webAuth = ref.watch(webAuthProvider);
                              if (_showQrScreen) return const SizedBox.shrink(); // Hide
                              if (webAuth.showTotpSetup) return const SizedBox.shrink();
                              return child ?? const SizedBox.shrink();
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_showOtpScreen) ...const [],
                              ],
                            ),
                          ),
                          
                          if (!_showQrScreen && _showOtpScreen && !ref.watch(webAuthProvider).showTotpSetup) ...[
                            // OTP Screen UI
                            
                            // Mobile / Client ID Display (Read Only)
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Mobile / Client ID",
                                    style: MyntWebTextStyles.caption(
                                        context,
                                        color: MyntColors.textSecondary,
                                        darkColor: MyntColors.textSecondaryDark
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        auth.loginMethCtrl.text,
                                        style: MyntWebTextStyles.title(
                                            context,
                                            fontWeight: MyntFonts.medium
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _showOtpScreen = false;
                                            _timer?.cancel();
                                          });
                                        },
                                        child: Text(
                                          "Change",
                                          style: MyntWebTextStyles.body(
                                              context,
                                              fontWeight: MyntFonts.semiBold,
                                             color: resolveThemeColor(context,
                                            dark: MyntColors.secondaryDark,
                                            light: MyntColors.secondary),
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                   Divider(height: 24, thickness: 1, color: resolveThemeColor(context,
                                      dark: MyntColors.dividerDark,
                                      light: MyntColors.divider)),
                                ],
                            ),
                            
                            const SizedBox(height: 20),

                            // OTP Input Field - Using webAuthProvider for mode detection
                            Consumer(
                              builder: (context, ref, _) {
                                final webAuth = ref.watch(webAuthProvider);
                                return TextFormField(
                                   // Force recreation when mode changes to prevent layout/hit-test errors
                                   key: ValueKey("otp_${webAuth.isTotp}_${webAuth.topflow}"),
                                   controller: auth.otpCtrl,
                                   autofocus: true,
                                   // focusNode: focusNode, 
                                   readOnly: _isProcessing || auth.loading,
                                   maxLength: webAuth.isTotp ? 6 : 4,
                                   keyboardType: TextInputType.number,
                                   textInputAction: TextInputAction.done,
                                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                   style: MyntWebTextStyles.title(
                                     context,
                                     fontWeight: MyntFonts.medium,
                                     color: resolveThemeColor(context,
                                         dark: MyntColors.textPrimaryDark,
                                         light: MyntColors.textPrimary),
                                   ),
                                   decoration: InputDecoration(
                                     filled: false,
                                     labelText: webAuth.topflow
                                         ? "Enter the 4-digit OTP to complete TOTP setup"
                                         : "Enter ${webAuth.isTotp ? '6' : '4'} digit ${webAuth.isTotp ? 'TOTP' : 'OTP'}",
                                     floatingLabelBehavior: FloatingLabelBehavior.auto,
                                     labelStyle: MyntWebTextStyles.body(
                                       context,
                                       fontWeight: MyntFonts.regular,
                                       color: resolveThemeColor(context,
                                           dark: MyntColors.textSecondaryDark,
                                           light: MyntColors.textSecondary),
                                     ),
                                     enabledBorder:  UnderlineInputBorder(
                                       borderSide: BorderSide(
                                           color: resolveThemeColor(context,
                                               dark: MyntColors.dividerDark,
                                               light: MyntColors.divider),
                                           width: 1),
                                     ),
                                     focusedBorder:  UnderlineInputBorder(
                                       borderSide: BorderSide(
                                           color: resolveThemeColor(context,
                                               dark: MyntColors.primaryDark,
                                               light: MyntColors.primary),
                                           width: 1),
                                     ),
                                     counterText: "",
                                     contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                     // Timer / Resend Display inside decoration? Or separate? 
                                     // Layout request shows "Resend in 117" on the right. 
                                     
                                     suffix: (!webAuth.isTotp && _start > 0) 
                                         ? Column(
                                             mainAxisAlignment: MainAxisAlignment.center,
                                             crossAxisAlignment: CrossAxisAlignment.end,
                                             mainAxisSize: MainAxisSize.min,
                                             children: [
                                                Text("Resend", style: MyntWebTextStyles.caption(context, color: resolveThemeColor(context,
                                                    dark: MyntColors.textSecondaryDark,
                                                    light: MyntColors.textSecondary))),
                                                Text("in ${formattedTime(timeInSecond: _start)}", style: MyntWebTextStyles.caption(context, color: resolveThemeColor(context,
                                                    dark: MyntColors.textSecondaryDark,
                                                    light: MyntColors.textSecondary), fontWeight: FontWeight.bold)),
                                             ],
                                           )
                                         : (!webAuth.isTotp && _start == 0)
                                            ? InkWell(
                                                onTap: () async {
                                                    if (!mounted) return;
                                                    _handleWebResendOtp(); // Use new web resend OTP
                                                },
                                                child: Text(
                                                    webAuth.topflow
                                                        ? "Resend Setup OTP"
                                                        : "Resend OTP",
                                                    style: MyntWebTextStyles.caption(context, color: resolveThemeColor(context,
                                                    dark: MyntColors.secondaryDark,
                                                    light: MyntColors.secondary), fontWeight: FontWeight.bold)),
                                              )
                                            // Generate TOTP button when in TOTP mode
                                            : webAuth.isTotp
                                                ? InkWell(
                                                    onTap: () async {
                                                        if (!mounted) return;
                                                        _handleGenerateTotpFlow(); // Start Generate TOTP flow
                                                    },
                                                    child: Text("Set up TOTP", style: MyntWebTextStyles.caption(context,  color: resolveThemeColor(context,
                                            dark: MyntColors.secondaryDark,
                                            light: MyntColors.secondary), fontWeight: MyntFonts.semiBold)),
                                                  )
                                                : null
                                   ),
                                   onChanged: (v) {
                                      // Clear error when user starts typing
                                      if (webAuth.otpError != null) {
                                        webAuth.clearErrors();
                                      }
                                      auth.activeBtnOtp(v);

                                      // Auto-submit if length is sufficient (using web auth)
                                      if (!_isProcessing && !auth.loading) {
                                        if (webAuth.isTotp && v.length == 6) {
                                          _handleWebOtpVerify(v);
                                        } else if (!webAuth.isTotp && v.length == 4) {
                                          _handleWebOtpVerify(v);
                                        }
                                      }
                                   },
                                   onFieldSubmitted: (v) {
                                      _handleWebOtpVerify(v);
                                   },
                                );
                              },
                            ),
                            
                            const SizedBox(height: 5),
                            // Use webAuth.otpError for proper TOTP/OTP error messages
                            Consumer(
                              builder: (context, ref, _) {
                                final webAuth = ref.watch(webAuthProvider);
                                if (webAuth.otpError != null && webAuth.otpError!.isNotEmpty) {
                                  return Text(
                                    webAuth.otpError!,
                                    style: MyntWebTextStyles.para(
                                      context,
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.lossDark,
                                          light: MyntColors.loss),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),

                            const SizedBox(height: 32),

                            // Continue Button (OTP Submit)
                            SizedBox(
                               height: 48,
                               child: ElevatedButton(
                                 onPressed: (_isProcessing || auth.loading)
                                     ? null
                                     : () => _handleWebOtpVerify(auth.otpCtrl.text), // Use new web OTP verify
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: resolveThemeColor(context,
                                       dark: MyntColors.secondary,
                                       light: MyntColors.primary),
                                   disabledBackgroundColor: resolveThemeColor(context,
                                       dark: MyntColors.secondary.withOpacity(0.6),
                                       light: MyntColors.primary.withOpacity(0.6)),
                                   shape: RoundedRectangleBorder(
                                       borderRadius: BorderRadius.circular(6)),
                                   elevation: 0,
                                 ),
                                 child: (_isProcessing || auth.loading)
                                     ? MyntLoader.inline()
                                     : Text(
                                         "Verify",
                                         style: MyntWebTextStyles.title(
                                           context,
                                           fontWeight: MyntFonts.bold,
                                           color: Colors.white,
                                         ),
                                       ),
                               ),
                            ),

                            const SizedBox(height: 24),

                            // Bottom Toolbar (Toggle / Forgot / Scan QR)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left Side: Toggle OTP/TOTP or Forgot Password
                                InkWell(
                                    onTap: () async {
                                      if (!auth.loading) {
                                        auth.otpCtrl.clear();
                                        _toggleWebTotpMode(); // Use new web toggle
                                      }
                                    },
                                    child: Consumer(
                                      builder: (context, ref, _) {
                                        final webAuth = ref.watch(webAuthProvider);
                                        return Text(
                                          webAuth.isTotp ? "Enter OTP" : "Enter TOTP",
                                          style: MyntWebTextStyles.body(
                                            context,
                                            fontWeight: MyntFonts.bold,
                                            color: resolveThemeColor(context,
                                                dark: MyntColors.secondaryDark,
                                                light: MyntColors.secondary),
                                          ),
                                        );
                                      },
                                    ),
                                ),
                                
                                // Right Side: Scan QR
                                InkWell(
                                    onTap: () async {
                                      _handleQrLogin(); 
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Scan QR",
                                          style: MyntWebTextStyles.body(
                                            context,
                                            fontWeight: MyntFonts.bold,
                                            color: resolveThemeColor(context,
                                                dark: MyntColors.secondaryDark,
                                                light: MyntColors.secondary),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.qr_code_scanner, size: 20, color: resolveThemeColor(context,
                                            dark: MyntColors.secondaryDark,
                                            light: MyntColors.secondary)),
                                      ],
                                    ),
                                ),
                              ],
                            ),

                          ] else if (!_showQrScreen && _showForgotPassword) ...[
                             // Forgot Password Form (Inlined)
                             TextFormField(
                               controller: forpass.forGetloginMethCtrl,
                               focusNode: focusNode,
                               readOnly: _isProcessing || forpass.loading,
                               maxLength: 10,
                               textCapitalization: TextCapitalization.characters,
                               textInputAction: TextInputAction.done,
                               inputFormatters: [
                                  UpperCaseTextFormatter(),
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z0-9]')),
                               ],
                               style: MyntWebTextStyles.title(
                                 context,
                                 fontWeight: MyntFonts.medium,
                                 color: resolveThemeColor(context,
                                     dark: MyntColors.textPrimaryDark,
                                     light: MyntColors.textPrimary),
                               ),
                               decoration: _mobileInputDecoration(context),
                               onChanged: (v) {
                                  forpass.validateForgetpassWord();
                                  forpass.activateFrogetbtn();
                               },
                               onFieldSubmitted: (_) {
                                  _handleForgotPasswordSubmit();
                               },
                             ),
                             const SizedBox(height: 5),
                             if (forpass.forgetpassError != null &&
                                 forpass.forgetpassError!.isNotEmpty)
                               Text(
                                 "${forpass.forgetpassError}",
                                 style: MyntWebTextStyles.para(
                                   context,
                                   color: resolveThemeColor(context,
                                       dark: MyntColors.lossDark,
                                       light: MyntColors.loss),
                                 ),
                               ),
                             
                             const SizedBox(height: 32),

                             // Continue Button
                             SizedBox(
                               height: 48,
                               child: ElevatedButton(
                                 onPressed: (forpass.loading)
                                     ? null
                                     : _handleForgotPasswordSubmit,
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: resolveThemeColor(context,
                                       dark: MyntColors.secondary,
                                       light: MyntColors.primary),
                                   disabledBackgroundColor:
                                       resolveThemeColor(context,
                                           dark: MyntColors.secondary.withOpacity( 0.6),
                                           light: MyntColors.primary.withOpacity(0.6)),
                                   shape: RoundedRectangleBorder(
                                       borderRadius: BorderRadius.circular(6)),
                                   elevation: 0,
                                 ),
                                 child: (forpass.loading)
                                     ? MyntLoader.inline()
                                     : Text(
                                         "Reset",
                                         style: MyntWebTextStyles.title(
                                           context,
                                           fontWeight: MyntFonts.bold,
                                           color: Colors.white,
                                         ),
                                       ),
                               ),
                             ),
                             const SizedBox(height: 24),

                             // Back to Login Button
                             Align(
                               alignment: Alignment.centerLeft, // Left aligned as per image? Or Center? Image shows left.
                               child: InkWell(
                                 onTap: () {
                                    setState(() {
                                      // Restore client ID back to login form before clearing
                                      auth.loginMethCtrl.text = forpass.forGetloginMethCtrl.text;
                                      auth.passCtrl.clear();
                                      _showForgotPassword = false;
                                      forpass.clearError();
                                      forpass.clearTextField();
                                      // Wipe any stale login-form errors so
                                      // the user lands on a clean form, not
                                      // one showing leftover "required" reds.
                                      auth.clearError();
                                    });
                                 },
                                 child: Text(
                                    "Back to login",
                                    style: MyntWebTextStyles.para(
                                      context,
                                      fontWeight: MyntFonts.bold,
                                      color: resolveThemeColor(context,
                                            dark: MyntColors.secondaryDark,
                                            light: MyntColors.secondary),
                                    ),
                                 ),
                               ),
                             ),

                          ] else if (!_showQrScreen && _showForgotPasswordOtp) ...[
                            // Forgot Password — OTP entry screen.
                            // Backend has dispatched a 4-digit OTP to the user's
                            // registered mobile/email via /ForgetPasswordOtpSend.
                            // On verify the backend itself runs the password
                            // generation, so we just advance to Change Password.
                            TextFormField(
                              controller: forpass.forgotOtpController,
                              readOnly: _isProcessing || forpass.loading,
                              maxLength: 4,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: MyntWebTextStyles.title(
                                context,
                                fontWeight: MyntFonts.medium,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                labelText: "Enter the 4-digit OTP",
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                labelStyle: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.regular,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.dividerDark,
                                          light: MyntColors.divider),
                                      width: 1),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.primaryDark,
                                          light: MyntColors.primary),
                                      width: 1),
                                ),
                                counterText: "",
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                // Mirror the login OTP screen's resend UX:
                                // a "Resend in m:ss" countdown while _start > 0,
                                // then a tappable "Resend OTP" once it hits 0.
                                // Resend tap restarts the 89-second cooldown.
                                suffix: (_start > 0)
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "Resend",
                                            style: MyntWebTextStyles.caption(
                                              context,
                                              color: resolveThemeColor(context,
                                                  dark: MyntColors.textSecondaryDark,
                                                  light: MyntColors.textSecondary),
                                            ),
                                          ),
                                          Text(
                                            "in ${formattedTime(timeInSecond: _start)}",
                                            style: MyntWebTextStyles.caption(
                                              context,
                                              color: resolveThemeColor(context,
                                                  dark: MyntColors.textSecondaryDark,
                                                  light: MyntColors.textSecondary),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      )
                                    : InkWell(
                                        onTap: () async {
                                          if (forpass.loading) return;
                                          final ok = await forpass
                                              .submitForgetPasswordOtpSend(context);
                                          if (ok && mounted) {
                                            forpass.forgotOtpController.clear();
                                            setState(() {
                                              _start = 89;
                                              resendTime = formattedTime(timeInSecond: _start);
                                            });
                                            startTimer();
                                          }
                                        },
                                        child: Text(
                                          "Resend OTP",
                                          style: MyntWebTextStyles.caption(
                                            context,
                                            color: resolveThemeColor(context,
                                                dark: MyntColors.secondaryDark,
                                                light: MyntColors.secondary),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                              onChanged: (v) {
                                if (forpass.forgotOtpError != null) {
                                  forpass.clearError();
                                }
                                // Auto-verify once the 4-digit OTP is filled —
                                // matches the login OTP UX (no manual Verify
                                // tap needed). Guarded against re-entry while
                                // a verify call is already in flight.
                                if (v.length == 4 &&
                                    !_isProcessing &&
                                    !forpass.loading) {
                                  _handleForgotPasswordOtpSubmit();
                                }
                              },
                              onFieldSubmitted: (_) {
                                _handleForgotPasswordOtpSubmit();
                              },
                            ),
                            const SizedBox(height: 5),
                            if (forpass.forgotOtpError != null &&
                                forpass.forgotOtpError!.isNotEmpty)
                              Text(
                                forpass.forgotOtpError!,
                                style: MyntWebTextStyles.para(
                                  context,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.lossDark,
                                      light: MyntColors.loss),
                                ),
                              ),
                            const SizedBox(height: 32),

                            // Verify Button
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: forpass.loading
                                    ? null
                                    : _handleForgotPasswordOtpSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: resolveThemeColor(context,
                                      dark: MyntColors.secondary,
                                      light: MyntColors.primary),
                                  disabledBackgroundColor: resolveThemeColor(
                                      context,
                                      dark: MyntColors.secondary.withOpacity(0.6),
                                      light: MyntColors.primary.withOpacity(0.6)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                  elevation: 0,
                                ),
                                child: forpass.loading
                                    ? MyntLoader.inline()
                                    : Text(
                                        "Verify",
                                        style: MyntWebTextStyles.title(
                                          context,
                                          fontWeight: MyntFonts.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Back to Login — bails out of the entire forgot
                            // flow. Identifier and OTP are cleared so the next
                            // entry starts fresh.
                            Align(
                              alignment: Alignment.centerLeft,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    auth.loginMethCtrl.text =
                                        forpass.forGetloginMethCtrl.text;
                                    auth.passCtrl.clear();
                                    _showForgotPasswordOtp = false;
                                    forpass.clearError();
                                    forpass.clearTextField();
                                    // Clear stale login-form validation
                                    // errors so the returned-to login form
                                    // is clean, not pre-flashing reds.
                                    auth.clearError();
                                  });
                                },
                                child: Text(
                                  "Back to login",
                                  style: MyntWebTextStyles.para(
                                    context,
                                    fontWeight: MyntFonts.bold,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.secondaryDark,
                                        light: MyntColors.secondary),
                                  ),
                                ),
                              ),
                            ),

                          ] else if (_showChangePassword) ...[
                            // Change Password Form

                            // // Client ID Field (Disabled)
                            // TextFormField(
                            //   controller: forpass.userIdController,
                            //   readOnly: true,
                            //   style: MyntWebTextStyles.title(
                            //     context,
                            //     fontWeight: MyntFonts.medium,
                            //     color: resolveThemeColor(context,
                            //         dark: MyntColors.textSecondaryDark,
                            //         light: MyntColors.textSecondary),
                            //   ),
                            //   decoration: InputDecoration(
                            //     filled: false,
                            //     labelText: "Client ID",
                            //     floatingLabelBehavior: FloatingLabelBehavior.auto,
                            //     labelStyle: MyntWebTextStyles.body(
                            //       context,
                            //       fontWeight: MyntFonts.regular,
                            //       color: resolveThemeColor(context,
                            //           dark: MyntColors.textSecondaryDark,
                            //           light: MyntColors.textSecondary),
                            //     ),
                            //     enabledBorder: UnderlineInputBorder(
                            //       borderSide: BorderSide(
                            //           color: resolveThemeColor(context,
                            //               dark: MyntColors.dividerDark,
                            //               light: MyntColors.divider),
                            //           width: 1),
                            //     ),
                            //     disabledBorder: UnderlineInputBorder(
                            //       borderSide: BorderSide(
                            //           color: resolveThemeColor(context,
                            //               dark: MyntColors.dividerDark,
                            //               light: MyntColors.divider),
                            //           width: 1),
                            //     ),
                            //     counterText: "",
                            //     contentPadding:
                            //         const EdgeInsets.symmetric(vertical: 8),
                            //   ),
                            // ),
                            // const SizedBox(height: 20),

                            // Old/Generated Password Field
                            TextFormField(
                              controller: forpass.oldPassword,
                              focusNode: focusNode,
                              readOnly: forpass.loading,
                              obscureText: forpass.hideoldpassword,
                              textInputAction: TextInputAction.next,
                              style: MyntWebTextStyles.title(
                                context,
                                fontWeight: MyntFonts.medium,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                labelText: _isPasswordExpired ? "Old Password" : "Generated Password",
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                labelStyle: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.regular,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary),
                                ),
                                suffixIcon: InkWell(
                                  onTap: () {
                                    forpass.hiddeoldpasswords();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SvgPicture.asset(
                                      forpass.hideoldpassword
                                          ? "assets/icon/eye-off.svg"
                                          : "assets/icon/eye.svg",
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.textSecondaryDark,
                                          light: MyntColors.textSecondary),
                                      width: 20,
                                    ),
                                  ),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.dividerDark,
                                          light: MyntColors.divider),
                                      width: 1),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.primaryDark,
                                          light: MyntColors.primary),
                                      width: 1),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onChanged: (v) {
                                forpass.validateOldPassword(isPasswordExpired: _isPasswordExpired);
                                forpass.activateChangePass();
                              },
                            ),
                            const SizedBox(height: 5),
                            if (forpass.oldPasswordError != null &&
                                forpass.oldPasswordError!.isNotEmpty &&
                                forpass.oldPasswordError != "")
                              Text(
                                "${forpass.oldPasswordError}",
                                style: MyntWebTextStyles.para(
                                  context,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.lossDark,
                                      light: MyntColors.loss),
                                ),
                              ),
                            const SizedBox(height: 20),

                            // New Password Field
                            TextFormField(
                              controller: forpass.newPassword,
                              focusNode: focusNode1,
                              readOnly: forpass.loading,
                              obscureText: forpass.hidenewpassword,
                              textInputAction: TextInputAction.done,
                              // Backend enforces max 12 chars + alphanumeric +
                              // allowed specials (#, $, -, *, @). Mirror that
                              // at the input level so users get immediate
                              // feedback instead of typing past 12 and only
                              // hitting the API error on submit.
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9#$\-*@]'),
                                ),
                                // Custom max-length formatter: when input
                                // would exceed 12, truncate AND fire the
                                // transient red error so the user knows the
                                // 13th keystroke (or oversized paste) was
                                // rejected. Built-in maxLength would silently
                                // block without surfacing the reason.
                                TextInputFormatter.withFunction(
                                  (oldValue, newValue) {
                                    if (newValue.text.length > 12) {
                                      _triggerNewPwdMaxLengthError();
                                      final truncated =
                                          newValue.text.substring(0, 12);
                                      return TextEditingValue(
                                        text: truncated,
                                        selection: TextSelection.collapsed(
                                            offset: truncated.length),
                                      );
                                    }
                                    return newValue;
                                  },
                                ),
                              ],
                              style: MyntWebTextStyles.title(
                                context,
                                fontWeight: MyntFonts.medium,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                labelText: "New Password",
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                labelStyle: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.regular,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary),
                                ),
                                suffixIcon: InkWell(
                                  onTap: () {
                                    forpass.hiddenewpasswords();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SvgPicture.asset(
                                      forpass.hidenewpassword
                                          ? "assets/icon/eye-off.svg"
                                          : "assets/icon/eye.svg",
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.textSecondaryDark,
                                          light: MyntColors.textSecondary),
                                      width: 20,
                                    ),
                                  ),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.dividerDark,
                                          light: MyntColors.divider),
                                      width: 1),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.primaryDark,
                                          light: MyntColors.primary),
                                      width: 1),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onChanged: (v) {
                                forpass.validateNewPassword();
                                forpass.activateChangePass();
                              },
                              onFieldSubmitted: (_) {
                                _handleChangePasswordSubmit();
                              },
                            ),
                            const SizedBox(height: 5),
                          
                            if (_showNewPwdMaxLengthError)
                              Text(
                                "Password must be exactly 12 characters",
                                style: MyntWebTextStyles.para(
                                  context,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.lossDark,
                                      light: MyntColors.loss),
                                ),
                              )
                            else if (forpass.newPasswordError != null &&
                                forpass.newPasswordError!.isNotEmpty &&
                                forpass.newPasswordError != "")
                              Text(
                                "${forpass.newPasswordError}",
                                style: MyntWebTextStyles.para(
                                  context,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.lossDark,
                                      light: MyntColors.loss),
                                ),
                              ),

                            const SizedBox(height: 32),

                            // Continue Button (Change Password Submit)
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: (forpass.loading)
                                    ? null
                                    : _handleChangePasswordSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: resolveThemeColor(context,
                                      dark: MyntColors.secondary,
                                      light: MyntColors.primary),
                                  disabledBackgroundColor: resolveThemeColor(
                                      context,
                                      dark:
                                          MyntColors.secondary.withOpacity(0.6),
                                      light:
                                          MyntColors.primary.withOpacity(0.6)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                  elevation: 0,
                                ),
                                child: (forpass.loading)
                                    ? MyntLoader.inline()
                                    : Text(
                                        "Set New Password",
                                        style: MyntWebTextStyles.title(
                                          context,
                                          fontWeight: MyntFonts.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Back to Login Button
                            Align(
                              alignment: Alignment.centerLeft,
                              child: InkWell(
                                onTap: () {
                                  final auth = ref.read(authProvider);
                                  setState(() {
                                    // Pre-populate login Client ID for convenience, clear stale password
                                    if (forpass.userIdController.text.isNotEmpty) {
                                      auth.loginMethCtrl.text = forpass.userIdController.text;
                                    }
                                    auth.passCtrl.clear();
                                    auth.passError = null;
                                    _showChangePassword = false;
                                    _isPasswordExpired = false;
                                    forpass.changePassMethod();
                                  });
                                },
                                child: Text(
                                  "Back to login",
                                  style: MyntWebTextStyles.para(
                                    context,
                                    fontWeight: MyntFonts.bold,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.secondaryDark,
                                        light: MyntColors.secondary),
                                  ),
                                ),
                              ),
                            ),

                          ] else if (!_showQrScreen && !_showOtpScreen && pref.islogOut! &&
                              (pref.clientId!.isNotEmpty ||
                                  pref.clientMob!.isNotEmpty)) ...[
                            // Saved Account UI
                            Builder(
                              builder: (context) {
                                if (auth.loginMethCtrl.text.isEmpty) {
                                  auth.loginMethCtrl.text = pref.clientId ?? "";
                                }
                                return Center(
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.backgroundColorDark,
                                              light: MyntColors.backgroundColor),
                                          border: Border.all(
                                            color: resolveThemeColor(context,
                                                dark: MyntColors.primaryDark,
                                                light: MyntColors.primary),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            pref.clientName!.isNotEmpty
                                                ? pref.clientName!
                                                    .split(' ')
                                                    .map((e) => e[0])
                                                    .take(2)
                                                    .join('')
                                                : '',
                                            style: MyntWebTextStyles.hero(
                                              context,
                                              fontWeight: MyntFonts.bold,
                                              color: resolveThemeColor(context,
                                                  dark: MyntColors.primaryDark,
                                                  light: MyntColors.primary),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        pref.clientName ?? '',
                                        style: MyntWebTextStyles.head(
                                          context,
                                          fontWeight: MyntFonts.bold,
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.textPrimaryDark,
                                              light: MyntColors.textPrimary),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        pref.clientId ?? '',
                                        style: MyntWebTextStyles.title(
                                          context,
                                          fontWeight: MyntFonts.semiBold,
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.textPrimaryDark,
                                              light: MyntColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            )
                          ] else if (!_showQrScreen && !_showOtpScreen) ...[
                            // Login Form - User ID Input
                            TextFormField(
                              controller: auth.loginMethCtrl,
                              focusNode: focusNode,
                              readOnly: _isProcessing || auth.loading,
                              maxLength: 10,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                UpperCaseTextFormatter(),
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9]')),
                              ],
                              style: MyntWebTextStyles.title(
                                context,
                                fontWeight: MyntFonts.medium,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                              ),
                              decoration: _mobileInputDecoration(context),
                              // No onTap: getCurrentPhone() relies on SMS
                              // auto-fill (mobile-only). On web that path
                              // falls through to setting the controller
                              // empty and triggering validateLogin, which
                              // flashed a spurious "required" error just
                              // from clicking the empty field.
                              onChanged: (v) {
                                auth.validateLogin();
                                auth.activeBtnLogin();
                              },
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).requestFocus(focusNode1);
                              },
                            ),
                            const SizedBox(height: 5),
                            if (auth.loginMethError != null &&
                                auth.loginMethError!.isNotEmpty)
                              Text(
                                "${auth.loginMethError}",
                                style: MyntWebTextStyles.para(
                                  context,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.lossDark,
                                      light: MyntColors.loss),
                                ),
                              ),
                          ],
                          
                          // Password and Actions (Only Show if NOT in Forgot Password or Change Password Mode)
                          if (!_showQrScreen && !_showForgotPassword && !_showForgotPasswordOtp && !_showOtpScreen && !_showChangePassword) ...[
                            const SizedBox(height: 20),
                            
                            // Password Input (Always Visible)
                            TextFormField(
                              controller: auth.passCtrl,
                              focusNode: focusNode1,
                              obscureText: auth.hidePass,
                              readOnly: _isProcessing || auth.loading,
                              textInputAction: TextInputAction.done,
                              style: MyntWebTextStyles.title(
                                context,
                                fontWeight: MyntFonts.medium,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                              ),
                              decoration: InputDecoration(
                                labelText: "Password",
                                filled: false,
                                labelStyle: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.regular,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary),
                                ),
                                suffixIcon: InkWell(
                                  onTap: auth.hiddenPass,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SvgPicture.asset(
                                      auth.hidePass
                                          ? "assets/icon/eye-off.svg"
                                          : "assets/icon/eye.svg",
                                      color: resolveThemeColor(context,
                                          dark:  MyntColors.textSecondaryDark,
                                          light: MyntColors.textSecondary),
                                      width: 20,
                                    ),
                                  ),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.dividerDark,
                                          light: MyntColors.divider),
                                      width: 1),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.primaryDark,
                                          light: MyntColors.primary),
                                      width: 1),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                              inputFormatters: [
                                NoEmojiInputFormatter(),
                                FilteringTextInputFormatter.deny(
                                    RegExp('[π£•₹€℅™∆√¶/,]')),
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              onChanged: (v) {
                                auth.validatePass();
                                auth.activeBtnLogin();
                              },
                              onFieldSubmitted: (_) {
                                if (!_isProcessing && !auth.loading) {
                                  _handleWebLogin(); // Use new web login flow
                                }
                              },
                            ),
                            const SizedBox(height: 5),
                            if (auth.passError != null &&
                                auth.passError!.isNotEmpty)
                              Text(
                                "${auth.passError}",
                                style: MyntWebTextStyles.para(
                                  context,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.lossDark,
                                      light: MyntColors.loss),
                                ),
                              ),
                            const SizedBox(height: 32),


                            // Login Button
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: (_isProcessing || auth.loading)
                                    ? null
                                    : _handleWebLogin, // Use new web login flow
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: resolveThemeColor(context,
                                      dark: MyntColors.secondary,
                                      light: MyntColors.primary),
                                  disabledBackgroundColor:
                                      resolveThemeColor(context,
                                          dark: MyntColors.secondary.withOpacity(0.6),
                                          light: MyntColors.primary.withOpacity(0.6)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                  elevation: 0,
                                ),
                                child: (_isProcessing || auth.loading)
                                    ? MyntLoader.inline()
                                    : Text(
                                        "Login",
                                        style: MyntWebTextStyles.title(
                                          context,
                                          fontWeight: MyntFonts.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Actions Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left Logic: Switch Account (if saved) OR Forgot Password (if new)
                                if (pref.islogOut! &&
                                    (pref.clientId!.isNotEmpty ||
                                        pref.clientMob!.isNotEmpty))
                                  InkWell(
                                    onTap: () async {
                                      pref.setLogout(false);
                                      pref.setHideLoginOptBtn(true);
                                      // Clear controller
                                      auth.loginMethCtrl.clear(); 
                                      auth.passCtrl.clear();
                                      await auth.loginMethod();
                                      auth.switchbackbutton(true);
                                    },
                                    child: Text(
                                      "Switch account",
                                      style: MyntWebTextStyles.para(
                                        context,
                                        fontWeight: MyntFonts.bold,
                                       color: resolveThemeColor(context,
                                            dark: MyntColors.secondaryDark,
                                            light: MyntColors.secondary),
                                      ),
                                    ),
                                  )
                                else
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        // Copy client ID to forgot password form before clearing
                                        forpass.forGetloginMethCtrl.text = auth.loginMethCtrl.text;
                                        // Clear the login client ID field
                                        auth.loginMethCtrl.clear();
                                        auth.loginMethError = null;
                                        _showForgotPassword = true;
                                        forpass.clearError();
                                      });
                                    },
                                    child: Text(
                                      "Forgot password",
                                      style: MyntWebTextStyles.para(
                                        context,
                                        fontWeight: MyntFonts.bold,
                                        color: resolveThemeColor(context,
                                            dark: MyntColors.secondaryDark,
                                            light: MyntColors.secondary),
                                      ),
                                    ),
                                  ),

                                // Right Logic: Forgot Password (if saved) OR Empty (if new)
                                // Right Logic: Scan QR
                                InkWell(
                                    onTap: () {
                                      _handleQrLogin(); 
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Scan QR",
                                          style: MyntWebTextStyles.para(
                                            context,
                                            fontWeight: MyntFonts.bold,
                                            color: resolveThemeColor(context,
                                            dark: MyntColors.secondaryDark,
                                            light: MyntColors.secondary),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.qr_code_scanner, size: 20, color: resolveThemeColor(context,
                                            dark: MyntColors.secondaryDark,
                                            light: MyntColors.secondary)),
                                      ],
                                    ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 32),



                          if (!_showQrScreen) ...[
                             const SizedBox(height: 32),
                             // Sign Up Link
                             Center(
                               child: InkWell(
                                 onTap: () {
                                   launch('https://oa.mynt.in/?ref=zws');
                                 },
                                 child: RichText(
                                   text: TextSpan(
                                     text: "Don't have an account yet? ",
                                     style: MyntWebTextStyles.body(
                                       context,
                                       color: resolveThemeColor(context,
                                           dark: MyntColors.textPrimaryDark,
                                           light: MyntColors.textPrimary),
                                     ),
                                     children: [
                                       TextSpan(
                                           text: "Sign Up",
                                           style: MyntWebTextStyles.body(
                                             context,
                                             fontWeight: MyntFonts.bold,
                                          color: resolveThemeColor(context,
                                            dark: MyntColors.secondaryDark,
                                            light: MyntColors.secondary),
                                           ))
                                     ],
                                   ),
                                 ),
                               ),
                             ),
                          ],

                          const SizedBox(height: 140),
                        ],
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            children: [
                              Text(
                                "Zebu Share and Wealth Managements Pvt. Ltd.",
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.bold,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  "SEBI Registration No: INZ000174634 | NSE : 13179 | BSE : 6550 | MCX : 55730 | CDSL : 12080400 | AMFI ARN : 113118 | Research Analyst : INH200006044",
                                  style: MyntWebTextStyles.para(
                                    context,
                                    color: resolveThemeColor(context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary),
                                  ).copyWith(height: 1.5),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Tooltip(
                                message: _appVersionLabel,
                                child: Text(
                                  _appVersionShort,
                                  style: MyntWebTextStyles.para(
                                    context,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary),
                                  ),
                                  textAlign: TextAlign.center,
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
                ],
              ),
            ),
          ),
        ),
      );
    }));
  }
}

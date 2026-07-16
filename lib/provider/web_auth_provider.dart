import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../api/web_auth_api.dart';
import '../locator/preference.dart';
import '../models/auth_model/mobile_login_model.dart';
import '../models/auth_model/mobile_otp_model.dart';
import '../utils/responsive_snackbar.dart';
import '../utils/totp_utils.dart';
import '../routes/web_router.dart';
import 'auth_provider.dart';

/// Provider for web-specific authentication
final webAuthProvider = ChangeNotifierProvider((ref) => WebAuthProvider(ref));

/// Web-specific authentication provider
/// Handles login flow with source="WEB", separate OTP send, and TOTP generation
class WebAuthProvider extends ChangeNotifier {
  final Ref ref;
  final Preferences pref = Preferences();
  final Uuid uuid = const Uuid();

  WebAuthProvider(this.ref);

  // Controllers
  final TextEditingController loginController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  // State
  bool _loading = false;
  bool get loading => _loading;

  bool _isTotp = true; // Default to TOTP mode
  bool get isTotp => _isTotp;

  String? _loginError;
  String? get loginError => _loginError;

  String? _passwordError;
  String? get passwordError => _passwordError;

  String? _otpError;
  String? get otpError => _otpError;

  MobileLoginModel? _mobileLogin;
  MobileLoginModel? get mobileLogin => _mobileLogin;

  MobileOtpModel? _mobileOtp;
  MobileOtpModel? get mobileOtp => _mobileOtp;

  // TOTP State
  TotpData? _totpData;
  TotpData? get totpData => _totpData;

  String _currentTotp = '';
  String get currentTotp => _currentTotp;

  int _totpTimer = 30;
  int get totpTimer => _totpTimer;

  Timer? _totpRefreshTimer;
  
  String? _apiSession;
  String? get apiSession => _apiSession;

  bool _showTotpSetup = false;
  bool get showTotpSetup => _showTotpSetup;

  // Flag for "Generate TOTP" flow - when user needs to create a new TOTP
  bool _topflow = false;
  bool get topflow => _topflow;

  // Flag when API says password must be changed (after OTP verify)
  bool _requiresPasswordChange = false;
  bool get requiresPasswordChange => _requiresPasswordChange;

  bool _isPasswordExpiredFlag = false;
  bool get isPasswordExpiredFlag => _isPasswordExpiredFlag;

  // Unique ID for device
  String _deviceUuid = '';

  // Source for web
  static const String _source = 'WEB';

  /// Initialize the provider - clears any stale state from previous sessions
  void init() {
    // Clear any stale state from previous sessions
    stopTotpTimer();
    _mobileLogin = null;
    _mobileOtp = null;
    _totpData = null;
    _currentTotp = '';
    _totpTimer = 30;
    _apiSession = null;
    _showTotpSetup = false;
    _topflow = false;
    _requiresPasswordChange = false;
    _isPasswordExpiredFlag = false;
    _loading = false;
    _loginError = null;
    _passwordError = null;
    _otpError = null;

    // Generate fresh device UUID for this session
    _deviceUuid = uuid.v4();
    _isTotp = true;
    notifyListeners();
  }

  /// Toggle loading state
  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  /// Toggle between OTP and TOTP mode
  void toggleTotpMode() {
    _isTotp = !_isTotp;
    _topflow = false; // Toggling exits the TOTP setup flow back to normal entry
    otpController.clear();
    _otpError = null;
    notifyListeners();
  }

  /// Set TOTP mode explicitly
  void setTotpMode(bool value) {
    _isTotp = value;
    notifyListeners();
  }

  /// Validate login input
  bool validateLogin() {
    if (loginController.text.trim().isEmpty) {
      _loginError = "Your mobile / client id is required";
      notifyListeners();
      return false;
    }
    _loginError = null;
    notifyListeners();
    return true;
  }

  /// Validate password input
  bool validatePassword() {
    if (passwordController.text.trim().isEmpty) {
      _passwordError = "Please enter the password";
      notifyListeners();
      return false;
    }
    _passwordError = null;
    notifyListeners();
    return true;
  }

  /// Validate OTP input
  bool validateOtp() {
    final length = _isTotp ? 6 : 4;
    if (otpController.text.length != length) {
      _otpError = "Please enter $length digit ${_isTotp ? 'TOTP' : 'OTP'}";
      notifyListeners();
      return false;
    }
    _otpError = null;
    notifyListeners();
    return true;
  }

  /// Clear all errors
  void clearErrors() {
    _loginError = null;
    _passwordError = null;
    _otpError = null;
    notifyListeners();
  }

  /// Clear all text fields
  void clearFields() {
    loginController.clear();
    passwordController.clear();
    otpController.clear();
    notifyListeners();
  }

  /// Check for existing valid session and auto-login
  Future<bool> checkAutoLogin(BuildContext context) async {
    // 1. Check if we have session data in preferences
    final session = pref.clientSession;
    final clientId = pref.clientId;

    if (session == null || session.isEmpty || clientId == null || clientId.isEmpty) {
      return false; // No session, stay on login
    }

    _setLoading(true);

    try {
      // 2. Validate session with API
      final result = await WebAuthApi.validateSession(
        clientId: clientId,
        apiSession: session,
      );

      // 3. Check if validation successful
      if (result != null && result['stat'] == 'Ok') {

        // Ensure other preferences are set if needed (e.g. clientName from result['uname'])
        if (result['uname'] != null) {
          await pref.setClientName(result['uname']);
        }

        // Call initialLoadMethods FIRST (it will handle navigation internally)
        // This ensures all data loading uses the correct context flow
        if (context.mounted) {
          await ref.read(authProvider).initialLoadMethods(context, "");
        }
        return true;
      } else {
        // Clear invalid session to ensure fresh login state
        await pref.clearClientSession();
        pref.setLogout(true);
        pref.setMobileLogin(false);
        // Reset provider state for fresh login
        reset();
      }
    } catch (e) {
      // Clear session on error to prevent stale state
      await pref.clearClientSession();
      pref.setLogout(true);
      pref.setMobileLogin(false);
      reset();
    } finally {
      _setLoading(false);
    }
    return false;
  }

  /// URL token-based auto-login (app.mynt.in/?uid=..&token=..).
  ///
  /// Validates (uid, token) against the backend and commits a session ONLY on
  /// success. Returns true if logged in (navigation to home is triggered).
  /// Returns false for an invalid/expired token WITHOUT modifying any stored
  /// pref — so a wrong link can never overwrite or log out the current user.
  Future<bool> tryUrlAutoLogin(
      BuildContext context, String uid, String token) async {
    _setLoading(true);
    try {
      final result =
          await WebAuthApi.validateSession(clientId: uid, apiSession: token);

      if (result != null && result['stat'] == 'Ok') {
        // Validated — now (and only now) replace any existing session. Start
        // clean so a new user never inherits the previous user's prefs.
        await pref.clearUserSession();
        await pref.setClientId(uid);
        await pref.setClientSession(token);
        if (result['uname'] != null) {
          await pref.setClientName(result['uname']);
        }
        await pref.setLogout(false);
        await pref.setMobileLogin(true);

        if (context.mounted) {
          await ref.read(authProvider).initialLoadMethods(context, "");
        }
        return true;
      }

      // Invalid/expired link — touch nothing; existing session stays intact.
      return false;
    } catch (e) {
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Web Login - Submit login credentials
  Future<bool> submitWebLogin(BuildContext context) async {
    if (!validateLogin() || !validatePassword()) {
      return false;
    }

    _setLoading(true);
    clearErrors();

    try {
      // Generate unique device ID
      _deviceUuid = uuid.v4();
      
      _mobileLogin = await WebAuthApi.webMobileLogin(
        uniqueId: _deviceUuid,
        mobileOrClientId: loginController.text.trim().toUpperCase(),
        password: passwordController.text,
        imei: _deviceUuid,
        totp: _isTotp,
        context: context,
      );

      if (_mobileLogin?.stat == 'Ok') {
        // Store the client ID for OTP verification
        pref.setImei(_deviceUuid);

        // Check if login is complete (has token) or needs OTP
        if (_mobileLogin?.apitoken != null && _mobileLogin?.token != null) {
          // Direct login success - no OTP needed
          await _handleLoginSuccess(context);
          return true;
        }

        // OTP/TOTP flow needed
        otpController.clear();
        _setLoading(false);

        if (!_isTotp && context.mounted) {
          ResponsiveSnackBar.showSuccess(context, 'OTP sent to your registered mobile and email');
        }

        return true;
      } else {
        // Error case - the API layer shows the specific error message
        // This is a fallback only if both emsg and msg are null
        final errorMsg = _mobileLogin?.emsg ?? _mobileLogin?.msg;
        if (errorMsg == null && _mobileLogin != null && context.mounted) {
          ResponsiveSnackBar.showWarning(context, 'Login failed. Please check your credentials.');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showWarning(context, 'Login failed. Please try again.');
      }
    } finally {
      _setLoading(false);
    }

    return false;
  }

  /// Send OTP - Separate API call for sending OTP
  Future<bool> sendOtp(BuildContext context) async {
    _setLoading(true);

    try {
      final result = await WebAuthApi.sendOtp(
        mobileOrClientId: loginController.text.trim().toUpperCase(),
        source: _source,
        context: context,
        // TOTP-setup flow → tell the backend this OTP is for TOTP setup.
        isTotp: _topflow,
      );

      if (result != null && (result['stat'] == 'Ok' || (result['msg'] != null && result['msg'].toString().toLowerCase().contains('otp')))) {
        if (context.mounted) {
          // _topflow is true only when the user is in the "Set up TOTP" flow,
          // where the OTP is for identity verification before revealing the
          // TOTP secret. Use a more specific success message in that case;
          // regular OTP login / resend keep the generic message.
          final successMsg = _topflow
              ? '4-digit TOTP Setup code sent successfully'
              : 'OTP sent successfully';
          ResponsiveSnackBar.showSuccess(context, successMsg);
        }
        _setLoading(false);
        return true;
      } else if (result != null && result['emsg'] != null && context.mounted) {
        ResponsiveSnackBar.showWarning(context, result['emsg'].toString());
      }
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showWarning(context, 'Failed to send OTP');
      }
    } finally {
      _setLoading(false);
    }

    return false;
  }

  /// Verify OTP/TOTP
  Future<bool> verifyOtp(BuildContext context) async {
    if (!validateOtp()) {
      return false;
    }

    _setLoading(true);

    try {
      // Build log data
      final logData = {
        'datetime': DateTime.now().toIso8601String(),
        'login_type': _isTotp ? 'totp' : 'otp',
        'src': 'flutter web app',
        'IP_address': 'web',
        'app': 'MYNT Web',
        'platform': 'web',
        'imei': _deviceUuid,
      };

      _mobileOtp = await WebAuthApi.webVerifyOtp(
        uniqueId: _deviceUuid,
        mobileOrClientId: loginController.text.trim().toUpperCase(),
        otp: otpController.text.trim(),
        imei: _deviceUuid,
        source: _source,
        logData: logData,
        context: context,
      );

      if (_mobileOtp?.stat == 'Ok' && _mobileOtp?.apitoken != null) {
        // Store session for TOTP generation if needed
        _apiSession = _mobileOtp!.apitoken;

        // Check if this is "Generate TOTP" flow (Vue.js topfloww logic)
        // If topflow is true, user clicked "Generate TOTP" - show TOTP setup screen
        if (_topflow) {
          _showTotpSetup = true;
          await fetchTotpData(context);
          notifyListeners();
          return true; // Don't navigate, stay on TOTP setup screen
        }

        await _handleOtpSuccess(context);
        return true;
      } else if (_mobileOtp?.emsg != null) {
        // Handle OTP/TOTP validation errors with proper distinction
        final errorMsg = _mobileOtp!.emsg!.toLowerCase();
        final otpTypeLabel = _isTotp ? 'TOTP' : 'OTP';

        if (errorMsg.contains('change password') || errorMsg.contains('password expired')) {
          // Set flags so the UI can show the change password screen
          _requiresPasswordChange = true;
          _isPasswordExpiredFlag = errorMsg.contains('password expired');
          _otpError = _mobileOtp!.emsg;
          if (context.mounted) {
            ResponsiveSnackBar.showWarning(context, _mobileOtp!.emsg!);
          }
          notifyListeners();
          return false;
        } else if (errorMsg.contains('invalid user')) {
          // OAuth: the account being logged in doesn't own the app key, so the
          // backend rejects with "Invalid User". Show that real reason as a toast,
          // NOT a misleading "Invalid TOTP" — the emsg ("Invalid Input : Invalid
          // User") would otherwise be swallowed by the 'invalid input' check below.
          // Strip the "Invalid Input :" prefix and show just "Invalid User".
          _otpError = null;
          if (context.mounted) {
            final reason = _mobileOtp!.emsg!.split(':').last.trim();
            ResponsiveSnackBar.showError(context, reason);
          }
        } else if (errorMsg.contains('otp not valid') || errorMsg.contains('invalid otp') || errorMsg.contains('invalid input')) {
          // API error → toaster only (consistent with login flow)
          _otpError = null;
          if (context.mounted) {
            ResponsiveSnackBar.showError(context, 'Invalid $otpTypeLabel, Please Try again');
          }
        } else {
          // API error → toaster only (raw emsg)
          _otpError = null;
          if (context.mounted) {
            ResponsiveSnackBar.showError(context, _mobileOtp!.emsg!);
          }
        }
        notifyListeners();
      } else if (_mobileOtp != null) {
        // Fallback — toaster only
        final otpTypeLabel = _isTotp ? 'TOTP' : 'OTP';
        _otpError = null;
        if (context.mounted) {
          ResponsiveSnackBar.showError(context, 'Invalid $otpTypeLabel, Please Try again');
        }
        notifyListeners();
      }
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showWarning(context, 'Verification failed. Please try again.');
      }
    } finally {
      _setLoading(false);
    }

    return false;
  }

  /// Enable "Generate TOTP" flow - switches to OTP mode with topflow flag
  void enableGenerateTotpFlow() {
    _topflow = true;
    _isTotp = false; // Switch to OTP mode for verification
    otpController.clear();
    _otpError = null; // Clear any existing error
    notifyListeners();
  }

  /// Clear password change requirement flags
  void clearPasswordChangeFlags() {
    _requiresPasswordChange = false;
    _isPasswordExpiredFlag = false;
    notifyListeners();
  }

  /// Back to login from TOTP setup screen
  void backToLogin() {
    _showTotpSetup = false;
    _topflow = false;
    _isTotp = true;
    _totpData = null;
    _apiSession = null;
    otpController.clear();
    _otpError = null; // Clear any existing error
    stopTotpTimer();
    notifyListeners();
  }

  /// Fetch TOTP data (Get or Generate)
  Future<void> fetchTotpData(BuildContext context) async {
    if (_apiSession == null) return;

    try {
      _totpData = await WebAuthApi.getOrGenerateTotp(
        clientId: _mobileOtp?.clientid ?? loginController.text.trim().toUpperCase(),
        apiSession: _apiSession!,
        context: context,
      );

      if (_totpData?.isValid == true) {
        _startTotpTimer();
      }

      notifyListeners();
    } catch (e) {
    }
  }

  /// Generate a brand-new TOTP secret key (triggered from "Generate New Key" button
  /// shown when no existing key is set up for the user).
  Future<void> generateNewTotpKey(BuildContext context) async {
    if (_apiSession == null) return;

    _setLoading(true);
    try {
      final newData = await WebAuthApi.generateTotpSecretKey(
        clientId: _mobileOtp?.clientid ?? loginController.text.trim().toUpperCase(),
        apiSession: _apiSession!,
        context: context,
      );

      if (newData != null) {
        _totpData = newData;
        if (_totpData?.isValid == true) {
          _startTotpTimer();
        }
      }
      notifyListeners();
    } catch (e) {
    } finally {
      _setLoading(false);
    }
  }

  /// Generate TOTP code from secret
  void _generateTotpCode() {
    if (_totpData?.pwd != null) {
      _currentTotp = TotpUtils.generateTotp(_totpData!.pwd!);
      _totpTimer = TotpUtils.getRemainingSeconds();
      notifyListeners();
    }
  }

  /// Start TOTP refresh timer
  void _startTotpTimer() {
    _totpRefreshTimer?.cancel();
    _generateTotpCode();
    
    _totpRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _totpTimer = TotpUtils.getRemainingSeconds();
      
      // Regenerate TOTP when timer resets
      if (_totpTimer == 30) {
        _generateTotpCode();
      }
      
      notifyListeners();
    });
  }

  /// Stop TOTP refresh timer
  void stopTotpTimer() {
    _totpRefreshTimer?.cancel();
    _totpRefreshTimer = null;
  }

  // --- QR Login Logic ---
  
  Timer? _qrPollTimer;
  String? _qrLoginImageUrl;
  String? get qrLoginImageUrl => _qrLoginImageUrl;
  
  /// Start QR Login Process
  void startQrLogin(BuildContext context) {
    // Stop any existing poll
    stopQrLogin();

    // Invalidate any previously stored UUID before generating a new one.
    // Tells the backend to mark the old QR session as abandoned so a
    // mobile-side confirmation of it gets rejected — closes the race
    // where mobile holds an unconfirmed scan and the user re-enters or
    // refreshes the QR screen on web.
    final oldUuid = pref.pendingQrUuid;
    if (oldUuid != null && oldUuid.isNotEmpty) {
      // Fire-and-forget — don't block the new QR fetch.
      WebAuthApi.invalidateQrSession(uniqueId: oldUuid);
    }

    // Fresh UUID per entry so each visit shows a newly generated QR and the
    // poll endpoint tracks a distinct session (no stale state across re-entries).
    _deviceUuid = uuid.v4();

    // Persist the new UUID so subsequent triggers (in-app reload, browser
    // refresh via beforeunload, crash recovery on next app boot) can find
    // it and invalidate it server-side.
    pref.setPendingQrUuid(_deviceUuid);

    // Construct QR Image URL
    // URL: {BASE_URL}/get_login_qr?unique_id={UUID}&source=WEB
    // Note: Assuming BASE_URL is https://ws.mynt.in/login based on WebAuthApi
    _qrLoginImageUrl = "https://ws.mynt.in/login/get_login_qr?unique_id=$_deviceUuid&source=$_source";
    notifyListeners();
    
    // Start polling after 2 seconds
    _qrPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _pollQrStatus(context, onLoginSuccess: () {
        // Navigate to Home screen using GoRouter for web
        if (context.mounted) {
          context.go(WebRoutes.home);
        }
      });
    });
  }

  /// Defensive cleanup for stale QR sessions left over from previous app
  /// runs — e.g., browser crash, OS kill, or any path where the normal
  /// beforeunload-based invalidate didn't fire. Called once when the
  /// login screen mounts; safe to invoke even when no stale UUID exists.
  void cleanupStaleQrSession() {
    final staleUuid = pref.pendingQrUuid;
    if (staleUuid != null && staleUuid.isNotEmpty) {
      WebAuthApi.invalidateQrSession(uniqueId: staleUuid);
      // Note: do NOT clear localStorage here. If user immediately enters
      // QR again, startQrLogin will harmlessly attempt to invalidate the
      // same UUID (idempotent on backend) and then overwrite with a new
      // one. The clear happens only on browser refresh via beforeunload.
    }
  }
  
  /// Stop QR Login Process
  void stopQrLogin() {
    _qrPollTimer?.cancel();
    _qrPollTimer = null;
    _qrLoginImageUrl = null;
    // Clear mobileOtp to prevent stale data from triggering navigation
    // Only clear if we're just cancelling (not after successful login)
    // _mobileOtp = null; // Don't clear here - it breaks successful QR login
    notifyListeners();
  }

  /// Cancel QR Login and clear all related state (called when user clicks "back to login")
  void cancelQrLogin() {
    _qrPollTimer?.cancel();
    _qrPollTimer = null;
    _qrLoginImageUrl = null;
    _mobileOtp = null; // Clear to prevent stale login data
    notifyListeners();
  }
  
  /// Poll QR Status
  Future<void> _pollQrStatus(BuildContext context, {VoidCallback? onLoginSuccess}) async {
    try {
      final res = await WebAuthApi.qrLogin(
        uniqueId: _deviceUuid,
        source: _source,
        imei: _deviceUuid,
        context: context,
      );
      
      if (res?.stat == 'Ok' && res?.apitoken != null) {
        // Success! Stop polling
        stopQrLogin();
        
        // Save session data (similar to _handleOtpSuccess)
        _mobileOtp = res; // Reusing model as it has same structure
        await _handleOtpSuccess(context);
        
        // Notify listener that login succeeded (UI should watch for this)
        notifyListeners();
        
        // Trigger navigation callback if provided
        if (onLoginSuccess != null) {
          onLoginSuccess();
        }
      }
    } catch (e) {
    }
  }

  /// The OAuth app key when the login is happening inside the OAuth flow — i.e.
  /// the current URL carries a client_id. Null for normal logins.
  String? get _oauthClientId {
    final id = (Uri.base.queryParameters['client_id'] ?? '').trim();
    return id.isEmpty ? null : id;
  }

  /// OAuth-flow login success: store the returned session under the OAuth-only
  /// keys (leaving the main web session — clientId/clientSession — untouched)
  /// and route back to the authorize screen. No full app load: we're authorising
  /// a partner, not entering the trading app, so the main session must survive.
  Future<void> _handleOAuthLoginSuccess(
      BuildContext context, String token) async {
    final clientId = _oauthClientId;
    if (clientId == null) return;
    await pref.setOauthSession(token);
    if (context.mounted) {
      context.go(
        '${WebRoutes.oauthAuthorize}?client_id=${Uri.encodeQueryComponent(clientId)}',
      );
    }
  }

  /// Handle successful login (direct login without OTP)
  Future<void> _handleLoginSuccess(BuildContext context) async {
    if (_mobileLogin == null) return;

    // OAuth flow: keep this session out of the main web session and bounce back
    // to the authorize screen instead of loading the trading app.
    if (_oauthClientId != null) {
      await _handleOAuthLoginSuccess(context, _mobileLogin!.apitoken ?? '');
      return;
    }

    await pref.setClientId(_mobileLogin!.clientid ?? '');
    await pref.setClientMob(_mobileLogin!.mobile ?? '');
    await pref.setClientSession(_mobileLogin!.apitoken ?? '');
    await pref.setClientName(_mobileLogin!.name ?? '');
    await pref.setApiToken(_mobileLogin!.token ?? '');
    await pref.setLogout(false);
    await pref.setMobileLogin(true);

    // Call initialLoadMethods FIRST (it will handle navigation internally)
    // This ensures all data loading uses the correct context flow
    if (context.mounted) {
      await ref.read(authProvider).initialLoadMethods(context, "");
    }
  }

  /// Handle successful OTP verification
  Future<void> _handleOtpSuccess(BuildContext context) async {
    if (_mobileOtp == null) return;

    // OAuth flow: store under the OAuth-only session keys and return to the
    // authorize screen, leaving the main web session untouched.
    if (_oauthClientId != null) {
      await _handleOAuthLoginSuccess(context, _mobileOtp!.apitoken ?? '');
      return;
    }

    await pref.setClientId(_mobileOtp!.clientid ?? '');
    await pref.setClientMob(_mobileOtp!.mobile ?? '');
    await pref.setClientSession(_mobileOtp!.apitoken ?? '');
    await pref.setClientName(_mobileOtp!.name ?? '');
    await pref.setApiToken(_mobileOtp!.token ?? '');
    await pref.setLogout(false);
    await pref.setMobileLogin(true);

    // Call initialLoadMethods FIRST (it will handle navigation internally)
    // This ensures all data loading uses the correct context flow
    if (context.mounted) {
      await ref.read(authProvider).initialLoadMethods(context, "");
    }
  }

  /// QR Login
  Future<MobileOtpModel?> qrLogin(BuildContext context) async {
    _deviceUuid = uuid.v4();
    
    return await WebAuthApi.qrLogin(
      uniqueId: _deviceUuid,
      source: _source,
      imei: _deviceUuid,
      context: context,
    );
  }

  /// Forgot Password
  Future<bool> forgotPassword(BuildContext context) async {
    if (loginController.text.trim().isEmpty) {
      _loginError = "Please enter your mobile or client ID";
      notifyListeners();
      return false;
    }

    _setLoading(true);

    try {
      final result = await WebAuthApi.forgotPassword(
        mobileOrClientId: loginController.text.trim().toUpperCase(),
        context: context,
      );

      if (result != null && result['stat'] == 'Ok') {
        if (context.mounted) {
          ResponsiveSnackBar.showSuccess(context, 'New password sent to your registered email and mobile');
        }
        _setLoading(false);
        return true;
      } else if (result != null && result['emsg'] != null && context.mounted) {
        ResponsiveSnackBar.showWarning(context, result['emsg'].toString());
      }
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showWarning(context, 'Failed to process request');
      }
    } finally {
      _setLoading(false);
    }

    return false;
  }

  /// Get formatted TOTP for display
  String get formattedTotp => TotpUtils.formatTotp(_currentTotp);

  /// Get TOTP QR code URI
  String get totpQrUri => _totpData?.getQrUri() ?? '';

  /// Check if TOTP is set up
  bool get hasTotpSetup => _totpData?.isValid == true;

  /// Enable TOTP setup mode
  void enableTotpSetup() {
    _showTotpSetup = true;
    notifyListeners();
  }

  /// Disable TOTP setup mode  
  void disableTotpSetup() {
    _showTotpSetup = false;
    stopTotpTimer();
    notifyListeners();
  }

  /// Reset provider state
  void reset() {
    stopTotpTimer();
    clearFields();
    clearErrors();
    _mobileLogin = null;
    _mobileOtp = null;
    _totpData = null;
    _currentTotp = '';
    _totpTimer = 30;
    _apiSession = null;
    _showTotpSetup = false;
    _requiresPasswordChange = false;
    _isPasswordExpiredFlag = false;
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTotpTimer();
    loginController.dispose();
    passwordController.dispose();
    otpController.dispose();
    super.dispose();
  }
}

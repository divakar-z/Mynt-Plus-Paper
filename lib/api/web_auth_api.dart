import 'dart:developer';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/auth_model/mobile_login_model.dart';
import '../models/auth_model/mobile_otp_model.dart';
import '../utils/responsive_snackbar.dart';

/// Web-specific authentication API service
/// This service handles the web login flow with source="WEB" 
/// and includes TOTP generation functionality
class WebAuthApi {
  // Base URL for login APIs
   static const String _loginBaseUrl = 'https://ws.mynt.in/login';
 static const String _loginBaseUrlWH = 'https://ws.mynt.in/wh';

  // Go Mynt URL for TOTP APIs  
  static const String _goMyntUrl = 'https://go.mynt.in/NorenWClientWeb';
  
  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
  };

  /// Determine if input is mobile or client ID
  static String _getInputType(String input) {
    return RegExp(r'^[0-9]+$').hasMatch(input) ? 'mobile' : 'clientid';
  }

  /// Web Login API - Validates credentials and triggers OTP/TOTP flow
  /// Uses source="WEB" instead of "MOB"
  static Future<MobileLoginModel?> webMobileLogin({
    required String uniqueId,
    required String mobileOrClientId,
    required String password,
    required String imei,
    required bool totp,
    required BuildContext context,
  }) async {
    try {
      final uri = Uri.parse('$_loginBaseUrl/MobileLogin');
      
      final inputType = _getInputType(mobileOrClientId);
      
      // OAuth flow: the login URL carries the partner app key as ?client_id=...
      // In that case the login is marked device=OAUTH and the app key is sent as
      // `authid`, so the backend ties this login to that app key. Normal logins
      // keep device=WEB and omit authid.
      final oauthClientId = (Uri.base.queryParameters['client_id'] ?? '').trim();
      final isOAuth = oauthClientId.isNotEmpty;

      Map<String, dynamic> data = {
        'device': isOAuth ? 'OAUTH' : 'WEB',
        inputType: mobileOrClientId.toUpperCase(),
        'password': password,
      };
      if (isOAuth) {
        data['authid'] = oauthClientId;
      }

      final res = await http.post(
        uri,
        headers: _defaultHeaders,
        body: jsonEncode(data),
      );


      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final model = MobileLoginModel.fromJson(json as Map<String, dynamic>);
        // Show error if stat is not Ok - check both emsg and msg fields
        if (model.stat != 'Ok') {
          final rawError = model.emsg ?? model.msg;
          if (rawError != null && rawError.isNotEmpty) {
            // Override the verbose API wording ("Invalid Input : Wrong
            // Password") with the standardized auth-module phrasing
            // "Wrong Password, Please Try again" — matches the OTP/TOTP
            // toast convention. Any other API error passes through as-is.
            final toastMsg = rawError.toLowerCase().contains('wrong password')
                ? 'Wrong Password, Please Try again'
                : rawError;
            ResponsiveSnackBar.showError(context, toastMsg);
          }
        }
        return model;
      } else {
        ResponsiveSnackBar.showError(context, "Server error. Please try again later.");
      }
    } catch (e) {
      ResponsiveSnackBar.showError(context, "An error occurred. Please try again.");
    }
    return null;
  }

  /// Send OTP API - Separate endpoint for sending OTP
  /// This is called when user switches from TOTP to OTP mode
  static Future<Map<String, dynamic>?> sendOtp({
    required String mobileOrClientId,
    required String source,
    required BuildContext context,
    bool isTotp = false,
  }) async {
    try {
      final uri = Uri.parse('$_loginBaseUrl/otp_send');

      final inputType = _getInputType(mobileOrClientId);

      Map<String, dynamic> data = {
        'device': source,
        inputType: mobileOrClientId.toUpperCase(),
        // Flags the OTP request as part of the TOTP-setup flow so the backend
        // can handle it accordingly. Only sent during TOTP setup; regular
        // login OTP requests keep the original payload.
        if (isTotp) 'is_totp': true,
      };

      
      final res = await http.post(
        uri, 
        headers: _defaultHeaders, 
        body: jsonEncode(data),
      );

      
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      ResponsiveSnackBar.showError(context, "Failed to send OTP. Please try again.");
    }
    return null;
  }

  /// Verify OTP API - Verify OTP/TOTP and complete login
  /// Uses source="WEB" for web platform
  static Future<MobileOtpModel?> webVerifyOtp({
    required String uniqueId,
    required String mobileOrClientId,
    required String otp,
    required String imei,
    required String source,
    required Map<String, dynamic>? logData,
    required BuildContext context,
  }) async {
    try {
      final uri = Uri.parse('$_loginBaseUrl/otp_verify');
      
      final inputType = _getInputType(mobileOrClientId);
      
      // OAuth flow: the login URL carries the partner app key as ?client_id=...
      // In that case mark source=OAUTH and forward the app key as `authid`, same
      // as MobileLogin. Normal OTP verifies keep the passed-in source, no authid.
      final oauthClientId = (Uri.base.queryParameters['client_id'] ?? '').trim();
      final isOAuth = oauthClientId.isNotEmpty;

      Map<String, dynamic> data = {
        'source': isOAuth ? 'OAUTH' : source,
        'otp': otp,
        inputType: mobileOrClientId.toUpperCase(),
      };
      if (isOAuth) {
        data['authid'] = oauthClientId;
      }

      // Add log data if provided
      if (logData != null) {
        data['log'] = logData;
      }

      
      final res = await http.post(
        uri, 
        headers: _defaultHeaders, 
        body: jsonEncode(data),
      );


      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final model = MobileOtpModel.fromJson(json as Map<String, dynamic>);
        // Don't show error toast here - let the provider handle it
        // This allows proper TOTP vs OTP distinction in error messages
        return model;
      } else {
        ResponsiveSnackBar.showError(context, "Server error. Please try again later.");
      }
    } catch (e) {
      ResponsiveSnackBar.showError(context, "OTP verification failed. Please try again.");
    }
    return null;
  }

  /// Get TOTP Secret Key - Retrieves existing TOTP secret if available
  static Future<TotpData?> getTotpSecretKey({
    required String clientId,
    required String apiSession,
    required BuildContext context,
  }) async {
    try {
      final uri = Uri.parse('$_goMyntUrl/GetSecretKey');
      
      final body = 'jData={"uid":"$clientId"}&jKey=$apiSession';

      
      final res = await http.post(
        uri, 
        headers: {'Content-Type': 'text/plain'}, 
        body: body,
      );

      
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        // Return TotpData even if pwd is empty so caller can detect
        // the "no key generated yet" state and prompt the user to create one.
        if (json is Map<String, dynamic>) {
          return TotpData.fromJson(json);
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch TOTP. Please try again.");
    }
    return null;
  }

  /// Generate TOTP Secret Key - Creates new TOTP secret
  static Future<TotpData?> generateTotpSecretKey({
    required String clientId,
    required String apiSession,
    required BuildContext context,
  }) async {
    try {
      final uri = Uri.parse('$_goMyntUrl/GenSecretKey');
      
      final body = 'jData={"uid":"$clientId"}&jKey=$apiSession';

      
      final res = await http.post(
        uri, 
        headers: {'Content-Type': 'text/plain'}, 
        body: body,
      );

      
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return TotpData.fromJson(json as Map<String, dynamic>);
      }
    } catch (e) {
      ResponsiveSnackBar.showError(context, "Failed to generate TOTP. Please try again.");
    }
    return null;
  }

  /// Fetch existing TOTP only
  /// Returns TotpData (possibly with empty pwd) so UI can show a
  /// "Generate New Key" button when no key exists yet.
  static Future<TotpData?> getOrGenerateTotp({
    required String clientId,
    required String apiSession,
    required BuildContext context,
  }) async {
    return getTotpSecretKey(
      clientId: clientId,
      apiSession: apiSession,
      context: context,
    );
  }

  /// Invalidate QR Session API
  ///
  /// Tells the backend to mark the given QR session UUID as abandoned so
  /// that a subsequent mobile-side confirmation for the same UUID is
  /// rejected. Called whenever the user moves away from an active QR
  /// session — clicks Scan QR again (new UUID), clicks Reload icon, or
  /// the app boots and finds a stale UUID left over from a previous
  /// session (e.g., browser crash where beforeunload didn't fire).
  ///
  /// Best-effort: failures are swallowed silently because the next entry
  /// (or backend's own session timeout) will eventually clean up.
  static Future<void> invalidateQrSession({
    required String uniqueId,
  }) async {
    try {
      // Backend expects only { unique_id } in the body.
      // Response shape: { "detail": "QR invalid" } on success.
      // Endpoint URL is repointed to the local dev server during integration
      // testing — update to prod URL before release.
      final uri = Uri.parse('https://ws.mynt.in/login/QRInvalidate');

      final data = {
        'unique_id': uniqueId,
      };

      await http.post(
        uri,
        headers: _defaultHeaders,
        body: jsonEncode(data),
      );
    } catch (e) {
      // Swallow — invalidate is best-effort, retried on next entry.
    }
  }

  /// QR Login API - For QR code based login
  static Future<MobileOtpModel?> qrLogin({
    required String uniqueId,
    required String source,
    required String imei,
    required BuildContext context,
  }) async {
    try {
      final uri = Uri.parse('https://ws.mynt.in/login/QRlogin');
      
      Map<String, dynamic> data = {
        'unique_id': uniqueId,
        'source': source,
        'imei': imei,
      };

      
      final res = await http.post(
        uri, 
        headers: _defaultHeaders, 
        body: jsonEncode(data),
      );

      
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return MobileOtpModel.fromJson(json as Map<String, dynamic>);
      }
    } catch (e) {
    }
    return null;
  }

  /// Forgot Password API
  static Future<Map<String, dynamic>?> forgotPassword({
    required String mobileOrClientId,
    required BuildContext context,
  }) async {
    try {
      final uri = Uri.parse('$_loginBaseUrl/ForgetPassword');
      
      final inputType = _getInputType(mobileOrClientId);
      
      Map<String, dynamic> data = {
        'field': inputType,
        'value': mobileOrClientId.toUpperCase(),
      };

      
      final res = await http.post(
        uri, 
        headers: _defaultHeaders, 
        body: jsonEncode(data),
      );

      
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      ResponsiveSnackBar.showError(context, "Failed to process request. Please try again.");
    }
    return null;
  }

  /// Forgot Password — Send OTP
  ///
  /// First half of the new OTP-gated forgot-password flow. Backend sends a
  /// 4-digit OTP to the user's registered mobile/email for the given
  /// identifier. Frontend should then show the OTP-entry screen and call
  /// [forgetPasswordOtpVerify] once the user types the OTP.
  ///
  /// Known responses:
  /// - { "msg": "otp sended" } — success
  /// - { "msg": "No data found" } — identifier doesn't exist
  /// - { "emsg": "Your mobile registered in multiple accounts, Please login
  ///     with client ID", "stat": "Not_Ok" } — ambiguous mobile
  /// - { "emsg": "Invalid field", "stat": "Not_Ok" } — bad field name
  static Future<Map<String, dynamic>?> forgetPasswordOtpSend({
    required String mobileOrClientId,
  }) async {
    try {
      final uri = Uri.parse('$_loginBaseUrl/ForgetPasswordOtpSend');
      final data = {
        'field': _getInputType(mobileOrClientId),
        'value': mobileOrClientId.toUpperCase(),
      };
      final res = await http.post(
        uri,
        headers: _defaultHeaders,
        body: jsonEncode(data),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Caller handles user-facing error toast.
    }
    return null;
  }

  /// Forgot Password — Verify OTP
  ///
  /// Second half of the new OTP-gated forgot-password flow. Backend
  /// validates the OTP and, on success, internally runs the old
  /// ForgetPassword behavior (generates and sends the temp password to the
  /// user's registered mobile/email). Frontend then jumps straight to the
  /// Change Password screen — no separate ForgetPassword call needed.
  ///
  /// Known error responses:
  /// - { "emsg": "clientid not found" } — identifier mismatch
  /// - { "emsg": "Invalid field", "stat": "Not_Ok" }
  /// - { "emsg": "OTP expired, Please request a new one", "stat": "Not_Ok" }
  /// - { "emsg": "OTP already used", "stat": "Not_Ok" }
  /// - { "emsg": "OTP not valid" }
  static Future<Map<String, dynamic>?> forgetPasswordOtpVerify({
    required String mobileOrClientId,
    required String otp,
  }) async {
    try {
      final uri = Uri.parse('$_loginBaseUrl/ForgetPasswordOtpVerify');
      final data = {
        'field': _getInputType(mobileOrClientId),
        'value': mobileOrClientId.toUpperCase(),
        'otp': otp,
      };
      final res = await http.post(
        uri,
        headers: _defaultHeaders,
        body: jsonEncode(data),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Caller handles user-facing error toast.
    }
    return null;
  }
  /// Create Webhook - Registers a webhook for the given symbol
  static Future<Map<String, dynamic>?> createWebhook({
    required String clientId,
    required String token,
    required String name,
    required BuildContext context,
  }) async {
    try {
      final uri = Uri.parse('$_loginBaseUrlWH/webhook/create');

      final data = {
        'clientid': clientId,
        'token': token,
        'name': name,
      };


      final res = await http.post(
        uri,
        headers: _defaultHeaders,
        body: jsonEncode(data),
      );


      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        ResponsiveSnackBar.showError(context, "Failed to create webhook. Please try again.");
      }
    } catch (e) {
      ResponsiveSnackBar.showError(context, "An error occurred while creating webhook.");
    }
    return null;
  }

  /// List Webhooks - Fetches all webhooks for the client
  static Future<Map<String, dynamic>?> listWebhooks({
    required String clientId,
    required String token,
  }) async {
    try {
      final uri = Uri.parse('$_loginBaseUrlWH/webhook/list');

      final data = {
        'clientid': clientId,
        'token': token,
      };


      final res = await http.post(
        uri,
        headers: _defaultHeaders,
        body: jsonEncode(data),
      );


      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
    }
    return null;
  }

  /// Enable Webhook
  static Future<Map<String, dynamic>?> enableWebhook({
    required int webhookId,
    required String clientId,
    required String token,
  }) async {
    try {
      final uri = Uri.parse('$_loginBaseUrlWH/webhook/enable/$webhookId');

      final data = {
        'clientid': clientId,
        'token': token,
      };

      final res = await http.post(
        uri,
        headers: _defaultHeaders,
        body: jsonEncode(data),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
    }
    return null;
  }

  /// Disable Webhook
  static Future<Map<String, dynamic>?> disableWebhook({
    required int webhookId,
    required String clientId,
    required String token,
  }) async {
    try {
      final uri = Uri.parse('$_loginBaseUrlWH/webhook/disable/$webhookId');

      final data = {
        'clientid': clientId,
        'token': token,
      };

      final res = await http.post(
        uri,
        headers: _defaultHeaders,
        body: jsonEncode(data),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
    }
    return null;
  }

  /// Webhook Logs - Fetches webhook execution logs for a date range
  static Future<Map<String, dynamic>?> webhookLogs({
    required String clientId,
    required String token,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final uri = Uri.parse('$_loginBaseUrlWH/webhook/logs');

      final data = {
        'clientid': clientId,
        'token': token,
        'from_date': fromDate,
        'to_date': toDate,
      };

      final res = await http.post(
        uri,
        headers: _defaultHeaders,
        body: jsonEncode(data),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
    }
    return null;
  }

  /// Validate Session - Check if existing session is valid
  static Future<Map<String, dynamic>?> validateSession({
    required String clientId,
    required String apiSession,
  }) async {
    try {
      final uri = Uri.parse('$_goMyntUrl/UserDetails');
      
      final body = 'jData={"uid":"$clientId"}&jKey=$apiSession';

      final res = await http.post(
        uri, 
        headers: {'Content-Type': 'text/plain'}, 
        body: body,
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
    }
    return null;
  }
}

/// Model for TOTP data
class TotpData {
  final String? uid;
  final String? pwd;
  final String? stat;
  final String? emsg;

  TotpData({
    this.uid,
    this.pwd,
    this.stat,
    this.emsg,
  });

  factory TotpData.fromJson(Map<String, dynamic> json) {
    return TotpData(
      uid: json['uid'] as String?,
      pwd: json['pwd'] as String?,
      stat: json['stat'] as String?,
      emsg: json['emsg'] as String?,
    );
  }

  /// Generate QR code URI for authenticator apps
  String getQrUri() {
    if (uid != null && pwd != null) {
      return 'otpauth://totp/MYNT:$uid?secret=$pwd&issuer=MYNT WEB';
    }
    return '';
  }

  bool get isValid => uid != null && uid!.isNotEmpty && pwd != ""  && pwd!.isNotEmpty && pwd != null;
}

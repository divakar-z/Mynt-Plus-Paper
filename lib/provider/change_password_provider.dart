
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../api/core/api_export.dart';
import '../api/web_auth_api.dart';
import '../locator/constant.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../models/auth_model/forgot_pass_model.dart';
import '../models/auth_model/mynt_changepass_model.dart';
import '../routes/route_names.dart';
import '../utils/responsive_snackbar.dart';
import 'auth_provider.dart';
import 'core/default_change_notifier.dart';
import 'index_list_provider.dart';

final changePasswordProvider =
    ChangeNotifierProvider((ref) => ChangePasswordProvider(ref));

class ChangePasswordProvider extends DefaultChangeNotifier {
  final Ref ref;
  final api = locator<ApiExporter>();
  final Preferences pref = locator<Preferences>();

  //  Text field controller for Change password

  final TextEditingController oldPassword = TextEditingController();
  final TextEditingController newPassword = TextEditingController();

  // Repeat of newPassword. Purely client-side — the change-password API only
  // takes uid/oldpwd/pwd, so this never leaves the app. Added 18 Sep 2026 on
  // client feedback that two boxes looked like new + retype but weren't.
  final TextEditingController confirmPassword = TextEditingController();
  final TextEditingController forGetloginMethCtrl = TextEditingController();

  // 4-digit OTP entered by user during the OTP-gated forgot-password flow.
  // Backend sends the OTP after a successful /ForgetPasswordOtpSend call.
  final TextEditingController forgotOtpController = TextEditingController();

  final TextEditingController userIdController = TextEditingController();

  bool get isMobileForgetpass => _isMobileForgetpass;
  bool _isMobileForgetpass = false;

  bool _isDisableforgetbtn = true;
  bool get isDisableforgetbtn => _isDisableforgetbtn;
  bool _hideoldpassword = true;
  bool _hidenewpassword = true;
  bool _hideconfirmpassword = true;
  bool get hideoldpassword => _hideoldpassword;
  bool get hidenewpassword => _hidenewpassword;
  bool get hideconfirmpassword => _hideconfirmpassword;

  bool _isDisableChangepassbtn = true;
  bool get isDisableChangepassbtn => _isDisableChangepassbtn;

  // True when New Password has text that breaks the rules, as opposed to
  // being empty. The empty case is an ordinary "please fill this in" message
  // and shows inline in red like every other field; only a rules failure goes
  // into the bubble.
  bool newPasswordRulesUnmet = false;

  // The unmet requirements, one per entry, in the order they are checked.
  // The validation bubble lists these as bullets — a comma-joined sentence
  // was hard to read (client review 18 Sep 2026). newPasswordError still
  // carries the joined version for surfaces that show a plain message.
  List<String> newPasswordMissing = [];

  String? userIdChangepassError,
      oldPasswordError,
      newPasswordError,
      confirmPasswordError,
      forgetpassError,
      forgotOtpError;

  ForgetPasswordModel? _forgetPasswordModel;
  ForgetPasswordModel? get changePass => _forgetPasswordModel;
  MyntChangePasswordModel? _changepasswordmodel;
  MyntChangePasswordModel? get changepasswordmodel => _changepasswordmodel;

// Masked mobile / email the generated password was sent to.

  String? maskedMobile;
  String? maskedEmail;


  static String? maskMobile(dynamic raw) {
    final digits = (raw?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.length <= 4) return 'X' * digits.length;
    if (digits.length <= 6) return 'XX${digits.substring(digits.length - 4)}';
    return '${digits.substring(0, 2)}'
        '${'X' * (digits.length - 6)}'
        '${digits.substring(digits.length - 4)}';
  }


  static String? maskEmail(dynamic raw) {
    final email = (raw?.toString() ?? '').trim();
    final at = email.lastIndexOf('@');
    if (at <= 0 || at == email.length - 1) return null;
    const stars = '***********';
    final local = email.substring(0, at);
    final domain = email.substring(at);
    if (local.length <= 2) return '$stars$domain';
    if (local.length <= 4) return '${local.substring(0, 1)}$stars$domain';
    return '${local.substring(0, 2)}$stars'
        '${local.substring(local.length - 2)}$domain';
  }

// Clear all text field values form change password screen
  void clearTextField() {
    _isDisableforgetbtn = true;
    oldPassword.clear();
    newPassword.clear();
    confirmPassword.clear();
    forGetloginMethCtrl.clear();
    forgotOtpController.clear();
    maskedMobile = null;
    maskedEmail = null;
    notifyListeners();
  }

// Clear change pass validation error
  void clearError() {
    userIdChangepassError = null;
    oldPasswordError = null;
    newPasswordError = null;
    newPasswordRulesUnmet = false;
    newPasswordMissing = [];
    confirmPasswordError = null;
    forgetpassError = null;
    forgotOtpError = null;
    notifyListeners();
  }

  changePassMethod() {
    _isDisableChangepassbtn = true;
    clearError();
    clearTextField();
    notifyListeners();
  }

  forgetMethod() {
    _isMobileForgetpass = !_isMobileForgetpass;
    _isDisableforgetbtn = true;

    clearError();
    clearTextField();
    notifyListeners();
  }

// Validating Forgot password

  bool validateForgetpassWord() {
    clearError();
    if (forGetloginMethCtrl.text.trim().isEmpty) {
      forgetpassError = "Your mobile / client id is required";
    }
    return forgetpassError == null;
  }

// If Forgot pass validation is successful, activate the  button.

  activateFrogetbtn() {
    if (validateForgetpassWord()) {
      _isDisableforgetbtn = false;
    } else {
      _isDisableforgetbtn = true;
    }
    notifyListeners();
  }

// Call this method while clicking if the Forgot pass validation process is successful.
  submitForgetPassword(BuildContext context) {
    if (validateForgetpassWord()) {
      fetchForgetPassword(
          // _isMobileForgetpass ? "clientid" : "mobile",
          forGetloginMethCtrl.text,
          forGetloginMethCtrl.text.toUpperCase(),
          context);
    }
  }

// If Change pass validation is successful, activate the button.

  activateChangePass() {
    if ((newPasswordError == "" || newPasswordError == null) &&
        (oldPasswordError == "" || oldPasswordError == null) &&
        (confirmPasswordError == "" || confirmPasswordError == null)) {
      _isDisableChangepassbtn = false;
    } else {
      _isDisableChangepassbtn = true;
    }

    notifyListeners();
  }

// Show / Hide password text values

  hiddeoldpasswords() {
    _hideoldpassword = !_hideoldpassword;
    notifyListeners();
  }

  hiddenewpasswords() {
    _hidenewpassword = !_hidenewpassword;
    notifyListeners();
  }

  hiddeconfirmpasswords() {
    _hideconfirmpassword = !_hideconfirmpassword;
    notifyListeners();
  }

// Validating Change Pass
  // bool validateChangePassword() {
  //   // clearError();
  //   // if (userIdController.text.trim().isEmpty) {
  //   //   userIdChangepassError = "Please enter username";
  //   // }

  //   if (oldPassword.text.trim().isEmpty) {
  //     oldPasswordError = "Please enter the Old Password";
  //   }
  //   if (newPassword.text.trim().isEmpty) {
  //     newPasswordError = "Please enter the New Password";
  //   } else if (!RegExp(r'^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[#$-*@]).{7,}$')
  //       .hasMatch(newPassword.text)) {
  //     newPasswordError = "Please Enter the Valid Password";
  //   }

  //   notifyListeners();
  //   return userIdChangepassError == null &&
  //       oldPasswordError == null &&
  //       newPasswordError == null;
  // }

  // validateNewPassword() {
  //   if (newPassword.text.trim().isEmpty) {
  //     newPasswordError = "Please enter the New Password";
  //   } else if (!RegExp(r'^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[#$-*@]).{7,}$')
  //       .hasMatch(newPassword.text)) {
  //     newPasswordError = "Password must be at least 8 characters";
  //   } else {
  //     newPasswordError = "";
  //   }
  //   notifyListeners();
  // }

  void validateNewPassword() {
    // Remove spaces from password
    if (newPassword.text.contains(' ')) {
      newPassword.text = newPassword.text.replaceAll(' ', '');
    }
    String value = newPassword.text.trim();
    newPasswordError = "";
    newPasswordRulesUnmet = false;
    newPasswordMissing = [];

    if (value.isEmpty) {
      newPasswordError = "Please enter the new password";
    } else {
      List<String> missing = [];

      if (!RegExp(r'[A-Z]').hasMatch(value)) {
        missing.add("an uppercase letter");
      }
      if (!RegExp(r'[a-z]').hasMatch(value)) {
        missing.add("a lowercase letter");
      }
      if (!RegExp(r'[0-9]').hasMatch(value)) {
        missing.add("a number");
      }
      if (!RegExp(r'[#$\-*@]').hasMatch(value)) {
        missing.add("one of these special characters: # \$ - * @");
      }
      if (value.length < 7) {
        missing.add("minimum 7 characters");
      }

      if (missing.isNotEmpty) {
        newPasswordError = "Please enter ${missing.join(', ')}";
        newPasswordMissing = missing;
        newPasswordRulesUnmet = true;
      } else {
        newPasswordError = "";
      }
    }

    notifyListeners();
  }

  // Repeat New Password check. Client-side only, so the message is shown
  // inline in red — never as a toast (toasts are reserved for backend emsg).
  void validateConfirmPassword() {
    // Match validateNewPassword: spaces are stripped, not rejected.
    if (confirmPassword.text.contains(' ')) {
      confirmPassword.text = confirmPassword.text.replaceAll(' ', '');
    }
    final confirmValue = confirmPassword.text.trim();
    final newValue = newPassword.text.trim();

    if (confirmValue.isEmpty) {
      confirmPasswordError = "Please repeat the new password";
    } else if (confirmValue != newValue) {
      confirmPasswordError = "Passwords do not match";
    } else {
      confirmPasswordError = "";
    }
    notifyListeners();
  }

  validateOldPassword({bool isPasswordExpired = true}) {
    // Remove spaces from password
    if (oldPassword.text.contains(' ')) {
      oldPassword.text = oldPassword.text.replaceAll(' ', '');
    }
    if (oldPassword.text.trim().isEmpty) {
      oldPasswordError = isPasswordExpired
          ? "Please enter the Old Password"
          : "Please enter the Generated Password";
    } else {
      oldPasswordError = "";
    }
    notifyListeners();
  }

// Fetching data from the api and stored in a variable
  fetchForgetPassword(String field, String value, BuildContext context) async {
    try {
      toggleLoadingOn(true);
      _forgetPasswordModel = await api.getForgetPassword(field, value, context);

      // Handle null response
      if (_forgetPasswordModel == null) {
        if (context.mounted) {
          ResponsiveSnackBar.showError(context, 'Failed to process request. Please try again.');
        }
        return;
      }

      if (_forgetPasswordModel!.stat == "Ok") {
        ConstantName.sessCheck = true;
        // Retired 18 Sep 2026 (client feedback): the "sent to your mobile
        // and email" message is now static text above the Generated Password
        // field on the Change Your Password screen, not a 4s toast.
        // if (context.mounted) {
        //   ResponsiveSnackBar.showSuccess(
        //       context, 'Generated Password has been sent to Your Mobile Number and Email');
        // }

        userIdController.text = '${_forgetPasswordModel!.clientid}';

        Future.delayed(const Duration(milliseconds: 200), () {
          forgetMethod();
          clearError();
          if (context.mounted && !kIsWeb) {
            Navigator.pushNamed(context, Routes.changePass, arguments: "No");
          }
        });
      } else if (_forgetPasswordModel!.stat == "Not_Ok") {
        // Show the specific error message from API
        final errorMsg = _forgetPasswordModel!.emsg ?? 'Invalid Client ID or Mobile number';
        if (context.mounted) {
          ResponsiveSnackBar.showError(context, errorMsg);
        }
      } else if (_forgetPasswordModel!.emsg ==
          "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
      } else {
        // Fallback for any other status
        final errorMsg = _forgetPasswordModel!.emsg ?? 'Something went wrong. Please try again.';
        if (context.mounted) {
          ResponsiveSnackBar.showError(context, errorMsg);
        }
      }

      notifyListeners();
    } catch (e) {
      ref.read(indexListProvider).logError.add({"type": "API", "Error": "$e"});
      if (context.mounted) {
        ResponsiveSnackBar.showError(context, 'An error occurred. Please try again.');
      }
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }
// OTP-gated forgot-password flow — Step 1: send OTP.
//
// Called when the user clicks Reset on the Forgot Password screen with a
// valid identifier. Replaces the legacy [fetchForgetPassword] direct
// password-generation path with a verification-first step: backend now
// only sends the temp password AFTER the OTP is verified
// (see [submitForgetPasswordOtpVerify]).
//
// Returns true on success (UI should switch to OTP screen). On any error
// it shows a toast and returns false.
  Future<bool> submitForgetPasswordOtpSend(BuildContext context) async {
    if (!validateForgetpassWord()) {
      notifyListeners();
      return false;
    }
    try {
      toggleLoadingOn(true);
      final res = await WebAuthApi.forgetPasswordOtpSend(
        mobileOrClientId: forGetloginMethCtrl.text.trim(),
      );

      if (res == null) {
        if (context.mounted) {
          ResponsiveSnackBar.showError(
              context, 'Failed to send OTP. Please try again.');
        }
        return false;
      }

      // Success — backend confirms OTP dispatched.
      if (res['msg'] == 'otp sended') {
        if (context.mounted) {
          ResponsiveSnackBar.showSuccess(
              context, 'OTP sent to your registered mobile/email');
        }
        return true;
      }

      // Known error shapes. "No data found" → unknown identifier;
      // multi-account / Invalid field surface their emsg directly.
      final emsg = res['emsg']?.toString();
      final msg = res['msg']?.toString();
      final errorText = emsg ?? (msg == 'No data found'
          ? 'No account found with this Mobile / Client ID'
          : 'Failed to send OTP. Please try again.');
      if (context.mounted) {
        ResponsiveSnackBar.showError(context, errorText);
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(
            context, 'An error occurred. Please try again.');
      }
      return false;
    } finally {
      toggleLoadingOn(false);
    }
  }

// OTP-gated forgot-password flow — Step 2: verify OTP.
//
// Called when the user submits the 4-digit OTP. On verify success the
// backend has already generated and dispatched the temp password to the
// user's registered mobile/email — frontend just switches to the Change
// Password screen, no separate ForgetPassword call needed.
//
// Returns true on verify success so the screen can advance. Errors are
// surfaced as toasts ("Invalid OTP, Please Try again", etc).
  Future<bool> submitForgetPasswordOtpVerify(BuildContext context) async {
    final otp = forgotOtpController.text.trim();
    if (otp.length != 4) {
      forgotOtpError = 'Please enter the 4-digit OTP';
      notifyListeners();
      return false;
    }
    try {
      toggleLoadingOn(true);
      final res = await WebAuthApi.forgetPasswordOtpVerify(
        mobileOrClientId: forGetloginMethCtrl.text.trim(),
        otp: otp,
      );

      if (res == null) {
        if (context.mounted) {
          ResponsiveSnackBar.showError(
              context, 'OTP verification failed. Please try again.');
        }
        return false;
      }

      final emsg = res['emsg']?.toString();
      // Success path: backend uses absence of emsg / explicit ok stat. Accept
      // either { stat: "Ok" } or no emsg as success signal.
      if (res['stat'] == 'Ok' || (emsg == null || emsg.isEmpty)) {
        ConstantName.sessCheck = true;
        // Pre-populate userIdController so the Change Password screen can
        // submit the password change against this client ID.
        if (res['clientid'] != null) {
          userIdController.text = res['clientid'].toString();
        } else {
          // Fallback — uppercase the input we already have.
          userIdController.text =
              forGetloginMethCtrl.text.trim().toUpperCase();
        }
        // Where the generated password was just sent. Masked immediately —
        // the raw values are never stored or displayed.
        maskedMobile = maskMobile(res['mobile']);
        maskedEmail = maskEmail(res['email']);
        // Retired 18 Sep 2026 (client feedback): the "sent to your mobile
        // and email" message is now static text above the Generated Password
        // field on the Change Your Password screen, not a 4s toast.
        // if (context.mounted) {
        //   ResponsiveSnackBar.showSuccess(context,
        //       'Generated Password has been sent to Your Mobile Number and Email');
        // }
        return true;
      }

      // Known error responses — surface emsg as a toast only, NOT inline.
      // Inline reds are reserved for client-side validation (e.g., OTP
      // length check above). Backend errors duplicate badly when shown
      // both inline and as a toast.
      forgotOtpError = null;
      if (context.mounted) {
        ResponsiveSnackBar.showError(context, emsg);
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(
            context, 'An error occurred. Please try again.');
      }
      return false;
    } finally {
      toggleLoadingOn(false);
    }
  }

// Call this method while clicking if the Change pass validation process is successful.

  submitChangePass(BuildContext context) {
    validateOldPassword();
    validateNewPassword();
    // NOTE: no validateConfirmPassword() here — this method is only reached
    // from the Mobile change_pass screen, which has no Repeat field. The two
    // web surfaces call fetchChangePassword directly and validate there.
    if (oldPasswordError == "" && newPasswordError == "") {
      fetchChangePassword(userIdController.text.toUpperCase(), oldPassword.text,
          newPassword.text, context);
    }
  }

// Fetching data from the api and stored in a variable
  fetchChangePassword(String userId, String oldpassword, String password,
      BuildContext context,
      {bool preventNavigation = false,
      bool isGeneratedPasswordFlow = false}) async {
    try {
      toggleLoadingOn(true);
      _changepasswordmodel =
          await api.getChangePasswordProfile(userId, oldpassword, password);

      // Handle null response
      if (_changepasswordmodel == null) {
        if (context.mounted) {
          ResponsiveSnackBar.showError(context, 'Failed to change password. Please try again.');
        }
        return;
      }

      if (_changepasswordmodel!.stat == "Ok") {
        ConstantName.sessCheck = true;
        ref.read(authProvider).clearTextField();
        if (context.mounted) {
          // Soften the API's "Password Change Success" phrasing to natural
          // English while preserving the trailing dynamic part (e.g.
          // "Your new password will expire in 365 days").
          final rawSuccess = _changepasswordmodel!.dmsg ??
              'Password changed successfully';
          final successMsg = rawSuccess.replaceAll(
            RegExp(r'password change success', caseSensitive: false),
            'Password changed successfully',
          );
          ResponsiveSnackBar.showSuccess(context, successMsg);
        }
        pref.setHideLoginOptBtn(false);
        // ref.read(authProvider).loginMethCtrl.text = pref.clientId!;
        ref.read(authProvider).loginMethCtrl.text = userIdController.text;
        pref.setMobileLogin(false);
        changePassMethod();

        // Only navigate if not prevented (for web inline flow)
        if (!preventNavigation && context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, Routes.loginScreen, (route) => route.isFirst);
        }
      } else if (_changepasswordmodel!.stat == "Not_Ok") {
        final rawMsg = _changepasswordmodel!.emsg
                ?.replaceAll("Error Occurred :", "")
                .trim() ??
            'Failed to change password';
        final rawLower = rawMsg.toLowerCase();
        String toastMsg;
        if (rawLower.contains('previous 3 passwords') ||
            rawLower.contains('last 3 passwords')) {
          // Standardize the password-reuse error wording across all flows
          // (Forgot, Password Expired, Settings) — backend phrasing is
          // verbose and grammatically awkward.
          toastMsg = 'New password cannot match your last 3 passwords';
        } else if (isGeneratedPasswordFlow) {
          // On the Forgot Password flow the field above this toast is
          // labeled "Generated Password", but the backend's error wording
          // is "Invalid Old Password" because it doesn't distinguish flows.
          // Substitute "Old Password" → "Generated Password" so the toast
          // matches the field the user is looking at.
          toastMsg = rawMsg.replaceAll(
            RegExp(r'old password', caseSensitive: false),
            'Generated Password',
          );
        } else {
          toastMsg = rawMsg;
        }
        if (context.mounted) {
          ResponsiveSnackBar.showError(context, toastMsg);
        }
      } else if (_changepasswordmodel!.emsg ==
          "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
      } else {
        // Fallback for any other status
        final errorMsg = _changepasswordmodel!.emsg ?? 'Something went wrong. Please try again.';
        if (context.mounted) {
          ResponsiveSnackBar.showError(context, errorMsg);
        }
      }

      notifyListeners();
    } catch (e) {
      ref.read(indexListProvider).logError.add({"type": "API", "Error": "$e"});
      if (context.mounted) {
        ResponsiveSnackBar.showError(context, 'An error occurred. Please try again.');
      }
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

  ChangePasswordProvider(this.ref);
}

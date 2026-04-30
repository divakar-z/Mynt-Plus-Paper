
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../api/core/api_export.dart';
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
  final TextEditingController forGetloginMethCtrl = TextEditingController();

  final TextEditingController userIdController = TextEditingController();

  bool get isMobileForgetpass => _isMobileForgetpass;
  bool _isMobileForgetpass = false;

  bool _isDisableforgetbtn = true;
  bool get isDisableforgetbtn => _isDisableforgetbtn;
  bool _hideoldpassword = true;
  bool _hidenewpassword = true;
  bool get hideoldpassword => _hideoldpassword;
  bool get hidenewpassword => _hidenewpassword;

  bool _isDisableChangepassbtn = true;
  bool get isDisableChangepassbtn => _isDisableChangepassbtn;

  String? userIdChangepassError,
      oldPasswordError,
      newPasswordError,
      forgetpassError;

  ForgetPasswordModel? _forgetPasswordModel;
  ForgetPasswordModel? get changePass => _forgetPasswordModel;
  MyntChangePasswordModel? _changepasswordmodel;
  MyntChangePasswordModel? get changepasswordmodel => _changepasswordmodel;

// Clear all text field values form change password screen
  void clearTextField() {
    _isDisableforgetbtn = true;
    oldPassword.clear();
    newPassword.clear();
    forGetloginMethCtrl.clear();
    notifyListeners();
  }

// Clear change pass validation error
  void clearError() {
    userIdChangepassError = null;
    oldPasswordError = null;
    newPasswordError = null;
    forgetpassError = null;
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
    if ((newPasswordError == "" || newPasswordError == null) && (oldPasswordError == "" || oldPasswordError == null)) {
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
        missing.add("a special character (#, \$, -, *, @)");
      }
      if (value.length < 7) {
        missing.add("at least 7 characters");
      }

      if (missing.isNotEmpty) {
        newPasswordError = "Please enter ${missing.join(', ')}";
      } else {
        newPasswordError = "";
      }
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
        if (context.mounted) {
          ResponsiveSnackBar.showSuccess(
              context, 'Generated Password has been sent to your registered Mobile Number / Email');
        }

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
// Call this method while clicking if the Change pass validation process is successful.

  submitChangePass(BuildContext context) {
    validateOldPassword();
    validateNewPassword();
    if (oldPasswordError == "" && newPasswordError == "") {
      fetchChangePassword(userIdController.text.toUpperCase(), oldPassword.text,
          newPassword.text, context);
    }
  }

// Fetching data from the api and stored in a variable
  fetchChangePassword(String userId, String oldpassword, String password,
      BuildContext context, {bool preventNavigation = false}) async {
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
          ResponsiveSnackBar.showSuccess(context, '${_changepasswordmodel!.dmsg}');
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
        final errorMsg = _changepasswordmodel!.emsg?.replaceAll("Error Occurred :", "") ?? 'Failed to change password';
        if (context.mounted) {
          ResponsiveSnackBar.showError(context, errorMsg);
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

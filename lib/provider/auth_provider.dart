import 'dart:async';
// Guarded imports: For web, use typed exceptions from `package:http` only
import 'dart:io' show SocketException, HttpException; // Used in non-web builds
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:go_router/go_router.dart';
import '../routes/web_router.dart';
import '../utils/custom_navigator.dart';
// import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
// import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:mynt_plus/provider/banner_provider.dart';
import 'package:mynt_plus/provider/text_nugget_provider.dart';
import 'package:mynt_plus/provider/mf_provider.dart';
import 'package:mynt_plus/provider/option_flash_provider.dart';
import 'package:mynt_plus/provider/profile_all_details_provider.dart';
import 'package:mynt_plus/provider/stocks_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/utils/pip_service.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:uuid/uuid.dart';
import '../api/core/api_core.dart';
import '../api/core/api_export.dart';
import '../locator/constant.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../models/auth_model/change_pass_model.dart';
import '../models/auth_model/forgot_pass_model.dart';
import '../models/auth_model/logged_mobile_model.dart';
import '../models/auth_model/login_otp.dart';
import '../models/auth_model/login_otp_verify.dart';
import '../models/auth_model/logout_model.dart';
import '../models/auth_model/mobile_login_model.dart';
import '../models/auth_model/mobile_otp_model.dart';
import '../models/profile_model/client_detail_model.dart';
import '../res/mynt_web_text_styles.dart';
import '../res/res.dart';
import '../routes/app_routes.dart';
import '../routes/route_names.dart';
import '../screens/Mobile/authentication/login/bottom_otp_screen.dart';
// import '../sharedWidget/functions.dart';
import '../sharedWidget/functions.dart';
import '../sharedWidget/risk_disclosure_bottom_sheet.dart';
import '../sharedWidget/snack_bar.dart';
import '../utils/overlay_manager.dart';
import '../utils/responsive_snackbar.dart';
import 'api_key_provider.dart';
import 'change_password_provider.dart';
import 'core/default_change_notifier.dart';
import 'fund_provider.dart';
import 'index_list_provider.dart';
// import 'iop_provider.dart';
import 'iop_provider.dart';
import 'ledger_provider.dart';
import 'market_watch_provider.dart';
import 'notification_provider.dart';
import 'order_provider.dart';
import 'portfolio_provider.dart';
// import 'stocks_provider.dart';
import 'transcation_provider.dart';
import 'user_profile_provider.dart';
import 'web_auth_provider.dart';

final authProvider = ChangeNotifierProvider((ref) => AuthProvider(ref));

class AuthProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();
  final Preferences pref = locator<Preferences>();
  final Ref ref;
  final String _version = "1.0.103(3)";
  late final String _versiontext =
      "Version 3.0.2 Build $_version Released on 17 Nov";
  String get versiontext => _versiontext;

  //  Text field controller for Login and otp screen

  final TextEditingController loginMethCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController otpCtrl = TextEditingController();

  bool _totp = true;
  bool get totp => _totp;

  late TabController exploreTab;

  int _selectedTab = 0;
  int get selectedTab => _selectedTab;

  Map _savedOrderPreference = {};
  Map get savedOrderPreference => _savedOrderPreference;

  setChangetotp(bool value) async {
    if (_totp == value) return; // Prevent unnecessary updates

    _totp = value;

    // Clear any existing OTP errors
    optError = null;
    notifyListeners();
  }

  removeUsers(user, i, context) {

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = ref.read(themeProvider);
        return AlertDialog(
          backgroundColor: theme.isDarkMode
              ? const Color(0xFF121212)
              : const Color(0xFFF1F3F8),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          scrollable: true,
          titlePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          actionsPadding:
              const EdgeInsets.only(bottom: 16, right: 16, left: 16, top: 8),
          title: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () async {
                        await Future.delayed(const Duration(milliseconds: 150));
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      splashColor: theme.isDarkMode
                          ? colors.splashColorDark
                          : colors.splashColorLight,
                      highlightColor: theme.isDarkMode
                          ? colors.splashColorDark
                          : colors.splashColorLight,
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: theme.isDarkMode
                              ? colors.textSecondaryDark
                              : colors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Do you like to remove this account from devices?",
                      style: MyntWebTextStyles.body(
                        context,
                        color: theme.isDarkMode
                            ? colors.textSecondaryDark
                            : colors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  if (i >= 0 && i < _loggedMobile.length) {
                    _loggedMobile.removeAt(i);
                    notifyListeners();
                    final List<String> jsonList =
                        _loggedMobile.map((obj) => obj.toJson()).toList();
                    pref.setLoggedClientList(jsonList);
                  }
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: BorderSide(color: colors.btnOutlinedBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  backgroundColor: colors.primaryDark,
                ),
                child: Text(
                  "Remove",
                  style: MyntWebTextStyles.title(
                    context,
                    color: colors.colorWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    // String clientId;
    // String mobile;
    // String userName;
    // String sesstion;
    // String imei;
  }

  changeTabIndex(int index) {
    _selectedTab = index;
  }

  List<Tab> _exploreTabName = [];
  List<Tab> get exploreTabName => _exploreTabName;
  exploretabSize() {
    _exploreTabName = [
      const Tab(
        icon: Row(
          children: [
            Icon(Icons.show_chart, size: 18),
            SizedBox(
              width: 5,
            ),
            Text('Stocks')
          ],
        ),
      ),
      const Tab(
        icon: Row(
          children: [
            Icon(Icons.bar_chart, size: 18),
            SizedBox(
              width: 5,
            ),
            Text('Mutual Funds')
          ],
        ),
      ),
      const Tab(
        icon: Row(
          children: [
            Icon(Icons.trending_up, size: 18),
            SizedBox(
              width: 5,
            ),
            Text('IPOs')
          ],
        ),
      ),
      const Tab(
        icon: Row(
          children: [
            Icon(
              Icons.monetization_on,
              size: 18,
            ),
            SizedBox(
              width: 5,
            ),
            Text('Bonds')
          ],
        ),
      ),
    ];

    notifyListeners();
  }

  String? loginMethError, passError, optError;

  bool _isMobileLogin = false;
  bool _isonTapMobile = true;
  bool _isDisableBtn = true;
  bool _hidePass = true;
  bool _isDisableOtpBtn = true;
  bool _hideOtp = true;

  final bool _bannervisble = false;

  String _logoutMsg = "";
  String get logoutMsg => _logoutMsg;

  List<LoggedMobile> _loggedMobile = [];
  var uuid = const Uuid();
  List<LoggedMobile> get loggedMobile => _loggedMobile;
  bool get isMobileLogin => _isMobileLogin;
  bool get isDisableBtn => _isDisableBtn;
  bool get hidePass => _hidePass;
  bool get hideOtp => _hideOtp;
  bool get isDisableOtpBtn => _isDisableOtpBtn;
  bool get bannervisble => _bannervisble;

  LoginOtp? _loginOtp;
  LoginOtp? get loginOtp => _loginOtp;

//
  String mobile_client = "";
  MobileLoginModel? _mobileLogin;
  MobileLoginModel? get mobileLogin => _mobileLogin;
  MobileOtpModel? _mobileOtp;
  MobileOtpModel? get mobileOtp => _mobileOtp;
//
  LoginOtpVerify? _loginOtpVerify;
  LoginOtpVerify? get loginOtpVerify => _loginOtpVerify;

  ClientDetailModel? _clientDetailModel;
  ClientDetailModel? get clientDetailModel => _clientDetailModel;
  String deviveInfo = "";
  LogoutModel? _logoutModel;
  LogoutModel? get logoutModel => _logoutModel;
  ChangePasswordModel? _changepasswordmodel;
  ChangePasswordModel? get changepasswordmodel => _changepasswordmodel;

  ForgetPasswordModel? _forgetPasswordModel;
  ForgetPasswordModel? get forgetPasswordModel => _forgetPasswordModel;

  Map<String, dynamic> _deviceData = <String, dynamic>{};
  Map<String, dynamic> get deviceInfo => _deviceData;

// This package for getting device info
  final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

  int currentYear = DateTime.now().year;

  final String _imeiLocal = "";
  String get imeilocal => _imeiLocal;

  // ValidateSession? _validateSession;
  // ValidateSession? get validSession => _validateSession;

  bool _addUser = false;
  bool get addUser => _addUser;

  addClient(bool val) {
    _addUser = true;
    notifyListeners();
  }

// Switch login option mobile to client id

  imieJson(String valueClient) {
    String checkimei = "";
    for (var element in _loggedMobile) {
      if (element.clientId == valueClient) {
        checkimei = element.imei;
      } else if (element.mobile == valueClient) {
        checkimei = element.imei;
      }
    }
    if (checkimei.isEmpty || checkimei == "") {
      return uuid.v4().toString();
    } else {
      return checkimei;
    }
  }

  loginMethod() {
    _isMobileLogin = !_isMobileLogin;

    pref.setMobileLogin(!pref.isMobileLogin!);

    _isDisableBtn = true;
    clearError();
    loginMethCtrl.clear();
    clearTextField();
    notifyListeners();
  }

  switchMobToClinent(bool val) {
    _isMobileLogin = val;
    notifyListeners();
  }

// If login validation is successful, activate the login button.
  set isDisableBtn(bool value) {
    _isDisableBtn = value;
    notifyListeners(); // remove this if you don't use Provider
  }

  activeBtnLogin() {
    if (loginMethError == "" &&
        passError == "" &&
        loginMethCtrl.text.isNotEmpty &&
        passCtrl.text.isNotEmpty) {
      _isDisableBtn = false;
    } else {
      _isDisableBtn = true;
    }
    notifyListeners();
  }

// If OTP validation is successful, activate the OTP button.
  activeBtnOtp(String otp) {
    if (otp.length <= 3 || otp.isEmpty) {
      _isDisableOtpBtn = false;
    } else {
      _isDisableOtpBtn = true;
    }
    notifyListeners();
  }
// Hide / Show password

  hiddenPass() {
    _hidePass = !_hidePass;
    notifyListeners();
  }
// Hide / Show OTP

  hiddenOtp() {
    _hideOtp = !_hideOtp;
    notifyListeners();
  }

// Clear login validation error
  void clearError() {
    loginMethError = "";
    passError = "";
    notifyListeners();
  }

  clearTextField() {
    otpCtrl.clear();
    // loginMethCtrl.clear();
    passCtrl.clear();
    notifyListeners();
  }

// Get Device information

  Future<void> getDeviceDetails() async {
    Map<String, dynamic>? deviceData = <String, dynamic>{};

    try {
      if (!kIsWeb && TargetPlatform.android == defaultTargetPlatform) {
        deviceData = _readAndroidDeviceInfo(await deviceInfoPlugin.androidInfo);
      } else if (!kIsWeb && TargetPlatform.iOS == defaultTargetPlatform) {
        deviceData = _readIosDeviceInfo(await deviceInfoPlugin.iosInfo);
      } else {
        deviceData = <String, dynamic>{'Error:': 'Unsupported platform'};
      }
      // TargetPlatform.fuchsia => null,
      // TargetPlatform.linux => null,
      // TargetPlatform.macOS => null,
      // TargetPlatform.windows => null
    } on PlatformException {
      deviceData = <String, dynamic>{
        'Error:': 'Failed to get platform version.'
      };
    }
    _deviceData = deviceData;

    deviveInfo = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        ? "${_deviceData['brand']}-${_deviceData['model']}-${_deviceData['id']}"
        : "${_deviceData['model'] ?? 'Web'}-${_deviceData['name'] ?? 'Browser'}-${_deviceData['identifierForVendor'] ?? 'N/A'}";

    pref.setDeviceName(deviveInfo);
    notifyListeners();
  }

  Map<String, dynamic> _readAndroidDeviceInfo(AndroidDeviceInfo build) {
    return <String, dynamic>{
      'brand': build.brand,
      'id': build.id,
      'model': build.model
    };
  }

  Map<String, dynamic> _readIosDeviceInfo(IosDeviceInfo data) {
    return <String, dynamic>{
      'name': data.name,
      'model': data.model,
      'identifierForVendor': data.identifierForVendor
    };
  }

  bool _switchback = false;
  bool get switchback => _switchback;

  switchbackbutton(bool value) {
    _switchback = value;
    notifyListeners();
  }

// Validate login
  validateLogin() {
    // clearError();
    if (loginMethCtrl.text.trim().isEmpty) {
      loginMethError = "Your mobile / client id is required";
    } else {
      loginMethError = "";
    }
    notifyListeners();
  }

  validatePass() {
    if (passCtrl.text.trim().isEmpty) {
      passError = "Please enter the password";
    } else {
      passError = "";
    }
    notifyListeners();
  }

// Validate OTP
  bool validateOtp(String otp) {
    if (otp == 'wrong' || otp == 'TOTP') {
      optError = "Invalid / wrong ${otp == 'TOTP' ? 'TOTP' : 'OTP'}";
    } else if (otp.length <= (_totp ? 5 : 3) || otp.isEmpty) {
      optError = "Please enter ${_totp ? 6 : 4} digit OTP";
    } else if (otp == 'success') {
      optError = "OTP Verified";
    } else {
      optError = null;
    }
    return optError == null;
  }

// Call this method while clicking if the login validation process is successful.

  submitLogin(BuildContext context, bool navi,
      {bool preventNavigation = false}) async {
    _loggedMobile = await getLocalData();
    // if (routeTo == "deviceLogin") {
    //   _isMobileLogin = true;
    // }

    if (loginMethError == "" && passError == "") {
      await fetchMobileLogin(
          context,
          passCtrl.text,
          loginMethCtrl.text.toUpperCase(),
          navi ? "pop" : "",
          imieJson(loginMethCtrl.text.toUpperCase()),
          _totp,
          preventNavigation: preventNavigation);
    }
  }

// Call this method while clicking if the OTP validation process is successful.
  submitOtp(BuildContext context, String otp) {
    if (validateOtp(otp)) {
      fetchMobileOtp(context, otp);
    }
  }

// Call this method while clicking Resent OTP .
  submitResendOtp(BuildContext context) {
    resendOtp(context, passCtrl.text, loginMethCtrl.text.toUpperCase());
  }

// Fetching data from the api and stored in a variable

  fetchMobileLogin(BuildContext context, String password, String mobileRclint,
      String s, String imei, bool totp,
      {bool preventNavigation = false}) async {
    try {
      pref.setImei(imei);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      toggleLoadingOn(true);

      // Clear any existing OTP state
      _mobileLogin = null;
      notifyListeners();

      _mobileLogin = await api.getMobileLogin(
          uniqueId: "${pref.deviceName!} ${pref.imei}",
          mobileRclient: mobileRclint,
          password: password,
          context: context,
          imei: imei,
          totp: totp);
      // final localstorage = await SharedPreferences.getInstance();

      if ((_mobileLogin!.stat == "Ok" && s.isNotEmpty) || s == "pop") {
        if (context.mounted) {
          Navigator.pop(context);
        }
        validateOtp("");
      }

      if (_mobileLogin!.stat == "Ok" &&
          (totp && _mobileLogin!.msg != null ||
              (_mobileLogin!.msg == "otp sended" ||
                  _mobileLogin!.msg ==
                      "otp sended, already logged in another device"))) {
        otpCtrl.clear();
        mobile_client = mobileRclint;
        if (!totp) {
          if (context.mounted) {
            if (kIsWeb) {
              ResponsiveSnackBar.showSuccess(context, 'The OTP is sent via email and SMS');
            } else {
              successMessage(context, 'The OTP is sent via email and SMS');
            }
          }
        }
        _isDisableBtn = true;
        pref.setRiskDiscloser(false);

        // Navigate to OTP screen
        if (context.mounted && !preventNavigation) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PopScope(
                canPop: true,
                onPopInvoked: (didPop) {
                  if (didPop) {
                    isDisableBtn = false;
                    notifyListeners();
                  }
                },
                child: const BottomSheetContent(),
              ),
            ),
          );
          //    },
          //           child: const BottomSheetContent())),
          // );

          // // showModalBottomSheet(
          // //   context: context,
          // //   shape: const RoundedRectangleBorder(
          // //       borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          // //   backgroundColor: const Color(0xffffffff),
          // //   isDismissible: false,
          // //   enableDrag: false,
          // //   showDragHandle: false,
          // //   useSafeArea: false,
          // //   isScrollControlled: true,
          // //   builder: (context) => PopScope(
          // //     canPop: true,
          // //     onPopInvoked: (didPop) {
          // //       _isDisableBtn = false;
          // //       notifyListeners();
          // //     },
          // //     child: const BottomSheetContent(),
          // //   ),
          // // );
          // // }
        }
      } else if (_mobileLogin!.emsg ==
          "Invalid Input : User Blocked due to multiple wrong attempts") {
        ref.read(changePasswordProvider).userIdController.text =
            "${_mobileLogin!.clientid}";
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, _mobileLogin!.emsg!);
        } else {
          warningMessage(context, _mobileLogin!.emsg!);
        }
        Future.delayed(const Duration(seconds: 3), () {
          Navigator.pushNamed(context, Routes.forgotPass);
        });
      } else if (_mobileLogin!.emsg == "Invalid Input : Change Password" ||
          _mobileLogin!.emsg == "Invalid Input : Password Expired") {
        ref.read(changePasswordProvider).userIdController.text =
            "${_mobileLogin!.clientid}";
        if (_mobileLogin!.emsg == "Invalid Input : Password Expired") {
          ref.read(changePasswordProvider).oldPassword.text =
              password.toString();
        }
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, _mobileLogin!.emsg!);
        } else {
          warningMessage(context, _mobileLogin!.emsg!);
        }
        Navigator.pushNamed(context, Routes.changePass,
            arguments: _mobileLogin!.emsg == "Invalid Input : Password Expired"
                ? 'Yes'
                : "No");
      } else if (_mobileLogin!.emsg ==
          "Your mobile registered in multiple accounts, Please login with client ID") {
        loginMethod();
        pref.setHideLoginOptBtn(false);
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context,
              "Multiple accounts linked to your mobile no. Login with Client ID");
        } else {
          warningMessage(context,
              "Multiple accounts linked to your mobile no. Login with Client ID");
        }
      } else if (_mobileLogin!.emsg == "mobile_unique not valid") {
        if (s.isNotEmpty) {
          Navigator.pop(context);
        }
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context,
              "This user id logged in another device, Please login again");
        } else {
          warningMessage(context,
              "This user id logged in another device, Please login again");
        }
        _isDisableBtn = true;
        pref.setHideLoginOptBtn(false);
        clearError();
        clearTextField();
        pref.setMobileLogin(false);
        pref.setLogout(true);
        ref.read(indexListProvider).bottomMenu(0, context);
        loginMethCtrl.text = pref.clientId!;
        if (currentRouteName != Routes.loginScreen) {
          Navigator.pushNamedAndRemoveUntil(
              context, Routes.loginScreen, (route) => false);
        }
      } else if (_mobileLogin!.apitoken != null && _mobileLogin!.stat == "Ok") {
        clearError();
        clearTextField();

        pref.setClientId("${_mobileLogin!.clientid}");
        pref.setClientMob("${_mobileLogin!.mobile}");
        pref.setClientSession("${_mobileLogin!.apitoken}");
        pref.setClientName("${_mobileLogin!.name}");
        pref.setApiToken("${_mobileLogin!.token}");

        List<LoggedMobile> currentUser = [
          LoggedMobile(
              clientId: pref.clientId!,
              mobile: pref.clientMob!,
              sesstion: pref.clientSession!,
              userName: pref.clientName!,
              imei: imei)
        ];
        _loggedMobile = await getLocalData();

        await setLocalData(_loggedMobile, currentUser);

        _loggedMobile = await getLocalData();
        if (s != "switchAc") {
          await deviceAuth(context, s);
        } else {
          ref.read(themeProvider).navigateToNewPage(context);
          initialLoadMethods(context, s);
        }
      } else if (password.isEmpty &&
          _mobileLogin!.emsg == "Invalid Input : Wrong Password") {
        _isDisableBtn = true;
        clearError();
        clearTextField();
        if (currentRouteName != Routes.loginScreen) {
          Navigator.pushNamedAndRemoveUntil(
              context,
              Routes.loginScreen,
              arguments: "login",
              (route) => false);
        }
      } else if (_mobileLogin == null) {
        _handleNetworkFailure(
            context, "Network error. Please check your connection.");
      } else {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, _mobileLogin!.emsg!);
        } else {
          warningMessage(context, _mobileLogin!.emsg!);
        }
        if (currentRouteName != Routes.loginScreen) {
          Navigator.pushNamedAndRemoveUntil(
              context,
              Routes.loginScreen,
              arguments: "login",
              (route) => false);
        }
      }

      // else {
      //   ScaffoldMessenger.of(context)
      //       .showSnackBar(warningMessage(context, _mobileLogin!.emsg!));
      // }
      notifyListeners();
    } catch (e) {
      _handleNetworkFailure(
          context, "Network error. Please check your connection.");
    } finally {
      toggleLoadingOn(false);
    }
  }

// Fetching data from the api and stored in a variable
  resendOtp(BuildContext context, String password, String mobileRclint) async {
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      toggleLoadingOn(true);
      _mobileLogin = await api.getMobileLogin(
          uniqueId: "${pref.deviceName!} ${pref.imei}",
          mobileRclient: mobileRclint,
          password: password,
          context: context,
          imei: pref.imei!,
          totp: _totp);

      otpCtrl.clear();
      _isDisableOtpBtn = true;
      if (_mobileLogin!.stat == "Ok" &&
          (_mobileLogin!.msg == "otp sended" ||
              _mobileLogin!.msg ==
                  "otp sended, already logged in another device")) {
        mobile_client = mobileRclint;
        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(context, 'The OTP is re-sent via SMS and email.');
        } else {
          successMessage(context, 'The OTP is re-sent via SMS and email.');
        }
        // _isDisableBtn = true;
      } else {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, _mobileLogin!.emsg!);
        } else {
          warningMessage(context, _mobileLogin!.emsg!);
        }
      }
      notifyListeners();
    } catch (e) {
    } finally {
      toggleLoadingOn(false);
    }
  }

// Fetching data from the api and stored in a variable
  fetchMobileOtp(BuildContext context, String otp) async {
    bool isSuccess = false;
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      toggleLoadingOn(true);
      _mobileOtp = await api.getMobileOtp(
          uniqueId: "${pref.deviceName!} ${pref.imei}",
          mobileRclient: mobile_client,
          otp: otp,
          context: context,
          imei: pref.imei!);

      // print('def sd ${pref.imei!}');
      // final localstorage = await SharedPreferences.getInstance();
      if (_mobileOtp!.stat == "Ok") {
        isSuccess = true;
        initLaod(true);
        _isDisableBtn = true;
        clearError();
        clearTextField();
        validateOtp('success');
// set values to save device
        pref.setClientId("${_mobileOtp!.clientid}");
        pref.setClientMob("${_mobileOtp!.mobile}");
        pref.setClientSession("${_mobileOtp!.apitoken}");
        pref.setClientName("${_mobileOtp!.name}");
        pref.setApiToken("${_mobileOtp!.token}");

        List<LoggedMobile> currentUser = [
          LoggedMobile(
              clientId: pref.clientId!,
              mobile: pref.clientMob!,
              sesstion: pref.clientSession!,
              userName: pref.clientName!,
              imei: pref.imei!)
        ];
        await deviceAuth(context, "");
        // Future.delayed(const Duration(seconds: 3), () async {
        // Navigator.pushNamed(context, Routes.forgotPass);
        _loggedMobile = await getLocalData();

        await setLocalData(_loggedMobile, currentUser);

        _loggedMobile = await getLocalData();

        //log("loggued Useer -- ${pref.loggedClient}");
        // ScaffoldMessenger.of(context)
        //     .showSnackBar(successMessage(context, 'OTP Verified'));
        // });

        notifyListeners();
      }
      if (_mobileOtp?.emsg == "otp not valid") {
        validateOtp('wrong');
      } else if (_mobileOtp!.emsg ==
          "Invalid Input : User Blocked due to multiple wrong attempts") {
        final ctx = context;
        ref.read(changePasswordProvider).userIdController.text = mobile_client;
        Navigator.pushNamed(ctx, Routes.forgotPass);
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, _mobileOtp!.emsg!);
        } else {
          warningMessage(context, _mobileOtp!.emsg!);
        }
        // Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context);
        // });
      }
      if (_mobileOtp?.emsg == "Invalid Input : Invalid OTP") {
        validateOtp('TOTP');
      }
    } finally {
      if (!isSuccess) {
        toggleLoadingOn(false);
      } else {
        // Reset loading silently or after delay to ensure global state is clean eventually
        Future.delayed(const Duration(seconds: 1), () {
          loading = false;
        });
      }
    }
  }

// Storing client login information locally
  Future<void> setLocalData(
      List<LoggedMobile> list, List<LoggedMobile> currentUser) async {
    List<LoggedMobile> uniqueList = [];
    list.add(currentUser[0]);

    Set<String> uniqueCombos = <String>{};
    for (var element in list.reversed) {
      String combo = '${element.clientId}-${element.mobile}';

      if (!uniqueCombos.contains(combo)) {
        uniqueCombos.add(combo);
        uniqueList.add(element);
      }
    }

    final List<String> jsonList =
        uniqueList.map((obj) => obj.toJson()).toList();

    pref.setLoggedClientList(jsonList);
  }

  // Retrieve a list of objects from shared preferences
  Future<List<LoggedMobile>> getLocalData() async {
    List<String>? jsonList = pref.loggedClient;

    if (jsonList != null) {
      
      return jsonList
          .map((jsonString) => LoggedMobile.fromJson(jsonString))
          .toList();
    } else {
      return [];
    }
  }

// Fetching data from the api and stored in a variable
  fetchLogout(BuildContext context, {String? target}) async {

    try {
      // Call both logout APIs in parallel
      final logoutFuture = api.getLogout();
      final deskLogoutFuture = api.getDeskLogout();

      // Wait for both APIs to complete
      _logoutModel = await logoutFuture;
      final deskLogoutModel = await deskLogoutFuture;


      // Treat session expired as successful logout — session is already gone on server
      if (_logoutModel!.stat == "Ok" ||
          _logoutModel!.emsg == "Session Expired :  Invalid Session Key") {
        // Close all open order/modify/GTT dialogs (web only)
        if (kIsWeb) {
          OverlayManager.closeAll();
        }

        // Cancel any active timers
        if (ConstantName.timer != null) {
          ConstantName.timer!.cancel();
        }

        // Close WebSocket connections and unsubscribe from market data
        ref.read(websocketProvider).closeSocket(true, force: true);
        ref.read(websocketProvider).websockConn(false);

        // Close PiP window if open
        PipService.closePipWindow();

        // Save the current page index before cleanup (for restoration after login)
        // We don't reset currentWatchlistPageIndex to preserve the user's last position

        // Clear user session data
        pref.clearClientSession();
        pref.setLogout(true);
        pref.setHideLoginOptBtn(false);
        pref.setMobileLogin(false);

        // Clear session state from index list provider to ensure fresh data load on re-login
        ref.read(indexListProvider).clearSessionState();

        ref.read(fundProvider).clearFunds();
        ref.read(transcationProvider).resetBankDetails();

        // Clear banner and text nugget seen storage on logout
        ref.read(bannerProvider).onUserLogout();
        ref.read(textNuggetProvider).onUserLogout();

        // Clear pending watchlists on logout
        ref.read(marketWatchProvider).clearPendingWatchlists();

        // Clear notification data on logout to prevent data leaking between users
        ref.read(notificationprovider).clearData();

        ref.read(optionFlashProvider).closePanel();

        ref.read(ledgerProvider).clearOnLogout();

        // Clear API key + TOTP state so the next logged-in user does not see
        // the previous user's TOTP secret on opening the settings section.
        ref.read(apikeyprovider).clearOnLogout();

        // Reset web auth provider state to ensure clean login on web
        if (kIsWeb) {
          ref.read(webAuthProvider).reset();
        }

        // Update UI state
        ref.read(indexListProvider).bottomMenu(0, context);

        // Pre-fill login field with last client ID for convenience
        if (pref.clientId != null && pref.clientId!.isNotEmpty) {
          loginMethCtrl.text = pref.clientId!;
        }

        notifyListeners();

        // Navigation handling — guard with context.mounted to avoid
        // using BuildContext after the widget tree has disposed.
        if (!context.mounted) return;

        try {
          Navigator.pop(context);
        } catch (e) {
        }

        if (!context.mounted) return;

        if (currentRouteName != Routes.loginScreen) {
          // Use GoRouter for web, Navigator for mobile
          if (kIsWeb) {
            context.go(target ?? WebRoutes.login);
          } else {
            Navigator.pushNamedAndRemoveUntil(
                context, Routes.loginScreen, (route) => false);
          }
        }
      }
    } catch (e) {
      try {
        ref.read(indexListProvider).logError.add({"type": "API", "Error": "$e"});
      } catch (_) {}
    }
  }

// if there is a mobile number available automatically obtain from the device
  getCurrentPhone() async {
    if (_isonTapMobile) {
      if (loginMethCtrl.text.toString().isEmpty) {
        try {
          final autoFill = SmsAutoFill();
          final phone = await autoFill.hint;

          _isonTapMobile = false;

          if (phone == null) {
            loginMethCtrl.text = "";
          } else if (phone.contains('+91')) {
            loginMethCtrl.text = phone.substring(3);
          } else {
            loginMethCtrl.text = phone.toString();
          }
          notifyListeners();
          validateLogin();

          activeBtnLogin();
        } catch (e) {
        }
      }
    }
  }

// When device authentication is enabled, a dialogue box appears to provide access to our app.

  // Future<void> deviceAuth(BuildContext context, String s) async {
  //   final localAuth = LocalAuthentication();
  //   final parentContext = context; // Capture stable context

  //   try {
  //     bool authenticated = await localAuth.authenticate(
  //       localizedReason: 'Authenticate to access the app',
  //       options: const AuthenticationOptions(
  //         useErrorDialogs: false,
  //         stickyAuth: true,
  //         biometricOnly: false,
  //       ),
  //     );

  //     if (!parentContext.mounted) return; // Ensure context is still valid

  //     if (authenticated) {
  //       ref.read(themeProvider).navigateToNewPage(parentContext);
  //       initialLoadMethods(parentContext, s);
  //     } else {
  //       showAuthDialog(parentContext, s);
  //       print('bioAuth - Authentication failed');
  //     }
  //   } on PlatformException catch (e) {
  //     if (!parentContext.mounted) return;

  //     if (e.code == auth_error.notAvailable &&
  //         defaultTargetPlatform == TargetPlatform.iOS) {
  //       showAuthDialog(parentContext, s);
  //     } else {
  //       initialLoadMethods(parentContext, s);
  //     }
  //   }
  //   notifyListeners();
  // }

  // void showAuthDialog(BuildContext context, String s) {
  //   showDialog(
  //     barrierDismissible: false,
  //     context: context,
  //     builder: (BuildContext dialogContext) {
  //       return AlertDialog(
  //         titleTextStyle: textStyles.appBarTitleTxt,
  //         contentTextStyle: textStyles.menuTxt,
  //         titlePadding:
  //             const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  //         shape: const RoundedRectangleBorder(
  //           borderRadius: BorderRadius.all(Radius.circular(14)),
  //         ),
  //         scrollable: true,
  //         contentPadding: const EdgeInsets.symmetric(horizontal: 14),
  //         insetPadding: const EdgeInsets.symmetric(horizontal: 20),
  //         title: const Text("Confirmation"),
  //         content: const Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text("Authentication is required to proceed further!"),
  //             SizedBox(height: 10),
  //           ],
  //         ),
  //         actions: [
  //           ElevatedButton(
  //             onPressed: () {
  //               Navigator.of(dialogContext, rootNavigator: true).pop();
  //               deviceAuth(context, s); // re-call using parent context
  //             },
  //             style: ElevatedButton.styleFrom(
  //               elevation: 0,
  //               backgroundColor: ref.read(themeProvider).isDarkMode
  //                   ? colors.colorbluegrey
  //                   : colors.colorBlack,
  //               padding:
  //                   const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(30),
  //               ),
  //             ),
  //             child: Text("Proceed", style: textStyles.btnText),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // Future<void> deviceAuth(BuildContext context, String s) async {
  //   final localAuth = LocalAuthentication();

  //   try {
  //     bool authenticated = await localAuth.authenticate(
  //         localizedReason: 'Authenticate to access the app',
  //         options: const AuthenticationOptions(
  //             useErrorDialogs: false, stickyAuth: true, biometricOnly: false));

  //     if (authenticated) {
  //       // print('bioAuth - User authenticated successfully');
  //       ref.read(themeProvider).navigateToNewPage(context);
  //       initialLoadMethods(context, s);
  //     } else {
  //       showDialog(
  //         barrierDismissible: false,
  //         context: context,
  //         builder: (BuildContext context) {
  //           return AlertDialog(
  //             titleTextStyle: textStyles.appBarTitleTxt,
  //             contentTextStyle: textStyles.menuTxt,
  //             titlePadding:
  //                 const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
  //             shape: const RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.all(Radius.circular(14))),
  //             scrollable: true,
  //             contentPadding: const EdgeInsets.symmetric(
  //               horizontal: 14,
  //             ),
  //             insetPadding: const EdgeInsets.symmetric(horizontal: 20),
  //             title: const Text("Confirmation"),
  //             content: SizedBox(
  //               width: MediaQuery.of(context).size.width,
  //               child: const Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text("Authentication is required to proceed further!"),
  //                   SizedBox(
  //                     height: 10,
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             actions: [
  //               ElevatedButton(
  //                   onPressed: () {
  //                     Navigator.of(context, rootNavigator: true).pop();
  //                      deviceAuth(context, s);},
  //                   style: ElevatedButton.styleFrom(
  //                       elevation: 0,
  //                       backgroundColor: ref.read(themeProvider).isDarkMode
  //                           ? colors.colorbluegrey
  //                           : colors.colorBlack,
  //                       padding: const EdgeInsets.symmetric(
  //                           vertical: 10, horizontal: 16),
  //                       shape: RoundedRectangleBorder(
  //                         borderRadius: BorderRadius.circular(30),
  //                       )),
  //                   child: Text("Proceed", style: textStyles.btnText)),
  //             ],
  //           );
  //         },
  //       );
  //       // Navigator.pushNamedAndRemoveUntil(
  //       //     context, Routes.loginScreen, arguments: "login", (route) => false);
  //       print('bioAuth - Authentication failed');
  //     }
  //     // } else {
  //     //   print('bioAuth Biometrics not available on this device');
  //     // }
  //   }
  //   // catch (e) {

  //   //   print('Error: $e');
  //   // }

  //   on PlatformException catch (e) {
  //     if (e.code == auth_error.notAvailable) {
  //       // Add handling of no hardware here.
  //       if (defaultTargetPlatform == TargetPlatform.iOS) {
  //         showDialog(
  //           barrierDismissible: false,
  //           context: context,
  //           builder: (BuildContext context) {
  //             return AlertDialog(
  //               titleTextStyle: textStyles.appBarTitleTxt,
  //               contentTextStyle: textStyles.menuTxt,
  //               titlePadding:
  //                   const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  //               shape: const RoundedRectangleBorder(
  //                   borderRadius: BorderRadius.all(Radius.circular(14))),
  //               scrollable: true,
  //               contentPadding: const EdgeInsets.symmetric(
  //                 horizontal: 14,
  //               ),
  //               insetPadding: const EdgeInsets.symmetric(horizontal: 20),
  //               title: const Text("Confirmation"),
  //               content: SizedBox(
  //                 width: MediaQuery.of(context).size.width,
  //                 child: const Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text("Authentication is reqired to proceed further!")
  //                   ],
  //                 ),
  //               ),
  //               actions: [
  //                 ElevatedButton(
  //                     onPressed: () {
  //                     Navigator.of(context, rootNavigator: true).pop();
  //                      deviceAuth(context, s);},
  //                     style: ElevatedButton.styleFrom(
  //                         elevation: 0,
  //                         backgroundColor: ref.read(themeProvider).isDarkMode
  //                             ? colors.colorbluegrey
  //                             : colors.colorBlack,
  //                         padding: const EdgeInsets.symmetric(vertical: 13),
  //                         shape: RoundedRectangleBorder(
  //                           borderRadius: BorderRadius.circular(30),
  //                         )),
  //                     child: Text("Proceed", style: textStyles.btnText)),
  //               ],
  //             );
  //           },
  //         );
  //       } else {
  //         initialLoadMethods(context, s);
  //       }
  //     } else if (e.code == auth_error.notEnrolled) {
  //       // print("bioAuth - - ${e.code}");
  //       // ...
  //     } else {
  //       // ...
  //       // print("bioAuth - --  -${e.code}");
  //     }

  //     // print("bioAuth - ${e.code}");
  //   }
  //   notifyListeners();
  // }

 Future<void> deviceAuth(BuildContext context, String s) async {
  if (kIsWeb) {
    ref.read(themeProvider).navigateToNewPage(context);
    initialLoadMethods(context, s);
    notifyListeners();
    return;
  }

  final localAuth = LocalAuthentication();

  try {
    final bool authenticated = await localAuth.authenticate(
      localizedReason: 'Authenticate to access the app',
      biometricOnly: false,                // allow PIN / pattern
      sensitiveTransaction: true,          // stronger security
      persistAcrossBackgrounding: true,    // keeps auth alive
    );

    if (authenticated) {
      ref.read(themeProvider).navigateToNewPage(context);
      initialLoadMethods(context, s);
    } else {
      _showAuthenticationFailedDialog(
        context,
        s,
        ref.read(themeProvider),
      );
    }
  } on PlatformException catch (e) {

    switch (e.code) {
      case 'NotAvailable':
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          _showAuthenticationRequiredDialog(
            context,
            s,
            ref.read(themeProvider),
          );
        } else {
          initialLoadMethods(context, s);
        }
        break;

      case 'NotEnrolled':
        _showBiometricNotSetupDialog(
          context,
          s,
          ref.read(themeProvider),
        );
        break;

      case 'LockedOut':
      case 'PermanentlyLockedOut':
        _showAuthenticationErrorDialog(
          context,
          s,
          'Biometric authentication is locked. Try again later.',
          ref.read(themeProvider),
        );
        break;

      default:
        _showAuthenticationErrorDialog(
          context,
          s,
          e.message ?? 'Authentication failed',
          ref.read(themeProvider),
        );
    }
  }

  notifyListeners();
}


  void _showAuthenticationFailedDialog(BuildContext context, String s, theme) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.isDarkMode
              ? const Color(0xFF121212)
              : const Color(0xFFF1F3F8),
          titlePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8))),
          scrollable: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          actionsPadding:
              const EdgeInsets.only(bottom: 16, right: 16, left: 16, top: 8),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          title: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () async {
                        await Future.delayed(const Duration(milliseconds: 150));
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      splashColor: theme.isDarkMode
                          ? colors.splashColorDark
                          : colors.splashColorLight,
                      highlightColor: theme.isDarkMode
                          ? colors.splashColorDark
                          : colors.splashColorLight,
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: theme.isDarkMode
                              ? colors.textSecondaryDark
                              : colors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      "Authentication is required to proceed further!",
                      style: MyntWebTextStyles.body(
                        context,
                        color: theme.isDarkMode
                            ? colors.textSecondaryDark
                            : colors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // TextButton(
            //   onPressed: () {
            //     Navigator.of(dialogContext).pop();
            //     // Go back to login or previous screen instead of recursive call
            //     Navigator.of(context).pop();
            //   },
            //   child: Text("Cancel", style: textStyles.btnText),
            // ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Use a slight delay to ensure dialog is closed before retry
                  Future.delayed(const Duration(milliseconds: 100), () {
                    deviceAuth(context, s);
                  });
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 45), // width, height
                  side: BorderSide(
                      color: colors.btnOutlinedBorder), // Outline border color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  backgroundColor: colors.primaryDark, // Transparent background
                ),
                child: Text(
                  "Try Again",
                  style: MyntWebTextStyles.title(
                    context,
                    color: colors.colorWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAuthenticationRequiredDialog(
      BuildContext context, String s, theme) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: colors.colorWhite,
          titlePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          scrollable: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          actionsPadding:
              const EdgeInsets.only(bottom: 16, right: 16, left: 16, top: 8),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          title: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () async {
                        await Future.delayed(const Duration(milliseconds: 150));
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      splashColor: theme.isDarkMode
                          ? colors.splashColorDark
                          : colors.splashColorLight,
                      highlightColor: theme.isDarkMode
                          ? colors.splashColorDark
                          : colors.splashColorLight,
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: theme.isDarkMode
                              ? colors.colorWhite
                              : colors.colorBlack,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // TextWidget.subText(
                    //   text: "Authentication Required",
                    //   theme: theme.isDarkMode,
                    //   color: theme.isDarkMode
                    //       ? colors.textPrimaryDark
                    //       : colors.textPrimaryLight,
                    //   fw: 3,
                    // ),
                    const SizedBox(height: 10),
                    Text(
                      "Authentication is required to proceed further!",
                      style: MyntWebTextStyles.body(
                        context,
                        color: theme.isDarkMode
                            ? colors.textPrimaryDark
                            : colors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Future.delayed(const Duration(milliseconds: 100), () {
                    deviceAuth(context, s);
                  });
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: BorderSide(color: colors.btnOutlinedBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  backgroundColor: colors.primaryDark,
                ),
                child: Text(
                  "Proceed",
                  style: MyntWebTextStyles.title(
                    context,
                    color: !theme.isDarkMode
                        ? colors.colorWhite
                        : colors.colorBlack,
                    fontWeight: MyntFonts.medium,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBiometricNotSetupDialog(BuildContext context, String s, theme) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: colors.colorWhite,
          titlePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          scrollable: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          actionsPadding:
              const EdgeInsets.only(bottom: 16, right: 16, left: 16, top: 8),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          title: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () async {
                        await Future.delayed(const Duration(milliseconds: 150));
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      splashColor: theme.isDarkMode
                          ? colors.splashColorDark
                          : colors.splashColorLight,
                      highlightColor: theme.isDarkMode
                          ? colors.splashColorDark
                          : colors.splashColorLight,
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: theme.isDarkMode
                              ? colors.colorWhite
                              : colors.colorBlack,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // TextWidget.subText(
                    //   text: "Biometric Not Setup",
                    //   theme: theme.isDarkMode,
                    //   color: theme.isDarkMode
                    //       ? colors.textPrimaryDark
                    //       : colors.textPrimaryLight,
                    //   fw: 3,
                    // ),
                    const SizedBox(height: 10),
                    Text(
                      "Please setup biometric authentication in your device settings.",
                      style: MyntWebTextStyles.body(
                        context,
                        color: theme.isDarkMode
                            ? colors.textPrimaryDark
                            : colors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  initialLoadMethods(context, s);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: BorderSide(color: colors.btnOutlinedBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  backgroundColor: colors.primaryDark,
                ),
                child: Text(
                  "Continue",
                  style: MyntWebTextStyles.title(
                    context,
                    color: !theme.isDarkMode
                        ? colors.colorWhite
                        : colors.colorBlack,
                    fontWeight: MyntFonts.medium,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAuthenticationErrorDialog(
      BuildContext context, String s, String error, theme) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: colors.colorWhite,
          titlePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          scrollable: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          actionsPadding:
              const EdgeInsets.only(bottom: 16, right: 16, left: 16, top: 8),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          title: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () async {
                        await Future.delayed(const Duration(milliseconds: 150));
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      splashColor: theme.isDarkMode
                          ? colors.splashColorDark
                          : colors.splashColorLight,
                      highlightColor: theme.isDarkMode
                          ? colors.splashColorDark
                          : colors.splashColorLight,
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: !theme.isDarkMode
                              ? colors.colorWhite
                              : colors.colorBlack,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TextWidget.subText(
                    //   text: "Authentication Error",
                    //   theme: theme.isDarkMode,
                    //   color: theme.isDarkMode
                    //       ? colors.textPrimaryDark
                    //       : colors.textPrimaryLight,
                    //   fw: 3,
                    // ),
                    Text(
                      "An error occurred: $error",
                      style: MyntWebTextStyles.body(
                        context,
                        color: !theme.isDarkMode
                            ? colors.textPrimaryDark
                            : colors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Future.delayed(const Duration(milliseconds: 100), () {
                    deviceAuth(context, s);
                  });
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: BorderSide(color: colors.btnOutlinedBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  backgroundColor: colors.primaryDark,
                ),
                child: Text(
                  "Retry",
                  style: MyntWebTextStyles.title(
                    context,
                    color: colors.colorWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  AuthProvider(this.ref);

  // Following a successful login and device authentication, these methods are called first.

  initialLoadMethods(BuildContext context, String s) async {
    try {
      if (s != "switchAc") {
        initLaod(true);
      }
      ConstantName.timer =
          Timer.periodic(const Duration(seconds: 1), (timer) {});
      ConstantName.timer!.cancel();
      ref.read(indexListProvider).bottomMenu(s.isEmpty ? 0 : 4, context);

      // Reset WebSocket for account switch or fresh login
      // For switchAc: force close the existing connection
      // For fresh login (not page refresh): reset stale state from expired session
      if (s.isNotEmpty && s == "switchAc") {
        ref.read(websocketProvider).closeSocket(true, force: true);
      } else if (kIsWeb && !ref.read(websocketProvider).wsConnected) {
        // On web fresh login, reset any stale state (stuck _connecting/_reconnecting)
        // from a session that expired while the user was away.
        // Only reset if NOT already connected (page refresh has an active connection).
        ref.read(websocketProvider).resetForNewSession();
      }

      try {
        await ref.read(indexListProvider).checkSession(context);
        // Don't reset watchlist name here as it will be properly set after fetching watchlist data
        _logoutMsg = "";

        if (ref.read(indexListProvider).checkSess!.stat == "Ok") {
          // Clear data first (quick operation)
          await ref.read(portfolioProvider).clearAllportfolio();
          await ref.read(fundProvider).clearFunds();
          await ref.read(orderProvider).clearAllorders();
          ref.read(indexListProvider).fetchNotifyMsg();
          ref.read(portfolioProvider).changeTabIndex(0);
          await ref.read(themeProvider).navigateToNewPage(context);
          
          // For web: Navigate immediately, then load data asynchronously
          // For mobile: Keep existing behavior but optimize
          if (kIsWeb || s.isEmpty) {
            // Navigate to home screen IMMEDIATELY without waiting for data
            if (s.isEmpty) {
              // For web, use GoRouter for URL-based navigation
              // Only navigate to home if coming from login/splash
              // Don't navigate if already on an authenticated route (preserves URL on refresh)
              if (kIsWeb) {
                final currentPath = WebNavigationHelper.getCurrentPath();
                final isOnAuthRoute = currentPath == WebRoutes.login ||
                                      currentPath == WebRoutes.splash ||
                                      currentPath.isEmpty;
                if (context.mounted && isOnAuthRoute) {
                  // If user arrived at /login via the OAuth redirect, the client_id
                  // travels along in the URL. Read it off Uri.base and return there.
                  final oauthClientId = Uri.base.queryParameters['client_id'];
                  if (oauthClientId != null && oauthClientId.isNotEmpty) {
                    context.go(
                      '${WebRoutes.oauthAuthorize}?client_id=${Uri.encodeQueryComponent(oauthClientId)}',
                    );
                  } else {
                    context.go(WebRoutes.home);
                  }
                }
              } else {
                final targetRoute = getResponsiveWidth(context) == 600
                    ? Routes.mainControlerScreenForWeb
                    : Routes.homeScreen;
                Navigator.pushNamedAndRemoveUntil(
                    context, targetRoute, (route) => false);
              }
              
              // Show risk disclosure if needed (non-blocking)
              if (pref.showRiskDis != 'true') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    getResponsiveWidth(context) == 600
                        ? showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return PopScope(
                                canPop: false,
                                onPopInvokedWithResult: (didPop, result) async {
                                  if (didPop) return;
                                },
                                child: Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width *
                                        0.3,
                                    child: const RiskDisclousreBottomSheet(),
                                  ),
                                ),
                              );
                            },
                          )
                        : showModalBottomSheet(
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16))),
                            backgroundColor: const Color(0xffffffff),
                            isDismissible: false,
                            enableDrag: false,
                            showDragHandle: false,
                            useSafeArea: false,
                            isScrollControlled: true,
                            context: context,
                            builder: (BuildContext context) {
                              return PopScope(
                                  canPop: false,
                                  onPopInvokedWithResult: (didPop, result) async {
                                    if (didPop) return;
                                  },
                                  child: const RiskDisclousreBottomSheet());
                            });
                  }
                });
              }
            }
            
            // Turn off global loader immediately so screen shows
            // initLaod(false);
            await ref.read(portfolioProvider).fetchOplist(context);

            ref.read(userProfileProvider).profileloaderfun(false);
            
            // Load data asynchronously in the background (non-blocking)
            Future.microtask(() async {
              try {
                // Load essential data first (for current tab)
                await ref.read(indexListProvider).getDeafultIndexList(context);
                ref.read(marketWatchProvider).resetCurrentWatchlistPageIndex();
                
                // Load data in parallel batches for better performance
                // Batch 1: Essential portfolio data (for first tab)
                // Note: getDeafultIndexList already awaited above, no need to call again
                final essentialFutures = [
                  ref.read(portfolioProvider).fetchHoldings(context, ""),
                ];
                await Future.wait(essentialFutures);
                
                // Batch 2: Market watch and stocks data
                // Use waitis=true for watchlist: loads first watchlist immediately, others in background
                final marketFutures = [
                  ref.read(marketWatchProvider).fetchMWList(context, true),
                  ref.read(stocksProvide).fetchCAevents(),
                ];
                Future.wait(marketFutures); // Don't await - let it run in background

                // User detail carries the entitled exchanges (exarr); load it
                // first, then fetch the derivative contract master for only those
                // exchanges. One-time, resolves contract names across all screens.
                Future.microtask(() async {
                  await ref.read(userProfileProvider).fetchUserDetail(context);
                  ref.read(marketWatchProvider).fetchDerivativeMaster();
                });

                // Batch 3: Order data (load in background)
                // Only fetch order book on login — trade book and GTT are lazy-loaded when user opens those tabs
                Future.microtask(() {
                  ref.read(orderProvider).fetchOrderBook(context, false);
                });
                
                // Batch 4: Portfolio additional data (load in background)
                Future.microtask(() {
                  ref.read(portfolioProvider).fetchPositionBook(context, false);
                  ref.read(portfolioProvider).fetchPosGroupSymbol("", false);
                });
                
                // Batch 5: Transaction and funds data (load in background)
                Future.microtask(() {
                //   if (!kIsWeb) {
                //   ref.read(transcationProvider).fetchcwithdraw(context);
                //   ref.read(transcationProvider).fetchfundbank(context);
                // }
                  ref.read(transcationProvider).fetchc(context);
                  ref.read(fundProvider).fetchFunds(context);
                  // ref.read(fundProvider).fetchPledgeDetails();
                });
                
                // Batch 6: Profile and other data (load in background)
                // (fetchUserDetail moved up so exarr is ready for the master fetch)
                Future.microtask(() {
                  ref.read(userProfileProvider).getProfileimage();
                  ref.read(ledgerProvider).setterfornullallSwitch = null;
                });
                
                // Batch 7: MF and other API calls (load in background)
                Future.microtask(() {
                  // if (!kIsWeb) {
                  // setmfapicalls(context);
                  //   ref.read(mfProvider).mfApicallinit(context, 0);
                  // }
                  setProfileAPicalls();
                  setPrefOrderPrefer(context);
                  ref.read(orderProvider).setOrderIp();
                });
                
                // App version logging (non-critical, can be delayed)
                Future.microtask(() {
                  Map data = {
                    "uid": "${pref.clientId}_${pref.imei}",
                    "log": {
                      "version": _version,
                      "os": defaultTargetPlatform.toString(),
                      "devices": pref.deviceName!.toString(),
                      "date": DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())
                    }
                  };
                  api.setAppversion(data, context);
                });
              } catch (e) {
              }
            });
          } else {
            // Mobile: Keep existing synchronous behavior but optimize
            await ref.read(portfolioProvider).fetchHoldings(context, "");
            await ref.read(indexListProvider).getDeafultIndexList(context);
            ref.read(marketWatchProvider).resetCurrentWatchlistPageIndex();
            await ref.read(stocksProvide).fetchCAevents();
            // Use waitis=true: loads first watchlist immediately, others in background
            await ref.read(marketWatchProvider).fetchMWList(context, true);
            
            ref.read(ledgerProvider).setterfornullallSwitch = null;
            ref.read(userProfileProvider).getProfileimage();

            // Load remaining data in parallel
            // Only fetch order book on login — trade book and GTT are lazy-loaded when user opens those tabs
            final futures = [
              ref.read(orderProvider).fetchOrderBook(context, false),
              ref.read(portfolioProvider).fetchPositionBook(context, false),
              ref.read(portfolioProvider).fetchOplist(context)
            ];
            await Future.wait(futures);
            ref.read(transcationProvider).fetchcwithdraw(context);
            ref.read(transcationProvider).fetchfundbank(context);
            ref.read(userProfileProvider).fetchUserDetail(context);
            ref.read(portfolioProvider).fetchPosGroupSymbol("", false);
            ref.read(transcationProvider).fetchc(context);
            
            ref.read(fundProvider).fetchPledgeDetails();
            setmfapicalls(context);
            ref.read(mfProvider).mfApicallinit(context, 0);
            setProfileAPicalls();
            setPrefOrderPrefer(context);
            ref.read(orderProvider).setOrderIp();
            
            if (s.isEmpty) {
              // For web, use GoRouter for URL-based navigation
              // Only navigate to home if coming from login/splash
              // Don't navigate if already on an authenticated route (preserves URL on refresh)
              if (kIsWeb) {
                final currentPath = WebNavigationHelper.getCurrentPath();
                final isOnAuthRoute = currentPath == WebRoutes.login ||
                                      currentPath == WebRoutes.splash ||
                                      currentPath.isEmpty;
                if (context.mounted && isOnAuthRoute) {
                  // If user arrived at /login via the OAuth redirect, the client_id
                  // travels along in the URL. Read it off Uri.base and return there.
                  final oauthClientId = Uri.base.queryParameters['client_id'];
                  if (oauthClientId != null && oauthClientId.isNotEmpty) {
                    context.go(
                      '${WebRoutes.oauthAuthorize}?client_id=${Uri.encodeQueryComponent(oauthClientId)}',
                    );
                  } else {
                    context.go(WebRoutes.home);
                  }
                }
              } else {
                getResponsiveWidth(context) == 600
                    ? Navigator.pushNamedAndRemoveUntil(
                        context, Routes.mainControlerScreenForWeb, (route) => false)
                    : Navigator.pushNamedAndRemoveUntil(
                        context, Routes.homeScreen, (route) => false);
              }

              if (pref.showRiskDis != 'true') {
                getResponsiveWidth(context) == 600
                    ? showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return PopScope(
                            canPop: false,
                            onPopInvokedWithResult: (didPop, result) async {
                              if (didPop) return;
                            },
                            child: Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.3,
                                child: const RiskDisclousreBottomSheet(),
                              ),
                            ),
                          );
                        },
                      )
                    : showModalBottomSheet(
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16))),
                        backgroundColor: const Color(0xffffffff),
                        isDismissible: false,
                        enableDrag: false,
                        showDragHandle: false,
                        useSafeArea: false,
                        isScrollControlled: true,
                        context: context,
                        builder: (BuildContext context) {
                          return PopScope(
                              canPop: false,
                              onPopInvokedWithResult: (didPop, result) async {
                                if (didPop) return;
                              },
                              child: const RiskDisclousreBottomSheet());
                        });
              }
            }

            await ref.read(fundProvider).fetchFunds(context);
            Map data = {
              "uid": "${pref.clientId}_${pref.imei}",
              "log": {
                "version": _version,
                "os": defaultTargetPlatform.toString(),
                "devices": pref.deviceName!.toString(),
                "date": DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())
              }
            };
            api.setAppversion(data, context);
          }
        } else {
          // Handle invalid session by redirecting to login
          _handleNetworkFailure(context, "Session invalid");
        }
      } catch (_) {}
    } on SocketException catch (e) {
      _handleNetworkFailure(context, "Network connection issue: ${e.message}");
    } on HttpException catch (e) {
      _handleNetworkFailure(
          context, "Server communication error: ${e.message}");
    } on TimeoutException catch (_) {
      _handleNetworkFailure(context, "Connection timed out");
    } catch (_) {
      _handleNetworkFailure(context, "Error connecting to server");
    } finally {
      // Only set loader to false if not already done (for web case)
      if (s != "switchAc") {
        Future.delayed(const Duration(milliseconds: 1000), () {
          initLaod(false);
        });
      }
      ref.read(userProfileProvider).profileloaderfun(false);
    }
  }

  // Helper method to handle network failures and redirect to login
  void _handleNetworkFailure(BuildContext context, String errorMessage) {

    // Clear user session
    pref.clearClientSession();
    pref.setLogout(true);
    pref.setHideLoginOptBtn(false);
    pref.setMobileLogin(false);

    // Clear session state from index list provider to ensure fresh data load on re-login
    ref.read(indexListProvider).clearSessionState();

    // Clear banner seen storage on logout (network failure scenario)
    ref.read(bannerProvider).onUserLogout();

    // Clear pending watchlists on logout (network failure scenario)
    ref.read(marketWatchProvider).clearPendingWatchlists();

    // Update UI state
    ref.read(indexListProvider).bottomMenu(0, context);

    // If we have client ID, prefill the login field
    if (pref.clientId != null && pref.clientId!.isNotEmpty) {
      loginMethCtrl.text = pref.clientId!;
    }

    // Close WebSocket connection (force to handle stuck _connecting state)
    ref.read(websocketProvider).closeSocket(true, force: true);
    ref.read(websocketProvider).websockConn(false);

    // Cancel any active timers
    if (ConstantName.timer != null) {
      ConstantName.timer!.cancel();
    }

    // Navigate to login screen if not already there
    if (context.mounted && currentRouteName != Routes.loginScreen) {
      // Use GoRouter for web, Navigator for mobile
      if (kIsWeb) {
        context.go(WebRoutes.login);
        ResponsiveSnackBar.showWarning(context,
            "Connection issue. Please check your internet and try again.");
      } else {
        Navigator.pushNamedAndRemoveUntil(
            context, Routes.loginScreen, (route) => false);
        warningMessage(context,
            "Connection issue. Please check your internet and try again.");
      }
    }
  }

  setIposAPicalls(BuildContext context) async {
    // await ref.read(ipoProvide).getDashboardIpos();
    await ref.read(ipoProvide).fetchAllOpenIpos(context);
    await ref.read(ipoProvide).getUpcomingIpoModel();
    await ref.read(ipoProvide).getipoperfomance(currentYear);
    await ref.read(ipoProvide).mergemainsme();
    await ref.read(ipoProvide).fetchIpoPreClose();
  }

  setmfapicalls(context) async {
    ref.read(mfProvider).fetchnewMFBestList();
    // ref.read(mfProvider).fetchMFCategoryList("Z", "Z");
    ref.read(mfProvider).fetchmfallcatnew();
    ref.read(mfProvider).fetchmfNFO(context);
    // ref.read(mfProvider).fetchMFWatchlist("", "", context, true, "");

    // ref.read(mfProvider).fetchmfNFO(context);
  }

  setPrefOrderPrefer(BuildContext context) async {
    Map getsavedOrderPreference = await api.setOrderprefer({}, false, context);
    Map local = {};
    String getapplocal = "";
    if (pref.showOrderpref != null) {
      getapplocal = pref.showOrderpref!;
    }

    if (getsavedOrderPreference.isNotEmpty &&
        getsavedOrderPreference.containsKey("metadata") &&
        getsavedOrderPreference["metadata"].containsKey("expos")) {
      _savedOrderPreference = getsavedOrderPreference['metadata'];
    } else if ((getapplocal.isNotEmpty && getapplocal.contains("expos"))) {
      local = {
        "clientid": pref.clientId,
        "metadata": jsonDecode(getapplocal),
        "source": "FWEB"
      };
      _savedOrderPreference = jsonDecode(getapplocal);
      await api.setOrderprefer(local, true, context);
    } else {
      local = {
        "clientid": pref.clientId,
        "metadata": {
          "prc": "Limit",
          "prd": "Delivery",
          "qtypref": "qty",
          "qty": "1",
          "validity": "DAY",
          "mrkprot": "1",
          "expos": "Market",
          "stickysrc": false,
        },
        "source": "FWEB"
      };
      _savedOrderPreference = local['metadata'];
      await api.setOrderprefer(local, true, context);
      // String jsonString = jsonEncode(local);
      // await pref.setOrderprefer("ord_prf_${pref.clientId}", jsonString);
    }
  }

  getPrefOrderPrefer(Map data, bool url, BuildContext context) async {
    await api.setOrderprefer(data, url, context);
  }

  setProfileAPicalls() async {
    await ref.read(profileAllDetailsProvider).fetchClientProfileAllDetails();
  }

// This method calls and returns to the login screen whenever the client session expires.
  ifSessionExpired(BuildContext context, {String? target}) {
    // Check if we're already in the process of showing the login screen
    // to prevent multiple calls to this method
    print('🔴 [SESSION] ifSessionExpired called — isSessionExpiring: ${ConstantName.isSessionExpiring}');
    if (ConstantName.isSessionExpiring) {
      print('🔴 [SESSION] BLOCKED — isSessionExpiring is already true, returning early');
      return;
    }
    ConstantName.isSessionExpiring = true;

    // Prepare session cleanup operations asynchronously
    Future.microtask(() {
      print('🔴 [SESSION] Microtask started — running cleanup');
      // Close all open order/modify/GTT dialogs immediately (web only)
      if (kIsWeb) {
        OverlayManager.closeAll();
      }

      // Close PiP window if open
      PipService.closePipWindow();

      // Clear all session data first
      pref.clearClientSession();
      pref.setLogout(true);
      pref.setHideLoginOptBtn(false);
      pref.setMobileLogin(false);

      // Clear session state from index list provider to ensure fresh data load on re-login
      ref.read(indexListProvider).clearSessionState();

      // Clear banner and text nugget seen storage on session expiry
      ref.read(bannerProvider).onUserLogout();
      ref.read(textNuggetProvider).onUserLogout();

      // Clear pending watchlists on session expiry
      ref.read(marketWatchProvider).clearPendingWatchlists();

      // Prefill the login field for convenience
      loginMethCtrl.text = pref.clientId ?? "";

      // Close WebSocket early to stop needless data flow
      // Use force:true to ensure cleanup even if _connecting is stuck
      ref.read(websocketProvider).closeSocket(true, force: true);
      ref.read(websocketProvider).websockConn(false);

      // Reset web auth provider state to prevent stale session data on re-login
      if (kIsWeb) {
        ref.read(webAuthProvider).reset();
      }

      if (ConstantName.timer != null) {
        ConstantName.timer!.cancel();
      }

      ConstantName.sessCheck = false;

      print('[SESSION] Cleanup done — checking navigation');
      print('[SESSION] currentRouteName: $currentRouteName');
      print('[SESSION] Routes.loginScreen: ${Routes.loginScreen}');
      print('[SESSION] context.mounted: ${context.mounted}');

      // Navigate to login screen immediately without waiting for other operations
      if (currentRouteName != Routes.loginScreen) {
        // A short delay ensures that any pending UI operations are completed
        Future.delayed(Duration.zero, () {
          print('[SESSION] Future.delayed fired — context.mounted: ${context.mounted}');
          if (context.mounted) {
            // Use GoRouter for web, Navigator for mobile
            if (kIsWeb) {
              print('[SESSION] ✅ Navigating to login via context.go()');
              context.go(target ?? WebRoutes.login);
              ResponsiveSnackBar.showWarning(
                  context, "Session Expired, Please log in again");
            } else {
              Navigator.pushNamedAndRemoveUntil(
                  context, Routes.loginScreen, (route) => false);
              warningMessage(context, "Session Expired, Please log in again");
            }
          } else {
            print('[SESSION] ❌ context.mounted is FALSE — navigation SKIPPED!');
          }

          // Reset the flag after navigation is complete
          ConstantName.isSessionExpiring = false;
          print('[SESSION] isSessionExpiring reset to false');
        });
      } else {
        print('[SESSION] Already on login screen — skipping navigation');
        ConstantName.isSessionExpiring = false;
      }
    });
  }
}

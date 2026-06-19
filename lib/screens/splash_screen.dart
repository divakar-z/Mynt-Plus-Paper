import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../provider/auth_provider.dart';
import '../provider/network_state_provider.dart';
import '../provider/thems.dart';
import '../provider/web_auth_provider.dart';
import '../routes/route_names.dart';
import '../routes/web_router.dart';
import '../sharedWidget/internet_widget.dart';
import '../sharedWidget/snack_bar.dart';
import '../sharedWidget/splash_loader.dart';
import '../utils/auto_login_handoff.dart';
import '../utils/responsive_snackbar.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Resources already initialized in main.dart - no need to re-initialize
      initialRoute();
      ref.read(networkStateProvider).networkStream();
      ref.read(networkStateProvider).getContext(context);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    return Scaffold(
        backgroundColor: theme.isDarkMode ? Colors.black : Colors.white,
        body: Stack(children: [
         const CircularLoaderImage(),
          if (ref.read(networkStateProvider).connectionStatus ==
              ConnectivityResult.none)
            const NoInternetScreen()
        ]));
  }

//When an application is opened, it is called and operates according to a condition.
  initialRoute() async {
    final Preferences pref = locator<Preferences>();
    try {
      print(
          "Device  Name  ${pref.deviceName!} - ${pref.clientSession} ----  ${ref.read(networkStateProvider).connectionStatus} ");

      // Ensure device details exist before any login path (initialLoadMethods
      // relies on them, e.g. for a brand-new browser).
      if (pref.deviceName!.isEmpty) {
        await ref.read(authProvider).getDeviceDetails();
      }

      // URL token-based auto-login. main.dart stashed the uid/token from the
      // launch URL. Validate them BEFORE touching any stored session so a
      // wrong/expired link can't log out the current user — a real session is
      // committed only on success. On failure we fall through and the existing
      // session (if any) resumes normally below.
      if (AutoLoginHandoff.hasPending) {
        final uid = AutoLoginHandoff.uid!;
        final token = AutoLoginHandoff.token!;
        AutoLoginHandoff.clear();
        final ok = await ref
            .read(webAuthProvider)
            .tryUrlAutoLogin(context, uid, token);
        if (ok) return; // validated, session committed, navigated to home

        // Invalid/expired link — tell the user which login failed. Uses the
        // app's global toast so it survives the screen we fall through to
        // (the login page, or the already-logged-in user's dashboard).
        ResponsiveSnackBar.showError(
          context,
          'Login link for $uid is invalid or has expired.',
        );
      }

      ref.read(authProvider).loginMethCtrl.text = pref.clientId!;
      ref
          .read(authProvider)
          .switchMobToClinent(pref.clientId!.isEmpty ? false : true);
      if (pref.clientSession!.isEmpty && pref.clientId!.isNotEmpty) {
        pref.setMobileLogin(false);
        pref.setHideLoginOptBtn(false);
      } else {
        pref.setHideLoginOptBtn(true);
      }
      if (pref.clientSession!.isEmpty) {
        pref.setLogout(true);

        // For web, use GoRouter navigation
        if (kIsWeb) {
          if (mounted) context.go(WebRoutes.login);
        } else {
          pref.clientId!.isNotEmpty
              ? Navigator.pushNamedAndRemoveUntil(
                  context, Routes.loginScreen, (route) => false)
              : Navigator.pushNamedAndRemoveUntil(
                  context, Routes.loginScreenBanner, (route) => false);
        }
      } else {
        pref.setMobileLogin(true);
        if (kIsWeb) {
          // For web, validate session first before deciding where to navigate
          // checkAutoLogin will navigate to home if valid, or we show login if invalid
          if (mounted) {
            final webAuth = ref.read(webAuthProvider);
            final isValid = await webAuth.checkAutoLogin(context);
            // If session was invalid, navigate to login
            if (!isValid && mounted) {
              context.go(WebRoutes.login);
            }
            // If valid, checkAutoLogin already called initialLoadMethods which navigates to home
          }
        } else {
          await ref.read(authProvider).fetchMobileLogin(
              context, "", pref.clientId!, "", pref.imei!, true);
        }
      }
    } catch (e) {
      error(context, "Something Wrong !!!");
      log("faild to build --- $e");
    }
  }
}

import 'dart:developer';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../res/mynt_web_color_styles.dart';
import '../themes/theme.dart';
import 'core/default_change_notifier.dart';
import 'user_profile_provider.dart';
import 'market_watch_provider.dart';
import '../sharedWidget/functions.dart';
import '../screens/web/chart/web_chart_manager.dart';
import '../utils/pip_service.dart';

final themeProvider = ChangeNotifierProvider((ref) => ThemesProvider(ref));

/// ThemesProvider - Single source of truth for app theme
///
/// Usage:
/// - Mobile: Provides ThemeData to MaterialApp
/// - Web: Provides ColorScheme to ShadcnApp via getShadcnColorScheme()
/// - Components: Use shadcn.Theme.of(context) or resolveThemeColor()
class ThemesProvider extends DefaultChangeNotifier {
  final pref = locator<Preferences>();
  ThemeMode themeMode = ThemeMode.light;
  ThemeData _currentTheme = MyThemes.lightThemebanner;
  ThemeData get currentTheme => _currentTheme;

  navigateToNewPage(BuildContext context) {
    _currentTheme = MyThemes.lightTheme;
    notifyListeners();
  }

    removeUsermatrial(BuildContext context) {
    _currentTheme = MyThemes.lightThemebanner;
    notifyListeners();
  }


  List<String> themeTypes = ["Light", "Dark"];
  String _deviceTheme = "Light";

  String get deviceTheme => _deviceTheme;

  bool get isDarkMode {
    if (pref.userAppTheme == "Dark") {
      themeMode = ThemeMode.dark;
      pref.setAppTheme("Dark");
      return themeMode == ThemeMode.dark;
    }
    //else if (pref.userAppTheme == "System Default") {
    //   final brightness = SchedulerBinding.instance.window.platformBrightness;
    //   themeMode =
    //       brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
    //   pref.setTheme(themeMode == Brightness.dark ? true : false);
    //   pref.setAppTheme("System Default");
    //   return brightness == Brightness.dark;
    // }
    else {
      pref.setAppTheme("Light");
      return themeMode == ThemeMode.dark;
    }

    // return false;
  }

  /// Get shadcn ColorScheme for web platform
  /// This ensures web (ShadcnApp) stays in sync with theme changes
  shadcn.ColorScheme getShadcnColorScheme() {
    if (themeMode == ThemeMode.dark) {
      return _DarkColorScheme;
    }
    return shadcn.ColorSchemes.lightDefaultColor;
  }

  static final shadcn.ColorScheme _DarkColorScheme = shadcn.ColorScheme(
    // Brightness
    brightness: Brightness.dark,

    // Background colors
    background: MyntColors.backgroundColorDark, // #0D1117 - canvas-default
    foreground: MyntColors.textPrimaryDark, // #C9D1D9 - fg-default

    // Card / Surface
    card: MyntColors.cardDark, // #161B22 - canvas-subtle
    cardForeground: MyntColors.textPrimaryDark,

    // Popover / Overlay
    popover: MyntColors.overlayBgDark, // #161B22
    popoverForeground: MyntColors.textPrimaryDark,

    // Primary (accent blue)
    primary: MyntColors.primaryDark, // #58A6FF - accent-fg
    primaryForeground: const Color(0xFFFFFFFF),

    // Secondary
    secondary: MyntColors.cardHoverDark, // #21262D - surface-hover
    secondaryForeground: MyntColors.textPrimaryDark,

    // Muted
    muted: MyntColors.cardDark, // #161B22
    mutedForeground: MyntColors.textSecondaryDark, // #8B949E - fg-muted

    // Accent
    accent: MyntColors.cardHoverDark, // #21262D
    accentForeground: MyntColors.textPrimaryDark,

    // Destructive (error/danger)
    destructive: MyntColors.lossDark, // #F85149 - danger-fg
    destructiveForeground: const Color(0xFFFFFFFF),

    // Border
    border: MyntColors.dividerDark, // #30363D - border-default

    // Input
    input: MyntColors.dividerDark, // #30363D

    // Ring (focus)
    ring: MyntColors.primaryDark, // #58A6FF

    // Sidebar
    sidebar: MyntColors.sidebarBgDark, // #010409 - canvas-inset
    sidebarForeground: MyntColors.textPrimaryDark,
    sidebarPrimary: MyntColors.primaryDark,
    sidebarPrimaryForeground: const Color(0xFFFFFFFF),
    sidebarAccent: MyntColors.cardHoverDark, // #21262D
    sidebarAccentForeground: MyntColors.textPrimaryDark,
    sidebarBorder: MyntColors.dividerDark, // #30363D
    sidebarRing: MyntColors.primaryDark,

    // Chart colors
    chart1: MyntColors.primaryDark,
    chart2: MyntColors.profitDark,
    chart3: MyntColors.lossDark,
    chart4: MyntColors.warningDark,
    chart5: const Color(0xFFA371F7),
  );

// Getting a default app theme

  void getThemeData() async {
    _deviceTheme = pref.userAppTheme!;
    if (pref.userAppTheme == "Dark") {
      themeMode = ThemeMode.dark;
      pref.setTheme(themeMode == ThemeMode.dark);
      log('themeMode   ::: $themeMode');
      pref.setAppTheme("Dark");
      // Only set system UI overlay on mobile (not web)
      if (!kIsWeb) {
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light, // For Android (dark icons)
            statusBarBrightness: Brightness.dark,
            statusBarColor: Colors.black,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.dark));
      }
    }
    // else if (pref.userAppTheme == "System Default") {
    //   final brightness = SchedulerBinding.instance.window.platformBrightness;
    //   themeMode =
    //       brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
    //   log('themeMode System ::: $themeMode');
    //   pref.setAppTheme("System Default");
    //    pref.setTheme(themeMode == ThemeMode.dark);
    // }
    else if (pref.userAppTheme == "Light") {
      // Only set system UI overlay on mobile (not web)
      if (!kIsWeb) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark, // For Android (light icons)
            statusBarBrightness: Brightness.light,
            statusBarColor: Colors.white,
            systemNavigationBarColor: Colors.grey[200],
            systemNavigationBarIconBrightness: Brightness.dark));
      }
      themeMode = ThemeMode.light;
      pref.setTheme(themeMode == ThemeMode.dark);
      pref.setAppTheme("Light");
    }
  }

// Set app theme mode

  set isDarkMode(bool value) {
    themeMode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void toggleTheme({required String themeMod}) {
    pref.setAppTheme(themeMod);
    final brightness = SchedulerBinding.instance.window.platformBrightness;
    themeMode =
        brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;

    if (pref.userAppTheme == "Dark") {
      // Only set system UI overlay on mobile (not web)
      if (!kIsWeb) {
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light, // For Android (dark icons)
            statusBarBrightness: Brightness.dark,
            statusBarColor: Colors.black,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.dark));
      }
      _deviceTheme = "Dark";
      themeMode = ThemeMode.dark;
      pref.setTheme(true);
    } else if (pref.userAppTheme == "Light") {
      // Only set system UI overlay on mobile (not web)
      if (!kIsWeb) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark, // For Android (light icons)
            statusBarBrightness: Brightness.light,
            statusBarColor: Colors.white,
            systemNavigationBarColor: Colors.grey[200],
            systemNavigationBarIconBrightness: Brightness.dark));
      }
      _deviceTheme = "Light";
      themeMode = ThemeMode.light;
      pref.setTheme(false);
    }
    // else {
    //   _deviceTheme = "System Default";
    //   final brightness = SchedulerBinding.instance.window.platformBrightness;
    // themeMode = brightness == Brightness.dark
    //     ? ThemeMode.dark
    //    : ThemeMode.light;

    //          pref.setTheme(brightness == Brightness.dark);
    // }
    ref.read(userProfileProvider).fetchsetting();
    // Update chart iframe theme on web
    if (kIsWeb) {
      final activeTab = ref.read(marketWatchProvider).activeTab;
      if (activeTab != null) {
        webChartManager.changeSymbol(
          exch: activeTab.exch,
          token: activeTab.token,
          tsym: activeTab.tsym,
          isDarkMode: isDarkMode,
          decorativeName:
              DerivativeMaster.nameFor(activeTab.exch, activeTab.token),
        );
      }
      // Update PiP window theme if open
      PipService.updateTheme(isDarkMode);
    }
    notifyListeners();  // This will trigger rebuild of both MaterialApp (mobile) and ShadcnApp (web)
  }

  final Ref ref;
  ThemesProvider(this.ref);
}

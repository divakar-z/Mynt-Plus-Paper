import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/global_state_text.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/app_spacing.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/provider/api_key_provider.dart';
import 'package:mynt_plus/provider/auth_provider.dart';
import 'package:mynt_plus/provider/change_password_provider.dart';
import 'package:mynt_plus/provider/fund_provider.dart';
import 'package:mynt_plus/provider/profile_all_details_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/user_profile_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart' show ScreenType;

import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/common_text_fields_web.dart';
import 'package:mynt_plus/sharedWidget/enums.dart';
import 'Api_key_screen.dart';
import 'api_key_screen_new.dart';

/// Callback type for screen navigation from profile dropdown
typedef OnNavigateToScreenCallback = void Function(ScreenType screenType);

/// InheritedWidget to access profile callbacks from child widgets
class ProfileNavigationCallback extends InheritedWidget {
  final VoidCallback? onClose;
  final OnNavigateToScreenCallback? onNavigateToScreen;

  const ProfileNavigationCallback({
    super.key,
    this.onClose,
    this.onNavigateToScreen,
    required super.child,
  });

  static ProfileNavigationCallback? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ProfileNavigationCallback>();
  }

  @override
  bool updateShouldNotify(ProfileNavigationCallback oldWidget) {
    return onClose != oldWidget.onClose || onNavigateToScreen != oldWidget.onNavigateToScreen;
  }
}

class ProfileMainScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final void Function(ScreenType)? onNavigateToScreen;
  const ProfileMainScreen({super.key, this.initialIndex = 0, this.onNavigateToScreen});

  @override
  ConsumerState<ProfileMainScreen> createState() => _ProfileMainScreenState();
}

class _ProfileMainScreenState extends ConsumerState<ProfileMainScreen> {
  // Currently displayed child screen (null = main menu)
  Widget? _currentChildScreen;
  String? _currentChildTitle;

  @override
  void initState() {
    super.initState();
    // If initialIndex is provided, navigate to that section
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (widget.initialIndex == 3) {
    //     // Settings
    //     _navigateToChild('Settings', const _SettingsSection());
    //   }
    // });
  }

  void _navigateToChild(String title, Widget child) {
    setState(() {
      _currentChildTitle = title;
      _currentChildScreen = child;
    });
  }

  void _navigateBack() {
    setState(() {
      _currentChildTitle = null;
      _currentChildScreen = null;
    });
  }

  /// Navigate to a screen in the main panel and close the dropdown
  void _navigateToScreenInPanel(ScreenType screenType) {
    // Use the ProfileNavigationCallback InheritedWidget to get the callback
    final callback = ProfileNavigationCallback.of(context);
    callback?.onNavigateToScreen?.call(screenType);
  }

  /// Close the dropdown
  void _closeDropdown() {
    final callback = ProfileNavigationCallback.of(context);
    callback?.onClose?.call();
  }

  String formatIndianCurrency(String amount) {
    final formatter = NumberFormat.currency(
      locale: "en_IN",
      symbol: '',
      decimalDigits: 2,
    );
    return formatter.format(double.tryParse(amount) ?? 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final isDark = theme.isDarkMode;

    if (widget.initialIndex == 0) {
      return MyAccountScreen(onNavigateToScreen: widget.onNavigateToScreen);
    }
    return _SettingsSection();

    // If we have a child screen, show it with a back button
    // if (_currentChildScreen != null) {
    //   return Container(
    //     color: isDark ? const Color(0xFF121212) : Colors.white,
    //     child: Column(
    //       children: [
    //         // Header with back button
    //         Container(
    //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    //           decoration: BoxDecoration(
    //             border: Border(
    //               bottom: BorderSide(
    //                 color: isDark ? MyntColors.dividerDark : MyntColors.divider,
    //               ),
    //             ),
    //           ),
    //           child: Row(
    //             children: [
    //               Column(
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 mainAxisSize: MainAxisSize.min,
    //                 children: [
    //                   Text(
    //                     _currentChildTitle ?? '',
    //                     style: MyntWebTextStyles.title(context, 
    //                       color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),fontWeight: MyntFonts.medium).copyWith(decoration: TextDecoration.none)),
    //                   if (_currentChildTitle == 'Settings')
    //                     Padding(
    //                       padding: const EdgeInsets.only(top: 8.0),
    //                       child: Text(
    //                         "Catch the log, setting up preference, get API key, and change themes.",
    //                         style: MyntWebTextStyles.body(context, 
    //                           color: resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary),fontWeight: MyntFonts.regular).copyWith(decoration: TextDecoration.none)),
    //                     ),
    //                 ],
    //               ),
    //             ],
    //           ),
    //         ),
    //         // Child content
    //         Expanded(child: _currentChildScreen!),
    //       ],
    //     ),
    //   );
    // }

    // // Main profile menu
    // return _buildMainMenu(theme);
  }

  Widget _buildMainMenu(ThemesProvider theme) {
    final userProfile = ref.watch(userProfileProvider);
    final funds = ref.watch(fundProvider);

    final userName = userProfile.userDetailModel?.uname ?? 'User';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MyntColors.primary,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        userInitial,
                        style: MyntWebTextStyles.title(context,
                            color: MyntColors.primary,
                            fontWeight: MyntFonts.semiBold).copyWith(fontSize: 32),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // User Name with chevron
                  InkWell(
                    onTap: () => _navigateToChild('My Profile', const _ProfileDetailsSection()),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              userName,
                              overflow: TextOverflow.ellipsis,
                              style: MyntWebTextStyles.title(context,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary,
                                  fontWeight: MyntFonts.semiBold),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Account Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: resolveThemeColor(context,
                          dark: MyntColors.listItemBgDark,
                          light: MyntColors.listItemBg),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: resolveThemeColor(context,
                            dark: MyntColors.dividerDark,
                            light: MyntColors.divider),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Balance',
                              style: MyntWebTextStyles.caption(context,
                                  darkColor: MyntColors.textSecondaryDark,
                                  lightColor: MyntColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatIndianCurrency(funds.fundDetailModel?.avlMrg ?? "0.00"),
                              style: MyntWebTextStyles.title(context,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary,
                                  fontWeight: MyntFonts.semiBold),
                            ),
                          ],
                        ),
                        OutlinedButton(
                          onPressed: () {
                            _closeDropdown();
                            _navigateToScreenInPanel(ScreenType.funds);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MyntColors.primary,
                            side: const BorderSide(color: MyntColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text('Add Money',
                              style: MyntWebTextStyles.bodySmall(context,
                                  color: MyntColors.primary,
                                  fontWeight: MyntFonts.medium)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Menu Items - navigate to screens in main panel
                  _buildMenuItem(
                    theme,
                    title: 'Pledge & Unpledge',
                    onTap: () {
                      _navigateToScreenInPanel(ScreenType.pledgeUnpledge);
                    },
                  ),

                  _buildMenuItem(
                    theme,
                    title: 'Corporate Actions',
                    onTap: () {
                      _navigateToScreenInPanel(ScreenType.corporateActions);
                    },
                  ),

                  _buildMenuItem(
                    theme,
                    title: 'Reports',
                    onTap: () {
                      _navigateToScreenInPanel(ScreenType.reports);
                    },
                  ),

                  _buildMenuItem(
                    theme,
                    title: 'Settings',
                    onTap: () {
                      _navigateToScreenInPanel(ScreenType.settings);
                    },
                  ),

                  _buildMenuItem(
                    theme,
                    title: 'Notification',
                    onTap: () {
                      // Navigate to notifications if available
                      _closeDropdown();
                    },
                  ),

                  _buildMenuItem(
                    theme,
                    title: 'Refer & Get ₹300',
                    onTap: () {
                      // Navigate to referral screen
                      _closeDropdown();
                    },
                  ),

                  _buildMenuItem(
                    theme,
                    title: 'Rate Us',
                    onTap: () {
                      // Open app store rating
                      _closeDropdown();
                    },
                  ),

                  const SizedBox(height: 16),

                  // Logout button
                  InkWell(
                    onTap: () => _showLogoutDialog(context, theme),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            size: 18,
                            color: MyntColors.loss,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Logout',
                            style: MyntWebTextStyles.bodySmall(context,
                                color: MyntColors.loss,
                                fontWeight: MyntFonts.semiBold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Version at bottom
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Version 3.0.2',
              style: MyntWebTextStyles.caption(context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(ThemesProvider theme, {required String title, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: resolveThemeColor(context,
                    dark: MyntColors.dividerDark,
                    light: MyntColors.divider.withValues(alpha: 0.5)),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: MyntWebTextStyles.bodySmall(context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, ThemesProvider theme) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: resolveThemeColor(ctx,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          title: Text(
            "Confirmation",
            style: MyntWebTextStyles.title(ctx,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.medium),
          ),
          content: Text(
            "Are you sure you want to logout?",
            style: MyntWebTextStyles.bodySmall(ctx,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel",
                  style: MyntWebTextStyles.bodySmall(ctx,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(authProvider).fetchLogout(context);
              },
              child: Text("Logout",
                  style: MyntWebTextStyles.bodySmall(ctx,
                      color: MyntColors.loss,
                      fontWeight: MyntFonts.semiBold)),
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// SETTINGS SECTION
// -----------------------------------------------------------------------------
class _SettingsSection extends ConsumerStatefulWidget {
  const _SettingsSection();

  @override
  ConsumerState<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends ConsumerState<_SettingsSection> {
  // Order preference state - using same variable names as order_prefere_screen.dart
  String priceType = "Limit";
  String expriceType = "Market";
  String orderType = "Delivery";
  String validity = "DAY";
  OrdQtyPref QtyPrefer = OrdQtyPref.mktqty;

  // Text controllers for editable fields
  TextEditingController mktProtCtrl = TextEditingController(text: "1");
  TextEditingController qtyCtrl = TextEditingController(text: "1");

  // Additional web-specific settings
  bool _stickyOrderWindow = false;
  bool _quickOrderScreen = false;

  // New Password (Change Password section) — transient max-length error.
  // Same pattern as the login screen's Forgot/Change Password field: fired
  // only when the user actually attempts to type/paste beyond 12 chars
  // (caught by the custom inputFormatter). Auto-hides after 2 seconds.
  bool _showNewPwdMaxLengthError = false;
  Timer? _newPwdMaxLengthHideTimer;

  // True once we've kicked off the TOTP fetch for this mounting of the
  // settings section. Reset on widget dispose (i.e., on logout/navigate-away),
  // so re-entering settings after re-login refetches cleanly.
  bool _totpFetchTriggered = false;

  @override
  void initState() {
    super.initState();
    // Fetch API keys and TOTP on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(apikeyprovider).fetchapikey(context);
      _loadSavedOrderPreferences();
    });
  }

  @override
  void dispose() {
    mktProtCtrl.dispose();
    qtyCtrl.dispose();
    _newPwdMaxLengthHideTimer?.cancel();
    super.dispose();
  }

  /// Triggered by the New Password field's custom inputFormatter when the
  /// user attempts to type/paste beyond 12 chars. Shows the inline red
  /// "Password must be exactly 12 characters" error briefly, then auto-hides
  /// after 2 seconds so the message disappears once the user stops trying.
  void _triggerNewPwdMaxLengthError() {
    if (!mounted) return;
    _newPwdMaxLengthHideTimer?.cancel();
    setState(() => _showNewPwdMaxLengthError = true);
    _newPwdMaxLengthHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showNewPwdMaxLengthError = false);
    });
  }

  /// Load saved order preferences from authProvider (same logic as order_prefere_screen.dart)
  void _loadSavedOrderPreferences() {
    if (!mounted) return;
    final userSavedOrderPreference = ref.read(authProvider).savedOrderPreference;
    if (userSavedOrderPreference.isNotEmpty && mounted) {
      setState(() {
        // Use same logic as order_prefere_screen.dart initState
        updatePriceAndOrderTypes(
            userSavedOrderPreference['prd'], userSavedOrderPreference['prc']);
        validity = userSavedOrderPreference['validity'] ?? 'DAY';
        QtyPrefer = userSavedOrderPreference['qtypref'] == 'lot'
            ? OrdQtyPref.mktlot
            : OrdQtyPref.mktqty;
        qtyCtrl = TextEditingController(text: "${userSavedOrderPreference['qty'] ?? '1'}");
        mktProtCtrl = TextEditingController(text: "${userSavedOrderPreference['mrkprot'] ?? '1'}");
        expriceType = ["Limit", "Market"].contains(userSavedOrderPreference['expos'])
            ? userSavedOrderPreference['expos']
            : 'Market';
        // Load sticky order window setting (handle both boolean and string values, default to false if null)
        _stickyOrderWindow = userSavedOrderPreference['stickysrc'] == true || userSavedOrderPreference['stickysrc'] == "True";
      });
    }
  }

  /// Update price and order types (same as order_prefere_screen.dart)
  void updatePriceAndOrderTypes(selectedOrderType, selectedPriceType) {
    orderType = selectedOrderType == "Cover" || selectedOrderType == "Bracket"
        ? "CO - BO"
        : (selectedOrderType ?? "Delivery");
    priceType = (orderType == "CO - BO" && selectedPriceType == "SL MKT")
        ? "Market"
        : (selectedPriceType ?? "Limit");
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Settings",
                        style: MyntWebTextStyles.title(context, 
                          color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),fontWeight: MyntFonts.medium).copyWith(decoration: TextDecoration.none)),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            "Catch the log, setting up preference, get API key, and change themes.",
                            style: MyntWebTextStyles.body(context, 
                              color: resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary),fontWeight: MyntFonts.regular).copyWith(decoration: TextDecoration.none)),
                        ),
                        const SizedBox(height: 16),
                    ],
                  ),
        Container(
          padding: const EdgeInsets.only(right: 16.0),
          decoration: BoxDecoration(
            border: Border.all(color: theme.isDarkMode ? MyntColors.dividerDark : MyntColors.divider),
            borderRadius: BorderRadius.circular(8),
          ),
          child: shadcn.Accordion(
            items: [
            // API Key
            shadcn.AccordionItem(
              trigger: shadcn.AccordionTrigger(
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('API Key', style: MyntWebTextStyles.titlesub(context, 
                      color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),fontWeight: MyntFonts.medium).copyWith(decoration: TextDecoration.none)),
                  ),
                ),
              ),
              content: FractionallySizedBox(
                widthFactor: 0.5,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: _buildApiKeyContent(theme),
                ),
              ),
            ),
            
            // TOTP
            shadcn.AccordionItem(
              trigger: Listener(
                // Listener observes pointer events without consuming them, so
                // AccordionTrigger still toggles expansion normally. We use it
                // to lazily fetch the TOTP key the first time the section is
                // tapped instead of on screen load.
                onPointerDown: (_) => _ensureTotpFetched(),
                child: shadcn.AccordionTrigger(
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('TOTP', style: MyntWebTextStyles.titlesub(context,
                        color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),fontWeight: MyntFonts.medium).copyWith(decoration: TextDecoration.none)),
                    ),
                  ),
                ),
              ),
              content: FractionallySizedBox(
                widthFactor: 0.5,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: _buildTotpContent(theme,context),
                ),
              ),
            ),
            
            // Password & Security
            shadcn.AccordionItem(
              trigger: shadcn.AccordionTrigger(
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Change Password ', style: MyntWebTextStyles.titlesub(context, 
                      color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),fontWeight: MyntFonts.medium).copyWith(decoration: TextDecoration.none)),
                  ),
                ),
              ),
              content: FractionallySizedBox(
                widthFactor: 0.5,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: _buildPasswordSecurityContent(theme),
                ),
              ),
            ),
            
            // Themes
            // shadcn.AccordionItem(
            //   trigger: shadcn.AccordionTrigger(
            //     child: SizedBox(
            //       width: double.infinity,
            //       child: Padding(
            //         padding: const EdgeInsets.symmetric(horizontal: 16.0),
            //         child: Text('Themes', style: MyntWebTextStyles.title(context, 
            //           color: theme.isDarkMode ? MyntColors.textPrimaryDark : MyntColors.textPrimary).copyWith(decoration: TextDecoration.none)),
            //       ),
            //     ),
            //   ),
            //   content: FractionallySizedBox(
            //     widthFactor: 0.5,
            //     alignment: Alignment.centerLeft,
            //     child: Padding(
            //       padding: const EdgeInsets.only(left: 16.0),
            //       child: _buildThemesContent(theme),
            //     ),
            //   ),
            // ),
            
            // Order Preference
            shadcn.AccordionItem(
              trigger: shadcn.AccordionTrigger(
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Order Preference', style: MyntWebTextStyles.titlesub(context, 
                      color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),fontWeight: MyntFonts.medium).copyWith(decoration: TextDecoration.none)),
                  ),
                ),
              ),
              content: FractionallySizedBox(
                widthFactor: 0.5,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: _buildOrderPreferenceContent(theme),
                ),
              ),
            ),
            
            // Freeze Account
            shadcn.AccordionItem(
              trigger: shadcn.AccordionTrigger(
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Freeze Account', style: MyntWebTextStyles.titlesub(context, 
                      color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),fontWeight: MyntFonts.medium).copyWith(decoration: TextDecoration.none)),
                  ),
                ),
              ),
              content: FractionallySizedBox(
                widthFactor: 0.5,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: _buildFreezeAccountContent(theme),
                ),
              ),
            ),
          ],
        ),
        ),
      ],
    );
  }

  Widget _buildApiKeyContent(ThemesProvider theme) {
    // Use ConstrainedBox to allow content to grow while maintaining reasonable bounds
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 300,
        maxHeight: 500,
      ),
      child: const ApiKeyBottomTabs(),
    );
  }

  /// Kick off a TOTP fetch the first time the user expands the TOTP section.
  /// Idempotent for the lifetime of this State — re-running has no effect.
  /// State is reset when the widget is disposed (e.g., on logout/navigation),
  /// so a fresh login starts with a clean fetch.
  void _ensureTotpFetched() {
    if (_totpFetchTriggered) return;
    _totpFetchTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(apikeyprovider).fetchTotp();
    });
  }

  Widget _buildTotpContent(ThemesProvider theme, BuildContext context) {
    final apikeys = ref.watch(apikeyprovider);
    final isDark = theme.isDarkMode;

    // In-flight fetch/generate — show a loader.
    if (apikeys.isFetchingTotp) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Key already exists (non-empty pwd) — show the inline TOTP widget.
    // Regenerate hits the same GenSecretKey endpoint as the initial generate.
    final totpPwd = apikeys.totpkey?.pwd;
    if (totpPwd != null && totpPwd.isNotEmpty) {
      return _TotpInlineWidget(
        // Keyed by the secret so a regenerate forces the timer/HMAC
        // state inside the widget to reset cleanly.
        key: ValueKey(totpPwd),
        secretKey: totpPwd,
        isDark: isDark,
        onRegenerate: () => ref.read(apikeyprovider).generateTotp(),
      );
    }

    // GetSecretKey returned empty (or hasn't run yet) — show generate button.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generate TOTP for 2FA authentication',
            style: MyntWebTextStyles.bodySmall(context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary),
          ),
          const SizedBox(height: 16),
          MyntPrimaryButton(
            label: "Generate TOTP",
            onPressed: () => ref.read(apikeyprovider).generateTotp(),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSecurityContent(ThemesProvider theme) {
    final isDark = theme.isDarkMode;
    final changePassword = ref.watch(changePasswordProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your Password',
            style: MyntWebTextStyles.title(context,
                fontWeight: MyntFonts.semiBold,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary),
          ),
          const SizedBox(height: 20),

          // Old Password Field
          Text(
            'Old Password',
            style: MyntWebTextStyles.body(context,
                fontWeight: MyntFonts.medium,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 400,
            child: MyntFormTextField(
              controller: changePassword.oldPassword,
              placeholder: 'Enter old password',
              height: 40,
              obscureText: changePassword.hideoldpassword,
              readOnly: changePassword.loading,
              trailingWidget: IconButton(
                icon: Icon(
                  changePassword.hideoldpassword ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
                onPressed: () {
                  changePassword.hiddeoldpasswords();
                  changePassword.activateChangePass();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              onChanged: (v) {
                changePassword.validateOldPassword();
                changePassword.activateChangePass();
              },
            ),
          ),
          if (changePassword.oldPasswordError != null && changePassword.oldPasswordError!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                changePassword.oldPasswordError!,
                style: MyntWebTextStyles.caption(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.lossDark,
                        light: MyntColors.loss)),
              ),
            ),
          const SizedBox(height: 16),

          // New Password Field
          Text(
            'New Password',
            style: MyntWebTextStyles.body(context,
                fontWeight: MyntFonts.medium,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 400,
            child: MyntFormTextField(
              controller: changePassword.newPassword,
              placeholder: 'Enter new password',
              height: 40,
              obscureText: changePassword.hidenewpassword,
              readOnly: changePassword.loading,
              // Backend enforces max 12 chars + alphanumeric + allowed
              // specials (#, $, -, *, @). Mirror that at the input level so
              // disallowed characters can't be typed and overflow gets
              // surfaced via the transient red error below.
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[A-Za-z0-9#$\-*@]'),
                ),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (newValue.text.length > 12) {
                    _triggerNewPwdMaxLengthError();
                    final truncated = newValue.text.substring(0, 12);
                    return TextEditingValue(
                      text: truncated,
                      selection: TextSelection.collapsed(
                          offset: truncated.length),
                    );
                  }
                  return newValue;
                }),
              ],
              trailingWidget: IconButton(
                icon: Icon(
                  changePassword.hidenewpassword ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
                onPressed: () {
                  changePassword.hiddenewpasswords();
                  changePassword.activateChangePass();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              onChanged: (v) {
                changePassword.validateNewPassword();
                changePassword.activateChangePass();
              },
            ),
          ),
          // Transient red error: takes priority over the missing-requirements
          // error so the user sees the most recent reason their input was
          // rejected (overflow attempt vs unmet requirements).
          if (_showNewPwdMaxLengthError)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                "Password must be exactly 12 characters",
                style: MyntWebTextStyles.caption(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.lossDark,
                        light: MyntColors.loss)),
              ),
            )
          else if (changePassword.newPasswordError != null && changePassword.newPasswordError!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                changePassword.newPasswordError!,
                style: MyntWebTextStyles.caption(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.lossDark,
                        light: MyntColors.loss)),
              ),
            ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: () {
                    changePassword.changePassMethod();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                    side: BorderSide(
                      color: resolveThemeColor(context,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    elevation: 0,
                  ),
                  child: Text(
                    'Cancel',
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.bold,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: changePassword.loading
                      ? null
                      : changePassword.oldPassword.text.isEmpty ||
                              changePassword.newPassword.text.isEmpty
                          ? () {
                              changePassword.validateOldPassword();
                              changePassword.validateNewPassword();
                            }
                          : () async {
                              // Set userId if not already set
                              if (changePassword.userIdController.text.isEmpty) {
                                final pref = locator<Preferences>();
                                changePassword.userIdController.text = "${pref.clientId}";
                              }

                              // Validate fields
                              changePassword.validateOldPassword();
                              changePassword.validateNewPassword();
                              changePassword.activateChangePass();

                              if ((changePassword.oldPasswordError != null && changePassword.oldPasswordError!.isNotEmpty) ||
                                  (changePassword.newPasswordError != null && changePassword.newPasswordError!.isNotEmpty)) {
                                return;
                              }

                              // Call API with preventNavigation for web
                              await changePassword.fetchChangePassword(
                                changePassword.userIdController.text.toUpperCase(),
                                changePassword.oldPassword.text,
                                changePassword.newPassword.text,
                                context,
                                preventNavigation: true,
                              );

                              // After successful password change, logout on web
                              if (changePassword.changepasswordmodel?.stat == "Ok" && mounted && context.mounted) {
                                ref.read(authProvider).fetchLogout(context);
                              }
                            },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? MyntColors.secondary : MyntColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    elevation: 0,
                    disabledBackgroundColor: resolveThemeColor(context,
                        dark: MyntColors.borderMutedDark,
                        light: MyntColors.borderMuted),
                  ),
                  child: changePassword.loading
                      ? MyntLoader.inline(color: Colors.white)
                      : Text(
                          'Set New Password',
                          style: MyntWebTextStyles.body(context,
                              fontWeight: MyntFonts.bold,
                              color: MyntColors.backgroundColor),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemesContent(ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: theme.themeTypes.map((t) {
          final isSelected = t == theme.deviceTheme;
          return Padding(
            padding: const EdgeInsets.only(right: 24),
            child: InkWell(
              onTap: () => theme.toggleTheme(themeMod: t),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? MyntColors.primary
                            : resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                        width: 2,
                      ),
                      color: Colors.transparent,
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: MyntColors.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t,
                    style: MyntWebTextStyles.para(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderPreferenceContent(ThemesProvider theme) {
    final isDark = theme.isDarkMode;

    // Map orderType to display value for segmented button
    String getProductTypeDisplay() {
      if (orderType == 'Delivery') return 'Delivery / Carry';
      return orderType;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Type
          _buildLabel('Product type', isDark),
          const SizedBox(height: 8),
          _buildSegmentedButton(
            options: ['Delivery / Carry', 'Intraday', 'CO - BO'],
            selected: getProductTypeDisplay(),
            onChanged: (val) => setState(() {
              orderType = val == 'Delivery / Carry' ? 'Delivery' : val;
              updatePriceAndOrderTypes(orderType, priceType);
            }),
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Order Type (Price Type)
          _buildLabel('Order type', isDark),
          const SizedBox(height: 8),
          _buildSegmentedButton(
            options: orderType == "CO - BO"
                ? ['Limit', 'Market', 'SL Limit']
                : ['Limit', 'Market', 'SL Limit', 'SL MKT'],
            selected: priceType,
            onChanged: (val) => setState(() {
              priceType = val;
              updatePriceAndOrderTypes(orderType, priceType);
            }),
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Validity
          _buildLabel('Validity', isDark),
          const SizedBox(height: 8),
          _buildSegmentedButton(
            options: ['DAY', 'IOC'],
            selected: validity,
            onChanged: (val) => setState(() => validity = val),
            isDark: isDark,
            compact: true,
          ),
          const SizedBox(height: 16),

          // Market Protection
          _buildLabel('Market Protection', isDark),
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            height: 40,
            child: TextField(
              controller: mktProtCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: MyntWebTextStyles.para(context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
              ),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Text(
                    '%',
                    style: MyntWebTextStyles.para(context,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary,
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? MyntColors.dividerDark : MyntColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? MyntColors.dividerDark : MyntColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary)),
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  int parsed = int.tryParse(value) ?? 1;
                  if (parsed > 20) {
                    mktProtCtrl.text = '20';
                    mktProtCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: mktProtCtrl.text.length),
                    );
                    ResponsiveSnackBar.showWarning(context, "Can't enter greater than 20% of Market Protection");
                  } else if (parsed < 1) {
                    mktProtCtrl.text = '1';
                    mktProtCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: mktProtCtrl.text.length),
                    );
                    ResponsiveSnackBar.showWarning(context, "Can't enter less than 1% of Market Protection");
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // Quantity Preference
          _buildLabel('Quantity preference', isDark),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRadioOption('Default Qty / Lot', QtyPrefer == OrdQtyPref.mktqty,
                () => setState(() {
                  QtyPrefer = OrdQtyPref.mktqty;
                  qtyCtrl.text = "1";
                }), isDark),
              const SizedBox(width: 48),
              _buildRadioOption('Multiples of Qty / Lot', QtyPrefer == OrdQtyPref.mktlot,
                () => setState(() => QtyPrefer = OrdQtyPref.mktlot), isDark),
            ],
          ),
          // Show quantity input when "Multiples of Qty / Lot" is selected
          if (QtyPrefer == OrdQtyPref.mktlot) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 100,
              height: 40,
              child: TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: MyntWebTextStyles.para(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Qty',
                  hintStyle: MyntWebTextStyles.para(context,
                    darkColor: MyntColors.textSecondaryDark.withValues(alpha: 0.5),
                    lightColor: MyntColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? MyntColors.dividerDark : MyntColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? MyntColors.dividerDark : MyntColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary)),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Position Exit
          _buildLabel('Position Exit $expriceType', isDark),
          const SizedBox(height: 8),
          _buildSegmentedButton(
            options: ['Limit', 'Market'],
            selected: expriceType,
            onChanged: (val) => setState(() => expriceType = val),
            isDark: isDark,
            compact: true,
          ),
          const SizedBox(height: 16),

          // Toggles
          _buildToggleRow('Sticky Order Window', _stickyOrderWindow,
            (val) => setState(() => _stickyOrderWindow = val), isDark),
          // const SizedBox(height: 8),
          // _buildToggleRow('Quick Order Screen', _quickOrderScreen,
          //   (val) => setState(() => _quickOrderScreen = val), isDark),
          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              MyntOutlinedButton(
                label: 'Reset',
                onPressed: () {
                  _resetPreferences();
                },
              ),
              const SizedBox(width: 16),
              MyntPrimaryButton(
                label: 'Save',
                onPressed: () {
                  _savePreferences();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resetPreferences() async {
    final pref = locator<Preferences>();

    // Update local state to match reset defaults (same as order_prefere_screen.dart)
    setState(() {
      priceType = "Limit";
      orderType = "Delivery";
      validity = "DAY";
      mktProtCtrl.text = "1";
      qtyCtrl.text = "1";
      QtyPrefer = OrdQtyPref.mktqty;
      expriceType = "Market";
      _stickyOrderWindow = false;
      _quickOrderScreen = false;
    });

    // Reset payload in the same format as mobile
    Map<String, dynamic> data = {
      "clientid": pref.clientId,
      "metadata": {
        "prc": priceType,
        "prd": orderType,
        "qtypref": "qty",
        "qty": qtyCtrl.text,
        "validity": validity,
        "mrkprot": mktProtCtrl.text,
        "expos": expriceType,
        "stickysrc": false,
      },
      "source": "WEB"
    };

    try {
      // Use authProvider.getPrefOrderPrefer to save (same as mobile)
      await ref.read(authProvider).getPrefOrderPrefer(data, true, context);

      // Refresh the savedOrderPreference cache
      await ref.read(authProvider).setPrefOrderPrefer(context);

      if (mounted) {
        ResponsiveSnackBar.showSuccess(context, 'Preferences reset successfully');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, 'Error: $e');
      }
    }
  }

  /// Save preferences using the same format as mobile (order_prefere_screen.dart)
  Future<void> _savePreferences() async {
    // Validate market protection (same as mobile)
    if (mktProtCtrl.text.isEmpty ||
        int.parse(mktProtCtrl.text) > 20 ||
        int.parse(mktProtCtrl.text) < 1) {
      ResponsiveSnackBar.showWarning(context, "Market Protection between 1% to 20%");
      return;
    }

    // Validate quantity if multiples selected (same as mobile)
    if ((QtyPrefer == OrdQtyPref.mktlot) && qtyCtrl.text == "") {
      ResponsiveSnackBar.showWarning(context, "Quantity can not be 0 or empty");
      return;
    }

    final pref = locator<Preferences>();

    // Build data in the exact same format as mobile (order_prefere_screen.dart setPrefOrderPrefer)
    Map<String, dynamic> data = {
      "clientid": pref.clientId,
      "metadata": {
        "prc": priceType,
        "prd": orderType,
        "qtypref": QtyPrefer == OrdQtyPref.mktlot ? 'lot' : 'qty',
        "qty": qtyCtrl.text,
        "validity": validity,
        "mrkprot": mktProtCtrl.text,
        "expos": expriceType,
        "stickysrc": _stickyOrderWindow ? true : false,
      },
      "source": "FWEB"
    };

    try {
      // Use authProvider.getPrefOrderPrefer to save (same as mobile)
      await ref.read(authProvider).getPrefOrderPrefer(data, true, context);

      // Refresh the savedOrderPreference cache
      await ref.read(authProvider).setPrefOrderPrefer(context);

      if (mounted) {
        ResponsiveSnackBar.showSuccess(context, 'Order Preference has been saved');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, 'Error: $e');
      }
    }
  }

  Widget _buildFreezeAccountContent(ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Freezing your account will temporarily disable trading. All open orders will be cancelled.',
            style: MyntWebTextStyles.bodySmall(context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary),
          ),
          const SizedBox(height: 16),
          MyntPrimaryButton(
            label: 'Freeze Account',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: resolveThemeColor(context,
                      dark: MyntColors.backgroundColorDark,
                      light: MyntColors.backgroundColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Container(
                    width: 340,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: resolveThemeColor(context,
                          dark: MyntColors.card,
                          light: MyntColors.backgroundColor),
                          border: Border.all(
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.backgroundColor),
                          ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Freeze Account',
                              style: MyntWebTextStyles.title(context,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary,
                                  fontWeight: MyntFonts.semiBold),
                            ),
                            MyntCloseButton(
                              onPressed: () => Navigator.pop(ctx),
                              iconSize: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Freezing your account will lock access for everyone, including you.',
                          style: MyntWebTextStyles.bodyMedium(context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All open orders will be automatically cancelled.',
                          style: MyntWebTextStyles.bodyMedium(context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Existing positions will remain unaffected.',
                          style: MyntWebTextStyles.bodyMedium(context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You can unfreeze your account anytime by verifying your identity.',
                          style: MyntWebTextStyles.bodyMedium(context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        MyntPrimaryButton(
                          label: 'Freeze My Account',
                          isFullWidth: true,
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref.read(userProfileProvider).fetchFreezeAc(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: MyntWebTextStyles.bodySmall(context,
        darkColor: MyntColors.textPrimaryDark,
        lightColor: MyntColors.textPrimary,
        fontWeight: MyntFonts.medium,
      ),
    );
  }

  Widget _buildSegmentedButton({
    required List<String> options,
    required String selected,
    required Function(String) onChanged,
    required bool isDark,
    bool compact = false,
  }) {
    return Row(
      children: options.map((option) {
        final isSelected = option == selected;
        return compact
            ? Padding(
                padding: EdgeInsets.only(right: option == options.last ? 0 : 8.0),
                child: InkWell(
                  onTap: () => onChanged(option),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? resolveThemeColor(context, dark: MyntColors.primaryDark.withValues(alpha: 0.1), light: const Color(0xFFEFF4FF))
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary)
                            : resolveThemeColor(context, dark: MyntColors.dividerDark, light: MyntColors.divider),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      style: MyntWebTextStyles.para(context,
                        fontWeight: MyntFonts.medium,
                        color: isSelected
                            ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary)
                            : resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
                      ),
                    ),
                  ),
                ),
              )
            : Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: option == options.last ? 0 : 8.0),
                  child: InkWell(
                    onTap: () => onChanged(option),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? resolveThemeColor(context, dark: MyntColors.primaryDark.withValues(alpha: 0.1), light: const Color(0xFFEFF4FF))
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary)
                              : resolveThemeColor(context, dark: MyntColors.dividerDark, light: MyntColors.divider),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        option,
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.para(context,
                          fontWeight: MyntFonts.medium,
                          color: isSelected
                              ?resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.primary)
                              : resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ),
              );
      }).toList(),
    );
  }

  Widget _buildRadioOption(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary)
                      : resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: MyntWebTextStyles.para(context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(String label, bool value, Function(bool) onChanged, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: MyntWebTextStyles.para(context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                  fontWeight: MyntFonts.medium,
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
              message:
                  'The order screen stays open after placing an order',
              waitDuration: const Duration(milliseconds: 150),
              verticalOffset: -35,
              showDuration: const Duration(seconds: 4),
              textStyle: TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.4,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? MyntColors.textPrimaryDark
                    : Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.info_outline,
                size: 14,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary,
                ),
              ),
            ),
          ],
        ),

          // Custom animated toggle switch like place order screen
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: Container(
                width: 40,
                height: 22,
                decoration: BoxDecoration(
                  color: value
                      ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary)
                      : resolveThemeColor(context,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      left: value ? 20 : 2,
                      top: 2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
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
        ],
      ),
    );
  }
}

class MyAccountScreen extends ConsumerStatefulWidget {
  const MyAccountScreen({super.key, this.initialIndex = 0, this.expandSection, this.onNavigateToScreen});
  final int initialIndex;
  final String? expandSection;
  final void Function(ScreenType)? onNavigateToScreen;
  @override
  ConsumerState<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends ConsumerState<MyAccountScreen> {
  // late int _expandedIndex;
  String? _expandedTitle;
  final _cardHoverStates = <int, bool>{};

  @override
  void initState() {
    super.initState();

    // Set initial expanded section from widget parameter
    if (widget.expandSection != null) {
      _expandedTitle = widget.expandSection;
    }

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ref.read(profileAllDetailsProvider).fetchPendingstatus();
      ref.read(userProfileProvider).getProfileimage();
    });
  }

  String _truncateProfileName(String text, {int maxLength = 18}) {
    return (text.length > maxLength)
        ? '${text.substring(0, maxLength)}...'
        : text;
  }

  // Add this variable
  final selectedBtmIndx = 4;

  // // Add this function
  // Widget buildBottomNav(int selectedTab, ThemesProvider theme) {
  //   final uid = ref.watch(userProfileProvider.select(
  //       (userProfile) => userProfile.userDetailModel?.uid?.toString() ?? ""));
  //   return BottomAppBar(
  //     height: 64,
  //     shadowColor:
  //         theme.isDarkMode ? MyntColors.dividerDark : MyntColors.divider,
  //     padding: EdgeInsets.zero,
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: <Widget>[
  //         _buildBottomNavItem(
  //             1, assets.watchlistIcon, "Watchlists", selectedTab, theme),
  //         _buildBottomNavItem(
  //             2, assets.portfolioIcon, "Portfolio", selectedTab, theme),
  //         _buildBottomNavItem(
  //             3, assets.ordersIcon, "Orders", selectedTab, theme),
  //         _buildBottomNavItem(4, assets.profileIcon, uid, selectedTab, theme,
  //             useHeight: true, height: 18),
  //       ],
  //     ),
  //   );
  // }

  // // Add this function
  // Widget _buildBottomNavItem(int index, String iconAsset, String label,
  //     int selectedIndex, ThemesProvider theme,
  //     {bool useHeight = false, double height = 24}) {
  //   final isSelected = selectedIndex == index;

  //   return Expanded(
  //     child: RepaintBoundary(
  //       child: InkWell(
  //         onTap: () {
  //           // Navigate to the corresponding screen
  //           switch (index) {
  //             case 1:
  //               Navigator.pushReplacementNamed(context, Routes.homeScreen);
  //               ref.read(indexListProvider).bottomMenu(1, context);
  //               break;
  //             case 2:
  //               Navigator.pushReplacementNamed(context, Routes.homeScreen);
  //               ref.read(indexListProvider).bottomMenu(2, context);
  //               break;
  //             case 3:
  //               Navigator.pushReplacementNamed(context, Routes.homeScreen);
  //               ref.read(indexListProvider).bottomMenu(3, context);
  //               break;
  //             case 4:
  //               // Already on profile screen
  //               break;
  //           }
  //         },
  //         child: Container(
  //           margin: const EdgeInsets.symmetric(horizontal: 7),
  //           decoration: BoxDecoration(
  //               border: isSelected
  //                   ? Border(
  //                       top: BorderSide(
  //                           color: theme.isDarkMode
  //                               ? colors.colorLightBlue
  //                               : colors.colorBlue,
  //                           width: 2))
  //                   : null),
  //           child: Column(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             crossAxisAlignment: CrossAxisAlignment.center,
  //             children: [
  //               useHeight
  //                   ? SvgPicture.asset(
  //                       iconAsset,
  //                       height: height,
  //                       color: _getBottomNavColor(theme, isSelected),
  //                     )
  //                   : SvgPicture.asset(
  //                       iconAsset,
  //                       color: _getBottomNavColor(theme, isSelected),
  //                     ),
  //               const SizedBox(height: 8),
  //               Text(
  //                 label,
  //                 style: TextWidget.textStyle(
  //                     fontSize: 12,
  //                     color: _getBottomNavColor(theme, isSelected),
  //                     theme: theme.isDarkMode,
  //                     fw: isSelected ? 1 : 00),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // List of items for the account screen with icons and descriptions
  List<Map<String, dynamic>> get accountItems => [
    {
      'title': 'Profile',
      'description': 'Personal details, PAN, email & address',
      'icon': Icons.person_outline_rounded,
      'color': resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
    },
    {
      'title': 'Bank',
      'description': 'Linked bank accounts & verification',
      'icon': Icons.account_balance_outlined,
      'color': Color(0xFF00875A),
    },
    {
      'title': 'Depository',
      'description': 'DDPI / POA authorization status',
      'icon': Icons.shield_outlined,
      'color': Color(0xFF6554C0),
    },
    {
      'title': 'Margin Trading Facility (MTF)',
      'description': 'Leverage trading activation & status',
      'icon': Icons.trending_up_rounded,
      'color': Color(0xFFE5700A),
    },
    {
      'title': 'Trading Preferences',
      'description': 'Segment activation & trading settings',
      'icon': Icons.tune_rounded,
      'color': Color(0xFF0065FF),
    },
    {
      'title': 'Nominee',
      'description': 'Manage nominee details for your account',
      'icon': Icons.people_outline_rounded,
      'color': Color(0xFF00A3BF),
    },
    {
      'title': 'Form Download',
      'description': 'Download account related forms',
      'icon': Icons.download_rounded,
      'color': Color(0xFF5243AA),
    },
    {
      'title': 'Closure',
      'description': 'Request account closure',
      'icon': Icons.cancel_outlined,
      'color': resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss),
    },
  ];

  // Map of titles to ScreenType for navigation
  static const _titleToScreenType = {
    'Profile': ScreenType.profileDetails,
    'Bank': ScreenType.bankDetails,
    'Depository': ScreenType.depositoryDetails,
    'Margin Trading Facility (MTF)': ScreenType.mtfDetails,
    'Trading Preferences': ScreenType.tradingPreferences,
    'Nominee': ScreenType.nomineeDetails,
    'Form Download': ScreenType.formDownload,
    'Closure': ScreenType.closureDetails,
  };

  // This method navigates to separate screens when an item is clicked
  void _onExpansionChanged(bool isExpanding, String title) {
    if (!isExpanding) return;

    final screenType = _titleToScreenType[title];
    if (screenType != null && widget.onNavigateToScreen != null) {
      widget.onNavigateToScreen!(screenType);
    }
  }

  /// Show profile image options: Change / Remove in a dialog
  void _showProfileImageOptions(BuildContext context, WidgetRef ref, bool hasImage) {
    final profileImage = ref.read(userProfileProvider).getprofileImage;
    final userProfile = ref.read(userProfileProvider);
    final userName = userProfile.userDetailModel?.uname ?? 'User';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile Photo',
                      style: MyntWebTextStyles.title(context,
                        color: resolveThemeColor(context,
                          dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
                        fontWeight: MyntFonts.semiBold,
                      ).copyWith(decoration: TextDecoration.none),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Profile image preview
                Container(
                  width: 96,
                  height: 96,
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
                              fontSize: 36,
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
                const SizedBox(height: 8),
                Text(
                  userName,
                  style: MyntWebTextStyles.bodySmall(context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                  ).copyWith(decoration: TextDecoration.none),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    // Upload / Change button
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            ref.read(userProfileProvider).pickAndUploadImageWeb(context);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: resolveThemeColor(context,
                                dark: MyntColors.secondary,
                                light: MyntColors.primary),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.photo_library_outlined,
                                  size: 18, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  hasImage ? 'Change' : 'Upload',
                                  style: MyntWebTextStyles.bodySmall(context,
                                    color: Colors.white,
                                    fontWeight: MyntFonts.medium,
                                  ).copyWith(decoration: TextDecoration.none),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (hasImage) ...[
                      const SizedBox(width: 12),
                      // Remove button
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              ref.read(userProfileProvider).removeProfileImage(context);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.error),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                   Icon(Icons.delete_outline_rounded,
                                    size: 18, color: resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.error)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Remove',
                                    style: MyntWebTextStyles.bodySmall(context,
                                      color: resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.error),
                                      fontWeight: MyntFonts.medium,
                                    ).copyWith(decoration: TextDecoration.none),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Helper method to get pending statuses for a specific section
  List<String> _getPendingStatusesForSection(
      String sectionTitle, WidgetRef ref) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    if (profileDetails.pendingStatusList.isEmpty ||
        profileDetails.pendingStatusList[0].data == null ||
        profileDetails.pendingStatusList[0].data!.isEmpty) {
      return [];
    }

    final pendingStatuses = profileDetails.pendingStatusList[0].data!;

    switch (sectionTitle) {
      case 'Profile':
        return pendingStatuses
            .where((status) =>
                status == 'address_change_pending' ||
                status == 'email_change_pending' ||
                status == 'mobile_change_pending')
            .toList();
      case 'Bank':
        return pendingStatuses
            .where((status) => status == 'bank_change_pending')
            .toList();
      case 'Depository':
        return pendingStatuses
            .where((status) => status == 'ddpicre_pending')
            .toList();
      case 'Margin Trading Facility (MTF)':
        return pendingStatuses
            .where((status) => status == 'mtf_pending')
            .toList();
      case 'Trading Preferences':
        return pendingStatuses
            .where((status) => status == 'segments_change_pending')
            .toList();
      case 'Nominee':
        return pendingStatuses
            .where((status) => status == 'nominee_pending')
            .toList();
      case 'Closure':
        return pendingStatuses
            .where((status) => status == 'closure_pending')
            .toList();
      case 'Form Download':
        return []; // No specific pending statuses for form download
      default:
        return [];
    }
  }

  /// Helper method to build section title with pending indicator
  Widget _buildSectionTitleWithPendingIndicator(
      String title, WidgetRef ref, ThemesProvider theme) {
    final pendingStatuses = _getPendingStatusesForSection(title, ref);
    final hasPending = pendingStatuses.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: MyntWebTextStyles.body(
              context,
              color: _expandedTitle == title
                  ? resolveThemeColor(context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary)
                  : resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
              fontWeight: _expandedTitle == title ? MyntFonts.semiBold : MyntFonts.medium,
            ),
          ),
        ),
        if (hasPending) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Text(
              '${pendingStatuses.length} Pending',
              style: MyntWebTextStyles.caption(
                context,
                color: Colors.orange.shade700,
                fontWeight: MyntFonts.regular,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  /// Helper method to build pending statuses display for a specific section
  Widget _buildSectionPendingStatuses(String sectionTitle, WidgetRef ref,
      ThemesProvider theme, VoidCallback onTap, VoidCallback onTapCancel) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final pendingStatuses = _getPendingStatusesForSection(sectionTitle, ref);

    if (pendingStatuses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      color: theme.isDarkMode ? Colors.black : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Pending Status",
                  style: MyntWebTextStyles.body(
                    context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                    fontWeight: MyntFonts.regular,
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.isDarkMode
                              ? MyntColors.primaryDark
                              : MyntColors.primary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          "Click here to E-sign",
                          style: MyntWebTextStyles.caption(
                            context,
                            color: Colors.white,
                            fontWeight: MyntFonts.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                  backgroundColor: resolveThemeColor(context,
                                      dark: MyntColors.backgroundColorDark,
                                      light: MyntColors.backgroundColor),
                                  titlePadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  shape: const RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(8))),
                                  scrollable: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  actionsPadding: const EdgeInsets.only(
                                      bottom: 16, right: 16, left: 16, top: 8),
                                  insetPadding: const EdgeInsets.symmetric(
                                      horizontal: 30, vertical: 12),
                                  title: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Material(
                                            color: Colors.transparent,
                                            shape: const CircleBorder(),
                                            child: InkWell(
                                              onTap: () async {
                                                await Future.delayed(
                                                    const Duration(
                                                        milliseconds: 150));
                                                Navigator.pop(context);
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              splashColor: theme.isDarkMode
                                                  ? MyntColors.rippleDark
                                                  : MyntColors.rippleLight,
                                              highlightColor: theme.isDarkMode
                                                  ? MyntColors.rippleDark
                                                  : MyntColors.rippleLight,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(6.0),
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  size: 22,
                                                  color: theme.isDarkMode
                                                      ? MyntColors.textSecondaryDark
                                                      : MyntColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              const SizedBox(height: 10),
                                              Text(
                                                "Are you sure want to cancel the Esign",
                                                style: MyntWebTextStyles.body(
                                                  context,
                                                  darkColor: MyntColors.textSecondaryDark,
                                                  lightColor: MyntColors.textPrimary,
                                                  fontWeight: MyntFonts.regular,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: onTapCancel,
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 40),
                                          side: BorderSide(
                                              color: MyntColors.outlinedBorder),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          backgroundColor: MyntColors.primaryDark,
                                        ),
                                        child: profileDetails.cancelpendingloader
                            ? MyntLoader.inline(color: Colors.white)
                            : Text("Yes",
                                style: MyntWebTextStyles.body(
                                  context,
                                  color: Colors.white,
                                  fontWeight: MyntFonts.bold,
                                )),
                                      ),
                                    ),
                                  ],
                                ));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.isDarkMode
                                ? MyntColors.lossDark
                                : MyntColors.loss,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Icon(Icons.close,
                            color: theme.isDarkMode
                                ? MyntColors.lossDark
                                : MyntColors.loss,
                            size: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// Pending Status as Chips
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: pendingStatuses.map((status) {
                final displayName = _getPendingStatusDisplayName(status);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.isDarkMode
                        ? MyntColors.pending.withValues(alpha: 0.1)
                        : MyntColors.pending.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MyntColors.pending.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    displayName,
                    style: MyntWebTextStyles.body(
                      context,
                      color: MyntColors.pending,
                      fontWeight: MyntFonts.regular,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to get display name for pending status
  String _getPendingStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'address_change_pending':
        return 'Address Change';
      case 'bank_change_pending':
        return 'Bank Change';
      case 'closure_pending':
        return 'Account Closure';
      case 'ddpicre_pending':
        return 'DPICRE';
      case 'email_change_pending':
        return 'Email Change';
      case 'income_change_pending':
        return 'Income Change';
      case 'mobile_change_pending':
        return 'Mobile Change';
      case 'mtf_pending':
        return 'MTF';
      case 'nominee_pending':
        return 'Nominee';
      case 'segments_change_pending':
        return 'Segments Change';
      default:
        return status
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                : word)
            .join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final isDark = theme.isDarkMode;
    final userProfile = ref.watch(userProfileProvider);
    final userName = userProfile.userDetailModel?.uname ?? 'User';
    final userId = userProfile.userDetailModel?.uid ?? '';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page Title ──
              Text(
                'Account',
                style: MyntWebTextStyles.hero(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                ).copyWith(decoration: TextDecoration.none),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your profile, preferences and account settings',
                style: MyntWebTextStyles.para(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ).copyWith(decoration: TextDecoration.none),
              ),
              const SizedBox(height: 16),
              // ── Unified 3-Column Grid ──
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width > 900 ? 3 : width > 600 ? 2 : 1;
                  const spacing = AppSpacing.sm;
                  final itemWidth = (width - (spacing * (crossAxisCount - 1))) / crossAxisCount;
                  final itemHeight = itemWidth / 4.5;
                  final profileImage = ref.watch(userProfileProvider).getprofileImage;
                  final imageLoading = ref.watch(userProfileProvider).imageLoader;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      // ── Profile Card ──
                      SizedBox(
                        width: itemWidth,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showProfileImageOptions(context, ref, profileImage != null),
                            hoverColor: isDark
                                ? MyntColors.cardHoverDark
                                : MyntColors.cardHover,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? MyntColors.cardDark : MyntColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? MyntColors.cardBorderDark
                                      : MyntColors.cardBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Avatar
                                  Stack(
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
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
                                        child: imageLoading
                                            ? Center(
                                                child: MyntLoader.inline(
                                                  color: resolveThemeColor(context,
                                                    dark: MyntColors.primaryDark,
                                                    light: MyntColors.primary),
                                                ),
                                              )
                                            : profileImage == null
                                                ? Center(
                                                    child: Text(
                                                      userInitial,
                                                      style: TextStyle(
                                                        fontSize: 28,
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
                                      // Camera badge
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: resolveThemeColor(context,
                                              dark: MyntColors.cardDark,
                                              light: MyntColors.card),
                                            border: Border.all(
                                              color: resolveThemeColor(context,
                                                dark: MyntColors.cardBorderDark,
                                                light: MyntColors.cardBorder),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.camera_alt_rounded,
                                            size: 13,
                                            color: resolveThemeColor(context,
                                              dark: MyntColors.primaryDark,
                                              light: MyntColors.primary),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  // Name & ID
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _truncateProfileName(userName, maxLength: 24),
                                          style: MyntWebTextStyles.title(context,
                                            color: resolveThemeColor(context,
                                              dark: MyntColors.textPrimaryDark,
                                              light: MyntColors.textPrimary),
                                            fontWeight: MyntFonts.semiBold,
                                          ).copyWith(decoration: TextDecoration.none),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          userId,
                                          style: MyntWebTextStyles.bodySmall(context,
                                            darkColor: MyntColors.textSecondaryDark,
                                            lightColor: MyntColors.textSecondary,
                                          ).copyWith(decoration: TextDecoration.none),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Icon(
                                  //   Icons.chevron_right_rounded,
                                  //   color: resolveThemeColor(context,
                                  //     dark: MyntColors.textTertiaryDark,
                                  //     light: MyntColors.textTertiary),
                                  //   size: 24,
                                  // ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Section Label (spans full width) ──
                      SizedBox(
                        width: width,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, top: 12),
                          child: Text(
                            'Account Settings',
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          fontWeight: MyntFonts.semiBold,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary),
                        ),
                      ),
                        ),
                      ),

                      // ── Account Items ──
                      ...List.generate(accountItems.length, (index) {
                      final item = accountItems[index];
                      final title = item['title'] as String;
                      final description = item['description'] as String;
                      final icon = item['icon'] as IconData;
                      final itemColor = item['color'] as Color;
                      final pendingStatuses = _getPendingStatusesForSection(title, ref);
                      final hasPending = pendingStatuses.isNotEmpty;

                      final hovered = _cardHoverStates[index] == true;

                      return SizedBox(
                        width: itemWidth,
                        height: itemHeight,
                        child: _ProfileHoverCard(
                          title: title,
                          description: description,
                          icon: icon,
                          iconColor: itemColor,
                          isDark: isDark,
                          hasPending: hasPending,
                          onTap: () => _onExpansionChanged(true, title),
                        ),
                      );
                    }),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // ── Version Text ──
              // Center(
              //   child: Padding(
              //     padding: const EdgeInsets.only(bottom: 8),
              //     child: TextWidget.captionText(
              //       text: ref.watch(authProvider).versiontext,
              //       theme: false,
              //       color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
              //     ),
              //   ),
              // ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper to build the content inside each ExpansionTile
  Widget _buildExpansionContent(
      String title, WidgetRef ref, ThemesProvider theme) {
    switch (title) {
      case 'Profile':
        return _buildProfileDetailsContent(ref, theme);
      case 'Bank':
        return _buildBankDetailsContent(ref, theme);
      case 'Depository':
        return _buildDepositoryContent(ref, theme);
      case 'Margin Trading Facility (MTF)':
        return _buildMTFContent(ref, theme);
      case 'Trading Preferences':
        return _buildTradingPreferencesContent(ref, theme);
      case 'Nominee':
        return _buildNomineeContent(ref, theme);
      case 'Form Download':
        return _buildFormDownloadContent(ref, theme);
      case 'Closure':
        return _buildClosureContent(ref, theme);
      default:
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Details for $title will be shown here.',
            style: MyntWebTextStyles.para(
              context,
              color: MyntColors.textTertiary,
            ),
          ),
        );
    }
  }

  /// Builds the UI for the "Profile" section, replicating ProfileInfoDetails
  Widget _buildProfileDetailsContent(WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final clientData = profileDetails.clientAllDetails.clientData;

    // if (profileDetails.isLoading) {
    //   return const Center(child: CircularProgressIndicator());
    // }

    return Column(
      children: [
        _buildDetailRow("Name", clientData?.panName ?? "N/A", theme, ref),
        _buildDetailRow("PAN", clientData?.pANNO ?? "N/A", theme, ref),
        _buildDetailRow("Email", clientData?.cLIENTIDMAIL ?? "N/A", theme, ref),

        _buildDetailRow("Mobile", clientData?.mOBILENO ?? "N/A", theme, ref),
        _buildDetailRow(
            "Address",
            "${clientData?.cLRESIADD1} ${clientData?.cLRESIADD2} ${clientData?.cLRESIADD3}" ??
                "N/A",
            theme,
            ref),

        // Show pending statuses for Profile section only
        _buildSectionPendingStatuses('Profile', ref, theme, () {
          if (_getPendingStatusesForSection("Profile", ref)
              .any((status) => status == 'email_change_pending')) {
            profileDetails.openInWebURLk(context, "profile", "email");
          } else if (_getPendingStatusesForSection("Profile", ref)
              .any((status) => status == 'mobile_change_pending')) {
            profileDetails.openInWebURLk(context, "profile", "mobile");
          } else if (_getPendingStatusesForSection("Profile", ref)
              .any((status) => status == 'address_change_pending')) {
            profileDetails.openInWebURLk(context, "profile", "address");
          }
        },
        () {
        if (_getPendingStatusesForSection("Profile", ref)
              .any((status) => status == 'email_change_pending')) {
           profileDetails.cancelPendingStatus("email_change", context);
          } else if (_getPendingStatusesForSection("Profile", ref)
              .any((status) => status == 'mobile_change_pending')) {
            profileDetails.cancelPendingStatus("mobile_change", context);
          } else if (_getPendingStatusesForSection("Profile", ref)
              .any((status) => status == 'address_change_pending')) {
            profileDetails.cancelPendingStatus("address_change", context);
          }
        },
        ),
        // _buildDetailRow("DP ID", clientData?.cLIENTDPCODE ?? "N/A", theme),
      ],
    );
  }

  /// Builds the UI for the "Bank" section
  Widget _buildBankDetailsContent(WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final bankData = profileDetails.clientAllDetails.bankData;

    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final cardBorder = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with Add button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Bank Accounts",
                style: MyntWebTextStyles.title(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium,
                ).copyWith(decoration: TextDecoration.none),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final pendingStatuses =
                        ref.watch(profileAllDetailsProvider).pendingStatusList;
                    if (pendingStatuses.isNotEmpty &&
                        pendingStatuses[0].data != null) {
                      final hasPendingChanges = pendingStatuses[0]
                          .data!
                          .any((status) => status == 'bank_change_pending');
                      if (hasPendingChanges) {
                        warningMessage(context, 'You have pending request.click on the E-Sign to proceed.');
                        return;
                      }
                    }
                    await Future.delayed(const Duration(milliseconds: 150));
                    profileDetails.openInWebURLWithbank(
                        context, "bank", "addbank", "");
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16, color: primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          "Add Bank",
                          style: MyntWebTextStyles.bodySmall(context,
                            color: primaryColor,
                            fontWeight: MyntFonts.semiBold,
                          ).copyWith(decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "View bank details and manage linked accounts",
            style: MyntWebTextStyles.para(context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
              fontWeight: MyntFonts.regular,
            ).copyWith(decoration: TextDecoration.none),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, thickness: 1, color: dividerColor),

          // Bank list
          if (bankData == null || bankData.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.account_balance_outlined, size: 40,
                        color: subtitleColor),
                    const SizedBox(height: 12),
                    Text(
                      "No bank accounts found",
                      style: MyntWebTextStyles.body(context,
                        color: subtitleColor,
                        fontWeight: MyntFonts.medium,
                      ).copyWith(decoration: TextDecoration.none),
                    ),
                  ],
                ),
              ),
            )
          else
            ...bankData.asMap().entries.map((entry) {
              final index = entry.key;
              final bank = entry.value;
              final isPrimary = bank.defaultAc == "Yes";

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bank Logo
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: resolveThemeColor(context,
                                dark: MyntColors.cardHoverDark,
                                light: MyntColors.cardHover),
                            border: Border.all(color: dividerColor),
                          ),
                          child: ClipOval(
                            child: SvgPicture.network(
                              "https://rekycbe.mynt.in/autho/banklogo?bank=${(bank.iFSCCode ?? "").substring(0, 4).toLowerCase()}&type=svg&t=${DateTime.now().millisecondsSinceEpoch}",
                              fit: BoxFit.contain,
                              height: 22,
                              width: 22,
                              placeholderBuilder: (context) => Icon(
                                Icons.account_balance,
                                color: subtitleColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Bank details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bank name + PRIMARY badge
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      bank.bankName ?? "Unknown Bank",
                                      style: MyntWebTextStyles.body(context,
                                        darkColor: MyntColors.textPrimaryDark,
                                        lightColor: MyntColors.textPrimary,
                                        fontWeight: MyntFonts.semiBold,
                                      ).copyWith(decoration: TextDecoration.none),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isPrimary) ...[
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "PRIMARY",
                                        style: MyntWebTextStyles.caption(context,
                                          color: primaryColor,
                                          fontWeight: MyntFonts.semiBold,
                                        ).copyWith(
                                          decoration: TextDecoration.none,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Account details in flat cols
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final w = constraints.maxWidth;
                                  final cols = w > 500 ? 3 : w > 300 ? 2 : 1;

                                  final fields = [
                                    ['ACCOUNT NUMBER', profileDetails.formateDataToDisplay(bank.bankAcNo ?? "", 2, 4)],
                                    ['IFSC CODE', bank.iFSCCode ?? "N/A"],
                                    ['ACCOUNT TYPE', bank.bANKACCTYPE ?? "N/A"],
                                  ];

                                  if (cols == 1) {
                                    return Column(
                                      children: fields.map((f) => Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _buildBankFieldItem(f[0], f[1], subtitleColor, textColor, dividerColor),
                                      )).toList(),
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (int i = 0; i < fields.length; i++) ...[
                                        Expanded(
                                          child: _buildBankFieldItem(
                                            fields[i][0], fields[i][1],
                                            subtitleColor, textColor, dividerColor,
                                          ),
                                        ),
                                        if (i < fields.length - 1)
                                          const SizedBox(width: 24),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Action buttons
                        Column(
                          children: [
                            // Edit icon
                            InkWell(
                              onTap: () async {
                                final pendingStatuses = ref
                                    .watch(profileAllDetailsProvider)
                                    .pendingStatusList;
                                if (pendingStatuses.isNotEmpty &&
                                    pendingStatuses[0].data != null) {
                                  final hasPendingChanges = pendingStatuses[0]
                                      .data!
                                      .any((status) =>
                                          status == 'bank_change_pending');
                                  if (hasPendingChanges) {
                                    warningMessage(context, 'You have pending request.click on the E-Sign to proceed.');
                                    return;
                                  }
                                }
                                await Future.delayed(
                                    const Duration(milliseconds: 150));
                                profileDetails.openInWebURLWithbank(context,
                                    "bank", "editbank", bank.bankAcNo ?? "");
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(Icons.edit_outlined, size: 16,
                                    color: primaryColor),
                              ),
                            ),
                            // More options for non-primary
                            if (!isPrimary) ...[
                              const SizedBox(height: 4),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                constraints:
                                    const BoxConstraints(minWidth: 160),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                color: cardBg,
                                onSelected: (value) {
                                  final pendingStatuses = ref
                                      .watch(profileAllDetailsProvider)
                                      .pendingStatusList;
                                  final hasPendingChanges = pendingStatuses
                                          .isNotEmpty &&
                                      pendingStatuses[0].data != null &&
                                      pendingStatuses[0].data!.any((status) =>
                                          status == 'bank_change_pending');

                                  if (value == 'set_primary') {
                                    if (hasPendingChanges) {
                                      warningMessage(context, 'You have pending request.click on the E-Sign to proceed.');
                                      return;
                                    }
                                    profileDetails.openInWebURLWithbank(
                                        context, "bank", "setasprimarybank",
                                        bank.bankAcNo ?? "");
                                  } else if (value == 'delete') {
                                    if (hasPendingChanges) {
                                      warningMessage(context, 'You have pending request.click on the E-Sign to proceed.');
                                      return;
                                    }
                                    profileDetails.openInWebURLWithbank(
                                        context, "bank", "deletebank",
                                        bank.bankAcNo ?? "");
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem<String>(
                                    value: 'set_primary',
                                    child: Text("Set as Primary",
                                      style: MyntWebTextStyles.bodySmall(context,
                                        darkColor: MyntColors.textPrimaryDark,
                                        lightColor: MyntColors.textPrimary,
                                        fontWeight: MyntFonts.medium,
                                      ).copyWith(decoration: TextDecoration.none),
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text("Delete",
                                      style: MyntWebTextStyles.bodySmall(context,
                                        color: Colors.red,
                                        fontWeight: MyntFonts.medium,
                                      ).copyWith(decoration: TextDecoration.none),
                                    ),
                                  ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(Icons.more_horiz, size: 16,
                                      color: subtitleColor),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (index < bankData.length - 1)
                    Divider(height: 1, thickness: 1, color: dividerColor),
                ],
              );
            }),

          const SizedBox(height: 12),

          // Regulation note
          Text(
            "*As per the regulation, you can have up to 5 bank a/c linked to trading a/c",
            style: MyntWebTextStyles.caption(context,
              darkColor: MyntColors.textTertiaryDark,
              lightColor: MyntColors.textTertiary,
              fontWeight: MyntFonts.regular,
            ).copyWith(
              decoration: TextDecoration.none,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 16),

          // Pending statuses
          _buildSectionPendingStatuses('Bank', ref, theme, () {
            profileDetails.openInWebURLk(context, "bank", "bank");
          },
          () {
            profileDetails.cancelPendingStatus("bank_change", context);
          },),
        ],
      ),
    );
  }

  /// Bank field: label + value + underline
  Widget _buildBankFieldItem(String label, String value,
      Color subtitleColor, Color textColor, Color dividerColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MyntWebTextStyles.caption(context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
            fontWeight: MyntFonts.semiBold,
          ).copyWith(
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value.isNotEmpty ? value : "N/A",
          style: MyntWebTextStyles.body(context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.medium,
          ).copyWith(decoration: TextDecoration.none),
        ),
        const SizedBox(height: 10),
        Divider(height: 1, thickness: 1, color: dividerColor),
      ],
    );
  }

  Widget _buildDepositoryContent(WidgetRef ref, ThemesProvider theme) {
    final profileprovider = ref.watch(profileAllDetailsProvider);
    final theme = ref.watch(themeProvider);
    bool DDPIActive = profileprovider.clientAllDetails.clientData!.dDPI == 'Y';
    bool POAActive = profileprovider.clientAllDetails.clientData!.pOA == 'Y';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: theme.isDarkMode ? Colors.black : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "CDSL",
                      style: MyntWebTextStyles.body(
                        context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: DDPIActive
                                ? theme.isDarkMode
                                    ? MyntColors.primaryDark
                                    : MyntColors.primary
                                : theme.isDarkMode
                                    ? MyntColors.textSecondaryDark.withValues(alpha: 0.2)
                                    : null,
                            border: !DDPIActive
                                ? Border(
                                    bottom: BorderSide(
                                      color: theme.isDarkMode
                                          ? MyntColors.lossDark
                                          : MyntColors.loss,
                                      width: 1,
                                    ),
                                  )
                                : null,
                          ),
                          child: Text(
                            "DDPI",
                            style: MyntWebTextStyles.body(
                              context,
                              color: DDPIActive
                                  ? Colors.white
                                  : resolveThemeColor(context,
                                      dark: MyntColors.lossDark,
                                      light: MyntColors.loss),
                              fontWeight: MyntFonts.medium,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: POAActive ? MyntColors.primary : null,
                            border: !POAActive
                                ? Border(
                                    bottom: BorderSide(
                                      color: theme.isDarkMode
                                          ? MyntColors.lossDark
                                          : MyntColors.loss,
                                      width: 1,
                                    ),
                                  )
                                : null,
                          ),
                          child: Text(
                            "POA",
                            style: MyntWebTextStyles.body(
                              context,
                              color: POAActive
                                  ? Colors.white
                                  : resolveThemeColor(context,
                                      dark: MyntColors.lossDark,
                                      light: MyntColors.loss),
                              fontWeight: MyntFonts.medium,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _buildDataWidget(
                      "DP ID",
                      profileprovider.clientAllDetails.clientData?.cLIENTDPCODE!
                              .substring(0, 8) ??
                          "",
                      theme),
                  _buildDataWidget(
                      "BO ID",
                      profileprovider.clientAllDetails.clientData?.cLIENTDPCODE!
                              .substring(8) ??
                          "",
                      theme),
                  _buildDataWidget(
                      "DP NAME",
                      profileprovider.clientAllDetails.clientData?.dPNAME ?? "",
                      theme),
                ],
              ),
            ],
          ),
        ),
        if (!DDPIActive && !POAActive)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Do you want to sell your stocks without CDSL T-Pin",
                style: MyntWebTextStyles.para(
                  context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                  fontWeight: MyntFonts.medium,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  // profileprovider.openInWebURL(context, "deposltory");
                  final pendingStatuses =
                      ref.watch(profileAllDetailsProvider).pendingStatusList;
                  if (pendingStatuses.isNotEmpty &&
                      pendingStatuses[0].data != null) {
                    final hasPendingChanges = pendingStatuses[0]
                        .data!
                        .any((status) => status == 'ddpicre_pending');
                    if (hasPendingChanges) {
                      warningMessage(context, 'You have pending request.click on the E-Sign to proceed.');
                      return;
                    }
                  }
                  profileprovider.openInWebURLk(context, "deposltory", "demat");
                },
                style: ElevatedButton.styleFrom(
                    elevation: 0,
                    minimumSize: Size(100, 45),
                    backgroundColor: theme.isDarkMode
                        ? MyntColors.primaryDark
                        : MyntColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4))),
                child: Text("Activate DDPI",
                    style: MyntWebTextStyles.body(context,
                        color: Colors.white,
                        fontWeight: MyntFonts.bold)),
              ),
              SizedBox(height: 10.0),
            ],
          ),

        // Show pending statuses for Depository section
        _buildSectionPendingStatuses('Depository', ref, theme, () {
          profileprovider.openInWebURLk(context, "deposltory", "demat");
        },
        () {
          profileprovider.cancelPendingStatus("DDPI", context);
        },
        ),
      ],
    );
  }

  /// Builds the MTF content section
  Widget _buildMTFContent(WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final clientData = profileDetails.clientAllDetails.clientData;

    bool DDPIActive = clientData?.dDPI == 'Y';
    bool POAActive = clientData?.pOA == 'Y';
    bool mtfCl = clientData?.mTFCl == 'Y';
    bool mtfClAuto = clientData?.mTFClAuto == "Y";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Status badges
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.end,
            //   children: [
            //     _buildStatusChip("DDPI", DDPIActive, theme),
            //     const SizedBox(width: 8),
            //     _buildStatusChip("POA", POAActive, theme),
            //   ],
            // ),
            // const SizedBox(height: 16),

            if (!DDPIActive && !POAActive) ...[
              Text(
                "You need to enable DDPI before you can proceed with processing MTF (Margin Trading Facility).",
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.lossDark,
                  lightColor: MyntColors.loss,
                  fontWeight: MyntFonts.medium,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  minimumSize: Size(100, 45),
                  backgroundColor: MyntColors.borderMuted,
                  disabledBackgroundColor: MyntColors.borderMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: Text("Enable MTF",
                    style: MyntWebTextStyles.body(context,
                        color: Colors.white, fontWeight: MyntFonts.bold)),
              ),
            ] else if (mtfCl && mtfClAuto) ...[
              Text(
                "You have activated the Margin Trading Facility (MTF) on your account",
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Chip(
                label: Text('MTF Enabled',
                    style: MyntWebTextStyles.body(context,
                        color: Colors.white)),
                backgroundColor: MyntColors.primary,
              ),
            ] else if (DDPIActive || POAActive) ...[
              Text(
                "Would you like to activate Margin Trading Facility (MTF) on your account",
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final pendingStatuses =
                      ref.watch(profileAllDetailsProvider).pendingStatusList;
                  if (pendingStatuses.isNotEmpty &&
                      pendingStatuses[0].data != null) {
                    final hasPendingChanges = pendingStatuses[0]
                        .data!
                        .any((status) => status == 'mtf_pending');
                    if (hasPendingChanges) {
                      warningMessage(context, 'You have pending request.click on the E-Sign to proceed.');
                      return;
                    }
                  }
                  // profileDetails.openInWebURL(context, "segment");
                  profileDetails.openInWebURLk(context, "segment", "mtf");
                },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  minimumSize: Size(100, 45),
                  backgroundColor: theme.isDarkMode
                      ? MyntColors.primaryDark
                      : MyntColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: Text("Enable MTF",
                    style: MyntWebTextStyles.body(context,
                        color: Colors.white, fontWeight: MyntFonts.bold)),
              ),
            ] else ...[
              if ((profileDetails.clientAllDetails.clientData!.mTFCl == 'N' &&
                      profileDetails.clientAllDetails.clientData!.mTFClAuto ==
                          'N') &&
                  (profileDetails.clientAllDetails.clientData!.dDPI == 'Y' ||
                      profileDetails.clientAllDetails.clientData!.pOA == "Y"))
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Would you like to activate Margin Trading Facility (MTF) on your account ",
                        style: MyntWebTextStyles.body(
                          context,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: ElevatedButton(
                          onPressed: () async {
                            //  if (Platform.isAndroid) {
                            //           await ref.read(fundProvider).fetchHstoken(context);
                            //             Navigator.pushNamed(
                            //                 context, Routes.profileWebViewApp,
                            //                 arguments: "mtf");

                            //         } else {
                            // profileDetails.openInWebURL(context, "mtf");
                            profileDetails.openInWebURLk(
                                context, "segment", "mtf");

                            // }

                            // await ref.read(fundProvider).fetchHstoken(context);
                            // Navigator.pushNamed(context, Routes.profileWebViewApp,
                            //     arguments: "mtf");
                            //  profileDetails.openInWebURL(context,"mtf");
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: theme.isDarkMode
                                ? Colors.black
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            side: BorderSide(
                              width: 1,
                              color: theme.isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          child: Text("Enable MTF",
                              style: MyntWebTextStyles.body(context,
                                  fontWeight: MyntFonts.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ]),
        ),

        // Show pending statuses for MTF section
        _buildSectionPendingStatuses(
            'Margin Trading Facility (MTF)', ref, theme, () {
          profileDetails.openInWebURLk(context, "segment", "mtf");
        },
        () {
          profileDetails.cancelPendingStatus("mtf", context);
        },
        ),
      ],
    );
  }

  /// Builds the Trading Preferences content section
  Widget _buildTradingPreferencesContent(WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final segmentsData =
        profileDetails.clientAllDetails.clientData?.segmentsData;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Segments",
                  style: MyntWebTextStyles.body(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium)),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final pendingStatuses =
                        ref.watch(profileAllDetailsProvider).pendingStatusList;
                    if (pendingStatuses.isNotEmpty &&
                        pendingStatuses[0].data != null) {
                      final hasPendingChanges = pendingStatuses[0]
                          .data!
                          .any((status) => status == 'segments_change_pending');
                      if (hasPendingChanges) {
                        warningMessage(context, 'You have pending request.click on the E-Sign to proceed.');
                        return;
                      }
                    }

                    // Add delay for visual feedback
                    await Future.delayed(const Duration(milliseconds: 150));
                    // profileDetails.openInWebURL(context, "segment");
                    profileDetails.openInWebURLk(context, "segment", "segment");
                  },
                  borderRadius: BorderRadius.circular(20),
                  splashColor: theme.isDarkMode
                      ? MyntColors.rippleDark
                      : MyntColors.rippleLight,
                  highlightColor: theme.isDarkMode
                      ? MyntColors.highlightDark
                      : MyntColors.highlightLight,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.edit_outlined,
                      color: theme.isDarkMode
                          ? MyntColors.textSecondaryDark
                          : MyntColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // const SizedBox(height: 5),
          if (segmentsData != null) ...[
            _buildSegmentRow(
                "Equities",
                segmentsData.where(
                    (s) => ['BSE_CASH', 'NSE_CASH'].contains(s.cOMPANYCODE)),
                theme),
            _buildSegmentRow(
                "F&O",
                segmentsData.where(
                    (s) => ['NSE_FNO', 'BSE_FNO'].contains(s.cOMPANYCODE)),
                theme),
            _buildSegmentRow(
                "Currency",
                segmentsData
                    .where((s) => ['CD_NSE', 'CD_BSE'].contains(s.cOMPANYCODE)),
                theme),
            _buildSegmentRow(
                "Commodities",
                segmentsData.where((s) =>
                    ['MCX', 'NSE_COM', 'BSE_COM'].contains(s.cOMPANYCODE)),
                theme),
          ] else
            Text("No segment data available",
                style: MyntWebTextStyles.para(context)),

          // Show pending statuses for Trading Preferences section
          _buildSectionPendingStatuses('Trading Preferences', ref, theme, () {
            profileDetails.openInWebURLk(context, "segment", "segment");
          },
          () {
            profileDetails.cancelPendingStatus("segment_change", context);
          },
          
          ),
        ],
      ),
    );
  }

  /// Builds the Nominee content section
  Widget _buildNomineeContent(WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final clientData = profileDetails.clientAllDetails.clientData;

    final primaryColor = theme.isDarkMode ? colors.primaryDark : colors.primaryLight;
    final textColor = theme.isDarkMode ? colors.textPrimaryDark : colors.textPrimaryLight;
    final subtitleColor = theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight;
    final errorColor = theme.isDarkMode ? const Color(0xFFF85149) : const Color(0xFFFF1717);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (clientData?.nomineeName == null ||
              clientData?.nomineeName == "") ...[
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: errorColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: errorColor, size: 14),
                  const SizedBox(width: 6),
                  TextWidget.subText(
                    text: "No nominee added - Account unsecured",
                    color: errorColor,
                    theme: theme.isDarkMode,
                    fw: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextWidget.subText(
              text: "Protect your investments by adding a nominee to your account.",
              color: subtitleColor,
              theme: theme.isDarkMode,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () async {
                await Future.delayed(const Duration(milliseconds: 150));
                profileDetails.openInWebURLk(context, "nominee", "nominee");
              },
              icon: const Icon(Icons.add, size: 18),
              label: TextWidget.subText(
                text: "Add Nominee",
                color: colors.colorWhite,
                theme: theme.isDarkMode,
                fw: 2,
              ),
              style: ElevatedButton.styleFrom(
                  elevation: 0,
                  minimumSize: const Size(100, 42),
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Nominee Details",
                    style: MyntWebTextStyles.body(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.medium)),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final pendingStatuses = ref
                          .watch(profileAllDetailsProvider)
                          .pendingStatusList;
                      if (pendingStatuses.isNotEmpty &&
                          pendingStatuses[0].data != null) {
                        final hasPendingChanges = pendingStatuses[0]
                            .data!
                            .any((status) => status == 'nominee_pending');
                        if (hasPendingChanges) {
                          warningMessage(context, 'You have pending request.click on the E-Sign to proceed.');
                          return;
                        }
                      }

                      await Future.delayed(const Duration(milliseconds: 150));
                      profileDetails.openInWebURLk(
                          context, "nominee", "nominee");
                    },
                    borderRadius: BorderRadius.circular(20),
                    splashColor: theme.isDarkMode
                        ? MyntColors.rippleDark
                        : MyntColors.rippleLight,
                    highlightColor: theme.isDarkMode
                        ? MyntColors.highlightDark
                        : MyntColors.highlightLight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.edit_outlined,
                        color: theme.isDarkMode
                            ? MyntColors.textSecondaryDark
                            : MyntColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            _buildDetailRow(
                "Nominee Name", clientData?.nomineeName ?? "", theme, ref),
            _buildDetailRow("Nominee Relation",
                clientData?.nomineeRelation ?? "", theme, ref),
            if (clientData?.nomineeDOB != null)
              _buildDetailRow("Nominee DOB",
                  formatNomineeDOB(clientData!.nomineeDOB! ?? ""), theme, ref),
          ],

          // Show pending statuses for Nominee section
          _buildSectionPendingStatuses('Nominee', ref, theme, () {
            profileDetails.openInWebURLk(context, "nominee", "nominee");
          },
          () {
            profileDetails.cancelPendingStatus("nominee", context);
          },
          ),
        ],
      ),
    );
  }

  /// Builds the Form Download content section
  Widget _buildFormDownloadContent(WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Download various forms and documents",
              style: MyntWebTextStyles.body(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium)),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  await Future.delayed(const Duration(milliseconds: 150));

                  profileDetails.openInWebURL(context, "formdownload");
                },
                style: ElevatedButton.styleFrom(
                    elevation: 0,
                    minimumSize: Size(100, 45),
                    backgroundColor: theme.isDarkMode
                        ? MyntColors.primaryDark
                        : MyntColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5))),
                child: Text("Download Forms",
                    style: MyntWebTextStyles.body(context,
                        color: Colors.white,
                        fontWeight: MyntFonts.bold)),
              ),
            ],
          ),
          // ElevatedButton(
          //   onPressed: () {
          //     profileDetails.openInWebURL(context, "formdownload");
          //   },
          //   style: ElevatedButton.styleFrom(
          //     elevation: 0,
          //     minimumSize: const Size(double.infinity, 40),
          //     backgroundColor:
          //         theme.isDarkMode ? Colors.black : Colors.white,
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(32),
          //     ),
          //     side: BorderSide(
          //       width: 1,
          //       color: theme.isDarkMode ? Colors.white : Colors.black,
          //     ),
          //   ),
          //   child: TextWidget.subText(
          //     text: "Download Forms",
          //     theme: theme.isDarkMode,
          //     fw: 1,
          //   ),
          // ),
          SizedBox(height: 10.0),
        ],
      ),
    );
  }

  /// Builds the Closure content section
  Widget _buildClosureContent(WidgetRef ref, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Closing your account is a permanent and irreversible action",
              style: MyntWebTextStyles.body(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final pendingStatuses =
                  ref.watch(profileAllDetailsProvider).pendingStatusList;
              if (pendingStatuses.isNotEmpty &&
                  pendingStatuses[0].data != null) {
                final hasPendingChanges = pendingStatuses[0]
                    .data!
                    .any((status) => status == 'closure_pending');
                if (hasPendingChanges) {
                  warningMessage(context, 'You have pending request.click on the E-Sign to proceed.');
                  return;
                }
              }

              await Future.delayed(const Duration(milliseconds: 150));

              // profileDetails.openInWebURL(context, "closure");
              profileDetails.openInWebURLk(context, "closure", "closure");
            },
            style: ElevatedButton.styleFrom(
                elevation: 0,
                minimumSize: Size(100, 45),
                backgroundColor:
                    theme.isDarkMode ? MyntColors.primaryDark : MyntColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5))),
            child: Text("Close Account",
                style: MyntWebTextStyles.body(context,
                    color: Colors.white,
                    fontWeight: MyntFonts.bold)),
          ),

          // Show pending statuses for Closure section
          _buildSectionPendingStatuses('Closure', ref, theme, () {
            profileDetails.openInWebURLk(context, "closure", "closure");
          },
          () {
            profileDetails.cancelPendingStatus("closure", context);
          },
          ),
        ],
      ),
    );
  }

  /// Helper method to build status chips
  Widget _buildStatusChip(String label, bool isActive, ThemesProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: theme.isDarkMode
            ? isActive
                ? MyntColors.primaryDark
                : MyntColors.listItemBg
            : isActive
                ? MyntColors.primary
                : MyntColors.listItemBg,
      ),
      child: Text(label,
          style: MyntWebTextStyles.para(context,
              color: isActive ? Colors.white : Colors.black)),
    );
  }

  /// Helper method to build segment rows
  Widget _buildSegmentRow(
      String label, Iterable segments, ThemesProvider theme) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: MyntWebTextStyles.body(context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                    fontWeight: MyntFonts.medium)),
            Row(
              children: segments.map<Widget>((segment) {
                bool isActive = segment.aCTIVEINACTIVE == "A";
                String displayName =
                    ['CD_BSE', 'CD_NSE'].contains(segment.cOMPANYCODE)
                        ? segment.cOMPANYCODE.split("_")[1]
                        : segment.cOMPANYCODE.split("_")[0];

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isActive
                        ? theme.isDarkMode
                            ? MyntColors.primaryDark
                            : MyntColors.primary
                        : null,
                    border: !isActive
                        ? Border(
                            bottom: BorderSide(
                              color: theme.isDarkMode
                                  ? MyntColors.lossDark
                                  : MyntColors.loss,
                              width: 1,
                            ),
                          )
                        : null,
                  ),
                  child: Text(displayName,
                      style: MyntWebTextStyles.body(context,
                          color: isActive
                              ? Colors.white
                              : resolveThemeColor(context,
                                  dark: MyntColors.lossDark,
                                  light: MyntColors.loss),
                          fontWeight: MyntFonts.medium)),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(
          thickness: 1,
          color: theme.isDarkMode ? MyntColors.dividerDark : MyntColors.divider,
        )
      ],
    );
  }

  /// Helper method to format date
  String _formatDate(String dateString) {
    List<String> formatPart = dateString.split(" ")[0].split("-");
    return formatPart.length == 3
        ? '${formatPart[2]}-${formatPart[1]}-${formatPart[0]}'
        : dateString;
  }

  /// Helper for consistent styling of profile detail rows (using data widget from holding_detail_screen)
  Widget _buildDetailRow(
      String label, String value, ThemesProvider theme, WidgetRef ref) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.20,
                  child: Text(label,
                      style: MyntWebTextStyles.body(context,
                          darkColor: MyntColors.textSecondaryDark,
                          lightColor: MyntColors.textSecondary,
                          fontWeight: MyntFonts.medium)),
                ),
                if (label == "Email" || label == "Mobile" || label == "Address")
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      splashColor: theme.isDarkMode
                          ? MyntColors.rippleDark
                          : MyntColors.rippleLight,
                      highlightColor: theme.isDarkMode
                          ? MyntColors.highlightDark
                          : MyntColors.highlightLight,
                      onTap: () {
                        final pendingStatuses = ref
                            .watch(profileAllDetailsProvider)
                            .pendingStatusList;
                        if (pendingStatuses.isNotEmpty &&
                            pendingStatuses[0].data != null) {
                          final hasPendingChanges = pendingStatuses[0]
                              .data!
                              .any((status) =>
                                  status == 'address_change_pending' ||
                                  status == 'mobile_change_pending' ||
                                  status == 'email_change_pending');
                          if (hasPendingChanges) {
                            warningMessage(context, 'You have pending request.click on the E-Sign to proceed.');
                            return;
                          } else {
                            if (label == "Address") {
                              final pref = locator<Preferences>();
                              final url = 'https://profile.zebuetrade.com/?uid=${pref.clientId}&token=${pref.token}';
                              html.window.open(url, '_blank', 'width=800,height=700,scrollbars=yes,resizable=yes,left=200,top=100');
                            } else {
                              ref.read(profileAllDetailsProvider).openInWebURLk(
                                  context, "profile", label.toLowerCase());
                            }
                          }
                        } else {
                          if (label == "Address") {
                            final pref = locator<Preferences>();
                            final url = 'https://profile.zebuetrade.com/?uid=${pref.clientId}&token=${pref.token}';
                            html.window.open(url, '_blank', 'width=800,height=700,scrollbars=yes,resizable=yes,left=200,top=100');
                          } else {
                            ref.read(profileAllDetailsProvider).openInWebURLk(
                                context, "profile", label.toLowerCase());
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.edit_outlined,
                          color: MyntColors.iconSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: Text(value,
                  style: MyntWebTextStyles.body(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium),
                  softWrap: true,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 4),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(
          thickness: 0,
          color: theme.isDarkMode ? MyntColors.dividerDark : MyntColors.divider,
        )
      ],
    );
  }

  /// Helper method to build data widget (same as data() from holding_detail_screen)
  Widget _buildDataWidget(String label, String value, ThemesProvider theme) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: MyntWebTextStyles.body(context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                    fontWeight: MyntFonts.medium)),
            SizedBox(
              width: 250,
              child: Text(value,
                  style: MyntWebTextStyles.body(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium),
                  textAlign: TextAlign.right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(
          thickness: 1,
          color: theme.isDarkMode ? MyntColors.dividerDark : MyntColors.divider,
        )
      ],
    );
  }

  /// Formats nominee DOB from 'October, 07 1983 00:00:00 +0530' to '07/10/1983'
  String formatNomineeDOB(String rawDate) {
    try {
      DateTime date = DateFormat("MMMM, dd yyyy HH:mm:ss Z").parse(rawDate);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return rawDate;
    }
  }
}

// -----------------------------------------------------------------------------
// PROFILE DETAILS SECTION
// -----------------------------------------------------------------------------
class _ProfileDetailsSection extends ConsumerStatefulWidget {
  const _ProfileDetailsSection();

  @override
  ConsumerState<_ProfileDetailsSection> createState() => _ProfileDetailsSectionState();
}

class _ProfileDetailsSectionState extends ConsumerState<_ProfileDetailsSection> {
  final List<String> _sections = [
    'Profile',
    'Bank',
    'Depository',
    'Margin Trading Facility (MTF)',
    'Trading Preferences',
    'Nominee',
    'Form Download',
    'Closure',
  ];

  @override
  void initState() {
    super.initState();
    // Fetch profile details on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(profileAllDetailsProvider).fetchClientProfileAllDetails();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final userProfile = ref.watch(userProfileProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User Info Header Card
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.listItemBgDark,
                light: MyntColors.listItemBg),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: MyntColors.primary,
                child: Text(
                  userProfile.userDetailModel?.uname?.substring(0, 1).toUpperCase() ?? "U",
                  style: MyntWebTextStyles.title(context,
                      color: Colors.white,
                      fontWeight: MyntFonts.bold),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userProfile.userDetailModel?.uname ?? "",
                    style: MyntWebTextStyles.bodySmall(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.semiBold),
                  ),
                  Text(
                    "Client ID: ${userProfile.userDetailModel?.uid ?? ""}",
                    style: MyntWebTextStyles.caption(context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Shadcn Accordion for profile sections
        shadcn.Accordion(
          items: _sections.map((section) => _buildAccordionItem(section, theme)).toList(),
        ),
      ],
    );
  }

  shadcn.AccordionItem _buildAccordionItem(String title, ThemesProvider theme) {
    return shadcn.AccordionItem(
      trigger: shadcn.AccordionTrigger(
        child: Text(
          title,
          style: MyntWebTextStyles.bodySmall(context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
              fontWeight: MyntFonts.medium),
        ),
      ),
      content: _buildSectionContent(title, theme),
    );
  }

  Widget _buildSectionContent(String section, ThemesProvider theme) {
    final profileDetails = ref.watch(profileAllDetailsProvider);

    if (profileDetails.isLoading) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: MyntLoader.simple()),
      );
    }

    final data = _getDataForSection(section);

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  e.key,
                  style: MyntWebTextStyles.caption(context,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  e.value,
                  style: MyntWebTextStyles.bodySmall(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Map<String, String> _getDataForSection(String section) {
    final userProfile = ref.read(userProfileProvider);
    final profileDetails = ref.read(profileAllDetailsProvider);

    switch (section) {
      case "Profile":
        final clientData = profileDetails.clientAllDetailsSafe?.clientData;
        return {
          "Mobile": userProfile.userDetailModel?.mNum ?? "--",
          "Email": userProfile.userDetailModel?.email ?? "--",
          "PAN": clientData?.pANNO ?? "--",
          "Address": "${clientData?.cLRESIADD1 ?? ''}, ${clientData?.cLRESIADD2 ?? ''}, ${clientData?.cLRESIADD3 ?? ''}",
        };
      case "Bank":
        final banks = profileDetails.clientAllDetailsSafe?.bankData;
        if (banks != null && banks.isNotEmpty) {
          return {
            "Bank Name": banks.first.bankName ?? "--",
            "Account No": banks.first.bankAcNo ?? "--",
            "IFSC": banks.first.iFSCCode ?? "--",
          };
        }
        return {"No Bank Details": "Found"};
      case "Depository":
        return {
          "DP ID": "--",
          "DP Name": "--",
          "BO ID": "--",
        };
      case "Margin Trading Facility (MTF)":
        return {
          "MTF Status": "--",
          "MTF Limit": "--",
        };
      case "Trading Preferences":
        return {
          "Exchange": "NSE, BSE",
          "Segments": "Equity, F&O",
        };
      case "Nominee":
        return {
          "Nominee Name": "--",
          "Relationship": "--",
          "Share %": "--",
        };
      case "Form Download":
        return {
          "Account Opening Form": "Download",
          "DDPI Form": "Download",
        };
      case "Closure":
        return {
          "Status": "Active",
          "Close Account": "Contact Support",
        };
      default:
        return {"Details": "View details for $section"};
    }
  }
}

// -----------------------------------------------------------------------------
// API KEY COMPONENT (Re-used)
// -----------------------------------------------------------------------------
class ApiKeyBottomTabs extends ConsumerStatefulWidget {
  const ApiKeyBottomTabs({super.key});

  @override
  ConsumerState<ApiKeyBottomTabs> createState() => _ApiKeyBottomTabsState();
}

class _ApiKeyBottomTabsState extends ConsumerState<ApiKeyBottomTabs>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: isDarkMode(context) ? MyntColors.primaryDark : MyntColors.primary,
          unselectedLabelColor: resolveThemeColor(context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary),
          indicatorColor: isDarkMode(context) ? MyntColors.primaryDark : MyntColors.primary,
          labelStyle: MyntWebTextStyles.bodySmall(context,
              fontWeight: MyntFonts.semiBold),
          unselectedLabelStyle: MyntWebTextStyles.bodySmall(context,
              fontWeight: MyntFonts.medium),
          dividerColor: Colors.transparent,
          labelPadding: EdgeInsets.all(0),
          // indicatorPadding: EdgeInsets.all(0),
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: "Base Key"),
            Tab(text: "OAuth Key"),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              ApiKeyScreen(),
              ApiKeyScreenNew(),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TOTP INLINE WIDGET
// -----------------------------------------------------------------------------
class _TotpInlineWidget extends StatefulWidget {
  final String secretKey;
  final bool isDark;
  final VoidCallback? onRegenerate;

  const _TotpInlineWidget({
    super.key,
    required this.secretKey,
    required this.isDark,
    this.onRegenerate,
  });

  @override
  State<_TotpInlineWidget> createState() => _TotpInlineWidgetState();
}

class _TotpInlineWidgetState extends State<_TotpInlineWidget> {
  bool isObscure = true;
  String otp = 'Loading...';
  late Timer timer;
  String totpkey = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  int remainingSeconds = 30;

  @override
  void initState() {
    super.initState();
    setTOTP();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  String base32ToHex(String base32) {
    var base32Chars = totpkey;
    String bits = '';
    String hex = '';

    for (int i = 0; i < base32.length; i++) {
      int val = base32Chars.indexOf(base32[i].toUpperCase());
      bits += val.toRadixString(2).padLeft(5, '0');
    }

    for (int i = 0; i + 8 <= bits.length; i += 8) {
      String byte = bits.substring(i, i + 8);
      hex += int.parse(byte, radix: 2).toRadixString(16).padLeft(2, '0');
    }

    return hex;
  }

  Uint8List hexToBytes(String hex) {
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  void setTOTP() async {
    generateTOTP();
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      generateTOTP();
      if (mounted) {
        setState(() {
          int currentSecond = DateTime.now().second;
          remainingSeconds = 30 - (currentSecond % 30);
        });
      }
    });
  }

  void generateTOTP() {
    String key = base32ToHex(widget.secretKey);

    int epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int time = (epoch ~/ 30);
    String timeHex = time.toRadixString(16).padLeft(16, '0');

    Uint8List timeBuffer = hexToBytes(timeHex);
    Uint8List keyBuffer = hexToBytes(key);

    Hmac hmac = Hmac(sha1, keyBuffer);
    Digest digest = hmac.convert(timeBuffer);

    List<int> hash = digest.bytes;
    int offset = hash[hash.length - 1] & 0xf;
    int binary = ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);

    int otpNumber = binary % 1000000;
    String otpCode = otpNumber.toString().padLeft(6, '0');

    if (mounted) {
      setState(() {
        otp = otpCode;
      });
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    successMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Token Label
          Text(
            'Token',
            style: MyntWebTextStyles.bodySmall(context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
                fontWeight: MyntFonts.medium),
          ),
          const SizedBox(height: 8),

          // Token Value with Copy and Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    otp.length >= 6 ? '${otp.substring(0, 3)} ${otp.substring(3, 6)}' : otp,
                    style: MyntWebTextStyles.title(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.semiBold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.copy, size: 18,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary)),
                    onPressed: () => _copyToClipboard(otp, 'TOTP copied to clipboard'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              Text(
                '$remainingSeconds sec',
                style: MyntWebTextStyles.para(context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Authenticator Key Label + inline Regenerate action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Authenticator Key',
                style: MyntWebTextStyles.bodySmall(context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                    fontWeight: MyntFonts.medium),
              ),
              if (widget.onRegenerate != null)
                InkWell(
                  onTap: widget.onRegenerate,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 14,
                          color: resolveThemeColor(context,
                              dark: MyntColors.primaryDark,
                              light: MyntColors.primary),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Regenerate',
                          style: MyntWebTextStyles.bodySmall(context,
                              darkColor: MyntColors.primaryDark,
                              lightColor: MyntColors.primary,
                              fontWeight: MyntFonts.medium),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Authenticator Key Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.listItemBgDark,
                  light: MyntColors.listItemBg),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: resolveThemeColor(context,
                  dark: MyntColors.primaryDark,
                  light: MyntColors.primary), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isObscure ? '••••••••••••••••••••' : widget.secretKey,
                    style: MyntWebTextStyles.para(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isObscure ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                      ),
                      onPressed: () => setState(() => isObscure = !isObscure),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(Icons.copy, size: 18,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary)),
                      onPressed: () => _copyToClipboard(widget.secretKey, 'Auth Key is copied to Clipboard'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A hoverable card widget for profile/report sections.
/// Shows icon, title, description, chevron with hover color change and optional pending badge.
class _ProfileHoverCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final bool hasPending;
  final VoidCallback onTap;

  const _ProfileHoverCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.onTap,
    this.hasPending = false,
  });

  @override
  State<_ProfileHoverCard> createState() => _ProfileHoverCardState();
}

class _ProfileHoverCardState extends State<_ProfileHoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark;

    final bgColor = _hovered
        ? (dark ? MyntColors.cardHoverDark : MyntColors.cardHover)
        : (dark ? MyntColors.cardDark : MyntColors.card);

    final borderColor = _hovered
        ? (dark
            ? MyntColors.primaryDark.withValues(alpha: 0.4)
            : MyntColors.primary.withValues(alpha: 0.25))
        : (dark ? MyntColors.cardBorderDark : MyntColors.cardBorder);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              // Icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: dark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: dark
                      ? widget.iconColor.withValues(alpha: 0.9)
                      : widget.iconColor,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),

              // Text content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: MyntFonts.medium,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        darkColor: MyntColors.textTertiaryDark,
                        lightColor: MyntColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Pending badge or Arrow
              if (widget.hasPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Pending',
                    style: MyntWebTextStyles.caption(context,
                      color: dark
                          ? Colors.orange.shade300
                          : Colors.orange.shade700,
                      fontWeight: MyntFonts.semiBold,
                    ).copyWith(decoration: TextDecoration.none),
                  ),
                )
              else
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _hovered ? 1.0 : 0.4,
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: _hovered
                        ? (dark
                            ? MyntColors.primaryDark
                            : MyntColors.primary)
                        : resolveThemeColor(context,
                            dark: MyntColors.textTertiaryDark,
                            light: MyntColors.textTertiary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


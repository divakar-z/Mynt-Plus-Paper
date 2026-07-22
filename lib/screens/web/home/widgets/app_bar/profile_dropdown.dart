import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart'
    hide MenuController, TextButton, AlertDialog, DropdownMenu, showDialog;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'dart:html' as html;
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/provider/auth_provider.dart';
import 'package:mynt_plus/provider/notification_provider.dart';
import 'package:mynt_plus/provider/privacy_provider.dart';
import 'package:mynt_plus/provider/profile_all_details_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/user_profile_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/web_colors.dart' as web_colors;
import 'package:mynt_plus/res/global_font_web.dart';
import 'package:mynt_plus/routes/route_names.dart';
import 'package:mynt_plus/routes/web_router.dart';
import 'package:mynt_plus/screens/web/profile/logged_user_list_web.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Theme;
import 'package:share_plus/share_plus.dart';
import '../../../customizable_split_home_screen.dart' show ScreenType, tickerVisibilityNotifier, toggleTickerVisibility;
import '../../../market_watch/tv_chart/chart_iframe_guard.dart';
import 'package:mynt_plus/utils/pip_service.dart';
import 'package:mynt_plus/provider/portfolio_provider.dart';

// Profile dropdown widget using shadcn
class ProfileDropdown extends ConsumerStatefulWidget {
  final bool isDarkMode;
  final String clientId;
  final Function(dynamic)? onNavigateToScreen;
  final VoidCallback? onThemeToggle;
  final VoidCallback? onSwapPanels;

  const ProfileDropdown({
    super.key,
    required this.isDarkMode,
    required this.clientId,
    this.onNavigateToScreen,
    this.onThemeToggle,
    this.onSwapPanels,
  });

  @override
  ConsumerState<ProfileDropdown> createState() => _ProfileDropdownState();
}

class _ProfileDropdownState extends ConsumerState<ProfileDropdown> {
  final TapGestureRecognizer _reopenAccountRecognizer = TapGestureRecognizer()
    ..onTap = () {
      html.window.open('https://oa.mynt.in/', '_blank');
    };

  @override
  void dispose() {
    _reopenAccountRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Capture parent context for navigation
    final parentContext = context;

    // `accountstatus == 'client_close'` derivation
    // (segments_data[].inactivetype_DESC ∈ {"Close Client-Close",
    // "close-Close"}). When true, render the red alert + tooltip on the
    // profile activator and the inline top-bar warning text on wider screens.
    final clientData =
        ref.watch(profileAllDetailsProvider).clientAllDetailsSafe?.clientData;
    final bool isClientClosed = clientData?.isClientClosed ?? false;
    const String closedMsg = 'Your trading account is closed.';
    final bool showInlineWarning =
        MediaQuery.of(context).size.width >= 1000;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GhostButton(
        onPressed: () {
          showDropdown(
            context: context,
            builder: (dropdownContext) {
              return ProfileDropdownMenu(
                isDarkMode: widget.isDarkMode,
                clientId: widget.clientId,
                onNavigateToScreen: widget.onNavigateToScreen,
                parentContext: parentContext,
                onThemeToggle: widget.onThemeToggle,
                onSwapPanels: widget.onSwapPanels,
              );
            },
          ).future.then((_) {
            if (kDebugMode) {
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isClientClosed && showInlineWarning) ...[
              Builder(builder: (context) {
                final errorColor = resolveThemeColor(
                  context,
                  dark: MyntColors.errorDark,
                  light: MyntColors.error,
                );
                final baseStyle = MyntWebTextStyles.bodySmall(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: errorColor,
                );
                return RichText(
                  text: TextSpan(
                    style: baseStyle,
                    children: [
                      const TextSpan(text: 'Your trading account is closed . '),
                      TextSpan(
                        text: 'Click here',
                        style: baseStyle.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: _reopenAccountRecognizer,
                        mouseCursor: SystemMouseCursors.click,
                      ),
                      const TextSpan(text: ' to reopen your account.'),
                    ],
                  ),
                );
              }),
              const SizedBox(width: 8),
            ],
            if (isClientClosed) ...[
              material.Tooltip(
                message: closedMsg,
                child: Icon(
                  Icons.error_outline,
                  size: 20,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.errorDark,
                    light: MyntColors.error,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              widget.clientId,
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.semiBold,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Profile dropdown menu content using shadcn DropdownMenu
class ProfileDropdownMenu extends ConsumerStatefulWidget {
  final bool isDarkMode;
  final String clientId;
  final Function(dynamic)? onNavigateToScreen;
  final BuildContext parentContext;
  final VoidCallback? onThemeToggle;
  final VoidCallback? onSwapPanels;

  const ProfileDropdownMenu({
    super.key,
    required this.isDarkMode,
    required this.clientId,
    required this.parentContext,
    this.onNavigateToScreen,
    this.onThemeToggle,
    this.onSwapPanels,
  });

  @override
  ConsumerState<ProfileDropdownMenu> createState() => _ProfileDropdownMenuState();
}

class _ProfileDropdownMenuState extends ConsumerState<ProfileDropdownMenu> {
  // The menu is taller than most screens; it is capped in height and scrolled
  // with an always-visible scrollbar (same style as the scanner screen).
  final ScrollController _menuScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Acquire chart iframe guard on init to prevent cursor bleed
    ChartIframeGuard.acquire();
    _disableAllChartIframes();
  }

  // Directly disable all chart iframes and reset cursor
  void _disableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'none';
          iframe.style.cursor = 'default';
        }
      }
      html.document.body?.style.cursor = 'default';
    } catch (e) {
    }
  }

  void _enableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'auto';
          iframe.style.cursor = '';
        }
      }
      html.document.body?.style.cursor = '';
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _menuScrollController.dispose();
    // Release chart iframe guard and re-enable iframes
    ChartIframeGuard.release();
    _enableAllChartIframes();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final theme = ref.watch(themeProvider);
    final Preferences pref = locator<Preferences>();
    final String reflink = "https://oa.mynt.in/?ref=${pref.clientId}";

    final userName = userProfile.userDetailModel?.uname ?? widget.clientId;
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    final textColor = resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final iconColor = resolveThemeColor(context, dark: MyntColors.iconDark, light: MyntColors.icon);

    return PointerInterceptor(
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) {
          ChartIframeGuard.acquire();
          _disableAllChartIframes();
        },
        onHover: (_) {
          _disableAllChartIframes();
        },
        onExit: (_) {
          ChartIframeGuard.release();
          _enableAllChartIframes();
        },
        child: Listener(
          onPointerMove: (_) {
            _disableAllChartIframes();
          },
          child: SizedBox(
            width: 300,
            child: ConstrainedBox(
              // Cap the menu height so Logout is always reachable.
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: MenuGroup(
                regionGroupId: Data.maybeOf<DropdownMenuData>(context)?.key,
                direction: Axis.vertical,
                itemPadding: EdgeInsets.zero,
                onDismissed: () {
                  closeOverlay(context);
                },
                builder: (context, children) {
                  // One popover card (same ModalContainer surface the stock
                  // DropdownMenu paints). The first two built items — the
                  // user header and its divider — stay pinned; everything
                  // after them scrolls inside the card behind an
                  // always-visible scrollbar (scanner style).
                  final shadTheme = shadcn.Theme.of(context);
                  return ModalContainer(
                    borderRadius: shadTheme.borderRadiusMd,
                    filled: true,
                    fillColor: shadTheme.colorScheme.popover,
                    borderColor: shadTheme.colorScheme.border,
                    surfaceBlur: shadTheme.surfaceBlur,
                    surfaceOpacity: shadTheme.surfaceOpacity,
                    padding: const EdgeInsets.all(4) * shadTheme.scaling,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        children[0],
                        children[1],
                        Flexible(
                          child: RawScrollbar(
                            controller: _menuScrollController,
                            thumbVisibility: true,
                            thickness: 6,
                            radius: const Radius.circular(8),
                            thumbColor: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary)
                                .withValues(alpha: 0.5),
                            child: SingleChildScrollView(
                              controller: _menuScrollController,
                              // Right gutter so content never sits under the
                              // always-visible scrollbar (same as scanner).
                              padding: const EdgeInsets.only(right: 10),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: children.sublist(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).normal();
                },
        children: [
          // User Profile Header (pinned above the scrolling items)
          MenuButton(
            // onPressed: (ctx) {
            //   Navigator.pushNamed(widget.parentContext, Routes.myAcc);
            // },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // User Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.primaryDark.withValues(alpha: 0.08),
                        light: MyntColors.primary.withValues(alpha: 0.08),
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        userInitial,
                        style: MyntWebTextStyles.head(
                          context,
                          fontWeight: MyntFonts.semiBold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: MyntWebTextStyles.titlesub(
                            context,
                            color: textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.clientId,
                          style: MyntWebTextStyles.para(
                            context,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const MenuDivider(),

          // My Account
            _buildMenuItem(
              context,
              icon: Icons.person_outline,
              title: 'My Account',
              subtitle: 'Profile, Bank, Segment, MTF',
              iconColor: iconColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
              onPressed: (ctx) {
                if (widget.onNavigateToScreen != null) {
                  widget.onNavigateToScreen!(ScreenType.myAccount);
                }
              },
            ),

            // Reports
            _buildMenuItem(
              context,
              icon: Icons.description_outlined,
              title: 'Reports',
              subtitle: 'Ledger, Holdings, PnL, Tax',
              iconColor: iconColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
           onPressed: (ctx) {
                widget.onNavigateToScreen!(ScreenType.reports);
              },
            ),

            // Corporate Action — internal screen (Buyback / Delisting / Takeover / OFS)
            _buildMenuItem(
              context,
              icon: Icons.business_outlined,
              title: 'Corporate Action',
              subtitle: 'Buyback, Delisting, Takeover, OFS',
              iconColor: iconColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
              onPressed: (ctx) {
                if (widget.onNavigateToScreen != null) {
                  widget.onNavigateToScreen!(ScreenType.caBuyback);
                } else {
                  Navigator.pushNamed(
                      widget.parentContext, WebRoutes.caBuyback);
                }
              },
            ),

            // Pledge & Unpledge
            _buildMenuItem(
              context,
              icon: Icons.lock_outline,
              title: 'Pledge & Unpledge',
              subtitle: 'Stocks held by various accounts',
              iconColor: iconColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
              onPressed: (ctx) async {
                if (widget.onNavigateToScreen != null) {
                  widget.onNavigateToScreen!(ScreenType.pledgeUnpledge);
                } else {
                  Navigator.pushNamed(widget.parentContext, Routes.pledgeandun);
                }
              },
            ),

            // Refer
            _buildMenuItem(
              context,
              icon: Icons.card_giftcard_outlined,
              title: 'Refer',
              subtitle: 'Refer your family & friends',
              iconColor: iconColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
              onPressed: (ctx) async {
                if (widget.onNavigateToScreen != null) {
                  widget.onNavigateToScreen!(ScreenType.refer);
                }
              },
            ),

            // Help & Support
            _buildMenuItem(
              context,
              icon: Icons.headset_mic_outlined,
              title: 'Help & Support',
              subtitle: 'Sales, Support & Desk',
              iconColor: iconColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
              onPressed: (ctx) async {
                if (widget.onNavigateToScreen != null) {
                  widget.onNavigateToScreen!(ScreenType.helpSupport);
                }
              },
            ),
            // webhook
            _buildMenuItem(
              context,
              icon: Icons.webhook,
              title: 'WebHook',
              subtitle: 'TradingView & Auto Alerts',
              iconColor: iconColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
              onPressed: (ctx) {
                if (widget.onNavigateToScreen != null) {
                  widget.onNavigateToScreen!(ScreenType.tradingViewWebHook);
                } else {
                  context.go(WebRoutes.tradingViewWebHook);
                }
              },
            ),
            // Setting
            _buildMenuItem(
              context,
              icon: Icons.settings_outlined,
              title: 'Setting',
              subtitle: 'API key, Change password',
              iconColor: iconColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
              onPressed: (ctx) async {
                if (widget.onNavigateToScreen != null) {
                  widget.onNavigateToScreen!(ScreenType.settings);
                } else {
                  await ref.read(userProfileProvider).fetchsetting();
                  Navigator.pushNamed(widget.parentContext, Routes.profilesettingscreen);
                }
              },
            ),

            // Notification
            _buildMenuItem(
              context,
              icon: Icons.notifications_outlined,
              title: 'Notification',
              subtitle: 'Alerts & Exchange messages',
              iconColor: iconColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
              onPressed: (ctx) async {
                // Pre-fetch notification data before navigating
                final notificationProviderRef = ref.read(notificationprovider);
                // Start all fetches in parallel (don't await all - just start them)
                notificationProviderRef.fetchbrokermsg(widget.parentContext);
                notificationProviderRef.fetchexchagemsg(widget.parentContext);
                notificationProviderRef.fetchInformationMessages(widget.parentContext);
                notificationProviderRef.fetchexchstatus(widget.parentContext);

                if (widget.onNavigateToScreen != null) {
                  widget.onNavigateToScreen!(ScreenType.notification);
                } else {
                  Navigator.pushNamed(widget.parentContext, Routes.notificationscreenweb);
                }
              },
            ),

          const MenuDivider(),

          // Swap Panels
          if (widget.onSwapPanels != null)
            _buildSimpleMenuItem(
              context,
              icon: Icons.swap_horiz,
              title: 'Swap Panels',
              iconColor: iconColor,
              textColor: textColor,
              onPressed: (ctx) {
                widget.onSwapPanels!();
              },
            ),

          // Ticker Strip Toggle
          _buildTickerToggleMenuItem(
            context,
            iconColor: iconColor,
            textColor: textColor,
            pref: pref,
          ),

          // Privacy Mode Toggle — masks P&L/holdings/fund values app-wide
          _buildPrivacyToggleMenuItem(
            context,
            iconColor: iconColor,
            textColor: textColor,
          ),

          // Position PiP Toggle
          if (PipService.isSupported)
            _buildPipToggleMenuItem(
              context,
              iconColor: iconColor,
              textColor: textColor,
            ),

          // Theme Toggle
          if (widget.onThemeToggle != null)
            _buildSimpleMenuItem(
              context,
              icon: theme.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              title: theme.isDarkMode ? 'Light Mode' : 'Dark Mode',
              iconColor: iconColor,
              textColor: textColor,
              onPressed: (ctx) {
                widget.onThemeToggle!();
              },
            ),

          // Switch Account
          // _buildSimpleMenuItem(
          //   context,
          //   icon: Icons.switch_account_outlined,
          //   title: 'Switch Account',
          //   iconColor: iconColor,
          //   textColor: textColor,
          //   onPressed: (ctx) {
          //     material.showDialog(
          //       context: widget.parentContext,
          //       builder: (context) => const LoggedUserListWeb(initRoute: ''),
          //     );
          //   },
          // ),

          // const MenuDivider(),

          // Logout
          MenuButton(
            onPressed: (ctx) {
              _showLogoutDialog(widget.parentContext, ref, theme);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    size: 22,
                    color: resolveThemeColor(context, dark: MyntColors.iconDark, light: MyntColors.icon),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Logout',
                    style: MyntWebTextStyles.body(
                      context,
                      fontWeight: MyntFonts.medium,
                      color: textColor,
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
      ),
    );
  }

  MenuButton _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color textColor,
    required Color subtitleColor,
    required void Function(BuildContext) onPressed,
  }) {
    return MenuButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                size: 22,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MyntWebTextStyles.body(
                      context,
                      fontWeight: MyntFonts.medium,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: MyntWebTextStyles.para(
                      context,
                      color: subtitleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  MenuButton _buildSimpleMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color textColor,
    required void Function(BuildContext) onPressed,
  }) {
    return MenuButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: iconColor,
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.medium,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  MenuButton _buildTickerToggleMenuItem(
    BuildContext context, {
    required Color iconColor,
    required Color textColor,
    required Preferences pref,
  }) {
    final isTickerVisible = tickerVisibilityNotifier.value;
    return MenuButton(
      onPressed: (ctx) async {
        await toggleTickerVisibility();
        setState(() {}); // Refresh the menu to show updated state
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              isTickerVisible ? Icons.visibility : Icons.visibility_off,
              size: 22,
              color: iconColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Portfolio Ticker',
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: textColor,
                ),
              ),
            ),
            Container(
              width: 36,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isTickerVisible
                    ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: isTickerVisible ? 18 : 2,
                    top: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  MenuButton _buildPrivacyToggleMenuItem(
    BuildContext context, {
    required Color iconColor,
    required Color textColor,
  }) {
    final privacy = ref.watch(privacyProvider);
    final isPrivate = privacy.isPrivate;
    return MenuButton(
      onPressed: (ctx) async {
        await privacy.toggle();
        setState(() {}); // Refresh the menu to show updated state
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              isPrivate ? Icons.shield : Icons.shield_outlined,
              size: 22,
              color: iconColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Privacy Mode',
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: textColor,
                ),
              ),
            ),
            Container(
              width: 36,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isPrivate
                    ? resolveThemeColor(context,
                        dark: MyntColors.secondary, light: MyntColors.primary)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: isPrivate ? 18 : 2,
                    top: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  MenuButton _buildPipToggleMenuItem(
    BuildContext context, {
    required Color iconColor,
    required Color textColor,
  }) {
    final isPipActive = pipVisibilityNotifier.value;
    return MenuButton(
      onPressed: (ctx) async {
        final portfolio = ref.read(portfolioProvider);
        final themeState = ref.read(themeProvider);
        final positions = PipService.buildPositionItems(
          groupedBySymbol: portfolio.groupedBySymbol,
          groupPositionSym: portfolio.groupPositionSym,
        );
        await PipService.togglePip(
          pnl: portfolio.totPnL,
          mtm: portfolio.totMtM,
          positions: positions,
          isDarkMode: themeState.isDarkMode,
        );
        setState(() {}); // Refresh the menu to show updated state
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              isPipActive
                  ? Icons.picture_in_picture_alt
                  : Icons.picture_in_picture_alt_outlined,
              size: 22,
              color: iconColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Position PiP',
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: textColor,
                ),
              ),
            ),
            Container(
              width: 36,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isPipActive
                    ? resolveThemeColor(context,
                        dark: MyntColors.secondary, light: MyntColors.primary)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: isPipActive ? 18 : 2,
                    top: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(
      BuildContext context, WidgetRef ref, ThemesProvider theme) {
    // Store the parent context for use in the logout callback
    final parentContext = context;
    // Capture authProvider before showing dialog to avoid "ref unmounted" error
    final authProviderRef = ref.read(authProvider);
    material.showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: theme.isDarkMode
              ? MyntColors.dialogDark : MyntColors.dialog,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: PointerInterceptor(
            child: MouseRegion(
              cursor: SystemMouseCursors.basic,
              onEnter: (_) {
                ChartIframeGuard.acquire();
                _disableAllChartIframes();
              },
              onHover: (_) {
                _disableAllChartIframes();
              },
              onExit: (_) {
                ChartIframeGuard.release();
                _enableAllChartIframes();
              },
              child: Listener(
                onPointerMove: (_) {
                  _disableAllChartIframes();
                },
                child: GestureDetector(
                  onTap: () {},
                  child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.isDarkMode
                            ? MyntColors.dividerDark
                            : MyntColors.divider,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Logout',
                        style: WebTextStyles.dialogTitle(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? MyntColors.textPrimaryDark
                              : MyntColors.textPrimary,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          splashColor: theme.isDarkMode
                              ? Colors.white.withOpacity(.15)
                              : Colors.black.withOpacity(.15),
                          highlightColor: theme.isDarkMode
                              ? Colors.white.withOpacity(.08)
                              : Colors.black.withOpacity(.08),
                          onTap: () => Navigator.of(dialogContext).pop(),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: theme.isDarkMode
                                  ? MyntColors.iconSecondaryDark
                                  : MyntColors.iconSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 16, top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Are you sure you want to logout?",
                            style: WebTextStyles.dialogContent(
                              isDarkTheme: theme.isDarkMode,
                              color: theme.isDarkMode
                                  ? MyntColors.textPrimaryDark
                                  : MyntColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.isDarkMode
                                    ? MyntColors.secondary
                                    : MyntColors.primary,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(5),
                                  splashColor: Colors.white.withOpacity(0.2),
                                  highlightColor: Colors.white.withOpacity(0.1),
                                  onTap: () async {
                                    Navigator.of(dialogContext).pop();
                                    await authProviderRef.fetchLogout(parentContext);
                                  },
                                  child: Center(
                                    child: Text(
                                      'Logout',
                                      style: WebTextStyles.buttonMd(
                                        isDarkTheme: theme.isDarkMode,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Keep these for backward compatibility if needed elsewhere
class ProfileMenuContentWrapper extends StatelessWidget {
  final VoidCallback onNavigate;

  const ProfileMenuContentWrapper({
    super.key,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class ProfileCloseCallback extends InheritedWidget {
  final VoidCallback onClose;

  const ProfileCloseCallback({
    super.key,
    required this.onClose,
    required super.child,
  });

  static ProfileCloseCallback? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ProfileCloseCallback>();
  }

  @override
  bool updateShouldNotify(ProfileCloseCallback oldWidget) {
    return onClose != oldWidget.onClose;
  }
}


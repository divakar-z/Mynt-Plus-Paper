import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart' hide WebColors;

/// Navigation drawer content for mobile/tablet responsive view.
/// Used inside shadcn openDrawer() - no Material Drawer wrapper needed.
class NavigationDrawerWeb extends StatelessWidget {
  final bool isDarkMode;
  final String clientId;
  final String userName;
  final bool Function(String screenName)? isScreenActive;
  final VoidCallback onDashboardTap;
  final VoidCallback onPositionsTap;
  final VoidCallback onHoldingsTap;
  final VoidCallback onOrderBookTap;
  final VoidCallback onFundsTap;
  final VoidCallback onIPOTap;
  final VoidCallback onSwapPanels;
  final VoidCallback? onThemeToggle;
  final VoidCallback? onMutualFundTap;
  final VoidCallback? onBondsTap;
  final VoidCallback? onOptionZTap;
  final VoidCallback? onOptionFlashTap;
  final VoidCallback? onScalperTap;
  final VoidCallback? onStrategyBuilderTap;
  final VoidCallback? onChartsTap;
  final VoidCallback? onClose;

  // Control which items to show - if null, show all items
  final bool? showHome;
  final bool? showPositions;
  final bool? showHoldings;
  final bool? showOrders;
  final bool? showFunds;
  final bool? showMutualFund;
  final bool? showIPO;
  final bool? showBonds;
  final bool? showOptionZ;
  final bool? showOptionFlash;
  final bool? showScalper;
  final bool? showStrategyBuilder;
  final bool? showCharts;

  const NavigationDrawerWeb({
    super.key,
    required this.isDarkMode,
    required this.clientId,
    this.userName = '',
    this.isScreenActive,
    required this.onDashboardTap,
    required this.onPositionsTap,
    required this.onHoldingsTap,
    required this.onOrderBookTap,
    required this.onFundsTap,
    required this.onIPOTap,
    required this.onSwapPanels,
    this.onThemeToggle,
    this.onMutualFundTap,
    this.onBondsTap,
    this.onOptionZTap,
    this.onOptionFlashTap,
    this.onScalperTap,
    this.onStrategyBuilderTap,
    this.onChartsTap,
    this.onClose,
    this.showHome,
    this.showPositions,
    this.showHoldings,
    this.showOrders,
    this.showFunds,
    this.showMutualFund,
    this.showIPO,
    this.showBonds,
    this.showOptionZ,
    this.showOptionFlash,
    this.showScalper,
    this.showStrategyBuilder,
    this.showCharts,
  });

  /// Display name: use userName if available, fallback to clientId
  String get _displayName =>
      userName.isNotEmpty ? userName : clientId;

  /// First letter for avatar: prefer userName, fallback to clientId
  String get _displayInitial {
    final source = userName.isNotEmpty ? userName : clientId;
    return source.isNotEmpty ? source[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark,
        light: MyntColors.textPrimary);
    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark,
        light: MyntColors.divider);

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Header with logo
            Container(
              padding: const EdgeInsets.only(left: 20, right: 8, top: 10, bottom: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: dividerColor.withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SvgPicture.asset(
                      assets.appLogoIcon,
                      width: 80,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      icon: Icon(shadcn.LucideIcons.x, color: textColor, size: 16),
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),

            // Navigation items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Home - show if null or true
                  if (showHome ?? true)
                    _buildDrawerItem(
                      context: context,
                      title: 'Home',
                      icon: shadcn.RadixIcons.home,
                      screenName: 'dashboard',
                      onTap: onDashboardTap,
                    ),

                  // TRADE section - show if any TRADE item is visible
                  if ((showPositions ?? true) || (showHoldings ?? true) || (showOrders ?? true) || (showFunds ?? true) || (showOptionZ ?? (onOptionZTap != null)) || (showOptionFlash ?? (onOptionFlashTap != null)) || (showScalper ?? (onScalperTap != null)) || (showStrategyBuilder ?? (onStrategyBuilderTap != null)) || (showCharts ?? (onChartsTap != null)))
                    _buildSectionHeader(context, 'TRADE'),
                  if (showPositions ?? true)
                    _buildDrawerItem(
                      context: context,
                      title: 'Positions',
                      icon: shadcn.LucideIcons.chartCandlestick,
                      screenName: 'positions',
                      onTap: onPositionsTap,
                    ),
                  if (showHoldings ?? true)
                    _buildDrawerItem(
                      context: context,
                      title: 'Holdings',
                      icon: shadcn.LucideIcons.briefcase,
                      screenName: 'holdings',
                      onTap: onHoldingsTap,
                    ),
                  if (showOrders ?? true)
                    _buildDrawerItem(
                      context: context,
                      title: 'Orders',
                      icon: shadcn.BootstrapIcons.receipt,
                      screenName: 'orderBook',
                      onTap: onOrderBookTap,
                    ),
                  if (showFunds ?? true)
                    _buildDrawerItem(
                      context: context,
                      title: 'Funds',
                      icon: shadcn.LucideIcons.wallet,
                      screenName: 'funds',
                      onTap: onFundsTap,
                    ),
                  if ((showOptionZ ?? (onOptionZTap != null)) && onOptionZTap != null)
                    _buildDrawerItem(
                      context: context,
                      title: 'OptionZ',
                      icon: shadcn.LucideIcons.chartBar,
                      screenName: 'tradeAction',
                      onTap: onOptionZTap!,
                    ),
                  if ((showOptionFlash ?? (onOptionFlashTap != null)) && onOptionFlashTap != null)
                    _buildDrawerItem(
                      context: context,
                      title: 'Option Flash',
                      icon: shadcn.BootstrapIcons.lightning,
                      screenName: 'optionFlash',
                      onTap: onOptionFlashTap!,
                    ),
                  if ((showScalper ?? (onScalperTap != null)) && onScalperTap != null)
                    _buildDrawerItemWithBadge(
                      context: context,
                      title: 'Scalper',
                      icon: Icons.speed,
                      screenName: 'scalper',
                      badge: 'Beta',
                      onTap: onScalperTap!,
                    ),
                  if ((showStrategyBuilder ?? (onStrategyBuilderTap != null)) && onStrategyBuilderTap != null)
                    _buildDrawerItemWithBadge(
                      context: context,
                      title: 'Strategy Builder',
                      icon: Icons.show_chart,
                      screenName: 'strategyBuilder',
                      badge: 'NEW',
                      onTap: onStrategyBuilderTap!,
                    ),
                  if ((showCharts ?? (onChartsTap != null)) && onChartsTap != null)
                    _buildDrawerItem(
                      context: context,
                      title: 'Charts',
                      icon: shadcn.LucideIcons.chartLine,
                      screenName: 'charts',
                      onTap: onChartsTap!,
                    ),

                  // INVEST section - show if any INVEST item is visible
                  if ((showMutualFund ?? (onMutualFundTap != null)) || (showIPO ?? true) || (showBonds ?? (onBondsTap != null)))
                    _buildSectionHeader(context, 'INVEST'),
                  if ((showMutualFund ?? (onMutualFundTap != null)) && onMutualFundTap != null)
                    _buildDrawerItem(
                      context: context,
                      title: 'Mutual Fund',
                      icon: shadcn.BootstrapIcons.cashCoin,
                      screenName: 'mutualFund',
                      onTap: onMutualFundTap!,
                    ),
                  if (showIPO ?? true)
                    _buildDrawerItem(
                      context: context,
                      title: 'IPO',
                      icon: shadcn.BootstrapIcons.suitcaseLg,
                      screenName: 'ipo',
                      onTap: onIPOTap,
                    ),
                  if ((showBonds ?? (onBondsTap != null)) && onBondsTap != null)
                    _buildDrawerItem(
                      context: context,
                      title: 'Bonds',
                      icon: shadcn.LucideIcons.receiptText,
                      screenName: 'bond',
                      onTap: onBondsTap!,
                    ),
                ],
              ),
            ),

            // Footer with user name
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: dividerColor.withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: (isDarkMode ?  MyntColors.primaryDark : MyntColors.primary).withValues(alpha: isDarkMode ? 0.2 : 0.1),
                    child: Text(
                      _displayInitial,
                      style: MyntWebTextStyles.hero(
                        context,
                        color:  isDarkMode ? MyntColors.primaryDark : MyntColors.primary,
                        fontWeight: MyntFonts.semiBold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: MyntWebTextStyles.body(
                            context,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary),
                            fontWeight: MyntFonts.semiBold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          clientId,
                          style: MyntWebTextStyles.para(
                            context,
                            fontWeight: MyntFonts.medium,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ),
                      ],
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 4),
      child: Text(
        title,
        style: MyntWebTextStyles.caption(
          context,
          color: resolveThemeColor(context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.textSecondary),
          fontWeight: MyntFonts.semiBold,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String screenName,
    required VoidCallback onTap,
  }) {
    final isActive = isScreenActive?.call(screenName) ?? false;

    final activeColor = resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark,
        light: MyntColors.textPrimary);
    final hoverColor = resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive ? hoverColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? activeColor : textColor,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: MyntWebTextStyles.body(
                    context,
                    color: isActive ? activeColor : textColor,
                    fontWeight: isActive ? MyntFonts.bold : MyntFonts.medium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItemWithBadge({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String screenName,
    required String badge,
    required VoidCallback onTap,
  }) {
    final isActive = isScreenActive?.call(screenName) ?? false;

    final activeColor = resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark,
        light: MyntColors.textPrimary);
    final hoverColor = resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive ? hoverColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? activeColor : textColor,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: MyntWebTextStyles.body(
                    context,
                    color: isActive ? activeColor : textColor,
                    fontWeight: isActive ? MyntFonts.bold : MyntFonts.medium,
                  ),
                ),
                const SizedBox(width: 4),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Text(
                    badge,
                    style: MyntWebTextStyles.caption(
                      context,
                      color: Colors.red,
                      fontWeight: MyntFonts.semiBold,
                    ).copyWith(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/provider/index_list_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'common_buttons_web.dart';

import '../../res/res.dart';

/// Reusable empty-state widget for Trading App.
///
/// - Modern, card-based design with dashed borders.
/// - structured layout suitable for dashboards.
class NoDataFoundWeb extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final Widget? body;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryEnabled;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final bool secondaryEnabled;
  final String? assetIcon;

  /// Overrides the SVG icon with any widget (e.g. a Material [Icon]) —
  /// for callers whose icon has no SVG asset. Wins over [assetIcon].
  final Widget? iconWidget;
  final double iconSize;
  final bool showTip;
  final String tipText;

  /// Tight spacing for small hosts (dropdown panels, popovers): slimmer
  /// margins, an icon box sized to the icon, a title one step smaller, and
  /// smaller gaps. Default off — full-screen callers are unaffected.
  final bool compact;

  const NoDataFoundWeb({
    super.key,
    this.title = "No Data Found",
    this.subtitle = "We couldn't find any data here.",
    this.body,
    this.primaryLabel = "Retry",
    this.onPrimary,
    this.primaryEnabled = false,
    this.secondaryLabel = "Explore",
    this.onSecondary,
    this.secondaryEnabled = true,
    this.assetIcon,
    this.iconWidget,
    this.iconSize = 100,
    this.showTip = false,
    this.tipText = "",
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use a chart or document icon as default
    final iconAsset = assetIcon ?? assets.documentIcon;

    return Center(
      child: Container(
        margin: EdgeInsets.all(compact ? 8 : 24),
        padding: EdgeInsets.symmetric(
            horizontal: 16, vertical: compact ? 8 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with a soft glow background
            Container(
              width: compact ? 44 : 80,
              height: compact ? 44 : 80,
              padding: const EdgeInsets.all(0),
              child: iconWidget ??
                  SvgPicture.asset(
                    iconAsset,
                    width: 100,
                    height: 100,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                  ),
            ),

            SizedBox(height: compact ? 10 : 24),

            // Title
            Text(
              title,
              style: (compact
                  ? MyntWebTextStyles.title(
                      context,
                      fontWeight: MyntFonts.semiBold,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                    )
                  : MyntWebTextStyles.head(
                      context,
                      fontWeight: MyntFonts.semiBold,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary,
                      ),
                    )),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Subtitle
            if (body != null)
              body!
            else if (subtitle != null)
              SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.7,
                child: Text(
                  subtitle!,
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: FontWeight.w500,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 16),

            // Buttons (Full width style)
            if (primaryEnabled || secondaryEnabled)
              Column(
                children: [
                  if (primaryEnabled)
                    MyntPrimaryButton(
                      onPressed: onPrimary,
                      label: primaryLabel,
                    ),
                  if (primaryEnabled && secondaryEnabled)
                    const SizedBox(height: 12),
                  if (secondaryEnabled)
                    MyntSecondaryButton(
                      onPressed: onSecondary ??
                          () {
                            ref.read(indexListProvider).bottomMenu(1, context);
                          },
                      label: secondaryLabel,
                    ),
                ],
              ),

            // Tip Section (Distinct Card)
            if (showTip) ...[
              const SizedBox(height: 24),
              Container(
                width: 110,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary,
                  ).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.dividerDark,
                      light: MyntColors.divider,
                    ),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 16,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tipText,
                        style: MyntWebTextStyles.para(
                          context,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

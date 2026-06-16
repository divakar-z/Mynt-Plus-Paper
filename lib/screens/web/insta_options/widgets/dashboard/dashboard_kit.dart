import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dashboard_enums.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Semantic accents not in the shared palette (short_covering / long_covering).
const Color kDashTeal = Color(0xFF14B8A6);
const Color kDashOrange = Color(0xFFE3852B);

/// Profit / loss / neutral colour for a signed value.
Color dashChangeColor(BuildContext context, double? v) {
  if (v == null || v == 0) {
    return resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
  }
  return v > 0
      ? resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit)
      : resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
}

/// Buildup category accent (spec §1): LB green · SC teal · SB red · LC orange ·
/// NA grey.
Color dashCategoryColor(BuildContext context, BuildupCategory c) {
  switch (c) {
    case BuildupCategory.longBuildup:
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    case BuildupCategory.shortCovering:
      return kDashTeal;
    case BuildupCategory.shortBuildup:
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    case BuildupCategory.longCovering:
      return kDashOrange;
    case BuildupCategory.na:
      return resolveThemeColor(context,
          dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
  }
}

String dashCategoryShort(BuildupCategory c) {
  switch (c) {
    case BuildupCategory.longBuildup:
      return 'LB';
    case BuildupCategory.shortBuildup:
      return 'SB';
    case BuildupCategory.shortCovering:
      return 'SC';
    case BuildupCategory.longCovering:
      return 'LC';
    case BuildupCategory.na:
      return 'NA';
  }
}

/// Pill chip for a buildup category (full label or short code).
class DashCategoryChip extends StatelessWidget {
  final BuildupCategory category;
  final bool short;

  const DashCategoryChip({
    super.key,
    required this.category,
    this.short = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = dashCategoryColor(context, category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        short ? dashCategoryShort(category) : category.label,
        style: MyntWebTextStyles.caption(
          context,
          color: color,
          fontWeight: MyntFonts.semiBold,
        ),
      ),
    );
  }
}

/// Titled section container built on `shadcn.Card` — the app's web card look.
class DashSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets bodyPadding;

  const DashSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    return shadcn.Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: MyntWebTextStyles.title(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.semiBold,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.caption(
                        context,
                        darkColor: MyntColors.textTertiaryDark,
                        lightColor: MyntColors.textTertiary,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(padding: bodyPadding, child: child),
        ],
      ),
    );
  }
}

/// Advance / unchanged / decline proportion bar.
class DashAdBar extends StatelessWidget {
  final int advances;
  final int declines;
  final int unchanged;
  final double height;

  const DashAdBar({
    super.key,
    required this.advances,
    required this.declines,
    required this.unchanged,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final total = advances + declines + unchanged;
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final neutral = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    if (total == 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: neutral,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (advances > 0)
              Expanded(flex: advances, child: ColoredBox(color: profit)),
            if (unchanged > 0)
              Expanded(flex: unchanged, child: ColoredBox(color: neutral)),
            if (declines > 0)
              Expanded(flex: declines, child: ColoredBox(color: loss)),
          ],
        ),
      ),
    );
  }
}

/// Compact "label / value" stat used inside cards.
class DashStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const DashStat({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MyntWebTextStyles.caption(
            context,
            darkColor: MyntColors.textTertiaryDark,
            lightColor: MyntColors.textTertiary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: MyntWebTextStyles.bodySmall(
            context,
            color: valueColor,
            darkColor: valueColor ?? MyntColors.textPrimaryDark,
            lightColor: valueColor ?? MyntColors.textPrimary,
            fontWeight: MyntFonts.semiBold,
          ),
        ),
      ],
    );
  }
}

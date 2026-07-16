import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dashboard_enums.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/common_search_fields_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Semantic accents not in the shared palette (short_covering / long_covering).
const Color kDashShortCov = Color(0xFF3E8EDE); // soft blue (replaces the teal)
const Color kDashOrange = Color(0xFFE3852B);

/// Paints a dashed rounded-rect border (BoxDecoration only does solid) — the
/// roadmap-tag pill outline used by the Net-points chip and the LIVE badge.
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  static const double _dash = 5;
  static const double _gap = 3;

  const DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, dist + _dash), paint);
        dist += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

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
      return kDashShortCov;
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

/// Chip label — buildup categories drop the redundant "Buildup" word (just
/// Long / Short); covering categories keep their full name.
String dashCategoryChipLabel(BuildupCategory c) {
  switch (c) {
    case BuildupCategory.longBuildup:
      return 'Long';
    case BuildupCategory.shortBuildup:
      return 'Short';
    case BuildupCategory.shortCovering:
      return 'Short Covering';
    case BuildupCategory.longCovering:
      return 'Long Covering';
    case BuildupCategory.na:
      return c.label;
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
    // Matches the Orders "Status" chip (executed tab): rectangular tag, colour
    // tinted at 12% for the background, uppercase para (12px) medium label in
    // the category colour.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        (short ? dashCategoryShort(category) : dashCategoryChipLabel(category))
            .toUpperCase(),
        style: MyntWebTextStyles.para(
          context,
          color: color,
          fontWeight: MyntFonts.medium,
        ),
        overflow: TextOverflow.ellipsis,
        softWrap: false,
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
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: resolveThemeColor(context,
                      dark: MyntColors.cardBorderDark,
                      light: MyntColors.cardBorder),
                ),
              ),
            ),
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
                      fontWeight: MyntFonts.bold,
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
                 SizedBox(width: 10),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(padding: bodyPadding, child: child),
        ],
      ),
    );
  }
}

/// Compact "Search symbol" field used in the table-section toolbars.
class DashSearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const DashSearchBox({
    super.key,
    required this.controller,
    this.hint = 'Search symbol',
  });

  @override
  Widget build(BuildContext context) {
    // Matches the Holdings search field (shared MyntSearchTextField with a
    // smart clear button). `hint` maps to the placeholder.
    return MyntSearchTextField.withSmartClear(
      controller: controller,
      placeholder: hint,
      leadingIcon: assets.searchIcon,
      onClear: () => controller.clear(),
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
          style: MyntWebTextStyles.body(
            context,
            darkColor: MyntColors.textTertiaryDark,
            lightColor: MyntColors.textTertiary,
            fontWeight: MyntFonts.regular,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: MyntWebTextStyles.body(
            context,
            color: valueColor,
            darkColor: valueColor ?? MyntColors.textPrimaryDark,
            lightColor: valueColor ?? MyntColors.textPrimary,
            fontWeight: MyntFonts.medium,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

class BreadcrumbSegment {
  final String label;
  final VoidCallback? onTap;
  const BreadcrumbSegment(this.label, {this.onTap});
}

class ScannerBreadcrumb extends StatelessWidget {
  final List<BreadcrumbSegment> segments;

  const ScannerBreadcrumb({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final separator = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(shadcn.LucideIcons.chevronRight, size: 14, color: secondary),
    );

    final children = <Widget>[];
    for (int i = 0; i < segments.length; i++) {
      final s = segments[i];
      final isLast = i == segments.length - 1;
      final color = isLast ? primary : secondary;
      final style = MyntWebTextStyles.caption(
        context,
        fontWeight: isLast ? MyntFonts.medium : MyntFonts.regular,
        color: color,
      );
      Widget txt = Text(s.label, style: style);
      if (s.onTap != null && !isLast) {
        txt = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: s.onTap, child: txt),
        );
      }
      children.add(txt);
      if (!isLast) children.add(separator);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

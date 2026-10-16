import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart'
    show ScannerSubPage;

class _RailItem {
  final ScannerSubPage page;
  final String label;
  final IconData icon;
  const _RailItem(this.page, this.label, this.icon);
}

class ScannerLeftRail extends StatelessWidget {
  final ScannerSubPage active;
  final ValueChanged<ScannerSubPage> onSelect;
  final bool collapsed;

  const ScannerLeftRail({
    super.key,
    required this.active,
    required this.onSelect,
    this.collapsed = false,
  });

  static const _items = <_RailItem>[
    // _RailItem(ScannerSubPage.scanners, 'Scanners', shadcn.LucideIcons.radar),
    _RailItem(ScannerSubPage.scannersNew, 'Scanners New',
        shadcn.LucideIcons.layoutDashboard),
    // _RailItem(ScannerSubPage.fundamentals, 'Fundamentals',
    //     shadcn.LucideIcons.chartBar),
    _RailItem(ScannerSubPage.fundamentalsNew, 'Fundamentals New',
        shadcn.LucideIcons.sparkles),
    _RailItem(ScannerSubPage.customScans, 'Custom Scans',
        shadcn.LucideIcons.code),
  ];

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.sidebarBgDark, light: MyntColors.sidebarBg);
    final border = shadcn.Theme.of(context).colorScheme.border;
    final sectionColor = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final width = collapsed ? 64.0 : 270.0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!collapsed)
            Padding(
              // Aligns with the pill content start (outer 8px + inner 12px = 20px).
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 6),
              child: Text(
                'RESEARCH',
                style: MyntWebTextStyles.caption(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  color: sectionColor,
                ).copyWith(letterSpacing: 1.4, fontSize: 11),
              ),
            )
          else
            const SizedBox(height: 16),
          for (final item in _items)
            _NavItem(
              key: ValueKey(item.page),
              item: item,
              active: item.page == active,
              collapsed: collapsed,
              onTap: () => onSelect(item.page),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final _RailItem item;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.item,
    required this.active,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final primary = resolveThemeColor(context,
        dark: MyntColors.secondaryDark, light: MyntColors.primary);
    // Softer baseline so the active item has clear contrast against siblings.
    final inactiveColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final hoverColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.rowHoverDark, light: MyntColors.rowHover);

    final bg = widget.active
        ? primary.withValues(alpha: 0.12)
        : (_hover ? hoverBg : Colors.transparent);
    final color = widget.active
        ? primary
        : (_hover ? hoverColor : inactiveColor);

    // MouseRegion wraps everything (no padding dead zone). Container is
    // non-animated for instant hover response — AnimatedContainer flickered
    // when crossing item boundaries quickly.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Container(
            // Padding-driven height instead of a fixed size — vertical 12
            // padding gives ~44px rows, matching the app-drawer nav item feel
            // in the reference design.
            padding: EdgeInsets.symmetric(
                horizontal: widget.collapsed ? 0 : 14, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: widget.collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(widget.item.icon, size: 20, color: color),
                if (!widget.collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: widget.active
                            ? MyntFonts.semiBold
                            : MyntFonts.medium,
                        darkColor: color,
                        lightColor: color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

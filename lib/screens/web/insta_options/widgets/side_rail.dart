import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Identifies the active InstaOptions sub-screen within the right panel.
/// Order matches INSTAOPTIONS_FEATURE_README.md §0.1.
enum InstaSubScreen {
  markets,
  contributors,
  chain,
  oiStats,
  trending,
  pcr,
  strike,
  buildup,
  findStrategy,
}

class InstaSideRailItem {
  final InstaSubScreen sub;
  final String title;
  final IconData icon;
  const InstaSideRailItem({
    required this.sub,
    required this.title,
    required this.icon,
  });
}

const List<InstaSideRailItem> kInstaSideRailItems = [
  InstaSideRailItem(
    sub: InstaSubScreen.markets,
    title: 'Markets Dashboard',
    icon: Icons.dashboard,
  ),
  InstaSideRailItem(
    sub: InstaSubScreen.contributors,
    title: 'Index Contributors',
    icon: Icons.account_tree,
  ),
  InstaSideRailItem(
    sub: InstaSubScreen.chain,
    title: 'Option Chain',
    icon: Icons.view_list,
  ),
  InstaSideRailItem(
    sub: InstaSubScreen.oiStats,
    title: 'OI Statistics',
    icon: Icons.bar_chart,
  ),
  InstaSideRailItem(
    sub: InstaSubScreen.trending,
    title: 'Trending OI',
    icon: Icons.trending_up,
  ),
  InstaSideRailItem(
    sub: InstaSubScreen.pcr,
    title: 'PCR Ratio',
    icon: Icons.show_chart,
  ),
  // Hidden for now — not yet rebuilt on the date-based backend: Per-Strike
  // Chart, OI Buildup, Find Strategy. Their InstaSubScreen cases + screens stay
  // wired in the shell; they're just unreachable from the rail until rebuilt.
];

class InstaSideRail extends StatelessWidget {
  final InstaSubScreen active;
  final ValueChanged<InstaSubScreen> onSelect;

  const InstaSideRail({
    super.key,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border(right: BorderSide(color: tokens.border, width: 1)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: kInstaSideRailItems.length,
        itemBuilder: (context, index) {
          final item = kInstaSideRailItems[index];
          return _InstaSideRailEntry(
            item: item,
            isActive: item.sub == active,
            onTap: () => onSelect(item.sub),
            tokens: tokens,
          );
        },
      ),
    );
  }
}

class _InstaSideRailEntry extends StatefulWidget {
  final InstaSideRailItem item;
  final bool isActive;
  final VoidCallback onTap;
  final InstaOptionsTokens tokens;

  const _InstaSideRailEntry({
    required this.item,
    required this.isActive,
    required this.onTap,
    required this.tokens,
  });

  @override
  State<_InstaSideRailEntry> createState() => _InstaSideRailEntryState();
}

class _InstaSideRailEntryState extends State<_InstaSideRailEntry> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final isActive = widget.isActive;
    final bg = isActive
        ? tokens.bgTertiary
        : (_hovered ? tokens.bgTertiary.withValues(alpha: 0.5) : tokens.bgSecondary);
    final textColor = isActive ? tokens.textPrimary : tokens.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            border: isActive
                ? Border(left: BorderSide(color: tokens.accent, width: 3))
                : null,
          ),
          child: Row(
            children: [
              Icon(widget.item.icon, size: 20, color: textColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.item.title,
                  style: MyntWebTextStyles.body(context, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

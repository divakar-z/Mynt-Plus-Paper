import 'package:flutter/material.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/insta_tab_chip.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/side_rail.dart';

/// Top tab bar for the InstaOptions Analytics module.
///
/// Replaces the left side-rail with a horizontal tab strip built from the
/// shared [InstaTabChip]. Reuses the same [kInstaSideRailItems] list so the set
/// of reachable sub-screens stays in lock-step with the (now commented-out)
/// side-rail. Selection is pure UI — it calls the same `onSelect` the rail did.
class InstaTopTabs extends StatelessWidget {
  final InstaSubScreen active;
  final ValueChanged<InstaSubScreen> onSelect;

  const InstaTopTabs({
    super.key,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Transparent, left-aligned strip that matches the Holdings tab row (no
    // underline / no background bar). Full width comes from the shell Column's
    // stretch alignment; horizontal padding lines the first tab up with the
    // sub-screens' content edge.
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in kInstaSideRailItems) ...[
              InstaTabChip(
                label: item.title,
                selected: item.sub == active,
                onTap: () => onSelect(item.sub),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

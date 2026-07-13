import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/scan_explain.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// Recursive renderer for the predicate-evaluation tree returned by the
/// explain endpoint. Each leaf shows the server-pre-rendered `display`
/// string verbatim (e.g. `"RSI(14) = 27.32 < 30 ✓"`); each group shows
/// an `ALL of` / `ANY of` / `NONE of` header with its children indented
/// one level. Pass/fail icons are driven by [ExplainNode.passed].
class ScanPredicatePanel extends StatelessWidget {
  final ExplainNode node;
  const ScanPredicatePanel({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why it matched',
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: _ExplainNodeRow(node: node, depth: 0),
            ),
          ),
        ],
      ),
    );
  }
}

/// One node in the tree. Renders itself, then — when it's a group —
/// recursively renders its children indented by one level. The depth
/// accumulates 16 px of left padding per nesting level.
class _ExplainNodeRow extends StatelessWidget {
  final ExplainNode node;
  final int depth;
  const _ExplainNodeRow({required this.node, required this.depth});

  @override
  Widget build(BuildContext context) {
    final indent = depth * 16.0;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, node),
          if (node is ExplainGroup)
            for (final child in (node as ExplainGroup).children)
              _ExplainNodeRow(node: child, depth: depth + 1),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ExplainNode n) {
    final passColor = resolveThemeColor(context, dark: MyntColors.successDark, light: MyntColors.success);
    final failColor = resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.error);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    final icon = Icon(
      n.passed ? shadcn.LucideIcons.circleCheck : shadcn.LucideIcons.circleX,
      size: 14,
      color: n.passed ? passColor : failColor,
    );

    if (n is ExplainGroup) {
      // Group header: "ALL of" / "ANY of" / "NONE of" — bold + colored
      // by overall pass/fail so the user can scan a deep tree at a glance.
      final label = switch (n.kind) {
        ExplainGroupKind.all => 'ALL of',
        ExplainGroupKind.any => 'ANY of',
        ExplainGroupKind.none => 'NONE of',
      };
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(label,
                style: MyntWebTextStyles.caption(context,
                        fontWeight: MyntFonts.bold,
                        color: n.passed ? passColor : failColor)
                    .copyWith(letterSpacing: 0.4)),
          ],
        ),
      );
    }

    final leaf = n as ExplainLeaf;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: icon,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              // Server pre-renders the full leaf display (e.g.
              // `"RSI(14) = 27.32 < 30 ✓"`). The trailing ✓/✗ glyph
              // is server-supplied and redundant with our icon, but
              // keeping it preserves copy-paste fidelity with the
              // backend's text representation — leaving as-is for v1.
              leaf.display.isNotEmpty
                  ? leaf.display
                  : _fallbackLeafText(leaf),
              style: MyntWebTextStyles.body(context,
                  color: leaf.passed ? primary : secondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Composes a readable summary when the server omitted the pre-rendered
  /// `display` string. Shouldn't happen in practice; defensive fallback so
  /// the panel never shows a blank row.
  String _fallbackLeafText(ExplainLeaf leaf) {
    final left = leaf.left.display ?? leaf.left.value?.toStringAsFixed(2) ?? '—';
    final right = switch (leaf.right) {
      ExplainScalarOperand(:final display, :final value) =>
        display ?? value?.toStringAsFixed(2) ?? '—',
      ExplainRangeOperand(:final display) => display,
      ExplainNoOperand() => '',
    };
    return '${leaf.left.label} = $left ${leaf.op} $right';
  }
}

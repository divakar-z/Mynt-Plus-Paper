import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../provider/accessibility_provider.dart';

/// Reusable clickable text link. When the "Highlight Links" accessibility
/// toggle is on, the link renders with a light-yellow background and a
/// visible border; otherwise it renders as plain text with the caller's
/// (or default link) style.
class AppLink extends ConsumerWidget {
  const AppLink({
    super.key,
    required this.text,
    required this.onTap,
    this.style,
    this.semanticsLabel,
  });

  final String text;
  final VoidCallback onTap;
  final TextStyle? style;
  final String? semanticsLabel;

  static const Color _highlightBg = Color(0xFFFFF59D);
  static const Color _highlightBorder = Color(0xFFF9A825);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlight = ref.watch(
      accessibilityProvider.select((a) => a.highlightLinksEnabled),
    );

    final effectiveStyle = (style ??
            DefaultTextStyle.of(context).style.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ))
        .copyWith(color: highlight ? Colors.black87 : null);

    final child = Text(
      text,
      style: effectiveStyle,
      semanticsLabel: semanticsLabel,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: highlight
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _highlightBg,
                  border: Border.all(color: _highlightBorder, width: 1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: child,
              )
            : child,
      ),
    );
  }
}

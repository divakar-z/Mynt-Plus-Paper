import 'package:flutter/material.dart';

import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';

/// A placeholder block, pulsing in time with every other block under the same
/// [SupportSkeletonGroup].
///
/// Skeletons exist so a screen's first paint has the *shape* of the answer
/// before it has the answer. A centred spinner throws away everything we
/// already know — that there is a table with six columns and rows 42px tall —
/// and then reflows the whole thing when the data lands. The block form keeps
/// the layout still and makes waiting read as obviously temporary rather than
/// as an empty screen.
class SupportSkeleton extends StatelessWidget {
  const SupportSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  /// Pass `double.infinity` for a block that should fill its column. Left null
  /// under a loosely-constrained parent it collapses to zero width, since a
  /// childless box has no intrinsic size to fall back on.
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final pulse = SupportSkeletonGroup.maybeOf(context);
    // A skeleton with no group above it still animates: it plants its own.
    if (pulse == null) {
      return SupportSkeletonGroup(
        child: SupportSkeleton(width: width, height: height, radius: radius),
      );
    }

    final base = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.listItemBg);
    final peak = resolveThemeColor(context,
        dark: MyntColors.borderMutedDark, light: MyntColors.borderMuted);

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        // Lerp between two concrete colours rather than fading opacity: the
        // resting grey is already near the card colour, so an opacity pulse
        // would make it vanish instead of breathe.
        return SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.lerp(base, peak, pulse.value),
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        );
      },
    );
  }
}

/// Drives one pulse for every [SupportSkeleton] beneath it.
///
/// Shared rather than per-block so a table of placeholders breathes as one
/// surface; twenty independent controllers would shimmer against each other
/// and read as noise.
class SupportSkeletonGroup extends StatefulWidget {
  const SupportSkeletonGroup({super.key, required this.child});

  final Widget child;

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonPulse>()?.pulse;

  @override
  State<SupportSkeletonGroup> createState() => _SupportSkeletonGroupState();
}

class _SupportSkeletonGroupState extends State<SupportSkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _pulse =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SkeletonPulse(pulse: _pulse, child: widget.child);
}

class _SkeletonPulse extends InheritedWidget {
  const _SkeletonPulse({required this.pulse, required super.child});

  final Animation<double> pulse;

  @override
  bool updateShouldNotify(_SkeletonPulse old) => old.pulse != pulse;
}

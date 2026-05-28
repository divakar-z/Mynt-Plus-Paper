import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// OI cell with a horizontal bar background scaled by `value / maxValue`.
///
/// CE bars fill from the LEFT; PE bars fill from the RIGHT.
class OIBarCell extends StatelessWidget {
  final int value;
  final int maxValue;
  final bool isCallSide;

  const OIBarCell({
    super.key,
    required this.value,
    required this.maxValue,
    required this.isCallSide,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    final barColor = isCallSide ? tokens.barCe : tokens.barPe;
    final align = isCallSide ? Alignment.centerLeft : Alignment.centerRight;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Align(
          alignment: align,
          child: FractionallySizedBox(
            widthFactor: ratio,
            heightFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              color: barColor,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Align(
            alignment: align,
            child: Text(
              InstaOptionsFormat.oi(value),
              style: MyntWebTextStyles.price(
                context,
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

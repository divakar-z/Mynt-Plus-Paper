import 'package:flutter/material.dart';

import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';

/// Shown in place of any screen that only makes sense with real money
/// (IPO, bonds, mutual funds, pledge, corporate actions …) on this
/// paper-trading-only platform.
class PaperUnavailableScreen extends StatelessWidget {
  final String feature;

  const PaperUnavailableScreen({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.science_outlined,
              size: 40,
              color: resolveThemeColor(context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              '$feature is not available in paper trading',
              textAlign: TextAlign.center,
              style: MyntWebTextStyles.title(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This is a practice platform. Only simulated stock, F&O and '
              'commodity trading is supported — no real orders or money are '
              'involved.',
              textAlign: TextAlign.center,
              style: MyntWebTextStyles.bodySmall(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

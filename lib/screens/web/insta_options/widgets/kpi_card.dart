import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// KpiCard — reusable headline metric tile.
///
/// Used by OI Statistics, PCR Ratio, and (later) Markets / Per-Strike screens.
/// See README §9.4.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final KpiDeltaTone deltaTone;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaTone = KpiDeltaTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border.all(color: tokens.border, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: MyntWebTextStyles.caption(
              context,
              color: tokens.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: MyntWebTextStyles.title(
              context,
              color: tokens.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Text(
              delta!,
              style: MyntWebTextStyles.caption(
                context,
                color: _deltaColor(tokens),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _deltaColor(InstaOptionsTokens tokens) {
    switch (deltaTone) {
      case KpiDeltaTone.profit:
        return tokens.profit;
      case KpiDeltaTone.loss:
        return tokens.loss;
      case KpiDeltaTone.neutral:
        return tokens.textSecondary;
    }
  }
}

enum KpiDeltaTone { profit, loss, neutral }

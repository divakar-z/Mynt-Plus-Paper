import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/basket_leg.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_basket_provider.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';

/// "B" and "S" circular badges (README §10.7) that enqueue a `BasketLeg` on
/// tap. Order placement is intentionally deferred (§3) — the basket only
/// accumulates legs for visual feedback via [BasketChip].
class BSBadges extends ConsumerWidget {
  final String expiry;
  final double strike;
  final String optionType;
  final double entryPrice;
  final String tradingSymbol;
  final int lot;

  const BSBadges({
    super.key,
    required this.expiry,
    required this.strike,
    required this.optionType,
    required this.entryPrice,
    required this.tradingSymbol,
    this.lot = 1,
  });

  void _add(WidgetRef ref, BuildContext context, String side) {
    ref.read(instaOptionsBasketProvider).add(
          BasketLeg(
            side: side,
            lot: lot,
            expiry: expiry,
            strike: strike,
            optionType: optionType,
            entryPrice: entryPrice,
            tradingSymbol: tradingSymbol,
          ),
        );
    final label = side == 'B' ? 'BUY' : 'SELL';
    ResponsiveSnackBar.showSuccess(
      context,
      'Added $label $tradingSymbol to strategy',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = InstaOptionsTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.bgTertiary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Badge(
            label: 'B',
            color: tokens.profit,
            onTap: () => _add(ref, context, 'B'),
          ),
          const SizedBox(width: 6),
          _Badge(
            label: 'S',
            color: tokens.loss,
            onTap: () => _add(ref, context, 'S'),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Badge({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

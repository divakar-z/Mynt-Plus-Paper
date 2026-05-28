import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/basket_leg.dart';
import 'package:mynt_plus/models/insta_options/chain_row.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_basket_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Bottom sheet shown when the user wants to enqueue an option leg.
///
/// **Order placement is deferred** (README §3). BUY/SELL only mutate the
/// in-memory basket and show a "coming soon" toast. There is no navigation.
class ChainLegBottomSheet extends ConsumerWidget {
  final ChainRow row;

  const ChainLegBottomSheet({super.key, required this.row});

  static Future<void> show(BuildContext context, ChainRow row) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ChainLegBottomSheet(row: row),
    );
  }

  void _enqueue(BuildContext context, WidgetRef ref, String side) {
    final basket = ref.read(instaOptionsBasketProvider);
    basket.add(
      BasketLeg(
        side: side,
        lot: 1,
        expiry: row.expiry,
        strike: row.strike,
        optionType: row.optionType,
        entryPrice: row.ltp,
        tradingSymbol: row.tradingSymbol,
      ),
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${side == 'B' ? 'BUY' : 'SELL'} ${row.tradingSymbol} '
          '— ${basket.count} legs queued (order placement coming soon).',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = InstaOptionsTokens.of(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.bgSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border.all(color: tokens.border, width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              row.tradingSymbol,
              style: MyntWebTextStyles.head(context, color: tokens.textPrimary),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _MetaChip(
                  label: 'LTP',
                  value: InstaOptionsFormat.price(row.ltp),
                  tokens: tokens,
                ),
                _MetaChip(
                  label: 'IV',
                  value: InstaOptionsFormat.iv(row.iv),
                  tokens: tokens,
                ),
                _MetaChip(
                  label: 'Δ',
                  value: InstaOptionsFormat.greek(row.delta),
                  tokens: tokens,
                ),
                _MetaChip(
                  label: 'OI',
                  value: InstaOptionsFormat.oi(row.oi),
                  tokens: tokens,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.profit,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _enqueue(context, ref, 'B'),
                    child: const Text('Add 1 lot BUY'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.loss,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _enqueue(context, ref, 'S'),
                    child: const Text('Add 1 lot SELL'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Order placement is currently disabled. Legs are queued in '
              'memory only.',
              style: MyntWebTextStyles.caption(
                context,
                color: tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final InstaOptionsTokens tokens;

  const _MetaChip({
    required this.label,
    required this.value,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: MyntWebTextStyles.caption(
            context,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: MyntWebTextStyles.bodySmall(
            context,
            color: tokens.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

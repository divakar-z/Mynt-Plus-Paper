import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_basket_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Floating bottom-right chip that shows the number of queued basket legs.
///
/// **Order placement is deferred** (INSTAOPTIONS_FEATURE_README.md §3). Tap is
/// a no-op except for a "coming soon" SnackBar. Renders disabled (reduced
/// accent opacity) to signal the disabled state.
class BasketChip extends ConsumerWidget {
  const BasketChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final basket = ref.watch(instaOptionsBasketProvider);
    if (basket.isEmpty) return const SizedBox.shrink();
    final tokens = InstaOptionsTokens.of(context);
    return Positioned(
      right: 24,
      bottom: 24,
      child: Material(
        elevation: 6,
        color: tokens.accent.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order placement coming in a future release.'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_basket, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '${basket.count} legs queued — coming soon',
                  style: MyntWebTextStyles.body(
                    context,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

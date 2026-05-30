import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/place_order_prefill.dart';

class PlusMenuPopup extends StatelessWidget {
  final Offset anchor;
  final String symbol;
  final int qty;
  final double price;
  // Live last-traded price for the symbol. Drives the buy-side / sell-side
  // menu split: clicks BELOW ltp expose buy-limit + sell-stop variants
  // (the classic "buy on dip / cut a long" zone); clicks ABOVE ltp expose
  // sell-limit + buy-stop variants ("sell on rally / breakout buy" zone).
  // Pass null to fall back to the legacy below-ltp menu (back-compat).
  final double? ltp;
  final ValueChanged<OrderPrefillKind> onPick;
  final VoidCallback onSetAlert;
  final VoidCallback onDismiss;

  const PlusMenuPopup({
    super.key,
    required this.anchor,
    required this.symbol,
    required this.qty,
    required this.price,
    required this.onPick,
    required this.onSetAlert,
    required this.onDismiss,
    this.ltp,
  });

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final long = resolveThemeColor(context,
        dark: const Color(0xFF3B82F6), light: const Color(0xFF2563EB));
    final short = resolveThemeColor(context,
        dark: const Color(0xFFEF4444), light: const Color(0xFFDC2626));

    final screen = MediaQuery.of(context).size;
    const w = 340.0;
    final left = anchor.dx.clamp(8.0, screen.width - w - 8.0);
    final top = anchor.dy.clamp(8.0, screen.height - 220.0);

    final priceStr = price.toStringAsFixed(2);

    Widget item(String label, IconData icon, Color color, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label, style: MyntWebTextStyles.body(context))),
          ]),
        ),
      );
    }

    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
      ),
      Positioned(
        left: left,
        top: top,
        width: w,
        child: PointerInterceptor(
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Branch menu items by click-position vs. LTP — matches
                  // TradingView / Sahi convention. Above LTP: sell-limit
                  // (sell on rally), buy-stop (breakout entry). Below LTP:
                  // buy-limit (buy on dip), sell-stop (cut a long).
                  if (ltp != null && price > ltp!) ...[
                    item('Sell $qty $symbol @ $priceStr limit',
                        Icons.arrow_downward, short,
                        () { onPick(OrderPrefillKind.sellLimit); }),
                    item('Buy $qty $symbol @ $priceStr stop',
                        Icons.arrow_upward, long,
                        () { onPick(OrderPrefillKind.buyStopMkt); }),
                    item('Buy $qty $symbol @ $priceStr stop, '
                        '${(price + 0.05).toStringAsFixed(2)} limit',
                        Icons.arrow_upward, long,
                        () { onPick(OrderPrefillKind.buyStopLmt); }),
                  ] else ...[
                    item('Buy $qty $symbol @ $priceStr limit',
                        Icons.arrow_upward, long,
                        () { onPick(OrderPrefillKind.buyLimit); }),
                    item('Sell $qty $symbol @ $priceStr stop',
                        Icons.arrow_downward, short,
                        () { onPick(OrderPrefillKind.sellStopMkt); }),
                    item('Sell $qty $symbol @ $priceStr stop, '
                        '${(price - 0.05).toStringAsFixed(2)} limit',
                        Icons.arrow_downward, short,
                        () { onPick(OrderPrefillKind.sellStopLmt); }),
                  ],
                  item('🔔  Set Alert at $priceStr',
                      Icons.notifications_active_outlined,
                      resolveThemeColor(context,
                          dark: const Color(0xFFF59E0B),
                          light: const Color(0xFFD97706)),
                      onSetAlert),
                  const Divider(height: 1),
                  item('Create new order…',
                      Icons.add_circle_outline,
                      resolveThemeColor(context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary),
                      () { onPick(OrderPrefillKind.blank); }),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:mynt_plus/models/marketwatch_model/alert_model/alert_pending_model.dart';
import 'package:mynt_plus/models/order_book_model/modify_order_model.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';
import 'package:mynt_plus/provider/auth_provider.dart';
import 'package:mynt_plus/provider/market_watch_provider.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/portfolio_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// Shows [child] as a modal dialog over an iframe-friendly backdrop.
///
/// The default Flutter modal barrier sits BELOW the HtmlElementView iframe
/// in the DOM z-order, so a `showDialog` over the chart looks broken: the
/// chart shows through and is still clickable. We disable the default
/// barrier (`barrierColor: transparent`) and render our own backdrop +
/// dialog inside [PointerInterceptor]s, which emit HTML elements stacked
/// above the iframe — covering it visually AND swallowing its pointer
/// events.
Future<T?> _showIframeSafeDialog<T>({
  required BuildContext context,
  required Widget child,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (ctx) => Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(ctx).pop(),
            child: Container(color: Colors.black54),
          ),
        ),
      ),
      Center(child: PointerInterceptor(child: child)),
    ]),
  );
}

/// House-style confirm dialog used by all chart-overlay actions. Replaces
/// the raw Material `AlertDialog` (which rendered with default Material
/// chrome that looked foreign next to the rest of the web app). Mirrors
/// the card convention used elsewhere on web (e.g. ipo cancel dialog):
/// a rounded card with a titled header + divider, a body line, and a
/// trailing Cancel / Confirm button row using app design tokens.
///
/// Returns true only when the user taps the confirm button.
Future<bool> _showConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  Color? confirmColor, // null → brand primary
}) async {
  final result = await _showIframeSafeDialog<bool>(
    context: context,
    child: _ConfirmCard(
      title: title,
      message: message,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      confirmColor: confirmColor,
    ),
  );
  return result ?? false;
}

class _ConfirmCard extends StatelessWidget {
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final Color? confirmColor;
  const _ConfirmCard({
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.dialogDark, light: MyntColors.dialog);
    final divider = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final titleColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final bodyColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final confirmBg = confirmColor ?? MyntColors.primary;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header — title + close, with a hairline divider beneath.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(title,
                        style: MyntWebTextStyles.title(context,
                            color: titleColor)),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(false),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 18, color: bodyColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message,
                      style: MyntWebTextStyles.body(context, color: bodyColor)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(cancelLabel,
                            style: MyntWebTextStyles.buttonMd(context,
                                color: bodyColor)),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: confirmBg,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(confirmLabel,
                              style: MyntWebTextStyles.buttonMd(context,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCloseOrderDialog({
  required BuildContext context,
  required WidgetRef ref,
  required OrderBookModel order,
}) async {
  final tsym = order.tsym ?? '';
  final qty = order.qty ?? '';
  final type = order.prctyp ?? '';
  final ok = await _showConfirm(
    context: context,
    title: 'Cancel order',
    message: 'Cancel $type order for $qty $tsym?',
    cancelLabel: 'Keep',
    confirmLabel: 'Cancel order',
    confirmColor: MyntColors.tertiary,
  );
  if (!ok || !context.mounted) return;
  await ref
      .read(orderProvider)
      .fetchOrderCancel(order.norenordno.toString(), context, false);
}

Future<void> showSquareOffDialog({
  required BuildContext context,
  required WidgetRef ref,
  required PositionBookModel position,
}) async {
  final tsym = position.tsym ?? '';
  final qty = position.netqty ?? '';
  final qtyInt = int.tryParse(qty) ?? 0;
  final side = qtyInt < 0 ? 'BUY' : 'SELL';
  final ok = await _showConfirm(
    context: context,
    title: 'Square off position',
    message: 'Place a MARKET $side for ${qty.replaceAll('-', '')} $tsym '
        'to close this position?',
    cancelLabel: 'Keep',
    confirmLabel: 'Square off',
    confirmColor: MyntColors.tertiary,
  );
  if (!ok || !context.mounted) return;
  final ls = int.tryParse(position.ls ?? '1') ?? 1;
  final frz = int.tryParse(position.frzqty ?? '0') ?? 0;
  final frzqty = ls > 0 ? (frz ~/ ls) * ls : frz;
  final deviceInfo = ref.read(authProvider).deviceInfo;
  final channel = defaultTargetPlatform == TargetPlatform.android
      ? '${deviceInfo["brand"]}'
      : '${deviceInfo["model"]}';
  final input = PlaceOrderInput(
    exch: position.exch ?? '',
    tsym: position.tsym ?? '',
    qty: (position.netqty ?? '0').replaceAll('-', ''),
    prc: '0',
    prctype: 'MKT',
    trantype: qtyInt < 0 ? 'B' : 'S',
    prd: position.prd ?? '',
    ret: 'DAY',
    trgprc: '',
    blprc: '',
    bpprc: '',
    dscqty: '',
    amo: '',
    trailprc: '',
    mktProt: '',
    channel: channel,
    frzqty: frzqty,
  );
  // multipleexit=true to suppress fetchExitPosition's internal
  // Navigator.pop — from the chart context it would close the
  // chart screen itself (blank-screen bug).
  await ref.read(portfolioProvider).fetchExitPosition(context, input, true, true);
}

Future<void> showModifyOrderDialog({
  required BuildContext context,
  required WidgetRef ref,
  required OrderBookModel order,
  required double newPrice,
  double? newTriggerPrice, // SL-LMT trigger drag also updates limit; pass both
}) async {
  final tsym = order.tsym ?? '';
  final qty = order.qty ?? '';
  final side = order.trantype == 'B' ? 'BUY' : 'SELL';
  final type = order.prctyp ?? '';
  final oldPrice = type == 'SL-MKT'
      ? order.trgprc ?? '0'
      : (type == 'SL-LMT' && newTriggerPrice != null
          ? order.trgprc ?? '0'
          : order.prc ?? '0');
  final bodyText = newTriggerPrice != null
      ? 'Move $side $type $qty $tsym '
          'from $oldPrice to ${newTriggerPrice.toStringAsFixed(2)}? '
          'Limit price will move to ${newPrice.toStringAsFixed(2)} '
          'to preserve offset.'
      : 'Move $side $type $qty $tsym '
          'from $oldPrice to ${newPrice.toStringAsFixed(2)}?';
  final ok = await _showConfirm(
    context: context,
    title: 'Modify order',
    message: bodyText,
    cancelLabel: 'Keep',
    confirmLabel: 'Modify',
  );
  if (!ok || !context.mounted) return;
  final input = ModifyOrderInput(
    exch: order.exch ?? '',
    token: order.token ?? '',
    tsym: order.tsym ?? '',
    orderNum: order.norenordno ?? '',
    qty: order.qty ?? '0',
    dscqty: order.dscqty ?? '0',
    mktProt: order.mktProtection ?? '',
    prctyp: order.prctyp ?? '',
    prd: order.prd ?? '',
    trantype: order.trantype ?? '',
    ret: order.ret ?? 'DAY',
    blprc: order.blprc ?? '',
    bpprc: order.bpprc ?? '',
    prc: newPrice.toStringAsFixed(2),
    trgprc: (newTriggerPrice ?? newPrice).toStringAsFixed(2),
  );
  await ref.read(orderProvider).fetchModifyOrder(input, context);
}

Future<void> showAlertCancelDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AlertPendingModel alert,
}) async {
  final price = alert.pp ?? '';
  final tsym = alert.tsym ?? '';
  final ok = await _showConfirm(
    context: context,
    title: 'Cancel alert',
    message: 'Cancel alert at $price for $tsym?',
    cancelLabel: 'Keep',
    confirmLabel: 'Cancel alert',
    confirmColor: MyntColors.tertiary,
  );
  if (!ok || !context.mounted) return;
  await ref
      .read(marketWatchProvider)
      .fetchCancelAlert(alert.alId ?? '', context);
}

/// One-time warning shown when the user first enables Instant orders.
/// Returns true if the user clicks Enable, false otherwise.
Future<bool> showInstantWarningDialog({
  required BuildContext context,
}) {
  return _showConfirm(
    context: context,
    title: 'Enable instant orders?',
    message:
        'Mutations (cancel, square-off, drag-modify, quick-place) will '
        'fire immediately on click. There will be no second chance to '
        'back out.',
    confirmLabel: 'Enable',
    confirmColor: const Color(0xFFF59E0B), // amber — caution, not destructive
  );
}

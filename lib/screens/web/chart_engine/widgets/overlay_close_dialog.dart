import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:mynt_plus/models/marketwatch_model/alert_model/alert_pending_model.dart';
import 'package:mynt_plus/models/order_book_model/gtt_order_book.dart';
import 'package:mynt_plus/models/order_book_model/modify_order_model.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/order_book_model/place_gtt_order.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';
import 'package:mynt_plus/provider/auth_provider.dart';
import 'package:mynt_plus/provider/market_watch_provider.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/portfolio_provider.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_order_validation.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/common_text_fields_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

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
  // loop=true shows the "Order Cancelled" toast + refreshes the book (web path
  // does NOT pop any route, so it's safe from the chart). With false it was
  // cancelling silently — unlike the order book.
  await ref
      .read(orderProvider)
      .fetchOrderCancel(order.norenordno.toString(), context, true);
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
  final ok = await _showIframeSafeDialog<bool>(
    context: context,
    child: _SquareOffCard(
      message: 'Place a MARKET $side for ${qty.replaceAll('-', '')} $tsym '
          'to close this position?',
    ),
  );
  if (ok != true || !context.mounted) return;
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

class _SquareOffCard extends StatelessWidget {
  final String message;
  const _SquareOffCard({required this.message});

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
    final btnColor = resolveThemeColor(context,
        dark: MyntColors.secondary, light: MyntColors.primary);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Square off',
                    style: MyntWebTextStyles.title(context, color: titleColor),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(false),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 20, color: bodyColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: MyntWebTextStyles.body(context,
                        fontWeight: FontWeight.w500, color: titleColor),
                  ),
                  const SizedBox(height: 24),
                  MyntButton(
                    type: MyntButtonType.primary,
                    size: MyntButtonSize.large,
                    label: 'Square off',
                    isFullWidth: true,
                    backgroundColor: btnColor,
                    onPressed: () => Navigator.of(context).pop(true),
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

Future<bool> showAlertCancelDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AlertPendingModel alert,
}) async {
  // Alert target price lives in `d` (same field the overlay renders). `pp`
  // is an unrelated value (showed up as "2" in the dialog).
  final price = alert.d ?? '';
  final tsym = alert.tsym ?? '';
  final ok = await _showIframeSafeDialog<bool>(
    context: context,
    child: _CancelAlertCard(
      message: 'Cancel alert at $price for $tsym?',
    ),
  );
  if (ok != true || !context.mounted) return false;
  return await ref
      .read(marketWatchProvider)
      .fetchCancelAlert(alert.alId ?? '', context);
}

class _CancelAlertCard extends StatelessWidget {
  final String message;
  const _CancelAlertCard({required this.message});

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
    final btnColor = resolveThemeColor(context,
        dark: MyntColors.errorDark, light: MyntColors.tertiary);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cancel Alert',
                    style: MyntWebTextStyles.title(context, color: titleColor),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(false),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 20, color: bodyColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style:
                        MyntWebTextStyles.body(context, color: titleColor),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        backgroundColor: btnColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: MyntWebTextStyles.buttonMd(context,
                            color: Colors.white),
                      ),
                    ),
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

/// Cancel a placed OCO bracket (both TP and SL legs) from the chart. The
/// broker treats the OCO as a single GTT keyed by [GttOrderBookModel.alId],
/// so cancelling either leg removes the whole bracket. Mirrors the wording
/// of the order-cancel dialog.
Future<void> showOcoCancelDialog({
  required BuildContext context,
  required WidgetRef ref,
  required GttOrderBookModel gtt,
}) async {
  final tsym = gtt.symbol?.isNotEmpty == true ? gtt.symbol! : (gtt.tsym ?? '');
  final ov = gtt.oivariable;
  final tp = (ov != null && ov.isNotEmpty) ? ov[0].d ?? '' : '';
  final sl = (ov != null && ov.length > 1) ? ov[1].d ?? '' : '';
  final ok = await _showIframeSafeDialog<bool>(
    context: context,
    child: _CancelOcoCard(
      message: 'Cancel the bracket for $tsym?\n'
          'Target $tp and Stop $sl will both be removed.',
    ),
  );
  if (ok != true || !context.mounted) return;
  await ref.read(orderProvider).cancelGttOrder(gtt.alId ?? '', context);
}

class _CancelOcoCard extends StatelessWidget {
  final String message;
  const _CancelOcoCard({required this.message});

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
    final btnColor = resolveThemeColor(context,
        dark: MyntColors.errorDark, light: MyntColors.tertiary);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cancel TP/SL',
                    style: MyntWebTextStyles.title(context, color: titleColor),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(false),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 20, color: bodyColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style:
                        MyntWebTextStyles.body(context, color: titleColor),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        backgroundColor: btnColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Cancel TP/SL',
                        style: MyntWebTextStyles.buttonMd(context,
                            color: Colors.white),
                      ),
                    ),
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

/// Modify ONE leg of a placed OCO bracket from a chart drag. [isTpLeg] picks
/// the target leg (oivariable[0] / place_order_params) vs the stop leg
/// (oivariable[1] / place_order_params_leg2). The untouched leg is replayed
/// verbatim so [orderProvider.modifyOCOOrder] (which replaces BOTH legs)
/// leaves it where it was. Keyed by [GttOrderBookModel.alId].
Future<void> showOcoLegModifyDialog({
  required BuildContext context,
  required WidgetRef ref,
  required GttOrderBookModel gtt,
  required bool isTpLeg,
  required double newPrice,
}) async {
  final ov = gtt.oivariable;
  if (ov == null || ov.length < 2) return;
  final leg1 = gtt.placeOrderParams;
  final leg2 = gtt.placeOrderParamsLeg2;
  // Both legs share the bracket's transaction side (exit side of the
  // position). Fall back across the available carriers.
  final trantype =
      leg1?.trantype ?? leg2?.trantype ?? gtt.trantype ?? 'S';
  final prd1 = leg1?.prd ?? gtt.prd ?? '';
  final prd2 = leg2?.prd ?? gtt.prd ?? '';
  final qty1 = (leg1?.qty ?? gtt.qty ?? 0).toString();
  final qty2 = (leg2?.qty ?? gtt.qty ?? 0).toString();
  final prctyp1 = leg1?.prctyp ?? 'LMT';
  final prctyp2 = leg2?.prctyp ?? 'LMT';

  final newStr = newPrice.toStringAsFixed(2);
  // Target leg = oivariable[0]; stop leg = oivariable[1]. Update only the
  // dragged leg's condition (`d`) and limit price (`prc`); keep the other.
  final d1 = isTpLeg ? newStr : (ov[0].d ?? '');
  final prc1 = isTpLeg ? newStr : (leg1?.prc ?? ov[0].d ?? '');
  final d2 = isTpLeg ? (ov[1].d ?? '') : newStr;
  final prc2 = isTpLeg ? (leg2?.prc ?? ov[1].d ?? '') : newStr;

  final tsym = gtt.symbol?.isNotEmpty == true ? gtt.symbol! : (gtt.tsym ?? '');
  final legName = isTpLeg ? 'Target' : 'Stop';
  final oldStr = isTpLeg ? (ov[0].d ?? '') : (ov[1].d ?? '');
  final ok = await _showConfirm(
    context: context,
    title: 'Modify $legName',
    message: 'Move $legName for $tsym from $oldStr to $newStr?',
    cancelLabel: 'Keep',
    confirmLabel: 'Modify',
  );
  if (!ok || !context.mounted) return;

  final input = PlaceOcoOrderInput(
    exch: gtt.exch ?? '',
    tsym: gtt.tsym ?? '',
    validity: gtt.validity ?? 'GTT',
    trantype: trantype,
    ret: 'DAY',
    remarks: '',
    qty1: qty1,
    prctyp1: prctyp1,
    prc1: prc1,
    trgprc1: '',
    prd1: prd1,
    d1: d1,
    qty2: qty2,
    prctyp2: prctyp2,
    prc2: prc2,
    trgprc2: '',
    prd2: prd2,
    d2: d2,
    alid: gtt.alId ?? '',
  );
  await ref.read(orderProvider).modifyOCOOrder(input, context);
}

/// Text-entry dialog for annotation drawing tools (text / note / callout /
/// comment / price label / sign post). Returns the entered string, or null if
/// the user cancelled (caller removes the just-placed drawing on null).
Future<String?> showDrawingTextDialog({
  required BuildContext context,
  String initial = '',
  String title = 'Add text',
}) {
  return _showIframeSafeDialog<String>(
    context: context,
    child: _DrawingTextCard(initial: initial, title: title),
  );
}

class _DrawingTextCard extends StatefulWidget {
  final String initial;
  final String title;
  const _DrawingTextCard({required this.initial, required this.title});
  @override
  State<_DrawingTextCard> createState() => _DrawingTextCardState();
}

class _DrawingTextCardState extends State<_DrawingTextCard> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Text cannot be empty');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return shadcn.Card(
      borderRadius: BorderRadius.circular(8),
      padding: EdgeInsets.zero,
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: shadcn.Theme.of(context).colorScheme.border,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: MyntWebTextStyles.title(
                      context,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary,
                      ),
                    ),
                  ),
                  MyntCloseButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyntFormTextField(
                      controller: _ctrl,
                      autofocus: true,
                      placeholder: 'Enter text',
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        style: MyntWebTextStyles.caption(
                          context,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.errorDark,
                            light: MyntColors.tertiary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    MyntPrimaryButton(
                      size: MyntButtonSize.large,
                      label: 'Add',
                      isFullWidth: true,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-time warning shown when the user first enables Instant orders.
/// Returns true if the user clicks Enable, false otherwise.
Future<bool> showInstantWarningDialog({
  required BuildContext context,
}) async {
  final result = await _showIframeSafeDialog<bool>(
    context: context,
    child: const _InstantWarningCard(),
  );
  return result ?? false;
}

class _InstantWarningCard extends StatelessWidget {
  const _InstantWarningCard();

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

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Enable instant orders?',
                    style: MyntWebTextStyles.title(context, color: titleColor),
                  ),
                  MyntCloseButton(
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mutations (cancel, square-off, drag-modify, quick-place) '
                    'will fire immediately on click. There will be no second '
                    'chance to back out.',
                    style:
                        MyntWebTextStyles.body(context, color: bodyColor),
                  ),
                  const SizedBox(height: 24),
                  MyntPrimaryButton(
                    size: MyntButtonSize.large,
                    label: 'Enable',
                    isFullWidth: true,
                    onPressed: () => Navigator.of(context).pop(true),
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

/// Dialog for setting a Target + Stop-loss on an open position, placed as an
/// OCO (one-cancels-other) order. Returns the entered (tp, sl) prices, or
/// null if cancelled. Pre-fills both from the position avg and validates
/// that each sits on the correct side (target favourable, stop protective)
/// so the user can't accidentally invert them.
Future<({double tp, double sl})?> showOcoTpSlDialog({
  required BuildContext context,
  required String tsym,
  required bool isLong,
  required double ltp,
  required double tpInit,
  required double slInit,
  required double ti,
  String? uc,
  String? lc,
}) {
  return _showIframeSafeDialog<({double tp, double sl})>(
    context: context,
    child: _OcoTpSlCard(
      tsym: tsym,
      isLong: isLong,
      ltp: ltp,
      tpInit: tpInit,
      slInit: slInit,
      ti: ti,
      uc: uc,
      lc: lc,
    ),
  );
}

class _OcoTpSlCard extends StatefulWidget {
  final String tsym;
  final bool isLong;
  final double ltp;
  final double tpInit;
  final double slInit;
  final double ti;
  final String? uc;
  final String? lc;
  const _OcoTpSlCard({
    required this.tsym,
    required this.isLong,
    required this.ltp,
    required this.tpInit,
    required this.slInit,
    required this.ti,
    this.uc,
    this.lc,
  });

  @override
  State<_OcoTpSlCard> createState() => _OcoTpSlCardState();
}

class _OcoTpSlCardState extends State<_OcoTpSlCard> {
  late final TextEditingController _tp;
  late final TextEditingController _sl;
  String? _error;

  int get _decimals => widget.ti >= 1
      ? 0
      : widget.ti >= 0.1
          ? 1
          : 2;

  @override
  void initState() {
    super.initState();
    _tp = TextEditingController(text: widget.tpInit.toStringAsFixed(_decimals));
    _sl = TextEditingController(text: widget.slInit.toStringAsFixed(_decimals));
  }

  @override
  void dispose() {
    _tp.dispose();
    _sl.dispose();
    super.dispose();
  }

  void _submit() {
    final tp = double.tryParse(_tp.text.trim());
    final sl = double.tryParse(_sl.text.trim());
    if (tp == null || sl == null || tp <= 0 || sl <= 0) {
      setState(() => _error = 'Enter valid target and stop-loss prices.');
      return;
    }
    // OCO legs are LTP-triggered, so both must straddle the CURRENT price
    // or the broker rejects with "Invalid Condition". Validate against the
    // live LTP, not the entry avg.
    final ltp = widget.ltp;
    if (widget.isLong) {
      if (tp <= ltp) {
        setState(() => _error =
            'Target must be above the current price (${ltp.toStringAsFixed(_decimals)}).');
        return;
      }
      if (sl >= ltp) {
        setState(() => _error =
            'Stop-loss must be below the current price (${ltp.toStringAsFixed(_decimals)}).');
        return;
      }
    } else {
      if (tp >= ltp) {
        setState(() => _error =
            'Target must be below the current price (${ltp.toStringAsFixed(_decimals)}).');
        return;
      }
      if (sl <= ltp) {
        setState(() => _error =
            'Stop-loss must be above the current price (${ltp.toStringAsFixed(_decimals)}).');
        return;
      }
    }
    // Circuit-limit check (TC_523/524): neither leg may sit outside [lc, uc].
    final circErr =
        validateChartOco(target: tp, stop: sl, uc: widget.uc, lc: widget.lc);
    if (circErr != null) {
      setState(() => _error = circErr);
      return;
    }
    Navigator.of(context).pop((tp: tp, sl: sl));
  }

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

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text('Set Target & Stop-loss',
                        style: MyntWebTextStyles.title(context,
                            color: titleColor)),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 20, color: bodyColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.tsym}  ·  ${widget.isLong ? 'LONG' : 'SHORT'}'
                    '  ·  LTP ${widget.ltp.toStringAsFixed(_decimals)}',
                    style: MyntWebTextStyles.caption(context, color: bodyColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Placed as an OCO order — when one fills, the other is '
                    'cancelled.',
                    style: MyntWebTextStyles.caption(context, color: bodyColor),
                  ),
                  const SizedBox(height: 16),
                  _priceField(context, 'Target (TP)', _tp),
                  const SizedBox(height: 12),
                  _priceField(context, 'Stop-loss (SL)', _sl),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: MyntWebTextStyles.caption(context,
                            color: MyntColors.error)),
                  ],
                  const SizedBox(height: 24),
                  MyntPrimaryButton(
                    size: MyntButtonSize.large,
                    label: 'Place OCO',
                    isFullWidth: true,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceField(
      BuildContext context, String label, TextEditingController c) {
    final border = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final labelColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MyntWebTextStyles.caption(context, color: labelColor)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: MyntWebTextStyles.body(context),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: border),
            ),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
      ],
    );
  }
}

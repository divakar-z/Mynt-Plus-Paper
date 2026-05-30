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

Future<void> showCloseOrderDialog({
  required BuildContext context,
  required WidgetRef ref,
  required OrderBookModel order,
}) async {
  final tsym = order.tsym ?? '';
  final qty = order.qty ?? '';
  final type = order.prctyp ?? '';
  return _showIframeSafeDialog<void>(
    context: context,
    child: AlertDialog(
      title: const Text('Cancel order'),
      content: Text('Cancel $type order for $qty $tsym?'),
      actions: [
        Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Keep'),
        )),
        Builder(builder: (ctx) => FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await ref
                .read(orderProvider)
                .fetchOrderCancel(order.norenordno.toString(), context, false);
          },
          child: const Text('Cancel order'),
        )),
      ],
    ),
  );
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
  return _showIframeSafeDialog<void>(
    context: context,
    child: AlertDialog(
      title: const Text('Square off position'),
      content: Text('Place a MARKET $side for ${qty.replaceAll('-', '')} $tsym '
          'to close this position?'),
      actions: [
        Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Keep'),
        )),
        Builder(builder: (ctx) => FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
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
            await ref.read(portfolioProvider).fetchExitPosition(
                context, input, true, true);
          },
          child: const Text('Square off'),
        )),
      ],
    ),
  );
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
  return _showIframeSafeDialog<void>(
    context: context,
    child: AlertDialog(
      title: const Text('Modify order'),
      content: Text(bodyText),
      actions: [
        Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Keep'),
        )),
        Builder(builder: (ctx) => FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
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
            await ref
                .read(orderProvider)
                .fetchModifyOrder(input, context);
          },
          child: const Text('Modify'),
        )),
      ],
    ),
  );
}

Future<void> showAlertCancelDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AlertPendingModel alert,
}) async {
  final price = alert.pp ?? '';
  final tsym = alert.tsym ?? '';
  return _showIframeSafeDialog<void>(
    context: context,
    child: AlertDialog(
      title: const Text('Cancel alert'),
      content: Text('Cancel alert at $price for $tsym?'),
      actions: [
        Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Keep'),
        )),
        Builder(builder: (ctx) => FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await ref
                .read(marketWatchProvider)
                .fetchCancelAlert(alert.alId ?? '', context);
          },
          child: const Text('Cancel alert'),
        )),
      ],
    ),
  );
}

/// One-time warning shown when the user first enables Instant orders.
/// Returns true if the user clicks Enable, false otherwise.
Future<bool> showInstantWarningDialog({
  required BuildContext context,
}) async {
  bool result = false;
  await _showIframeSafeDialog<void>(
    context: context,
    child: AlertDialog(
      title: const Text('Enable instant orders?'),
      content: const Text(
          'Mutations (cancel, square-off, drag-modify, quick-place) will '
          'fire immediately on click. There will be no second chance to '
          'back out.'),
      actions: [
        Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        )),
        Builder(builder: (ctx) => FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
          onPressed: () {
            result = true;
            Navigator.of(ctx).pop();
          },
          child: const Text('Enable'),
        )),
      ],
    ),
  );
  return result;
}

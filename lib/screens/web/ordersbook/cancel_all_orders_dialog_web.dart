// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../models/order_book_model/order_book_model.dart';
import '../../../provider/order_provider.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../utils/responsive_snackbar.dart';

class CancelAllOrdersDialogWeb extends ConsumerStatefulWidget {
  final List<OrderBookModel> openOrders;

  /// When true, cancels ALL open orders. When false, cancels only selected orders.
  final bool isCancelAll;

  const CancelAllOrdersDialogWeb({
    super.key,
    required this.openOrders,
    required this.isCancelAll,
  });

  @override
  ConsumerState<CancelAllOrdersDialogWeb> createState() =>
      _CancelAllOrdersDialogWebState();
}

class _CancelAllOrdersDialogWebState
    extends ConsumerState<CancelAllOrdersDialogWeb> {
  bool _isLoading = false;

  /// Get order count to cancel
  int get _cancelCount {
    if (widget.isCancelAll) {
      return widget.openOrders.length;
    }
    return widget.openOrders
        .where((order) => order.isExitSelection ?? false)
        .length;
  }

  Future<void> _handleCancelOrders() async {
    if (_isLoading) return;

    final orderCount = _cancelCount;

    setState(() {
      _isLoading = true;
    });

    try {
      final orderProv = ref.read(orderProvider);

      // if (widget.isCancelAll) {
      //   // Cancel all pending orders directly
      //   await orderProv.cancelAllPendingOrders(context);
      // } else {
      //   // Cancel only selected orders
      //   await orderProv.exitOrders(context);
      // }
      //
      // ResponsiveSnackBar.showSuccess(
      //   context,
      //   '$orderCount order${orderCount > 1 ? 's' : ''} cancelled successfully',
      // );

      // Both calls return how many orders the exchange refused, so a partly
      // failed run no longer reports full success.
      final dynamic failedResult;
      if (widget.isCancelAll) {
        // Cancel all pending orders directly
        failedResult = await orderProv.cancelAllPendingOrders(context);
      } else {
        // Cancel only selected orders
        failedResult = await orderProv.exitOrders(context);
      }
      final failed = failedResult is int ? failedResult : 0;

      if (failed == 0) {
        ResponsiveSnackBar.showSuccess(
          context,
          '$orderCount order${orderCount > 1 ? 's' : ''} cancelled successfully',
        );
      } else if (failed >= orderCount) {
        ResponsiveSnackBar.showError(
          context,
          'Failed to cancel orders. Please try again.',
        );
      } else {
        final cancelled = orderCount - failed;
        ResponsiveSnackBar.showError(
          context,
          '$cancelled of $orderCount orders cancelled. $failed could not be cancelled.',
        );
      }
    } catch (e) {
      ResponsiveSnackBar.showError(
        context,
        'Failed to cancel orders. Please try again.',
      );
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderCount = _cancelCount;

    return Center(
      child: shadcn.Card(
        borderRadius: BorderRadius.circular(8),
        padding: EdgeInsets.zero,
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 250),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                      'Cancel Orders',
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
                      onPressed: () => Navigator.of(context).pop(false),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.isCancelAll
                            ? 'Are you sure you want to cancel all $orderCount open order${orderCount > 1 ? 's' : ''}?'
                            : 'Are you sure you want to cancel $orderCount selected order${orderCount > 1 ? 's' : ''}?',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.body(
                          context,
                          fontWeight: FontWeight.w500,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      MyntButton(
                        type: MyntButtonType.primary,
                        size: MyntButtonSize.large,
                        label: widget.isCancelAll
                            ? 'Cancel All'
                            : 'Cancel ($orderCount)',
                        isFullWidth: true,
                        isLoading: _isLoading,
                        backgroundColor: resolveThemeColor(
                          context,
                          dark: MyntColors.errorDark,
                          light: MyntColors.tertiary,
                        ),
                        onPressed: _isLoading || orderCount == 0
                            ? null
                            : _handleCancelOrders,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

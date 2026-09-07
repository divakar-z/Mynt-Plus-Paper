// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/ipo_model/ipo_order_book_model.dart';
import '../../../../models/ipo_model/ipo_place_order_model.dart';
import '../../../../provider/iop_provider.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';

class IpoCancelAlert extends ConsumerStatefulWidget {
  final IpoOrderBookModel ipocancel;

  const IpoCancelAlert({super.key, required this.ipocancel});

  @override
  ConsumerState<IpoCancelAlert> createState() => _IpoCancelAlertState();
}

class _IpoCancelAlertState extends ConsumerState<IpoCancelAlert> {
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: resolveThemeColor(
            context,
            dark: MyntColors.dialogDark,
            light: MyntColors.dialog,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with title and close button
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.dividerDark,
                      light: MyntColors.divider,
                    ),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cancel IPO Order',
                    style: MyntWebTextStyles.title(
                      context,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(false),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content area
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Are you sure you want to cancel this IPO order? This action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: MyntWebTextStyles.body(
                      context,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: _isCancelling
                          ? null
                          : () => _handleCancelOrder(context),
                      style: TextButton.styleFrom(
                        backgroundColor: resolveThemeColor(context,
                            dark: MyntColors.errorDark,
                            light: MyntColors.tertiary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _isCancelling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Cancel Order',
                              style: MyntWebTextStyles.buttonMd(
                                context,
                                color: Colors.white,
                              ),
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

  Future<void> _handleCancelOrder(BuildContext context) async {
    if (_isCancelling) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      final ipo = ref.read(ipoProvide);
      final menudata = MenuData(
        flow: "can",
        type: widget.ipocancel.type.toString(),
        symbol: widget.ipocancel.symbol.toString(),
        category: ipo.orderCategoryCode(widget.ipocancel),
        name: widget.ipocancel.companyName.toString(),
        applicationNumber: widget.ipocancel.applicationNumber.toString(),
        respBid: [BidReference(bidReferenceNumber: '67890')],
      );

      const List<IposBid> iposbids = [];

      await ipo.getipoplaceorder(context, menudata, iposbids, "");

      // Close the dialog after successful cancellation
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      // Handle error - dialog will remain open
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }
}

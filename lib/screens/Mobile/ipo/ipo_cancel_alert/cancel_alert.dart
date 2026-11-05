// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/ipo_model/ipo_order_book_model.dart';
import '../../../../models/ipo_model/ipo_place_order_model.dart';
import '../../../../provider/iop_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/global_state_text.dart';
import '../../../../res/res.dart';

class IpoCancelAlert extends ConsumerWidget {
  final IpoOrderBookModel ipocancel;

  const IpoCancelAlert({super.key, required this.ipocancel});

  static const Color _greyButtonColor = Color(0xffF1F3F8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);

    return AlertDialog(
      backgroundColor: theme
                                                                        .isDarkMode
                                                                    ? const Color(
                                                                        0xFF121212)
                                                                    : const Color(
                                                                        0xFFF1F3F8),
      titlePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8))),
      scrollable: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      actionsPadding:
          const EdgeInsets.only(bottom: 16, right: 16, left: 16, top: 8),
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      title: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () async {
                    await Future.delayed(const Duration(milliseconds: 150));
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(20),
                  splashColor: theme.isDarkMode
                      ? colors.splashColorDark
                      : colors.splashColorLight,
                  highlightColor: theme.isDarkMode
                      ? colors.splashColorDark
                      : colors.splashColorLight,
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.close_rounded,
                      size: 22,
                     color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  TextWidget.subText(
                    text:
                        "Are you sure you want to cancel the (${ipocancel.symbol} order)",
                    theme: theme.isDarkMode,
                      color: theme.isDarkMode
                                                                                ? colors.textSecondaryDark
                                                                                : colors.textPrimaryLight,
                    fw: 3,
                    align: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              _handleCancelOrder(context, ref);
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              side: BorderSide(color: colors.btnOutlinedBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              backgroundColor: colors.primaryDark,
            ),
            child: TextWidget.titleText(
                text: "Yes",
                theme: theme.isDarkMode,
                color:
                   colors.colorWhite ,
                fw: 2),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCancelOrder(BuildContext context, WidgetRef ref) async {
    final menudata = MenuData(
      flow: "can",
      type: ipocancel.type.toString(),
      symbol: ipocancel.symbol.toString(),
      category: "",
      name: ipocancel.companyName.toString(),
      applicationNumber: ipocancel.applicationNumber.toString(),
      respBid: [BidReference(bidReferenceNumber: '67890')],
      cancelBids: ipocancel.bidDetail ?? const [],
    );

    const List<IposBid> iposbids = [];

    await ref
        .read(ipoProvide)
        .getipoplaceorder(context, menudata, iposbids, "");

    if (context.mounted) {
      Navigator.pop(context);
      Navigator.pop(context);
    }
  }

  static TextStyle _textStyle(
      Color color, double fontSize, FontWeight fWeight) {
    return GoogleFonts.inter(
        textStyle:
            TextStyle(fontWeight: fWeight, color: color, fontSize: fontSize));
  }
}

class _CancelIcon extends StatelessWidget {
  const _CancelIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset("assets/icon/ipo_cancel_icon.svg");
  }
}

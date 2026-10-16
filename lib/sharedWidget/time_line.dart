import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';

import 'package:timeline_tile/timeline_tile.dart';
import '../../provider/thems.dart';
import '../models/order_book_model/order_history_model.dart';
import '../res/global_state_text.dart';
import '../res/res.dart';
import 'functions.dart';

class TimeLineWidget extends ConsumerWidget {
  final bool isfFrist;
  final bool isLast;
  final OrderHistoryModel orderHistoryData;

  const TimeLineWidget(
      {super.key,
      required this.isfFrist,
      required this.isLast,
      required this.orderHistoryData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 65,
      child: TimelineTile(
          hasIndicator: true,
          isFirst: isfFrist,
          isLast: isLast,
          afterLineStyle: LineStyle(
              thickness: 2,
              color: Color(orderHistoryData.status == "COMPLETE"
                  ? 0xff2DB266
                  : orderHistoryData.status == "CANCELED" ||
                          orderHistoryData.status == "REJECTED"
                      ? 0xffDC2626
                      : 0xffFFB038)),
          beforeLineStyle: LineStyle(
              thickness: 2,
              color: Color(orderHistoryData.status == "COMPLETE"
                  ? 0xff2DB266
                  : orderHistoryData.status == "CANCELED" ||
                          orderHistoryData.status == "REJECTED"
                      ? 0xffDC2626
                      : 0xffFFB038)),
          indicatorStyle: IndicatorStyle(
              width: 20,
              color: Color(orderHistoryData.status == "COMPLETE"
                  ? 0xff2DB266
                  : orderHistoryData.status == "CANCELED" ||
                          orderHistoryData.status == "REJECTED"
                      ? 0xffDC2626
                      : 0xffFFB038),
              iconStyle: IconStyle(
                iconData: orderHistoryData.status == "COMPLETE"
                    ? Icons.done
                    : orderHistoryData.status == "CANCELED" ||
                            orderHistoryData.status == "REJECTED"
                        ? Icons.clear
                        : Icons.more_horiz_outlined,
                fontSize: 12,
                color: const Color(0xffffffff),
              )),
          endChild: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
            dense: true,
            title: Text(
                "${orderHistoryData.stIntrn![0].toUpperCase()}${orderHistoryData.stIntrn!.substring(1).toLowerCase().replaceAll("_", " ")}",
                style: TextWidget.textStyle(
                    fontSize: 14,
                    theme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? colors.textPrimaryDark  
                        : colors.textPrimaryLight,
                    fw: 0)),
            subtitle: Text(formatDateTime(value: orderHistoryData.norentm!),
                style: TextWidget.textStyle(
                    fontSize: 12,
                    theme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? colors.textSecondaryDark
                        : colors.textSecondaryLight,
                    fw: 0)),
          )),
    );
  }

  TextStyle textStyle(Color color, double fontSize, fWeight) {
    return dysInter(
        textStyle:
            TextStyle(fontWeight: fWeight, color: color, fontSize: fontSize));
  }
}

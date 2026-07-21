import 'package:flutter/material.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../provider/thems.dart';
import '../../../res/global_state_text.dart';

class MFtimelineWidgetWeb extends StatelessWidget {
  final bool isfFrist;
  final bool isLast;
  final Map<String, dynamic> orderHistoryData;

  const MFtimelineWidgetWeb({
    super.key,
    required this.isfFrist,
    required this.isLast,
    required this.orderHistoryData,
  });

  @override
  Widget build(BuildContext context) {
    final registerCancelValue = orderHistoryData['register_cancel'] as String?;
    final isLive = registerCancelValue == "CANCELLED";
    final lineColor =
        isLive ? const Color(0xFFD34645) : const Color(0xff2DB266);
    final indicatorColor =
        isLive ? const Color(0xFFD34645) : const Color(0xff2DB266);

    return Consumer(builder: (context, ref, child) {
      final theme = ref.watch(themeProvider);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        height: 60,
        child: TimelineTile(
          isFirst: isfFrist,
          isLast: isLast,
          hasIndicator: true,
          afterLineStyle: LineStyle(thickness: 2, color: lineColor),
          beforeLineStyle: LineStyle(thickness: 2, color: indicatorColor),
          indicatorStyle: IndicatorStyle(
            width: 20,
            color: lineColor,
            iconStyle: IconStyle(
              iconData:
                  isLive ? Icons.more_horiz_outlined : Icons.check,
              fontSize: 12,
              color: const Color(0xffffffff),
            ),
          ),
          endChild: Container(
            margin: const EdgeInsets.only(left: 4),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              dense: true,
              title: TextWidget.paraText(
                align: TextAlign.start,
                text: (registerCancelValue ?? "UNKNOWN").toUpperCase(),
                color: theme.isDarkMode
                    ? colors.textPrimaryDark
                    : colors.textPrimaryLight,
                textOverflow: TextOverflow.ellipsis,
                theme: theme.isDarkMode,
                fw: 3,
              ),
              subtitle: 
              TextWidget.captionText(
                align: TextAlign.start,
                text: orderHistoryData['date'] as String? ?? "Unknown date",
                color: theme.isDarkMode
                    ? colors.textSecondaryDark
                    : colors.textSecondaryLight,
                textOverflow: TextOverflow.ellipsis,
                theme: theme.isDarkMode,
                fw: 3,
              ),
              
            ),
          ),
        ),
      );
    });
  }

  TextStyle textStyle(Color color, double fontSize, FontWeight fWeight) {
    return dysInter(
      textStyle: TextStyle(
        fontWeight: fWeight,
        color: color,
        fontSize: fontSize,
      ),
    );
  }
}

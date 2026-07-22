import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import '../../provider/thems.dart';
import '../../res/res.dart';
import '../res/global_state_text.dart';

class AlertDialogue extends ConsumerWidget {
  final String scripName;
  final String exch;
  final String content;
  const AlertDialogue(
      {super.key,
      required this.scripName,
      required this.exch,
      required this.content});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;
    // Constrain dialog width on desktop
    final dialogWidth =
        isDesktop ? 400.0 : screenWidth - 60; // 60 = 2 * 30 insetPadding

    return AlertDialog(
      backgroundColor: colors.colorWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      scrollable: true,
      titlePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? (screenWidth - 400) / 2 : 30,
        vertical: 12,
      ),
      actionsPadding:
          const EdgeInsets.only(bottom: 16, right: 16, left: 16, top: 8),
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
                      color: theme.isDarkMode
                          ? colors.colorWhite
                          : colors.colorBlack,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: dialogWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TextWidget.subText(
                //   text: "$scripName",
                //   theme: theme.isDarkMode,
                //   color: theme.isDarkMode
                //       ? colors.textPrimaryDark
                //       : colors.textPrimaryLight,
                //   fw: 3,
                //   align: TextAlign.center,
                // ),
                TextWidget.subText(
                  text: content,
                  theme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? colors.textPrimaryDark
                      : colors.textPrimaryLight,
                  fw: 3,
                  align: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: dialogWidth,
          child: OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
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
              text: "Ok",
              theme: theme.isDarkMode,
              color: !theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
              fw: 0,
            ),
          ),
        ),
      ],
    );
  }

  TextStyle textStyle(Color color, double fontSize, fWeight) {
    return dysInter(
        textStyle:
            TextStyle(fontWeight: fWeight, color: color, fontSize: fontSize));
  }

  Text headerTitleText(String text) {
    return Text(text,
        style: textStyle(const Color(0xff000000), 14, FontWeight.w500));
  }
}

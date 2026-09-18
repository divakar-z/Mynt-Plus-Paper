import 'package:flutter/material.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/res/res.dart';

class TextWidget {
  static Widget heroText(
      {required String text,
      required bool theme,
      Color? color,
      int? fw,
      int? maxLines,
      TextAlign? align,
      TextOverflow? textOverflow}) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: textOverflow,
      textAlign: align,
      style: dysInter(
          textStyle: TextStyle(
        fontSize: 20,
        color: (color != null)
            ? color
            : theme
                ? colors.colorWhite
                : colors.colorBlack,
        fontWeight: fw == 2
            ? FontWeight.bold
            : fw == 1
                ? FontWeight.w600
                : fw == 0
                    ? FontWeight.w500
                    : FontWeight.normal,
      )),
    );
  }

  static Widget headText(
      {required String text,
      required bool theme,
      Color? color,
      int? fw,
      int? maxLines,
      TextAlign? align,
      TextOverflow? textOverflow}) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: textOverflow,
      textAlign: align,
      style: dysInter(
          textStyle: TextStyle(
        fontSize: 18,
        color: (color != null)
            ? color
            : theme
                ? colors.colorWhite
                : colors.colorBlack,
        fontWeight: fw == 2
            ? FontWeight.bold
            : fw == 1
                ? FontWeight.w600
                : fw == 0
                    ? FontWeight.w500
                    : FontWeight.normal,
      )),
    );
  }

  static Widget titleText(
      {required String text,
      required bool theme,
      Color? color,
      int? fw,
      int? maxLines,
      TextAlign? align,
      TextOverflow? textOverflow}) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: textOverflow,
      textAlign: align,
      style: dysInter(
          textStyle: TextStyle(
        fontSize: 14,
        color: (color != null)
            ? color
            : theme
                ? colors.colorWhite
                : colors.colorBlack,
        fontWeight: fw == 2
            ? FontWeight.bold
            : fw == 1
                ? FontWeight.w600
                : fw == 0
                    ? FontWeight.w500
                    : FontWeight.normal,
      )),
    );
  }

  static Widget subText({
    required String text,
    required bool theme,
    Color? color,
    int? fw,
    int? maxLines,
    TextAlign? align,
    TextOverflow? textOverflow,
    double? letterSpacing,
    double? lineHeight,
    bool? softWrap,
    TextDecoration? decoration,
    Key? key,
  }) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: textOverflow,
      textAlign: align,
      softWrap: softWrap,
      style: dysInter(
        textStyle: TextStyle(
          fontSize: 14,
          color: (color != null)
              ? color
              : theme
                  ? colors.colorWhite
                  : colors.colorBlack,
          fontWeight: fw == 2
              ? FontWeight.bold
              : fw == 1
                  ? FontWeight.w600
                  : fw == 0
                      ? FontWeight.w500
                      : fw == 3
                          ? FontWeight.w400
                          : fw == 00
                              ? FontWeight.w400
                              : FontWeight.normal,
          letterSpacing: letterSpacing ?? 0.5,
          height: lineHeight,
          decoration: decoration,
        ),
      ),
    );
  }

 static Widget paraText({
  required String text,
  required bool theme,
  Color? color,
  int? fw,
  int? maxLines,
  double? height,
  TextAlign? align,
  TextOverflow? textOverflow,
  double? letterSpacing,
  TextDecoration? decoration, // ✅ added
}) {
  return Text(
    text,
    maxLines: maxLines,
    overflow: textOverflow,
    textAlign: align,
    style: dysInter(
      textStyle: TextStyle(
        fontSize: 12,
        color: (color != null)
            ? color
            : theme
                ? colors.colorWhite
                : colors.colorBlack,
        height: height,
        fontWeight: fw == 2
            ? FontWeight.bold
            : fw == 1
                ? FontWeight.w600
                : fw == 0
                    ? FontWeight.w500
                    : fw == 3
                        ? FontWeight.w400
                        : FontWeight.normal,
        letterSpacing: letterSpacing ?? 0.5,
        decoration: decoration, // ✅ apply optional decoration
      ),
    ),
  );
}


  static Widget captionText(
      {required String text,
      required bool theme,
      Color? color,
      int? fw,
      int? maxLines,
      TextAlign? align,
      TextOverflow? textOverflow}) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: textOverflow,
      textAlign: align,
      style: dysInter(
          textStyle: TextStyle(
        fontSize: 10,
        color: (color != null)
            ? color
            : theme
                ? colors.colorWhite
                : colors.colorBlack,
        fontWeight: fw == 2
            ? FontWeight.bold
            : fw == 1
                ? FontWeight.w600
                : fw == 0
                    ? FontWeight.w500
                    : FontWeight.normal,
      )),
    );
  }

  static Widget overlineText(
      {required String text,
      required bool theme,
      Color? color,
      int? fw,
      int? maxLines,
      TextAlign? align,
      TextOverflow? textOverflow}) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: textOverflow,
      textAlign: align,
      style: dysInter(
          textStyle: TextStyle(
        fontSize: 8,
        color: (color != null)
            ? color
            : theme
                ? colors.colorWhite
                : colors.colorBlack,
        fontWeight: fw == 2
            ? FontWeight.bold
            : fw == 1
                ? FontWeight.w600
                : fw == 0
                    ? FontWeight.w500
                    : FontWeight.normal,
      )),
    );
  }

  static Widget custmText({
    required String text,
    required int fs,
    required bool theme,
    Color? color,
    int? fw,
    int? maxLines,
    TextAlign? align,
    TextOverflow? textOverflow,
    double? letterSpacing,
  }) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: textOverflow,
      textAlign: align,
      style: dysInter(
          textStyle: TextStyle(
        fontSize: fs.toDouble(),
        color: (color != null)
            ? color
            : theme
                ? colors.colorWhite
                : colors.colorBlack,
        fontWeight: fw == 2
            ? FontWeight.bold
            : fw == 1
                ? FontWeight.w600
                : fw == 0
                    ? FontWeight.w500
                    : FontWeight.normal,
        letterSpacing: letterSpacing ?? 0.5,
      )),
    );
  }

  static TextStyle textStyle({
    required double fontSize,
    required bool theme,
    Color? color,
    int? fw,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return dysInter(
      textStyle: TextStyle(
        fontSize: fontSize,
        color: color ?? (theme ? colors.colorWhite : colors.colorBlack),
        fontWeight: fw == 2
            ? FontWeight.bold
            : fw == 1
                ? FontWeight.w600
                : fw == 0
                    ? FontWeight.w500
                    : fw == 00
                        ? FontWeight.w400
                        : fw == 3
                            ? FontWeight.w400
                            : FontWeight.normal,
        height: height,
        letterSpacing: letterSpacing ?? 0.5,
        decoration: decoration,
      ),
    );
  }
}

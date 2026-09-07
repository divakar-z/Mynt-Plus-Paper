import 'package:flutter/material.dart';

import '../provider/accessibility_provider.dart';
import 'colors.dart';

// Helper function to use Geist font instead of Inter. Resolves through
// dyslexiaFontOr so every AppTextStyles entry swaps to OpenDyslexic when
// Dyslexia Support is on (an explicit fontFamily won't inherit it otherwise).
TextStyle geistFont({TextStyle? textStyle}) {
  return TextStyle(
    fontFamily: dyslexiaFontOr('Geist'),
    fontWeight: textStyle?.fontWeight,
    fontSize: textStyle?.fontSize,
    color: textStyle?.color,
    letterSpacing: textStyle?.letterSpacing,
    height: textStyle?.height,
    decoration: textStyle?.decoration,
    decorationColor: textStyle?.decorationColor,
    decorationStyle: textStyle?.decorationStyle,
    fontStyle: textStyle?.fontStyle,
  );
}

// NOTE: `textStyles` is a long-lived singleton (see res.dart), so these are
// getters — not `final` fields — so the font re-resolves on every access and
// the Dyslexia Support toggle takes effect live instead of being frozen to
// whatever font was active when the singleton was first built.
class AppTextStyles {
  TextStyle get appBarTitleTxt => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors().colorBlack,
  ));
  TextStyle get textFieldLabelStyleInterV => TextStyle(
    fontFamily: dyslexiaFontOr('Geist'),
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors().colorBlack,
  );
  TextStyle get textFieldLabelStyle => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors().colorBlack,
  ));
  TextStyle get notificationtextstyle => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: AppColors().colorBlack,
  ));
  TextStyle get darkmorestyle => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors().colorLightBlue,
  ));
  TextStyle get morestyle => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors().colorBlue,
  ));
  TextStyle get notificationtimestyle => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: AppColors().colorGrey,
  ));
  TextStyle get actMenuTxt => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: AppColors().colorBlue,
  ));
  TextStyle get menuTxt => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: AppColors().colorGrey,
  ));

  TextStyle get prdText => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: AppColors().colorGrey,
  ));
  TextStyle get actPrdText => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: AppColors().colorBlue,
  ));

  TextStyle get darktextBtn => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors().colorLightBlue,
  ));

  TextStyle get textBtn => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors().colorBlue,
  ));

  TextStyle get btnText => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors().colorWhite,
  ));

  TextStyle get lengthtextstyle => geistFont(
      textStyle: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xff666666)));

  TextStyle get cnfrmvalidInfo => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: AppColors().colorBlack,
  ));

  TextStyle get scripNameTxtStyle => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: AppColors().colorBlack,
  ));

  TextStyle get scripExchTxtStyle => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 11,
    color: AppColors().colorGrey,
  ));

  TextStyle get resendOtpstyle => geistFont(
      textStyle: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: AppColors().colorBlue,
  ));
}

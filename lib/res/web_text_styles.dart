import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../provider/accessibility_provider.dart';
import 'colors.dart';

class WebTextStyles {
  // Check if running on web platform
  static bool get isWeb => kIsWeb;

  // Tenon font family for web (Adobe Typekit)
  static const String _tenonFontFamily = 'tenon';

  // Fallback to Inter for non-web platforms
  static const String _fallbackFontFamily = 'Inter';

  // Dyslexia Support swaps in OpenDyslexic; otherwise keep the platform font.
  String get _fontFamily =>
      dyslexiaFontOr(isWeb ? _tenonFontFamily : _fallbackFontFamily);

  TextStyle get appBarTitleTxt => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    color: AppColors().colorBlack,
  );

  TextStyle get textFieldLabelStyleInterV => TextStyle(
    fontFamily: dyslexiaFontOr(isWeb ? _tenonFontFamily : 'InterVariable'),
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: AppColors().colorBlack,
  );

  TextStyle get textFieldLabelStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: AppColors().colorBlack,
  );

  TextStyle get notificationtextstyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    color: AppColors().colorBlack,
  );

  TextStyle get darkmorestyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors().colorLightBlue,
  );

  TextStyle get morestyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors().colorBlue,
  );

  TextStyle get notificationtimestyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: AppColors().colorGrey,
  );

  TextStyle get actMenuTxt => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: AppColors().colorBlue,
  );

  TextStyle get menuTxt => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: AppColors().colorGrey,
  );

  TextStyle get prdText => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: AppColors().colorGrey,
  );

  TextStyle get actPrdText => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: AppColors().colorBlue,
  );

  TextStyle get darktextBtn => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors().colorLightBlue,
  );

  TextStyle get textBtn => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors().colorBlue,
  );

  TextStyle get btnText => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors().colorWhite,
  );

  TextStyle get lengthtextstyle => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: const Color(0xff666666),
  );

  TextStyle get cnfrmvalidInfo => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: AppColors().colorBlack,
  );

  TextStyle get scripNameTxtStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: AppColors().colorBlack,
  );

  TextStyle get scripExchTxtStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: AppColors().colorGrey,
  );

  TextStyle get resendOtpstyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: AppColors().colorBlue,
  );

  // Additional web-specific text styles
  TextStyle get webTitleStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    color: AppColors().colorBlack,
  );

  TextStyle get webSubtitleStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: AppColors().colorBlack,
  );

  TextStyle get webBodyStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors().colorBlack,
  );

  TextStyle get webCaptionStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: AppColors().colorGrey,
  );

  // Web-specific larger font styles for better readability
  TextStyle get webLargeTitleStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    color: AppColors().colorBlack,
  );

  TextStyle get webNavigationStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    color: AppColors().colorBlack,
  );

  TextStyle get webTableHeaderStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: AppColors().colorBlack,
  );

  TextStyle get webTableDataStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors().colorBlack,
  );

  TextStyle get webSummaryValueStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    color: AppColors().colorBlack,
  );

  TextStyle get webSummaryLabelStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: AppColors().colorGrey,
  );

  TextStyle get webMarketIndexStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    color: AppColors().colorBlack,
  );

  TextStyle get webMarketValueStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    color: AppColors().colorBlack,
  );

  TextStyle get webMarketChangeStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: AppColors().colorGrey,
  );
}
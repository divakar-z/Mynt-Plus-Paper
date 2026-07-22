import 'package:flutter/material.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';

/// A comprehensive typography system for consistent text styling across the app.
///
/// Uses Google Fonts Inter family and follows Material Design 3 principles.
/// Provides type-safe font weights and semantic text scales for consistent
/// typography throughout the application.
///
/// Example usage:
/// ```dart
/// Text("Hello", style: AppTypography.headlineLarge());
/// Text("Welcome", style: AppTypography.headlineLarge(
///   fontWeight: AppFontWeight.bold,
///   color: Colors.blue,
/// ));
/// ```

/// Defines semantic font weights for consistent typography.
///
/// Maps semantic weight names to Flutter [FontWeight] values, providing
/// compile-time safety and better readability than raw FontWeight values.
enum AppFontWeight {
  /// Light weight (300) - For subtle text
  light(FontWeight.w300),

  /// Regular weight (400) - Default body text
  regular(FontWeight.w400),

  /// Medium weight (500) - Emphasis without being too bold
  medium(FontWeight.w500),

  /// Semi-bold weight (600) - Strong emphasis, headings
  semiBold(FontWeight.w600),

  /// Bold weight (700) - Maximum emphasis, titles
  bold(FontWeight.w700);

  const AppFontWeight(this.value);
  final FontWeight value;
}

/// Defines semantic text sizes following Material Design 3 principles.
///
/// Provides a consistent set of text sizes organized by semantic meaning
/// rather than arbitrary pixel values. Based on a modular scale for visual harmony.
///
/// Size categories include Display (hero content), Headline (page titles),
/// Title (card titles), Body (content text), Label (form elements), and Caption
/// (metadata).
enum AppTextScale {
  // Display sizes for hero content
  /// 32px - Hero titles, app names on splash screens
  displayLarge(32.0),

  /// 28px - Large promotional text, main CTAs
  displayMedium(28.0),

  /// 24px - Secondary hero content
  displaySmall(24.0),

  // Headline sizes for titles
  /// 22px - Page titles, main screen headers ("Dashboard", "Login")
  headlineLarge(22.0),

  /// 20px - Section titles, card headers
  headlineMedium(20.0),

  /// 18px - Subsection titles, dialog headers
  headlineSmall(18.0),

  // Title sizes for subtitles
  /// 16px - Card titles, list item titles
  titleLarge(16.0),

  /// 14px - Form section titles, tab labels
  titleMedium(14.0),

  /// 12px - Small titles, grouped content headers
  titleSmall(12.0),

  // Body text sizes
  /// 16px - Primary body text, form inputs
  bodyLarge(16.0),

  /// 14px - Secondary body text, descriptions
  bodyMedium(14.0),

  /// 12px - Fine print, helper text
  bodySmall(12.0),

  // Label and caption sizes
  /// 14px - Button text, form labels
  labelLarge(14.0),

  /// 12px - Small buttons, input labels
  labelMedium(12.0),

  /// 10px - Tiny labels, status indicators
  labelSmall(10.0),

  /// 10px - Timestamps, version info, metadata
  caption(10.0);

  const AppTextScale(this.size);
  final double size;
}

/// Typography system for consistent text styling across the application.
///
/// Provides a centralized system for text styles using Google Fonts Inter.
/// All methods return [TextStyle] objects that can be used with [Text] widgets
/// or [TextFormField] styling.
///
/// Features type-safe font weights, semantic text scales, and easy customization.
/// Colors are handled separately through [AppColors] for theme awareness.
class AppTypography {
  AppTypography._(); // Private constructor to prevent instantiation

  /// Base text style factory method
  static TextStyle _createTextStyle({
    required double fontSize,
    required AppFontWeight fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return dysInter(
      fontSize: fontSize,
      fontWeight: fontWeight.value,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }

  // === DISPLAY STYLES ===
  // For hero content and major headings

  /// Creates a display large text style (32px).
  ///
  /// Use for hero titles, app names, and the most prominent text elements.
  /// Default font weight is [AppFontWeight.bold].
  ///
  /// The [fontWeight] parameter sets the font weight.
  /// The [color] parameter overrides the default text color.
  /// The [height] parameter sets the line height multiplier.
  /// The [letterSpacing] parameter adjusts character spacing.
  static TextStyle displayLarge({
    AppFontWeight fontWeight = AppFontWeight.bold,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.displayLarge.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle displayMedium({
    AppFontWeight fontWeight = AppFontWeight.bold,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.displayMedium.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle displaySmall({
    AppFontWeight fontWeight = AppFontWeight.semiBold,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.displaySmall.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // === HEADLINE STYLES ===
  // For page titles and section headers

  /// Creates a headline large text style (22px).
  ///
  /// Use for page titles, main screen headers, and dialog titles.
  /// Default font weight is [AppFontWeight.semiBold].
  ///
  /// The [fontWeight] parameter sets the font weight.
  /// The [color] parameter overrides the default text color.
  /// The [height] parameter sets the line height multiplier.
  /// The [letterSpacing] parameter adjusts character spacing.
  static TextStyle headlineLarge({
    AppFontWeight fontWeight = AppFontWeight.semiBold,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.headlineLarge.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle headlineMedium({
    AppFontWeight fontWeight = AppFontWeight.medium,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.headlineMedium.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle headlineSmall({
    AppFontWeight fontWeight = AppFontWeight.medium,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.headlineSmall.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // TITLE STYLES - For card titles and form labels
  static TextStyle titleLarge({
    AppFontWeight fontWeight = AppFontWeight.medium,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.titleLarge.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle titleMedium({
    AppFontWeight fontWeight = AppFontWeight.medium,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.titleMedium.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle titleSmall({
    AppFontWeight fontWeight = AppFontWeight.regular,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.titleSmall.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // === BODY STYLES ===
  // For content text and form inputs

  /// **Body Large (16px)** - Primary body text, form inputs
  ///
  /// The workhorse text style for:
  /// - TextFormField input text
  /// - Primary paragraph content
  /// - List item descriptions
  /// - Card content text
  ///
  /// ## Example:
  /// ```dart
  /// // For form inputs
  /// TextFormField(
  ///   style: AppTypography.bodyLarge(),
  ///   decoration: InputDecoration(labelText: "Email"),
  /// )
  ///
  /// // For content text
  /// Text(
  ///   "Your portfolio value has increased by 12% this month.",
  ///   style: AppTypography.bodyLarge(),
  /// )
  /// ```
  static TextStyle bodyLarge({
    AppFontWeight fontWeight = AppFontWeight.regular,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.bodyLarge.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle bodyMedium({
    AppFontWeight fontWeight = AppFontWeight.regular,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.bodyMedium.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle bodySmall({
    AppFontWeight fontWeight = AppFontWeight.regular,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.bodySmall.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // === LABEL STYLES ===
  // For form labels, buttons, and UI elements

  /// **Label Large (14px)** - Button text, form labels
  ///
  /// Essential for interactive elements:
  /// - Button text: "Login", "Sign Up", "Continue"
  /// - Form field labels: "Email Address", "Password"
  /// - Tab labels: "Overview", "Transactions"
  /// - Navigation items
  ///
  /// ## Example:
  /// ```dart
  /// // Button text
  /// ElevatedButton(
  ///   child: Text(
  ///     "Login",
  ///     style: AppTypography.labelLarge(
  ///       fontWeight: AppFontWeight.medium,
  ///       color: Colors.white,
  ///     ),
  ///   ),
  ///   onPressed: () {},
  /// )
  ///
  /// // Form label
  /// InputDecoration(
  ///   labelText: "Email",
  ///   labelStyle: AppTypography.labelLarge(),
  /// )
  /// ```
  static TextStyle labelLarge({
    AppFontWeight fontWeight = AppFontWeight.medium,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.labelLarge.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle labelMedium({
    AppFontWeight fontWeight = AppFontWeight.medium,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.labelMedium.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle labelSmall({
    AppFontWeight fontWeight = AppFontWeight.regular,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.labelSmall.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // === CAPTION STYLE ===
  // For small text and metadata

  /// **Caption (10px)** - Timestamps, version info, metadata
  ///
  /// Perfect for supplementary information:
  /// - Timestamps: "Last updated 5 minutes ago"
  /// - Version info: "Version 3.0.2"
  /// - Character counters: "8/10"
  /// - Helper text: "Password must be 8+ characters"
  /// - Status indicators: "Online", "Offline"
  ///
  /// ## Example:
  /// ```dart
  /// // Version info
  /// Text(
  ///   "Version 3.0.2",
  ///   style: AppTypography.caption(
  ///     color: Colors.grey,
  ///   ),
  /// )
  ///
  /// // Character counter
  /// Text(
  ///   "${controller.text.length}/10",
  ///   style: AppTypography.caption(),
  /// )
  ///
  /// // Error message
  /// Text(
  ///   "Invalid mobile number",
  ///   style: AppTypography.caption(
  ///     color: Colors.red,
  ///   ),
  /// )
  /// ```
  static TextStyle caption({
    AppFontWeight fontWeight = AppFontWeight.regular,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _createTextStyle(
        fontSize: AppTextScale.caption.size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // CUSTOM STYLE - For special cases
  static TextStyle custom({
    required double fontSize,
    AppFontWeight fontWeight = AppFontWeight.regular,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) =>
      _createTextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        decoration: decoration,
      );
}

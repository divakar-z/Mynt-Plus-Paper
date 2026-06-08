import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../res/mynt_web_text_styles.dart';
import '../res/mynt_web_color_styles.dart';

/// Common search text field widget library for web project
/// Provides consistent search field styles across the application
///
/// Usage Examples:
///
/// 1. Basic search field:
///    MyntSearchTextField(
///      controller: controller,
///      placeholder: 'Search stocks, indices, options',
///      leadingIcon: assets.searchIcon,
///    )
///
/// 2. Search field with smart clear button:
///    MyntSearchTextField.withSmartClear(
///      controller: controller,
///      placeholder: 'Search stocks, indices, options',
///      leadingIcon: assets.searchIcon,
///      onChanged: (value) { ... },
///    )

/// Search text field widget with hover effects and smart visibility
class MyntSearchTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? placeholder;
  final Widget? placeholderWidget;
  final TextStyle? placeholderStyle;
  final String? leadingIcon;
  final bool leadingIconHoverEffect;
  final shadcn.InputFeatureVisibility? leadingIconVisibility;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final double? height;
  final double? borderRadius;
  final bool autofocus;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final VoidCallback? onClear;
  final shadcn.InputFeatureVisibility? clearButtonVisibility;
  final Widget? trailingWidget;

  const MyntSearchTextField({
    super.key,
    required this.controller,
    this.placeholder,
    this.placeholderWidget,
    this.placeholderStyle,
    this.leadingIcon,
    this.leadingIconHoverEffect = true,
    this.leadingIconVisibility = shadcn.InputFeatureVisibility.textEmpty,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.height = 40,
    this.borderRadius = 5,
    this.autofocus = false,
    this.enabled = true,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.characters,
    this.onClear,
    this.clearButtonVisibility,
    this.trailingWidget,
  }) : assert(
          placeholder != null || placeholderWidget != null,
          'Either placeholder or placeholderWidget must be provided',
        );

  /// Factory constructor for advanced search with smart clear button visibility
  factory MyntSearchTextField.withSmartClear({
    Key? key,
    required TextEditingController controller,
    String? placeholder,
    Widget? placeholderWidget,
    TextStyle? placeholderStyle,
    String? leadingIcon,
    bool leadingIconHoverEffect = true,
    shadcn.InputFeatureVisibility? leadingIconVisibility,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    FocusNode? focusNode,
    double? height = 40,
    double? borderRadius = 5,
    bool autofocus = false,
    bool enabled = true,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.characters,
    VoidCallback? onClear,
    Widget? trailingWidget,
  }) {
    // Smart clear button visibility: visible whenever the field has text.
    final smartClearVisibility = shadcn.InputFeatureVisibility.textNotEmpty;

    return MyntSearchTextField(
      key: key,
      controller: controller,
      placeholder: placeholder,
      placeholderWidget: placeholderWidget,
      placeholderStyle: placeholderStyle,
      leadingIcon: leadingIcon,
      leadingIconHoverEffect: leadingIconHoverEffect,
      leadingIconVisibility:
          leadingIconVisibility ?? shadcn.InputFeatureVisibility.textEmpty,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      focusNode: focusNode,
      height: height,
      borderRadius: borderRadius,
      autofocus: false, // Always disabled
      enabled: enabled,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      onClear: onClear,
      clearButtonVisibility: smartClearVisibility,
      trailingWidget: trailingWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height ?? 40;

    // Placeholder style: textSecondary
    final effectivePlaceholderStyle = placeholderStyle ??
        MyntWebTextStyles.placeholder(
          context,
          color: resolveThemeColor(
            context,
            dark: WebColors.textSecondaryDark,
            light: WebColors.textSecondary,
          ),
          fontWeight: MyntFonts.medium,
        );

    // Input text style: textPrimary
    final effectiveTextStyle = MyntWebTextStyles.body(
      context,
      color: resolveThemeColor(
        context,
        dark: WebColors.textPrimaryDark,
        light: WebColors.textPrimary,
      ),
      fontWeight: MyntFonts.medium,
    );

    // Build placeholder widget
    final placeholder = placeholderWidget ??
        (this.placeholder != null
            ? Text(
                this.placeholder!,
                style: effectivePlaceholderStyle,
              )
            : null);

    // Build features (icons)
    final features = _buildFeatures(context);

    Widget textField = shadcn.Theme(
      data: shadcn.Theme.of(context).copyWith(
        radius: () => 0.2,
        colorScheme: () => shadcn.Theme.of(context).colorScheme.copyWith(
              border: () => Colors.transparent,
              ring: () => Colors.transparent,
            ),
      ),
      child: shadcn.TextField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        focusNode: focusNode,
        placeholder: placeholder,
        style: effectiveTextStyle,
        features: features,
      ),
    );

    // Apply height constraint
    textField = SizedBox(height: effectiveHeight, child: textField);

    return textField;
  }

  List<shadcn.InputFeature> _buildFeatures(BuildContext context) {
    final features = <shadcn.InputFeature>[];

    // Leading search icon with hover effect
    if (leadingIcon != null) {
      Widget iconWidget;

      if (leadingIconHoverEffect) {
        // Use StatedWidget for hover effect
        iconWidget = shadcn.StatedWidget.builder(
          builder: (context, states) {
            final iconColor = states.hovered
                ? resolveThemeColor(
                    context,
                    dark: WebColors.textPrimaryDark,
                    light: WebColors.textPrimary,
                  )
                : resolveThemeColor(
                    context,
                    dark: WebColors.textSecondaryDark,
                    light: WebColors.textSecondary,
                  );

            return SvgPicture.asset(
              leadingIcon!,
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              fit: BoxFit.scaleDown,
            );
          },
        );
      } else {
        iconWidget = SvgPicture.asset(
          leadingIcon!,
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(
            resolveThemeColor(
              context,
              dark: WebColors.iconDark,
              light: WebColors.icon,
            ),
            BlendMode.srcIn,
          ),
          fit: BoxFit.scaleDown,
        );
      }

      if (leadingIconVisibility != null) {
        features.add(
          shadcn.InputFeature.leading(
            iconWidget,
            visibility: leadingIconVisibility!,
          ),
        );
      } else {
        features.add(shadcn.InputFeature.leading(iconWidget));
      }
    }

    // Clear button
    if (onClear != null || clearButtonVisibility != null) {
      if (clearButtonVisibility != null) {
        features.add(
          shadcn.InputFeature.clear(
            visibility: clearButtonVisibility!,
          ),
        );
      } else {
        features.add(shadcn.InputFeature.clear());
      }
    }

    // Trailing widget
    if (trailingWidget != null) {
      features.add(shadcn.InputFeature.trailing(trailingWidget!));
    }

    return features;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../res/mynt_web_text_styles.dart';
import '../res/mynt_web_color_styles.dart';

// Import resolveThemeColor from mynt_web_text_styles
// It's already available via the mynt_web_text_styles import

/// Common button widget library for web project
/// Provides consistent button styles across the application
///
/// Usage Examples:
///
/// 1. Primary button with text:
///    MyntPrimaryButton(
///      label: 'Submit',
///      onPressed: () {},
///    )
///
/// 2. Secondary button with icon (like "New Watchlist"):
///    MyntSecondaryButton(
///      label: 'New Watchlist',
///      iconAsset: assets.addCircleIcon,
///      onPressed: () {},
///    )
///
/// 3. Outlined button:
///    MyntOutlinedButton(
///      label: 'Cancel',
///      onPressed: () {},
///    )
///
/// 4. Text button:
///    MyntTextButton(
///      label: 'Learn More',
///      onPressed: () {},
///    )
///
/// 5. Icon-only button:
///    MyntIconButton(
///      icon: Icons.add,
///      onPressed: () {},
///    )
///
/// 6. Button with loading state:
///    MyntPrimaryButton(
///      label: 'Save',
///      isLoading: true,
///      onPressed: () {},
///    )
///
/// 7. Full-width button:
///    MyntPrimaryButton(
///      label: 'Submit',
///      isFullWidth: true,
///      onPressed: () {},
///    )

enum MyntButtonSize {
  small,
  medium,
  large,
}

enum MyntButtonType {
  primary,
  secondary,
  outlined,
  text,
  ghost,
  tertiary,
}

/// Main button widget with icon and text support
class MyntButton extends StatelessWidget {
  final String? label;
  final VoidCallback? onPressed;
  final MyntButtonType type;
  final MyntButtonSize size;
  final IconData? icon;
  final String? iconAsset;
  final Widget? customIcon;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? borderRadius;
  final EdgeInsets? padding;
  final MainAxisAlignment? iconAlignment;

  const MyntButton({
    super.key,
    this.label,
    this.onPressed,
    this.type = MyntButtonType.primary,
    this.size = MyntButtonSize.medium,
    this.icon,
    this.iconAsset,
    this.customIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.borderRadius,
    this.padding,
    this.iconAlignment,
  }) : assert(
          label != null ||
              icon != null ||
              iconAsset != null ||
              customIcon != null,
          'Button must have either label, icon, iconAsset, or customIcon',
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Build button content
    Widget buttonContent = _buildButtonContent(context, isDarkMode);

    // Apply size constraints (skip for primary and outlined as they have fixed height)
    Widget sizedButton;
    if (type == MyntButtonType.primary || type == MyntButtonType.outlined) {
      sizedButton = buttonContent;
    } else {
      sizedButton = _applySizeConstraints(buttonContent);
    }

    // Apply full width if needed
    if (isFullWidth) {
      sizedButton = SizedBox(width: double.infinity, child: sizedButton);
    }

    return sizedButton;
  }

  Widget _buildButtonContent(BuildContext context, bool isDarkMode) {
    switch (type) {
      case MyntButtonType.primary:
        return _buildPrimaryButton(context, isDarkMode);
      case MyntButtonType.secondary:
        return _buildSecondaryButton(context, isDarkMode);
      case MyntButtonType.outlined:
        return _buildOutlinedButton(context, isDarkMode);
      case MyntButtonType.text:
        return _buildTextButton(context, isDarkMode);
      case MyntButtonType.ghost:
        return _buildGhostButton(context, isDarkMode);
      case MyntButtonType.tertiary:
        return _buildTertiaryButton(context, isDarkMode);
    }
  }

  Widget _buildPrimaryButton(BuildContext context, bool isDarkMode) {
    final txtColor = textColor ?? Colors.white;
    final bgColor = backgroundColor ??
        resolveThemeColor(
          context,
          dark: MyntColors.secondary,
          light: MyntColors.primary,
        );
    final borderRadiusValue = borderRadius ?? _getDefaultBorderRadius();
    final buttonPadding = padding ?? _getDefaultPadding();

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadiusValue),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadiusValue),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1.0,
            child: Padding(
              padding: buttonPadding,
              child: _buildButtonChild(context, txtColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(BuildContext context, bool isDarkMode) {
    final txtColor = textColor ??
        resolveThemeColor(
          context,
          dark: MyntColors.textPrimaryDark,
          light: MyntColors.textPrimary,
        );
    final bgColor = backgroundColor ??
        resolveThemeColor(
          context,
          dark: MyntColors.listItemBgDark,
          light: MyntColors.listItemBg,
        );
    final borderRadiusValue = borderRadius ?? _getDefaultBorderRadius();
    final buttonPadding = padding ?? _getDefaultPadding();

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadiusValue),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadiusValue),
          splashColor:
              (resolveThemeColor(context, dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor) ).withOpacity(0.05),
          highlightColor:
              (resolveThemeColor(context, dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor) ).withOpacity(0.02),
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1.0,
            child: Padding(
              padding: buttonPadding,
              child: _buildButtonChild(context, txtColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(BuildContext context, bool isDarkMode) {
    final txtColor = textColor ??
        resolveThemeColor(
          context,
          dark: Colors.white,
          light: MyntColors.primary,
        );
    final bgColor = backgroundColor ??
        resolveThemeColor(
          context,
          dark: MyntColors.textSecondaryDark.withOpacity(0.6),
          light: MyntColors.listItemBg,
        );
    final brdrColor = borderColor ??
        resolveThemeColor(
          context,
          dark: MyntColors.primaryDark,
          light: MyntColors.primary,
        );
    final borderRadiusValue = borderRadius ?? _getDefaultBorderRadius();
    final buttonPadding = padding ?? _getDefaultPadding();

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: brdrColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(borderRadiusValue),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadiusValue),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1.0,
            child: Padding(
              padding: buttonPadding,
              child: _buildButtonChild(context, txtColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextButton(BuildContext context, bool isDarkMode) {
    final txtColor = textColor ??
        resolveThemeColor(
          context,
          dark: MyntColors.primaryDark,
          light: MyntColors.primary,
        );

    return shadcn.TextButton(
      onPressed: isLoading ? null : onPressed,
      child: _buildButtonChild(context, txtColor),
    );
  }

  Widget _buildGhostButton(BuildContext context, bool isDarkMode) {
    final txtColor = textColor ??
        resolveThemeColor(
          context,
          dark: MyntColors.textPrimaryDark,
          light: MyntColors.textPrimary,
        );

    // Use shadcn IconButton with ghost variance for ghost button
    return shadcn.IconButton(
      onPressed: isLoading ? null : onPressed,
      size: shadcn.ButtonSize.small,
      variance: shadcn.ButtonVariance.ghost,
      icon: _buildButtonChild(context, txtColor),
    );
  }

  Widget _buildTertiaryButton(BuildContext context, bool isDarkMode) {
    final txtColor = textColor ??
        resolveThemeColor(
          context,
          dark: Colors.white,
          light: Colors.white,
        );

    final bgColor = backgroundColor ??
        resolveThemeColor(
          context,
          dark: MyntColors.errorDark,
          light: MyntColors.tertiary,
        );

    // Tertiary button: Primary style but with tertiary background
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(_getDefaultBorderRadius()),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_getDefaultBorderRadius()),
          onTap: isLoading ? null : onPressed,
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1.0,
             child: Padding(
            padding: padding ?? _getDefaultPadding(),
            child: _buildButtonChild(context, txtColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonChild(BuildContext context, Color textColor) {
    if (isLoading) {
      return SizedBox(
        width: _getIconSize(),
        height: _getIconSize(),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }

    final hasIcon = icon != null || iconAsset != null || customIcon != null;
    final hasLabel = label != null && label!.isNotEmpty;

    if (!hasLabel && hasIcon) {
      // Icon-only button
      return _buildIconWidget(textColor);
    }

    // Use bold font weight for primary and outlined buttons
    final shouldUseBold =
        type == MyntButtonType.primary || type == MyntButtonType.outlined;
    final fontWeight = shouldUseBold ? MyntFonts.bold : null;

    if (hasLabel && !hasIcon) {
      // Text-only button
      return Text(
        label!,
        style: _getTextStyle(context, textColor, fontWeight: fontWeight),
      );
    }

    if (hasLabel && hasIcon) {
      // Button with icon and text
      final alignment = iconAlignment ?? MainAxisAlignment.center;
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment,
        children: [
          _buildIconWidget(textColor),
          const SizedBox(width: 6),
          Text(
            label!,
            style: _getTextStyle(context, textColor, fontWeight: fontWeight),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildIconWidget(Color color) {
    if (customIcon != null) {
      return customIcon!;
    }
    if (iconAsset != null) {
      return SvgPicture.asset(
        iconAsset!,
        width: _getIconSize(),
        height: _getIconSize(),
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    if (icon != null) {
      return Icon(
        icon,
        size: _getIconSize(),
        color: color,
      );
    }
    return const SizedBox.shrink();
  }

  TextStyle _getTextStyle(BuildContext context, Color color,
      {FontWeight? fontWeight}) {
    TextStyle baseStyle;
    switch (size) {
      case MyntButtonSize.small:
        baseStyle = MyntWebTextStyles.buttonSm(
          context,
          color: color,
        );
        break;
      case MyntButtonSize.medium:
        baseStyle = MyntWebTextStyles.buttonMd(
          context,
          color: color,
        );
        break;
      case MyntButtonSize.large:
        baseStyle = MyntWebTextStyles.buttonXl(
          context,
          color: color,
        );
        break;
    }
    return fontWeight != null
        ? baseStyle.copyWith(fontWeight: fontWeight)
        : baseStyle;
  }

  double _getIconSize() {
    switch (size) {
      case MyntButtonSize.small:
        return 16;
      case MyntButtonSize.medium:
        return 18;
      case MyntButtonSize.large:
        return 20;
    }
  }

  Widget _applySizeConstraints(Widget child) {
    final buttonPadding = padding ?? _getDefaultPadding();
    final borderRadiusValue = borderRadius ?? _getDefaultBorderRadius();

    return Container(
      padding: buttonPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadiusValue),
      ),
      child: child,
    );
  }

  EdgeInsets _getDefaultPadding() {
    // Standardized padding for all button sizes - consistent horizontal padding
    switch (size) {
      case MyntButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case MyntButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
      case MyntButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
  }

  double _getDefaultBorderRadius() {
    switch (size) {
      case MyntButtonSize.small:
        return 5;
      case MyntButtonSize.medium:
        return 5;
      case MyntButtonSize.large:
        return 5;
    }
  }
}

/// Convenience constructors for common button types

/// Primary button with icon
class MyntPrimaryButton extends MyntButton {
  const MyntPrimaryButton({
    super.key,
    required super.label,
    super.onPressed,
    super.size = MyntButtonSize.medium,
    super.icon,
    super.iconAsset,
    super.customIcon,
    super.isLoading = false,
    super.isFullWidth = false,
    super.iconAlignment,
    super.backgroundColor,
    super.textColor,
    super.borderColor,
    super.borderRadius,
    super.padding,
  }) : super(type: MyntButtonType.primary);
}

/// Secondary button with icon (like "New Watchlist")
class MyntSecondaryButton extends MyntButton {
  const MyntSecondaryButton({
    super.key,
    required super.label,
    super.onPressed,
    super.size = MyntButtonSize.medium,
    super.icon,
    super.iconAsset,
    super.customIcon,
    super.isLoading = false,
    super.isFullWidth = false,
    super.iconAlignment,
    super.padding,
  }) : super(type: MyntButtonType.secondary);
}

/// Outlined button
class MyntOutlinedButton extends MyntButton {
  const MyntOutlinedButton({
    super.key,
    required super.label,
    super.onPressed,
    super.size = MyntButtonSize.medium,
    super.icon,
    super.iconAsset,
    super.customIcon,
    super.isLoading = false,
    super.isFullWidth = false,
    super.borderColor,
    super.textColor,
    super.iconAlignment,
    super.padding,
  }) : super(type: MyntButtonType.outlined);
}

/// Text button
class MyntTextButton extends MyntButton {
  const MyntTextButton({
    super.key,
    required super.label,
    super.onPressed,
    super.size = MyntButtonSize.medium,
    super.icon,
    super.iconAsset,
    super.customIcon,
    super.isLoading = false,
    super.isFullWidth = false,
    super.iconAlignment,
    super.padding,
  }) : super(type: MyntButtonType.text);
}

/// Tertiary button (Primary style with tertiary background)
class MyntTertiaryButton extends MyntButton {
  const MyntTertiaryButton({
    super.key,
    required super.label,
    super.onPressed,
    super.size = MyntButtonSize.medium,
    super.icon,
    super.iconAsset,
    super.customIcon,
    super.isLoading = false,
    super.isFullWidth = false,
    super.iconAlignment,
    super.padding,
  }) : super(type: MyntButtonType.tertiary);
}

/// Icon-only button
class MyntIconButton extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final Widget? customIcon;
  final VoidCallback? onPressed;
  final MyntButtonSize size;
  final Color? color;
  final Color? backgroundColor;
  final double? borderRadius;
  final EdgeInsets? padding;

  const MyntIconButton({
    super.key,
    this.icon,
    this.iconAsset,
    this.customIcon,
    this.onPressed,
    this.size = MyntButtonSize.medium,
    this.color,
    this.backgroundColor,
    this.borderRadius,
    this.padding,
  }) : assert(
          icon != null || iconAsset != null || customIcon != null,
          'IconButton must have either icon, iconAsset, or customIcon',
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final iconColor = color ??
        resolveThemeColor(
          context,
          dark: MyntColors.iconDark,
          light: MyntColors.icon,
        );

    final iconSize = _getIconSize();
    final buttonPadding = padding ?? _getDefaultPadding();

    Widget iconWidget;
    if (customIcon != null) {
      iconWidget = customIcon!;
    } else if (iconAsset != null) {
      iconWidget = SvgPicture.asset(
        iconAsset!,
        width: iconSize,
        height: iconSize,
        color: iconColor,
        // colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
    } else {
      iconWidget = Icon(icon, size: iconSize, color: iconColor);
    }

    return Material(
      color: backgroundColor ?? Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        splashColor: resolveThemeColor(
          context,
          dark: MyntColors.rippleDark,
          light: MyntColors.rippleLight,
        ),
        highlightColor: resolveThemeColor(
          context,
          dark: MyntColors.highlightDark,
          light: MyntColors.highlightLight,
        ),
        onTap: onPressed,
        child: Padding(
          padding: buttonPadding,
          child: iconWidget,
        ),
      ),
    );
  }

  EdgeInsets _getDefaultPadding() {
    switch (size) {
      case MyntButtonSize.small:
        return const EdgeInsets.all(8);
      case MyntButtonSize.medium:
        return const EdgeInsets.all(8);
      case MyntButtonSize.large:
        return const EdgeInsets.all(10);
    }
  }

  double _getIconSize() {
    switch (size) {
      case MyntButtonSize.small:
        return 16;
      case MyntButtonSize.medium:
        return 18;
      case MyntButtonSize.large:
        return 20;
    }
  }
}

/// Icon + Text button with InkWell (no background, just hover effect)
class MyntIconTextButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String? iconAsset;
  final Widget? customIcon;
  final VoidCallback? onPressed;
  final MyntButtonSize size;
  final Color? textColor;
  final Color? iconColor;
  final EdgeInsets? padding;
  final double? borderRadius;

  const MyntIconTextButton({
    super.key,
    this.label,
    this.icon,
    this.iconAsset,
    this.customIcon,
    this.onPressed,
    this.size = MyntButtonSize.medium,
    this.textColor,
    this.iconColor,
    this.padding,
    this.borderRadius,
  }) : assert(
          label != null ||
              icon != null ||
              iconAsset != null ||
              customIcon != null,
          'IconTextButton must have either label, icon, iconAsset, or customIcon',
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final defaultTextColor = textColor ??
        resolveThemeColor(
          context,
          dark: MyntColors.primaryDark,
          light: MyntColors.primary,
        );

    final defaultIconColor = iconColor ?? defaultTextColor;
    final iconSize = _getIconSize();
    final buttonPadding = padding ?? _getDefaultPadding();
    final borderRadiusValue = borderRadius ?? _getDefaultBorderRadius();

    Widget iconWidget;
    if (customIcon != null) {
      iconWidget = customIcon!;
    } else if (iconAsset != null) {
      iconWidget = SvgPicture.asset(
        iconAsset!,
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(defaultIconColor, BlendMode.srcIn),
      );
    } else if (icon != null) {
      iconWidget = Icon(icon, size: iconSize, color: defaultIconColor);
    } else {
      iconWidget = const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadiusValue),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadiusValue),
        hoverColor:
            (isDarkMode ? Colors.white : Colors.black).withOpacity(0.05),
        splashColor:
            (isDarkMode ? Colors.white : Colors.black).withOpacity(0.1),
        highlightColor:
            (isDarkMode ? Colors.white : Colors.black).withOpacity(0.03),
        onTap: onPressed,
        child: Padding(
          padding: buttonPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              if (label != null && label!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label!,
                  style: _getTextStyle(context, defaultTextColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _getTextStyle(BuildContext context, Color color) {
    switch (size) {
      case MyntButtonSize.small:
        return MyntWebTextStyles.buttonSm(
          context,
          color: color,
        );
      case MyntButtonSize.medium:
        return MyntWebTextStyles.buttonMd(
          context,
          color: color,
        );
      case MyntButtonSize.large:
        return MyntWebTextStyles.buttonXl(
          context,
          color: color,
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case MyntButtonSize.small:
        return 16;
      case MyntButtonSize.medium:
        return 18;
      case MyntButtonSize.large:
        return 20;
    }
  }

  EdgeInsets _getDefaultPadding() {
    switch (size) {
      case MyntButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
      case MyntButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case MyntButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    }
  }

  double _getDefaultBorderRadius() {
    switch (size) {
      case MyntButtonSize.small:
        return 6;
      case MyntButtonSize.medium:
        return 8;
      case MyntButtonSize.large:
        return 10;
    }
  }
}

/// Close button for dialogs - optimized for consistent dialog close behavior
class MyntCloseButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double? iconSize;
  final Color? iconColor;
  final EdgeInsets? padding;

  const MyntCloseButton({
    super.key,
    this.onPressed,
    this.iconSize,
    this.iconColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final defaultIconColor = iconColor ??
        resolveThemeColor(
          context,
          dark: MyntColors.textSecondaryDark,
          light: MyntColors.textSecondary,
        );

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        hoverColor:
            (isDarkMode ? Colors.white : Colors.black).withOpacity(0.05),
        splashColor:
            (isDarkMode ? Colors.white : Colors.black).withOpacity(0.1),
        highlightColor:
            (isDarkMode ? Colors.white : Colors.black).withOpacity(0.03),
        onTap: onPressed,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(6.0),
          child: Icon(
            Icons.close,
            size: iconSize ?? 18,
            color: defaultIconColor,
          ),
        ),
      ),
    );
  }
}

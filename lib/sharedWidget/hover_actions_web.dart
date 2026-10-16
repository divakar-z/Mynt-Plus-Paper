import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../res/mynt_web_text_styles.dart';
import '../res/mynt_web_color_styles.dart';
import '../res/global_font_web.dart';

/// Common hover actions widget library for web project
/// Provides consistent hover action button styles across the application
///
/// Usage Examples:
///
/// 1. Basic hover actions with Buy/Sell buttons:
///    HoverActionsContainer(
///      isVisible: isHovered,
///      actions: [
///        HoverActionButton(
///          label: 'B',
///          color: Colors.white,
///          backgroundColor: MyntColors.primary,
///          onPressed: () => handleBuy(),
///        ),
///        HoverActionButton(
///          label: 'S',
///          color: Colors.white,
///          backgroundColor: MyntColors.tertiary,
///          onPressed: () => handleSell(),
///        ),
///      ],
///    )
///
/// 2. Icon-only action buttons:
///    HoverActionsContainer(
///      isVisible: isHovered,
///      actions: [
///        HoverActionButton(
///          iconAsset: assets.depthIcon,
///          color: Colors.black,
///          onPressed: () => showDepth(),
///        ),
///        HoverActionButton(
///          icon: Icons.delete_outline,
///          color: Colors.black,
///          onPressed: () => deleteItem(),
///        ),
///      ],
///    )
///
/// 3. Mixed buttons with custom spacing:
///    HoverActionsContainer(
///      isVisible: isHovered,
///      spacing: 8.0,
///      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
///      actions: [
///        HoverActionButton.buy(onPressed: () => handleBuy()),
///        HoverActionButton.sell(onPressed: () => handleSell()),
///        HoverActionButton.icon(iconAsset: assets.chartIcon, onPressed: () {}),
///      ],
///    )

/// Individual hover action button widget
/// Can display either a label (text) or an icon
class HoverActionButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String? iconAsset;
  final Color color;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final VoidCallback? onPressed;
  final double? size;
  final double? width;
  final double? height;
  final double? iconSize;

  const HoverActionButton({
    super.key,
    this.label,
    this.icon,
    this.iconAsset,
    required this.color,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.onPressed,
    this.size,
    this.width,
    this.height,
    this.iconSize,
  }) : assert(
          label != null || icon != null || iconAsset != null,
          'HoverActionButton must have either label, icon, or iconAsset',
        );

  /// Factory constructor for Buy button
  factory HoverActionButton.buy({
    required BuildContext context,
    required VoidCallback? onPressed,
    double? borderRadius,
    double? size,
    double? iconSize,
  }) {
    return HoverActionButton(
      label: 'B',
      color: Colors.white,
      backgroundColor: resolveThemeColor(
        context,
        dark: MyntColors.secondary,
        light: MyntColors.primary,
      ),
      borderColor: resolveThemeColor(
        context,
        dark: MyntColors.secondary,
        light: MyntColors.primary,
      ),
      onPressed: onPressed,
      borderRadius: borderRadius,
      size: size,
      iconSize: iconSize,
    );
  }

  /// Factory constructor for Sell button
  factory HoverActionButton.sell({
    required BuildContext context,
    required VoidCallback? onPressed,
    double? borderRadius,
    double? size,
    double? iconSize,
  }) {
    return HoverActionButton(
      label: 'S',
      color: Colors.white,
      backgroundColor: resolveThemeColor(
        context,
        dark: MyntColors.errorDark,
        light: MyntColors.tertiary,
      ),
      borderColor: resolveThemeColor(
        context,
        dark: MyntColors.errorDark,
        light: MyntColors.tertiary,
      ),
      onPressed: onPressed,
      borderRadius: borderRadius,
      size: size,
      iconSize: iconSize,
    );
  }

  /// Factory constructor for Redeem button
  factory HoverActionButton.redeem({
    required BuildContext context,
    required VoidCallback? onPressed,
    double? borderRadius,
    double? width,
    double? height,
  }) {
    return HoverActionButton(
      label: 'Redeem',
      color: Colors.white,
      backgroundColor: resolveThemeColor(
        context,
        dark: MyntColors.primaryDark,
        light: MyntColors.primary,
      ),
      borderColor: resolveThemeColor(
        context,
        dark: MyntColors.primaryDark,
        light: MyntColors.primary,
      ),
      onPressed: onPressed,
      borderRadius: borderRadius,
      width: width ?? 60.0,
      height: height ?? 24.0,
    );
  }

  /// Factory constructor for icon-only button with transparent background
  factory HoverActionButton.icon({
    required BuildContext context,
    IconData? icon,
    String? iconAsset,
    required VoidCallback? onPressed,
    Color? iconColor,
    double? borderRadius,
    double? size,
    double? iconSize,
  }) {
    return HoverActionButton(
      icon: icon,
      iconAsset: iconAsset,
      color: iconColor ??
          resolveThemeColor(
            context,
            dark: MyntColors.textSecondaryDark,
            light: Colors.black,
          ),
      backgroundColor: Colors.transparent,
      onPressed: onPressed,
      borderRadius: borderRadius,
      size: size,
      iconSize: iconSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderRadiusValue = borderRadius ?? 5.0;
    final defaultSize = label != null ? 24.0 : 26.0;
    final w = width ?? size ?? defaultSize;
    final h = height ?? size ?? defaultSize;
    final iconSizeValue = iconSize ?? 13.0;

    return SizedBox(
      width: w,
      height: h,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          splashColor: color.withOpacity(0.15),
          highlightColor: color.withOpacity(0.08),
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadiusValue),
              border: borderColor != null
                  ? Border.all(
                      color: borderColor!,
                      width: 1,
                    )
                  : null,
            ),
            child: Center(
              child: _buildContent(context, iconSizeValue),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double iconSizeValue) {
    if (iconAsset != null) {
      return SvgPicture.asset(
        iconAsset!,
        width: iconSizeValue,
        height: iconSizeValue,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    if (icon != null) {
      return Icon(
        icon,
        size: iconSizeValue,
        color: color,
      );
    }

    if (label != null) {
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      return Text(
        label!,
        // style: WebTextStyles.buttonSm(
        //   isDarkTheme: isDarkMode,
        //   color: color,
        // ),
        style: MyntWebTextStyles.buttonSm(context, color: color),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Container widget that wraps hover action buttons
/// Handles the animated opacity and shadow effects
class HoverActionsContainer extends StatelessWidget {
  final bool isVisible;
  final List<Widget> actions;
  final Duration animationDuration;
  final EdgeInsets? padding;
  final double? spacing;
  final double? borderRadius;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  const HoverActionsContainer({
    super.key,
    required this.isVisible,
    required this.actions,
    this.animationDuration = const Duration(milliseconds: 150),
    this.padding,
    this.spacing,
    this.borderRadius,
    this.backgroundColor,
    this.boxShadow,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final defaultPadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final defaultBorderRadius = borderRadius ?? 8.0;
    final defaultSpacing = spacing ?? 4.0;
    final defaultBackgroundColor = backgroundColor ??
        (dark
            ? MyntColors.textPrimaryDark
            : Colors.white);
    final defaultBoxShadow = boxShadow ??
        (dark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ]);
    final defaultBorder = border ??
        (dark
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              )
            : null);

    final borderRadiusGeometry =
        BorderRadius.circular(defaultBorderRadius);

    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: animationDuration,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: ClipRRect(
          borderRadius: borderRadiusGeometry,
          child: BackdropFilter(
            filter: dark
                ? ImageFilter.blur(sigmaX: 12, sigmaY: 12)
                : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              padding: defaultPadding,
              decoration: BoxDecoration(
                color: defaultBackgroundColor,
                borderRadius: borderRadiusGeometry,
                boxShadow: defaultBoxShadow,
                border: defaultBorder,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _buildActionsWithSpacing(defaultSpacing),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActionsWithSpacing(double spacing) {
    final List<Widget> result = [];
    for (int i = 0; i < actions.length; i++) {
      result.add(actions[i]);
      if (i < actions.length - 1) {
        result.add(SizedBox(width: spacing));
      }
    }
    return result;
  }
}

/// A wrapper widget that provides hover detection and positions
/// the hover actions container
class HoverActionsWrapper extends StatefulWidget {
  final Widget child;
  final List<Widget> Function(BuildContext context) actionsBuilder;
  final Alignment actionsAlignment;
  final EdgeInsets? actionsPadding;
  final bool enabled;

  /// Optional background painted behind the child while hovered. Pass null to
  /// paint no hover background (e.g. when the row already has a selection color).
  final Color? hoverBackgroundColor;

  const HoverActionsWrapper({
    super.key,
    required this.child,
    required this.actionsBuilder,
    this.actionsAlignment = Alignment.centerRight,
    this.actionsPadding,
    this.enabled = true,
    this.hoverBackgroundColor,
  });

  @override
  State<HoverActionsWrapper> createState() => _HoverActionsWrapperState();
}

class _HoverActionsWrapperState extends State<HoverActionsWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        color: (_isHovered && widget.hoverBackgroundColor != null)
            ? widget.hoverBackgroundColor
            : null,
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: Align(
                alignment: widget.actionsAlignment,
                child: Padding(
                  padding:
                      widget.actionsPadding ?? const EdgeInsets.only(right: 8),
                  child: HoverActionsContainer(
                    isVisible: _isHovered,
                    actions: widget.actionsBuilder(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

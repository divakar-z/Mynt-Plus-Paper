import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/main.dart' show getNavigatorContext, getNavigatorState, rootScaffoldMessengerKey;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/responsive_extensions.dart';
import 'dart:async';

/// Responsive SnackBar utility that adapts to screen size
/// Shows toast-style notification in top-right corner on desktop with Stacking effect
/// Uses standard SnackBar behavior on mobile
class ResponsiveSnackBar {
  static int _toastCounter = 0;

  /// Shows a responsive snackbar/toast notification
  static void show({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    // Use navigator context if available, fallback to passed context
    final effectiveContext = getNavigatorContext() ?? context;

    // Use centralized breakpoint check with effective context
    if (effectiveContext.isWebLayout) {
      // Desktop: Show as stacked toast in bottom-right corner
      _showDesktopToast(
        context: effectiveContext,
        message: message,
        type: type,
        duration: duration,
        actionLabel: actionLabel,
        onActionPressed: onActionPressed,
      );
    } else {
      // Mobile: Use standard SnackBar
      _showMobileSnackBar(
        context: effectiveContext,
        message: message,
        type: type,
        duration: duration,
        actionLabel: actionLabel,
        onActionPressed: onActionPressed,
      );
    }
  }
  
  // -- Desktop Logic (Stacking Toasts) --

  static OverlayEntry? _overlayEntry;

  /// Adds a new toast to the manager and ensures overlay is active
  static void _showDesktopToast({
    required BuildContext context,
    required String message,
    required SnackBarType type,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    // 1. Add toast to manager
    _toastCounter++;
    _ToastManager.instance.addToast(
      _ToastData(
        id: '${DateTime.now().microsecondsSinceEpoch}_$_toastCounter',
        message: message,
        type: type,
        duration: duration,
        actionLabel: actionLabel,
        onActionPressed: onActionPressed,
      )
    );

    // 2. Ensure Overlay is present
    if (_overlayEntry == null || !_overlayEntry!.mounted) {
      _overlayEntry = OverlayEntry(
        builder: (context) => const ProviderScope(
          child: _ToastStackWidget(),
        ),
      );

      // Try multiple ways to find an overlay
      OverlayState? overlay;

      // Method 1: Try Navigator's overlay from rootNavigatorKey
      final navigatorState = getNavigatorState();
      if (navigatorState != null) {
        overlay = navigatorState.overlay;
      }

      // Method 2: Try Overlay.maybeOf from context
      overlay ??= Overlay.maybeOf(context);

      // Method 3: Try from rootNavigatorKey context
      if (overlay == null) {
        final rootContext = getNavigatorContext();
        if (rootContext != null) {
          overlay = Overlay.maybeOf(rootContext);
        }
      }

      // Insert if we found an overlay
      if (overlay != null) {
        overlay.insert(_overlayEntry!);
      } else {
        // Schedule for next frame in case Navigator isn't ready yet
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_overlayEntry != null && !_overlayEntry!.mounted) {
            final navigatorState = getNavigatorState();
            if (navigatorState?.overlay != null) {
              navigatorState!.overlay!.insert(_overlayEntry!);
            }
          }
        });
      }
    }
  }
  
  // -- Mobile Logic (Standard SnackBar) --

  static void _showMobileSnackBar({
    required BuildContext context,
    required String message,
    required SnackBarType type,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    final colorScheme = _getColorScheme(type);

    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: colorScheme.surface,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.primary, width: 1),
      ),
      action: actionLabel != null && onActionPressed != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: colorScheme.primary,
              onPressed: onActionPressed,
            )
          : null,
    );

    // Try to use ScaffoldMessenger from context first, fallback to root key
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (e) {
      // Fallback to root scaffold messenger key
      rootScaffoldMessengerKey.currentState?.clearSnackBars();
      rootScaffoldMessengerKey.currentState?.showSnackBar(snackBar);
    }
  }
  
  /// Gets color scheme based on SnackBar type
  static _ColorScheme _getColorScheme(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return _ColorScheme(
          surface: colors.successLight.withValues(alpha: 0.9),
          onSurface: Colors.white,
          primary: colors.successLight,
        );
      case SnackBarType.error:
        return _ColorScheme(
          surface: colors.lossLight.withValues(alpha: 0.9),
          onSurface: Colors.white,
          primary: colors.lossLight,
        );
      case SnackBarType.warning:
        return _ColorScheme(
          surface: Colors.orange.withValues(alpha: 0.9),
          onSurface: Colors.white,
          primary: Colors.orange,
        );
      case SnackBarType.info:
        return _ColorScheme(
          surface: colors.colorBlue.withValues(alpha: 0.9),
          onSurface: Colors.white,
          primary: colors.colorBlue,
        );
    }
  }
  
  /// Convenience methods
  static void showSuccess(BuildContext context, String message, {Duration? duration}) {
    show(context: context, message: message, type: SnackBarType.success, duration: duration ?? const Duration(seconds: 4));
  }
  
  static void showError(BuildContext context, String message, {Duration? duration}) {
    show(context: context, message: message, type: SnackBarType.error, duration: duration ?? const Duration(seconds: 4));
  }
  
  static void showWarning(BuildContext context, String message, {Duration? duration}) {
    show(context: context, message: message, type: SnackBarType.warning, duration: duration ?? const Duration(seconds: 3));
  }
  
  static void showInfo(BuildContext context, String message, {Duration? duration}) {
    show(context: context, message: message, type: SnackBarType.info, duration: duration ?? const Duration(seconds: 3));
  }
}

enum SnackBarType { info, success, warning, error }

/// Data model for a single toast
class _ToastData {
  final String id;
  final String message;
  final SnackBarType type;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  _ToastData({
    required this.id,
    required this.message,
    required this.type,
    required this.duration,
    this.actionLabel,
    this.onActionPressed,
  });
}

/// Manager for active toasts
class _ToastManager extends ChangeNotifier {
  static final _ToastManager instance = _ToastManager();
  
  final List<_ToastData> _toasts = [];
  List<_ToastData> get toasts => List.unmodifiable(_toasts);
  
  // Maximum number of toasts visible in the stack
  static const int maxVisible = 3;

  void addToast(_ToastData toast) {
    // Add to beginning of list (top of stack conceptually, but rendered differently)
    // We insert at 0 so the "newest" is index 0
    _toasts.insert(0, toast);
    notifyListeners();
    
    // Auto dismiss
    Future.delayed(toast.duration, () {
      removeToast(toast.id);
    });
  }

  void removeToast(String id) {
    _toasts.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}

/// Widget that displays the stack of active toasts
class _ToastStackWidget extends ConsumerStatefulWidget {
  const _ToastStackWidget();

  @override
  ConsumerState<_ToastStackWidget> createState() => _ToastStackWidgetState();
}

class _ToastStackWidgetState extends ConsumerState<_ToastStackWidget> {
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _ToastManager.instance.addListener(_onMeasureChanged);
  }

  @override
  void dispose() {
    _ToastManager.instance.removeListener(_onMeasureChanged);
    super.dispose();
  }

  void _onMeasureChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final toasts = _ToastManager.instance.toasts;
    // If no toasts, return SizedBox (OverlayEntry still exists but is invisible)
    // Logic could be improved to remove OverlayEntry but keeping it simple for now.
    if (toasts.isEmpty) return const SizedBox.shrink();

    // We only render the top N toasts to avoid performance issues
    final visibleToasts = toasts.take(_ToastManager.maxVisible + 1).toList().asMap().entries.toList().reversed.toList();
    
    // Calculate dynamic height for the container based on hovering
    // Collapsed: ~150px
    // Expanded: Estimate based on content. Since height is dynamic, we give it plenty of room.
    final double itemsHeight = _isHovering ? ((visibleToasts.length * 120.0) + 50) : 150;

    return Positioned(
      top: 24,
      right: 24,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 360,
          height: itemsHeight,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: visibleToasts.map((entry) {
              final index = entry.key; // 0 is newest
              final toast = entry.value;
              
              return _ToastItemWidget(
                key: ValueKey(toast.id),
                toast: toast,
                index: index,
                isHovering: _isHovering,
                isDarkMode: true, 
                onDismiss: () => _ToastManager.instance.removeToast(toast.id),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Individual Toast Card with animation based on index
class _ToastItemWidget extends StatefulWidget {
  final _ToastData toast;
  final int index; // 0 = front, 1 = behind, etc.
  final bool isHovering;
  final bool isDarkMode;
  final VoidCallback onDismiss;

  const _ToastItemWidget({
    super.key,
    required this.toast,
    required this.index,
    required this.isHovering,
    required this.isDarkMode,
    required this.onDismiss,
  });

  @override
  State<_ToastItemWidget> createState() => _ToastItemWidgetState();
}

class _ToastItemWidgetState extends State<_ToastItemWidget> {
  // Using implicit animations via AnimatedPositioned/AnimatedScale

  @override
  Widget build(BuildContext context) {
    // If index > maxVisible, hide it (opacity 0)
    final isVisible = widget.index < _ToastManager.maxVisible;
    
    // Layout Logic
    // Expanded: Vertical list with gaps. Taking ~120px per item to fit potential 10 lines of text + padding
    // Collapsed: Stacked with larger offset for better visibility
    
    // Base spacing for expanded items (Height + Margin) - reduced for tighter list
    const double expandedSpacing = 80.0;
    // Spacing for collapsed stack effect
    const double collapsedSpacing = 10.0;
    
    final double topOffset = widget.isHovering
        ? widget.index * expandedSpacing
        : widget.index * collapsedSpacing;
        
    final double scale = widget.isHovering 
        ? 1.0 
        : (1.0 - (widget.index * 0.05));
        
    final double opacity = (isVisible || widget.isHovering) 
        ? (widget.isHovering ? 1.0 : (1.0 - (widget.index * 0.1)).clamp(0.0, 1.0))
        : 0.0;
    
    // Use Global Colors
    // Filled Style: Text is always white on colored background
    // Style based on the uploaded image (Clean White Card)
    // Background: White
    // Border: Subtle Light Grey
    // Text/Icon: Colored based on type (as per previous request)
    
    Color borderColor =  resolveThemeColor(context, dark: MyntColors.overlayBgDark, light: const Color(0xFFE4E4E7)); // Subtle grey border
    Color bgColor = resolveThemeColor(context, dark: MyntColors.overlayBgDark, light: MyntColors.dialog);
    Color contentColor = resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    Color subTextColor = Colors.grey[600]!;
    Color statusColor;
    IconData statusIcon;
    
    switch (widget.toast.type) {
      case SnackBarType.success:
        statusColor = ToastGlobals.success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case SnackBarType.error:
        statusColor = ToastGlobals.error;
        statusIcon = Icons.cancel_rounded;
        break;
      case SnackBarType.warning:
        statusColor = ToastGlobals.warning;
        statusIcon = Icons.warning_rounded;
        break;
      case SnackBarType.info:
        statusColor = resolveThemeColor(context, dark: MyntColors.textWhite, light: MyntColors.textPrimary); // Info is typically neutral
        statusIcon = Icons.info_rounded;
        break;
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      top: topOffset,
      left: 0,
      right: 0,
      // Removed fixed height to allow text expansion
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 300),
          child: Dismissible(
            key: ValueKey(widget.toast.id),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => widget.onDismiss(),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: borderColor, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        // Colored left border strip
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(11),
                              bottomLeft: Radius.circular(11),
                            ),
                          ),
                        ),
                        // Main content
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Status Icon
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      statusIcon,
                                      color: statusColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Content
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Title (Type)
                                        Text(
                                          _getTypeLabel(widget.toast.type),
                                          style: MyntWebTextStyles.body(
                                            context,
                                            color: statusColor,
                                            fontWeight: MyntFonts.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Message
                                        Text(
                                          widget.toast.message,
                                          style: MyntWebTextStyles.bodySmall(
                                            context,
                                            color: contentColor,
                                            fontWeight: MyntFonts.medium,
                                          ),
                                          maxLines: 10,
                                          overflow: TextOverflow.visible,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Action Button or Close
                                  if (widget.toast.actionLabel != null)
                                    SizedBox(
                                      height: 32,
                                      child: ElevatedButton(
                                        onPressed: widget.toast.onActionPressed ?? widget.onDismiss,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        child: Text(
                                          widget.toast.actionLabel!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: InkWell(
                                        onTap: widget.onDismiss,
                                        child: Icon(Icons.close, size: 18, color: contentColor.withValues(alpha: 0.5)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  String _getTypeLabel(SnackBarType type) {
    // If user specifically wants "Event has been created" as title, they need to pass it differently.
    // Assuming they use message for subtitle and type for title, or message is title?
    // Current API: show(message: "...")
    // The previous prompt code snippet had: title: Text('Event has been created'), subtitle: Text(...)
    // Just using mapped labels for now.
    
    switch (type) {
      case SnackBarType.success:
        return 'Success';
      case SnackBarType.error:
        return 'Error';
      case SnackBarType.warning:
        return 'Warning';
      case SnackBarType.info:
        return 'Info';
    }
  }
}

/// Simple color scheme class for SnackBar theming
class _ColorScheme {
  final Color surface;
  final Color onSurface;
  final Color primary;
  
  const _ColorScheme({
    required this.surface,
    required this.onSurface,
    required this.primary,
  });
}

/// Global Toast Colors configuration
/// Change these values to update the toast styling across the app
class ToastGlobals {
  // Status Colors (Icon, Title, Border)
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Colors.black;

// Base Background (Unused in Filled style, but kept for reference)
  static const Color baseBackground = Color(0xFF161616);
  static const double tintStrength = 0.15;
  
  // Message Text
  static const Color subText = Color(0xFFA1A1AA);

  // Background Getters (For Filled style, returns solid colors)
  static Color get successBg => success;
  static Color get errorBg => error;
  static Color get warningBg => warning;
  static Color get infoBg => info;
}

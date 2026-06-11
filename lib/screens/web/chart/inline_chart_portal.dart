import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/user_profile_provider.dart';
import 'package:mynt_plus/screens/web/chart/web_chart_manager.dart';

/// Persistent chart portal widget that renders at root level.
///
/// This widget is placed in the home screen's Stack and uses
/// [CompositedTransformFollower] to position itself over the chart area
/// defined by [ChartWithDepthWeb]'s [CompositedTransformTarget].
///
/// The key benefit is that the [HtmlElementView] never leaves the widget tree,
/// so the TradingView iframe is never destroyed, enabling instant chart display
/// when navigating back to stock screens.
class InlineChartPortal extends ConsumerStatefulWidget {
  const InlineChartPortal({super.key});

  @override
  ConsumerState<InlineChartPortal> createState() => _InlineChartPortalState();
}

class _InlineChartPortalState extends ConsumerState<InlineChartPortal> {
  @override
  void initState() {
    super.initState();
    // Initialize chart manager on startup - registers iframe factory
    webChartManager.initialize();
  }

  // Persistent LayerLink - used when the target's link is not available
  final LayerLink _fallbackLayerLink = LayerLink();

  // Store the last known size to use when hidden
  Size _lastKnownSize = const Size(800, 600);

  @override
  Widget build(BuildContext context) {
    // Watch inline chart state from provider
    final showInline = ref.watch(
        userProfileProvider.select((p) => p.showInlineChart));
    final layerLink = ref.watch(
        userProfileProvider.select((p) => p.inlineChartLayerLink));
    final size = ref.watch(
        userProfileProvider.select((p) => p.inlineChartSize));

    // IMPORTANT: Always keep HtmlElementView in the widget tree to preserve the iframe.
    // The widget tree structure MUST stay the same to prevent Flutter from unmounting.
    // When hidden, we position off-screen; when visible, follower positions over target.

    final isVisible = showInline && layerLink != null && size != null;

    // Update last known size when we have valid size
    if (size != null) {
      _lastKnownSize = size;
    }

    // Use current size when visible, last known size when hidden
    final chartWidth = isVisible ? size!.width : _lastKnownSize.width;
    final chartHeight = isVisible ? size!.height : _lastKnownSize.height;

    // debugPrint('InlineChartPortal: visible=$isVisible, size=${chartWidth}x$chartHeight');

    // CRITICAL: Keep the SAME widget tree structure regardless of visibility.
    // Only change: position (off-screen vs 0,0) and which layerLink to use.
    // This ensures HtmlElementView is never unmounted.
    return Positioned(
      // When visible: position at 0,0 so follower can offset from there
      // When hidden: position off-screen to hide but keep in tree
      left: isVisible ? 0 : -9999,
      top: isVisible ? 0 : -9999,
      child: CompositedTransformFollower(
        // When visible: use the real layerLink connected to target
        // When hidden: use fallback link (not connected, showWhenUnlinked=false hides it)
        link: isVisible ? layerLink : _fallbackLayerLink,
        showWhenUnlinked: false,
        child: SizedBox(
          width: chartWidth,
          height: chartHeight,
          child: HtmlElementView(
            key: const ValueKey(WebChartManager.viewType),
            viewType: WebChartManager.viewType,
          ),
        ),
      ),
    );
  }
}

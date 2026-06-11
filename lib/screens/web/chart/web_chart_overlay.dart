import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/user_profile_provider.dart';
import 'package:mynt_plus/res/web_colors.dart';

import 'web_chart_manager.dart';

/// The chart overlay widget that renders the persistent iframe.
/// Place this ONCE in your app's main layout Stack.
class WebChartOverlay extends ConsumerStatefulWidget {
  const WebChartOverlay({super.key});

  @override
  ConsumerState<WebChartOverlay> createState() => _WebChartOverlayState();
}

class _WebChartOverlayState extends ConsumerState<WebChartOverlay> {
  @override
  void initState() {
    super.initState();
    // Initialize the chart manager (registers iframe)
    webChartManager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    // Use existing showchartof state from userProfileProvider
    final isVisible = ref.watch(
        userProfileProvider.select((profile) => profile.showchartof));
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned(
      // When hidden, position off-screen (below the viewport)
      bottom: isVisible ? 0 : -(screenHeight + 100),
      left: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: screenHeight,
        width: screenWidth,
        decoration: BoxDecoration(
          color: theme.isDarkMode ? WebDarkColors.surface : WebColors.surface,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Close button header
              _buildHeader(theme),
              // Chart iframe
              Expanded(
                child: HtmlElementView(
                  key: const ValueKey(WebChartManager.viewType),
                  viewType: WebChartManager.viewType,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemesProvider theme) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.isDarkMode ? WebDarkColors.surface : WebColors.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Chart',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: theme.isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: () {
              // Use existing provider method to hide chart
              ref.read(userProfileProvider).setChartdialog(false);
            },
          ),
        ],
      ),
    );
  }
}

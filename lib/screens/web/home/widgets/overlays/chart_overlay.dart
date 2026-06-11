import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/user_profile_provider.dart';
import 'package:mynt_plus/res/web_colors.dart';
import 'package:mynt_plus/screens/web/chart/web_chart_manager.dart';

/// Chart overlay that renders the persistent TradingView iframe.
///
/// Symbol changes are handled by [WebChartManager] via [setChartScript] in
/// MarketWatchProvider. This widget only manages visibility and rendering.
class ChartOverlay extends ConsumerStatefulWidget {
  const ChartOverlay({super.key});

  @override
  ConsumerState<ChartOverlay> createState() => _ChartOverlayState();
}

class _ChartOverlayState extends ConsumerState<ChartOverlay> {
  @override
  void initState() {
    super.initState();
    // Initialize the chart manager (registers iframe factory if not already)
    webChartManager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final showChart = ref.watch(
        userProfileProvider.select((userProfile) => userProfile.showchartof));
    final webViewKey = ref.watch(
        userProfileProvider.select((userProfile) => userProfile.webViewKey));
    final theme = ref.watch(themeProvider);

    // Note: Symbol changes are handled by setChartScript() in MarketWatchProvider
    // which calls webChartManager.changeSymbol() directly with the correct params.
    // This widget only renders the iframe - it does NOT manage symbol changes.

    return Positioned(
      key: webViewKey,
      bottom: showChart ? 0 : -(MediaQuery.of(context).size.height + 100),
      left: 0,
      child: AnimatedContainer(
        alignment: Alignment.center,
        duration: const Duration(milliseconds: 100),
        curve: Curves.fastLinearToSlowEaseIn,
        decoration: BoxDecoration(
          color: theme.isDarkMode ? WebDarkColors.surface : WebColors.surface,
        ),
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Header with close button
              _buildHeader(context, theme),
              // Chart iframe - use the shared WebChartManager
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

  Widget _buildHeader(BuildContext context, ThemesProvider theme) {
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
              ref.read(userProfileProvider).setChartdialog(false);
            },
          ),
        ],
      ),
    );
  }
}

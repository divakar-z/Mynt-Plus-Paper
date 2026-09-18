import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/marketwatch_model/opt_chain_model.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../scalper_chart_manager.dart';
import '../scalper_provider.dart';

/// Chart panel for displaying Call or Put option with strike selector
/// Clicking strike selector opens option chain overlay
class ScalperOptionChartPanel extends ConsumerStatefulWidget {
  final bool isCall;
  final OptionValues? option;
  final String selectedStrike;
  final VoidCallback onStrikeTap;

  const ScalperOptionChartPanel({
    super.key,
    required this.isCall,
    required this.option,
    required this.selectedStrike,
    required this.onStrikeTap,
  });

  @override
  ConsumerState<ScalperOptionChartPanel> createState() =>
      _ScalperOptionChartPanelState();
}

class _ScalperOptionChartPanelState
    extends ConsumerState<ScalperOptionChartPanel> {
  static const String _callViewType = 'scalper-call-chart';
  static const String _putViewType = 'scalper-put-chart';

  String get _viewType => widget.isCall ? _callViewType : _putViewType;
  String get _chartType => widget.isCall ? 'call' : 'put';

  /// Token the chart is currently displaying — prevents pushing wrong ticks
  /// during symbol transitions.
  String? _chartToken;

  @override
  Widget build(BuildContext context) {
    final scalper = ref.watch(scalperProvider);
    final option = widget.option;

    // Get real-time data from WebSocket
    // Use direct watch (not select) to ensure initial data triggers rebuild
    final socketData = option?.token != null
        ? ref.watch(websocketProvider).socketDatas[option!.token]
        : null;

    // Push live tick data to TradingView chart for real-time candle updates.
    // Only push when the chart is actually displaying this token.
    if (option?.token != null && _chartToken == option?.token &&
        socketData != null && socketData['lp'] != null) {
      final tickData = Map<String, dynamic>.from(socketData);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scalperChartManager.pushTick(chartId: _chartType, tickData: tickData);
      });
    }

    // Parse LTP and change
    final ltp = socketData?['lp']?.toString() ?? option?.lp ?? '0.00';
    final change = socketData?['chng']?.toString() ?? '0.00';
    final perChange = socketData?['pc']?.toString() ?? '0.00';

    final isPositive =
        !change.startsWith('-') && change != '0.00' && change != '0';
    final changeColor = isPositive
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: resolveThemeColor(
          context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor,
        ),
        border: Border.all(
          color: resolveThemeColor(
            context,
            dark: MyntColors.dividerDark,
            light: MyntColors.divider,
          ),
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Column(
          children: [
            // Header with consistent height
            _buildHeader(context, scalper, ltp, change, perChange, changeColor),
            // Chart
            Expanded(
              child: _buildChart(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ScalperProvider scalper,
    String ltp,
    String change,
    String perChange,
    Color changeColor,
  ) {
    final option = widget.option;
    // Prefer the backend display name (DerivativeMaster) for the contract title.
    final tsym = DerivativeMaster.nameFor(option?.exch, option?.token) ??
        (option?.tsym ?? '');
    final isExpanded = scalper.expandedChart == _chartType;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: resolveThemeColor(
          context,
          dark: MyntColors.listItemBgDark,
          light: MyntColors.listItemBg,
        ),
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(
              context,
              dark: MyntColors.dividerDark,
              light: MyntColors.divider,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          // Left column: Symbol name + LTP/Change
          Expanded(
            child: Row(
              children: [
                // Symbol name
                Flexible(
                  child: Text(
                    tsym.isNotEmpty ? tsym : '${scalper.selectedIndex.name}...',
                    style: MyntWebTextStyles.symbol(
                      context,
                      fontWeight: MyntFonts.medium,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                // LTP
                Text(
                  ltp,
                  style: MyntWebTextStyles.price(
                    context,
                    // fontWeight: MyntFonts.bold,
                    color: changeColor,
                  ),
                ),
                const SizedBox(width: 8),
                // Change
                Text(
                  '$change ($perChange%)',
                  style: MyntWebTextStyles.exch(
                    context,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Right column: CE/PE badge + Strike button + Expand icon
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // CE/PE badge (derived from actual option type)
              Builder(builder: (context) {
                final optType = option?.optt ?? (widget.isCall ? 'CE' : 'PE');
                final isCE = optType == 'CE';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCE
                        ? resolveThemeColor(context,
                            dark: MyntColors.secondary, light: MyntColors.primary)
                        : resolveThemeColor(context,
                            dark: MyntColors.errorDark, light: MyntColors.tertiary),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    optType,
                    style: MyntWebTextStyles.caption(
                      context,
                      fontWeight: MyntFonts.medium,
                      color: Colors.white,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              // Strike selector button
              GestureDetector(
                onTap: widget.onStrikeTap,
                child: Container(
                  width: 120,
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.transparent,
                      light: const Color(0xffF1F3F8),
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.primary,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.selectedStrike.isNotEmpty ? widget.selectedStrike : '--',
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            darkColor: MyntColors.textWhite,
                            lightColor: MyntColors.textBlack,
                            fontWeight: MyntFonts.medium,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_right,
                        size: 18,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Expand/Collapse icon
              InkWell(
                onTap: () => ref.read(scalperProvider).toggleChartExpansion(_chartType),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isExpanded ? Icons.close_fullscreen : Icons.open_in_full,
                    size: 16,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final option = widget.option;
    final isDark = isDarkMode(context);
    final hasOption = option != null && option.token != null;

    // Update the chart symbol when option changes
    if (hasOption) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.isCall) {
            scalperChartManager.changeCallSymbol(
              exch: option.exch ?? 'NFO',
              token: option.token ?? '',
              tsym: option.tsym ?? '',
              isDarkMode: isDark,
            );
          } else {
            scalperChartManager.changePutSymbol(
              exch: option.exch ?? 'NFO',
              token: option.token ?? '',
              tsym: option.tsym ?? '',
              isDarkMode: isDark,
            );
          }
          _chartToken = option.token;
      });
    }

    // Always render the chart iframe - use Stack to overlay loading message
    return Stack(
      children: [
        // Always render the HtmlElementView so iframe is created
        ClipRect(
          child: HtmlElementView(
            key: ValueKey(_viewType),
            viewType: _viewType,
          ),
        ),
        // Overlay message when no option selected
        if (!hasOption)
          Positioned.fill(
            child: Container(
              color: resolveThemeColor(
                context,
                dark: MyntColors.backgroundColorDark,
                light: MyntColors.backgroundColor,
              ),
              child: Center(
                child: Text(
                  'Loading chart...',
                  style: MyntWebTextStyles.body(
                    context,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

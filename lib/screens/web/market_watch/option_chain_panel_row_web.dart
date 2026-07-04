// Option chain row widget for the watchlist sidebar panel.
// Contains [Call Cell | Strike Price | Put Cell] with Buy/Sell/Depth hover actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/marketwatch_model/opt_chain_model.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../models/order_book_model/order_book_model.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/res.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/hover_actions_web.dart';
import '../../../utils/responsive_navigation.dart';
import '../../../utils/responsive_snackbar.dart';
import 'options/option_chain_row_web.dart' show StrikeRowData;

/// Option chain row for the watchlist sidebar panel.
class OCPanelRow extends ConsumerStatefulWidget {
  final StrikeRowData rowData;
  final int index;
  final GlobalKey? atmKey;

  const OCPanelRow({
    super.key,
    required this.rowData,
    required this.index,
    this.atmKey,
  });

  @override
  ConsumerState<OCPanelRow> createState() => _OCPanelRowState();
}

class _OCPanelRowState extends ConsumerState<OCPanelRow> {
  final _isCallHovered = ValueNotifier<bool>(false);
  final _isPutHovered = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isCallHovered.dispose();
    _isPutHovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callSocketData = widget.rowData.callOption != null
        ? ref.watch(websocketProvider
            .select((p) => p.socketDatas[widget.rowData.callOption!.token]))
        : null;
    final putSocketData = widget.rowData.putOption != null
        ? ref.watch(websocketProvider
            .select((p) => p.socketDatas[widget.rowData.putOption!.token]))
        : null;

    return RepaintBoundary(
      key: widget.atmKey,
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: _buildCallCell(callSocketData),
          ),
          _buildStrikeCell(),
          Expanded(
            flex: 6,
            child: _buildPutCell(putSocketData),
          ),
        ],
      ),
    );
  }

  // ─── Call Cell ───────────────────────────────────────────────

  Widget _buildCallCell(Map<String, dynamic>? socketData) {
    final option = widget.rowData.callOption;
    if (option == null) return const SizedBox.shrink();

    final lp =
        socketData?['lp']?.toString() ?? option.lp ?? option.close ?? "0.00";
    final perChange =
        socketData?['pc']?.toString() ?? option.perChange ?? "0.00";
    final currentOI =
        double.tryParse(socketData?['oi']?.toString() ?? option.oi ?? "0") ??
            0.0;
    final oiLack = (currentOI / 100000).toStringAsFixed(2);

    final poi = double.tryParse(
            socketData?['poi']?.toString() ?? option.poi ?? "0") ??
        0.0;
    String oiPerChng = "0.00";
    if (poi > 0) {
      oiPerChng = (((currentOI - poi) / poi) * 100).toStringAsFixed(2);
    }

    final changeColor = _getChangeColor(context, perChange);

    // Watch (not read) so the bookmark icon updates the moment this option is
    // added to / removed from the current watchlist.
    final isInWatchlist = ref.watch(marketWatchProvider.select((p) => p.scrips
        .any((s) =>
            "${s['exch']}|${s['token']}" == "${option.exch}|${option.token}")));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _isCallHovered.value = true,
      onExit: (_) => _isCallHovered.value = false,
      child: GestureDetector(
        onTap: () => _openDepth(option),
        child: ValueListenableBuilder<bool>(
          valueListenable: _isCallHovered,
          builder: (context, isHovered, _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              color: isHovered
                  ? resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary)
                      .withValues(alpha: 0.10)
                  : Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildOIColumn(context, oiLack, oiPerChng),
                      ),
                      Expanded(
                        child: _buildLTPColumn(context, lp, perChange, changeColor),
                      ),
                    ],
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: HoverActionsContainer(
                    isVisible: isHovered,
                    actions: [
                      HoverActionButton.buy(
                        context: context,
                        onPressed: () => _placeOrder(option, true),
                      ),
                      HoverActionButton.sell(
                        context: context,
                        onPressed: () => _placeOrder(option, false),
                      ),
                      // Depth button hidden — Chart covers the chart view
                      // HoverActionButton(
                      //   iconAsset: assets.depthIcon,
                      //   color: resolveThemeColor(context,
                      //       dark: MyntColors.textPrimary,
                      //       light: Colors.black),
                      //   backgroundColor: Colors.transparent,
                      //   onPressed: () => _openDepth(option),
                      // ),
                      HoverActionButton.icon(
                        context: context,
                        iconAsset: assets.chartnew,
                        onPressed: () => _handleChartTap(option),
                      ),
                      HoverActionButton.icon(
                        context: context,
                        iconAsset: isInWatchlist
                            ? assets.bookmarkIcon
                            : assets.bookmarkLineIcon,
                        iconColor: isInWatchlist
                            ? resolveThemeColor(context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary)
                            : null,
                        onPressed: () => _handleSaveToWatchlist(option),
                      ),
                    ],
                  )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Strike Cell ────────────────────────────────────────────

  Widget _buildStrikeCell() {
    return SizedBox(
      width: 80,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.symmetric(
            vertical: BorderSide(
              color: resolveThemeColor(context,
                  dark: MyntColors.dividerDark, light: MyntColors.divider),
              width: 0.5,
            ),
          ),
        ),
        child: Text(
          widget.rowData.strikePrice,
          style: MyntWebTextStyles.para(
            context,
            fontWeight: FontWeight.w500,
            color: resolveThemeColor(context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary),
          ),
        ),
      ),
    );
  }

  // ─── Put Cell ───────────────────────────────────────────────

  Widget _buildPutCell(Map<String, dynamic>? socketData) {
    final option = widget.rowData.putOption;
    if (option == null) return const SizedBox.shrink();

    final lp =
        socketData?['lp']?.toString() ?? option.lp ?? option.close ?? "0.00";
    final perChange =
        socketData?['pc']?.toString() ?? option.perChange ?? "0.00";
    final currentOI =
        double.tryParse(socketData?['oi']?.toString() ?? option.oi ?? "0") ??
            0.0;
    final oiLack = (currentOI / 100000).toStringAsFixed(2);

    final poi = double.tryParse(
            socketData?['poi']?.toString() ?? option.poi ?? "0") ??
        0.0;
    String oiPerChng = "0.00";
    if (poi > 0) {
      oiPerChng = (((currentOI - poi) / poi) * 100).toStringAsFixed(2);
    }

    final changeColor = _getChangeColor(context, perChange);

    // Watch (not read) so the bookmark icon updates the moment this option is
    // added to / removed from the current watchlist.
    final isInWatchlist = ref.watch(marketWatchProvider.select((p) => p.scrips
        .any((s) =>
            "${s['exch']}|${s['token']}" == "${option.exch}|${option.token}")));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _isPutHovered.value = true,
      onExit: (_) => _isPutHovered.value = false,
      child: GestureDetector(
        onTap: () => _openDepth(option),
        child: ValueListenableBuilder<bool>(
          valueListenable: _isPutHovered,
          builder: (context, isHovered, _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              color: isHovered
                  ? resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary)
                      .withValues(alpha: 0.15)
                  : Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildLTPColumn(context, lp, perChange, changeColor),
                      ),
                      Expanded(
                        child: _buildOIColumn(context, oiLack, oiPerChng),
                      ),
                    ],
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: HoverActionsContainer(
                    isVisible: isHovered,
                    actions: [
                      HoverActionButton.buy(
                        context: context,
                        onPressed: () => _placeOrder(option, true),
                      ),
                      HoverActionButton.sell(
                        context: context,
                        onPressed: () => _placeOrder(option, false),
                      ),
                      // Depth button hidden — Chart covers the chart view
                      // HoverActionButton(
                      //   iconAsset: assets.depthIcon,
                      //   color: resolveThemeColor(context,
                      //       dark: MyntColors.textPrimary,
                      //       light: Colors.black),
                      //   backgroundColor: Colors.transparent,
                      //   onPressed: () => _openDepth(option),
                      // ),
                      HoverActionButton.icon(
                        context: context,
                        iconAsset: assets.chartnew,
                        onPressed: () => _handleChartTap(option),
                      ),
                      HoverActionButton.icon(
                        context: context,
                        iconAsset: isInWatchlist
                            ? assets.bookmarkIcon
                            : assets.bookmarkLineIcon,
                        iconColor: isInWatchlist
                            ? resolveThemeColor(context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary)
                            : null,
                        onPressed: () => _handleSaveToWatchlist(option),
                      ),
                    ],
                  )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Shared Sub-widgets ─────────────────────────────────────

  Widget _buildOIColumn(BuildContext context, String oiLack, String oiPerChng) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          oiLack,
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.para(
            context,
            fontWeight: FontWeight.w500,
            color: (oiLack == "0.00" || oiLack == "0.0")
                ? resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary)
                : resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "(${oiPerChng == "NaN" ? "0.00" : oiPerChng}%)",
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.caption(
            context,
            fontWeight: FontWeight.w400,
            color: _getChangeColor(context, oiPerChng),
          ),
        ),
      ],
    );
  }

  Widget _buildLTPColumn(
      BuildContext context, String lp, String perChange, Color changeColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          lp,
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.para(
            context,
            fontWeight: FontWeight.w500,
            color: (lp == "0.00" || lp == "0.0")
                ? resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary)
                : resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
          ),
        ),
        Text(
          "($perChange%)",
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.caption(
            context,
            fontWeight: FontWeight.w400,
            color: changeColor,
          ),
        ),
      ],
    );
  }

  Color _getChangeColor(BuildContext context, String value) {
    if (value.startsWith("-")) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    }
    if (value == "0.00" || value == "0.0") {
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    }
    return resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
  }

  // ─── Actions ────────────────────────────────────────────────

  Future<void> _placeOrder(OptionValues option, bool isBuy) async {
    final scripData = ref.read(marketWatchProvider);

    await scripData.fetchScripInfo(
      option.token.toString(),
      option.exch.toString(),
      context,
      true,
    );

    final lotSize = option.ls?.isNotEmpty == true
        ? option.ls
        : scripData.scripInfoModel?.ls.toString();

    OrderScreenArgs orderArgs = OrderScreenArgs(
      exchange: option.exch.toString(),
      tSym: option.tsym.toString(),
      isExit: false,
      token: option.token.toString(),
      transType: isBuy,
      lotSize: lotSize,
      ltp: "${option.lp ?? option.close ?? 0.00}",
      perChange: option.perChange ?? "0.00",
      orderTpye: '',
      holdQty: '',
      isModify: false,
      raw: {},
    );

    ResponsiveNavigation.toPlaceOrderScreen(
      context: context,
      arguments: {
        "orderArg": orderArgs,
        "scripInfo": scripData.scripInfoModel!,
        "isBskt": "",
      },
    );
  }

  Future<void> _openDepth(OptionValues option) async {
    final marketWatch = ref.read(marketWatchProvider);

    DepthInputArgs depthArgs = DepthInputArgs(
      exch: option.exch.toString(),
      token: option.token.toString(),
      tsym: option.tsym.toString(),
      instname: option.symbol ?? option.tsym.toString(),
      symbol: option.symbol ?? '',
      expDate: option.expDate ?? '',
      option: option.optt ?? '',
    );

    marketWatch.scripdepthsize(false);
    await marketWatch.calldepthApis(context, depthArgs, "");

    await ref.read(marketWatchProvider).setIsDepthVisibleWeb(
          true,
          context: context,
          exch: depthArgs.exch,
          token: depthArgs.token,
          tsym: depthArgs.tsym,
        );
  }

  /// Open this option's chart — reuses the web panel/chart mechanism the
  /// Depth action uses, but without forcing the depth view.
  Future<void> _handleChartTap(OptionValues option) async {
    final marketWatch = ref.read(marketWatchProvider);

    final depthArgs = DepthInputArgs(
      exch: option.exch.toString(),
      token: option.token.toString(),
      tsym: option.tsym.toString(),
      instname: option.symbol ?? option.tsym.toString(),
      symbol: option.symbol ?? '',
      expDate: option.expDate ?? '',
      option: option.optt ?? '',
    );

    marketWatch.scripdepthsize(false);
    marketWatch.openOnChartTab = true;
    await marketWatch.calldepthApis(context, depthArgs, "");
  }

  /// Add / remove this option to the currently-selected watchlist.
  Future<void> _handleSaveToWatchlist(OptionValues option) async {
    final scripData = ref.read(marketWatchProvider);

    if (scripData.isPreDefWLs == "Yes") {
      ResponsiveSnackBar.showWarning(
          context, "This is a pre-defined watchlist that cannot be edited!");
      return;
    }

    final scripToken = "${option.exch}|${option.token}";
    final isCurrentlyInWatchlist = scripData.scrips
        .any((scrip) => "${scrip['exch']}|${scrip['token']}" == scripToken);

    if (isCurrentlyInWatchlist) {
      final success = await scripData.addDelMarketScrip(
          scripData.wlName, scripToken, context, false, true, false, false);
      if (success && mounted) {
        ResponsiveSnackBar.showSuccess(context, 'Removed from your watchlist "${scripData.wlName}"');
      }
    } else {
      ref.read(websocketProvider).establishConnection(
            channelInput: scripToken,
            task: "d",
            context: context,
          );
      final success = await scripData.addDelMarketScrip(
          scripData.wlName, scripToken, context, true, true, false, false);
      if (success && mounted) {
        ResponsiveSnackBar.showSuccess(context, 'Added to your watchlist "${scripData.wlName}"');
      }
    }
  }
}

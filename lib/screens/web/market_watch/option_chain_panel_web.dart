// Collapsible Option Chain panel for the watchlist sidebar.
// Collapsed: thin bar at bottom. Expanded: full option chain with symbol/expiry dropdowns.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../../models/marketwatch_model/search_scrip_model.dart';
import '../../../provider/watchlist_oc_provider.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/mynt_loader.dart';
import 'option_chain_panel_row_web.dart';
import 'options/option_chain_row_web.dart' show StrikeRowData;
import 'tv_chart/chart_iframe_guard.dart';

class OptionChainPanelWeb extends ConsumerStatefulWidget {
  const OptionChainPanelWeb({super.key});

  @override
  ConsumerState<OptionChainPanelWeb> createState() =>
      _OptionChainPanelWebState();
}

class _OptionChainPanelWebState extends ConsumerState<OptionChainPanelWeb> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _strikePriceKey = GlobalKey();

  // Search overlay
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _searchFieldKey = GlobalKey();
  OverlayEntry? _searchOverlay;

  // Expiry overlay
  final GlobalKey _expiryButtonKey = GlobalKey();
  OverlayEntry? _expiryOverlay;

  bool _hasScrolledToATM = false;

  /// Keeps the search overlay in sync with provider changes
  /// (e.g. when fetchAvailableSymbols completes and isLoadingSymbols flips).
  VoidCallback? _providerListener;

  /// Saved reference so we can safely removeListener in dispose()
  /// without calling ref.read() on an unmounted widget.
  late final _watchlistOC = ref.read(watchlistOCProvider);

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChange);

    _providerListener = () {
      _searchOverlay?.markNeedsBuild();
    };
    _watchlistOC.addListener(_providerListener!);
  }

  @override
  void dispose() {
    if (_providerListener != null) {
      _watchlistOC.removeListener(_providerListener!);
    }
    _removeSearchOverlay();
    _removeExpiryOverlay();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded =
        ref.watch(watchlistOCProvider.select((p) => p.isExpanded));

    if (!isExpanded) {
      return _buildCollapsedBar();
    }

    return _buildExpandedPanel();
  }

  // ─── Collapsed Bar ──────────────────────────────────────────

  Widget _buildCollapsedBar() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            ref.read(watchlistOCProvider).toggleExpanded(context),
        child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          border: Border(
            top: BorderSide(
              color: resolveThemeColor(context,
                  dark: MyntColors.dividerDark, light: MyntColors.divider),
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Text(
              'Option Chain',
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.medium,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 20,
              color: resolveThemeColor(context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
      ),
    );
  }

  // ─── Expanded Panel ─────────────────────────────────────────

  Widget _buildExpandedPanel() {
    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      child: Column(
        children: [
          _buildHeader(),
          _buildColumnHeaders(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  // ─── Header: Symbol dropdown + Expiry dropdown + Collapse ───

  Widget _buildHeader() {
    final ocProv = ref.watch(watchlistOCProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
          ),
        ),
      ),
      child: Row(
        children: [
          // Symbol search dropdown
          Expanded(child: _buildSymbolDropdown(ocProv)),
          const SizedBox(width: 8),
          // Expiry dropdown
          _buildExpiryDropdown(ocProv),
          const SizedBox(width: 8),
          // Collapse button
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () =>
                  ref.read(watchlistOCProvider).collapse(context),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Symbol Search Dropdown ──────────────────────────────────

  Widget _buildSymbolDropdown(WatchlistOCProvider ocProv) {
    return Container(
      key: _searchFieldKey,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.searchBgDark, light: MyntColors.searchBg),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: resolveThemeColor(context,
              dark: MyntColors.dividerDark, light: MyntColors.divider),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 14,
            color: resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (_) => _updateSearchOverlay(),
              decoration: InputDecoration(
                hintText: ocProv.selectedSymbol.name,
                hintStyle: MyntWebTextStyles.para(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                  fontWeight: MyntFonts.medium,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: MyntWebTextStyles.bodySmall(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _updateSearchOverlay();
              },
              child: Icon(
                Icons.close,
                size: 14,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Search Overlay Logic ───────────────────────────────────

  void _onSearchFocusChange() {
    if (_searchFocusNode.hasFocus) {
      // Fetch symbols on first focus
      ref.read(watchlistOCProvider).fetchAvailableSymbols();
      _showSearchOverlay();
    }
  }

  void _showSearchOverlay() {
    _removeSearchOverlay();

    final renderBox =
        _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    ChartIframeGuard.acquire();

    _searchOverlay = OverlayEntry(
      builder: (_) => _buildSearchOverlayContent(position, size),
    );
    Overlay.of(context).insert(_searchOverlay!);
  }

  void _updateSearchOverlay() {
    _searchOverlay?.markNeedsBuild();
    setState(() {});
  }

  void _removeSearchOverlay() {
    if (_searchOverlay != null) {
      _searchOverlay!.remove();
      _searchOverlay = null;
      ChartIframeGuard.release();
    }
  }

  Widget _buildSearchOverlayContent(Offset position, Size size) {
    final ocProv = ref.watch(watchlistOCProvider);
    final allSymbols = ocProv.availableSymbols;
    final query = _searchController.text.trim().toUpperCase();

    final filtered = query.isEmpty
        ? allSymbols
        : allSymbols.where((s) {
            final tsym = (s.tsym ?? '').toUpperCase();
            final cname = (s.cname ?? '').toUpperCase();
            return tsym.contains(query) || cname.contains(query);
          }).toList();

    final bgColor = resolveThemeColor(context,
        dark: MyntColors.listItemBgDark, light: Colors.white);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondaryColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final selectedBg = resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary)
        .withValues(alpha: 0.12);

    return Stack(
      children: [
        // Dismiss area
        Positioned.fill(
          child: PointerInterceptor(
            child: GestureDetector(
              onTap: () {
                _searchFocusNode.unfocus();
                _removeSearchOverlay();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // Dropdown
        Positioned(
          left: position.dx,
          top: position.dy + size.height + 4,
          child: PointerInterceptor(
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: bgColor,
              child: Container(
                width: 280,
                constraints: const BoxConstraints(maxHeight: 350),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ocProv.isLoadingSymbols)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          query.isEmpty
                              ? 'No symbols available'
                              : 'No results for "$query"',
                          style: MyntWebTextStyles.para(context,
                              color: secondaryColor),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final symbol = filtered[index];
                            final isSelected = symbol.token ==
                                ocProv.selectedSymbol.token;

                            return InkWell(
                              onTap: () => _onSymbolSelected(symbol),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                color: isSelected ? selectedBg : null,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        symbol.tsym ?? '',
                                        style: MyntWebTextStyles.body(
                                          context,
                                          fontWeight: isSelected
                                              ? MyntFonts.semiBold
                                              : MyntFonts.regular,
                                          color: textColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      symbol.exch ?? '',
                                      style: MyntWebTextStyles.caption(
                                          context,
                                          color: secondaryColor),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onSymbolSelected(ScripValue symbol) async {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _removeSearchOverlay();

    _hasScrolledToATM = false;
    await ref.read(watchlistOCProvider).setSelectedSymbol(symbol, context);
  }

  // ─── Expiry Dropdown ────────────────────────────────────────

  Widget _buildExpiryDropdown(WatchlistOCProvider ocProv) {
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondaryColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return InkWell(
      key: _expiryButtonKey,
      onTap: () => _showExpiryOverlay(ocProv),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: MyntColors.searchBgDark, light: MyntColors.searchBg),
          border: Border.all(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ocProv.selectedExpiry?.exd ?? '—',
              style: MyntWebTextStyles.bodySmall(
                context,
                fontWeight: MyntFonts.medium,
                color: textColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: secondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showExpiryOverlay(WatchlistOCProvider ocProv) {
    _removeExpiryOverlay();

    final renderBox =
        _expiryButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    ChartIframeGuard.acquire();

    _expiryOverlay = OverlayEntry(
      builder: (_) {
        final bgColor = resolveThemeColor(context,
            dark: MyntColors.listItemBgDark, light: Colors.white);
        final textColor = resolveThemeColor(context,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
        final selectedBg = resolveThemeColor(context,
                dark: MyntColors.primaryDark, light: MyntColors.primary)
            .withValues(alpha: 0.12);
        final borderColor = resolveThemeColor(context,
            dark: MyntColors.dividerDark, light: MyntColors.divider);

        return Stack(
          children: [
            Positioned.fill(
              child: PointerInterceptor(
                child: GestureDetector(
                  onTap: _removeExpiryOverlay,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              left: position.dx,
              top: position.dy + size.height + 4,
              child: PointerInterceptor(
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  color: bgColor,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: ocProv.expiryDates.map((exp) {
                          final isSelected =
                              exp.exd == ocProv.selectedExpiry?.exd;
                          return InkWell(
                            onTap: () async {
                              _removeExpiryOverlay();
                              _hasScrolledToATM = false;
                              await ref
                                  .read(watchlistOCProvider)
                                  .setSelectedExpiry(exp, context);
                            },
                            child: Container(
                              width: 180,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              color: isSelected ? selectedBg : null,
                              child: Text(
                                exp.exd ?? '',
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: isSelected
                                      ? MyntFonts.semiBold
                                      : MyntFonts.regular,
                                  color: textColor,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_expiryOverlay!);
  }

  void _removeExpiryOverlay() {
    if (_expiryOverlay != null) {
      _expiryOverlay!.remove();
      _expiryOverlay = null;
      ChartIframeGuard.release();
    }
  }

  // ─── Column Headers ─────────────────────────────────────────

  Widget _buildColumnHeaders() {
    return RepaintBoundary(
      child: Column(
        children: [
          // Main header: CALLS | STRIKES | PUTS
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: resolveThemeColor(context,
                      dark: MyntColors.dividerDark,
                      light: MyntColors.primary.withValues(alpha: 0.07)),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Center(
                    child: Text(
                      "CALL",
                      style: MyntWebTextStyles.bodySmall(context,
                          fontWeight: MyntFonts.medium,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary)),
                    ),
                  ),
                ),
                Container(
                  width: 80,
                  alignment: Alignment.center,
                  child: Text(
                    "STRIKES",
                    style: MyntWebTextStyles.bodySmall(context,
                        fontWeight: MyntFonts.medium,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary)),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Center(
                    child: Text(
                      "PUT",
                      style: MyntWebTextStyles.bodySmall(context,
                          fontWeight: MyntFonts.medium,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sub-headers: OI/(OI ch) | LTP/(CH) | gap | LTP/(CH) | OI/(OI ch)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: resolveThemeColor(context,
                      dark: MyntColors.dividerDark,
                      light: MyntColors.primary.withValues(alpha: 0.07)),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Row(
                    children: [
                      Expanded(child: _buildSubHeader("OI", "OI ch")),
                      Expanded(child: _buildSubHeader("LTP", "CH")),
                    ],
                  ),
                ),
                const SizedBox(width: 80),
                Expanded(
                  flex: 6,
                  child: Row(
                    children: [
                      Expanded(child: _buildSubHeader("LTP", "CH")),
                      Expanded(child: _buildSubHeader("OI", "OI ch")),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader(String top, String bottom) {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            top,
            style: MyntWebTextStyles.caption(
              context,
              fontWeight: MyntFonts.medium,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            "($bottom)",
            style: MyntWebTextStyles.caption(
              context,
              fontWeight: MyntFonts.regular,
              color: resolveThemeColor(context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Content: Option Chain Rows ─────────────────────────────

  Widget _buildContent() {
    final isLoading = ref
        .watch(watchlistOCProvider.select((p) => p.isLoadingOptionChain));
    final isLoadingExpiries =
        ref.watch(watchlistOCProvider.select((p) => p.isLoadingExpiries));
    final sortedStrikes =
        ref.watch(watchlistOCProvider.select((p) => p.sortedStrikes));
    final atmStrike =
        ref.watch(watchlistOCProvider.select((p) => p.atmStrike));
    final currentLTP =
        ref.watch(watchlistOCProvider.select((p) => p.currentIndexLTP));

    if (isLoading || isLoadingExpiries) {
      return const Center(child: MyntLoader());
    }

    if (sortedStrikes.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: MyntWebTextStyles.body(context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary)),
        ),
      );
    }

    final ocProv = ref.read(watchlistOCProvider);

    // Build row data
    final rows = <StrikeRowData>[];
    for (final strike in sortedStrikes) {
      rows.add(StrikeRowData(
        strikePrice: strike,
        isATM: strike == atmStrike,
        callOption: ocProv.getCallForStrike(strike),
        putOption: ocProv.getPutForStrike(strike),
      ));
    }

    // Calculate LTP line position
    final liveLtp = currentLTP;
    int ltpLineIndex = -1;
    for (int i = 0; i < sortedStrikes.length - 1; i++) {
      final currentStrike = double.tryParse(sortedStrikes[i]) ?? 0;
      final nextStrike = double.tryParse(sortedStrikes[i + 1]) ?? 0;
      if (liveLtp >= currentStrike && liveLtp < nextStrike) {
        ltpLineIndex = i + 1;
        break;
      }
    }
    if (ltpLineIndex == -1 && sortedStrikes.isNotEmpty) {
      final firstStrike = double.tryParse(sortedStrikes.first) ?? 0;
      final lastStrike = double.tryParse(sortedStrikes.last) ?? 0;
      if (liveLtp < firstStrike) {
        ltpLineIndex = 0;
      } else if (liveLtp >= lastStrike) {
        ltpLineIndex = sortedStrikes.length;
      }
    }

    final bool showLtpLine = ltpLineIndex >= 0 && liveLtp > 0;
    final int totalItemCount = rows.length + (showLtpLine ? 1 : 0);

    // Scroll to ATM on first load
    if (!_hasScrolledToATM && atmStrike.isNotEmpty) {
      _hasScrolledToATM = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToATM();
      });
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: totalItemCount,
      itemExtent: 48,
      itemBuilder: (context, index) {
        // LTP center line
        if (showLtpLine && index == ltpLineIndex) {
          return _LtpCenterLine(
            key: const ValueKey('oc-panel-ltp-line'),
            fallbackLtp: liveLtp,
            underlyingToken: ocProv.selectedSymbol.token,
          );
        }

        // Adjust data index past the LTP line
        final dataIndex =
            showLtpLine && index > ltpLineIndex ? index - 1 : index;

        if (dataIndex < 0 || dataIndex >= rows.length) {
          return const SizedBox.shrink();
        }

        final row = rows[dataIndex];
        return OCPanelRow(
          key: ValueKey('oc_${row.strikePrice}'),
          rowData: row,
          index: dataIndex,
          atmKey: row.isATM ? _strikePriceKey : null,
        );
      },
    );
  }

  void _scrollToATM() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_strikePriceKey.currentContext != null) {
        Scrollable.ensureVisible(
          _strikePriceKey.currentContext!,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }
}

// ─── LTP Center Line ─────────────────────────────────────────────

class _LtpCenterLine extends ConsumerWidget {
  final double fallbackLtp;
  final String underlyingToken;

  const _LtpCenterLine({
    super.key,
    required this.fallbackLtp,
    required this.underlyingToken,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<Map>(
      stream: ref.read(websocketProvider).socketDataStream,
      builder: (context, snapshot) {
        final socketDatas =
            snapshot.data ?? ref.read(websocketProvider).socketDatas;
        double liveLtp = fallbackLtp;
        if (socketDatas.containsKey(underlyingToken)) {
          final socketData = socketDatas[underlyingToken];
          final wsLtp = socketData['lp']?.toString();
          if (wsLtp != null && wsLtp != "null" && wsLtp != "0") {
            liveLtp = double.tryParse(wsLtp) ?? fallbackLtp;
          }
        }

        final formattedLtp = liveLtp.toStringAsFixed(2);

        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // Left gradient line (Calls side)
              Expanded(
                flex: 6,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        resolveThemeColor(context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
              // Center LTP badge
              Container(
                width: 120,
                alignment: Alignment.center,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: resolveThemeColor(context,
                        dark: MyntColors.secondary,
                        light: MyntColors.primary),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: resolveThemeColor(context,
                                dark: MyntColors.secondary,
                                light: MyntColors.primary)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    formattedLtp,
                    style: MyntWebTextStyles.para(
                      context,
                      fontWeight: MyntFonts.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Right gradient line (Puts side)
              Expanded(
                flex: 6,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        resolveThemeColor(context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../models/marketwatch_model/get_quotes.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../provider/portfolio_provider.dart';
import '../../../../provider/privacy_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../../res/res.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/list_divider.dart';
import '../../../../sharedWidget/hover_actions_web.dart';
import '../../../../utils/responsive_navigation.dart';
import '../../../../utils/responsive_snackbar.dart';
import '../../../../models/order_book_model/order_book_model.dart';
import '../../../../sharedWidget/mynt_loader.dart';

class PositionsScreenWeb extends ConsumerStatefulWidget {
  const PositionsScreenWeb({super.key});

  @override
  ConsumerState<PositionsScreenWeb> createState() => _PositionsScreenWebState();
}

class _PositionsScreenWebState extends ConsumerState<PositionsScreenWeb> {
  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, WidgetRef ref, _) {
      final portfolio = ref.watch(portfolioProvider);
      final allPositions = portfolio.postionBookModel;
      final marketWatch = ref.watch(marketWatchProvider);
      final theme = ref.watch(themeProvider);

      if (portfolio.loading) {
        return Center(
          child: MyntLoader.simple(),
        );
      }

      if (allPositions == null || allPositions.isEmpty) {
        return Container(
          color: resolveThemeColor(context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "No Open Positions",
                  style: MyntWebTextStyles.title(
                    context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 300,
                  child: Text(
                    "You don't have any open positions right now.",
                    textAlign: TextAlign.center,
                    style: MyntWebTextStyles.para(
                      context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: allPositions.length,
          padding: const EdgeInsets.only(right: 12.0, bottom: 8.0),
          separatorBuilder: (_, __) => const ListDivider(),
          itemBuilder: (BuildContext context, int index) {
            return RepaintBoundary(
              child: _PositionCardWeb(
                position: allPositions[index],
                index: index,
                marketWatch: marketWatch,
                theme: theme,
              ),
            );
          },
        ),
      );
    });
  }
}

class _PositionCardWeb extends ConsumerStatefulWidget {
  final dynamic position;
  final int index;
  final MarketWatchProvider marketWatch;
  final ThemesProvider theme;

  const _PositionCardWeb({
    required this.position,
    required this.index,
    required this.marketWatch,
    required this.theme,
  });

  @override
  ConsumerState<_PositionCardWeb> createState() => _PositionCardWebState();
}

class _PositionCardWebState extends ConsumerState<_PositionCardWeb> {
  final ValueNotifier<bool> _isHovered = ValueNotifier<bool>(false);
  bool _isNavigating = false;

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  String get _token => widget.position.token?.toString() ?? "";
  String get _exch => widget.position.exch?.toString() ?? "";
  String get _tsym => widget.position.tsym?.toString() ?? "";
  String get _symbol => widget.position.symbol?.toString() ?? "";
  String get _option => widget.position.option?.toString() ?? "";
  String get _expDate => widget.position.expDate?.toString() ?? "";
  String get _netQty => widget.position.netqty?.toString() ?? "0";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map>(
      stream: ref.read(websocketProvider).socketDataStream,
      builder: (context, snapshot) {
        final socketDatas = snapshot.data ?? {};

        if (socketDatas.containsKey(_token)) {
          final socketData = socketDatas[_token];
          final lp = socketData['lp']?.toString();
          if (lp != null && lp != "null" && lp != "0" && lp != "0.00") {
            widget.position.lp = lp;
          }
          final chng = socketData['chng']?.toString();
          if (chng != null && chng != "null") {
            widget.position.chng = chng;
          }
          final pc = socketData['pc']?.toString();
          if (pc != null && pc != "null") {
            widget.position.perChange = pc;
          }
        }

        return MouseRegion(
          onEnter: (_) => _isHovered.value = true,
          onExit: (_) => _isHovered.value = false,
          child: ValueListenableBuilder<bool>(
            valueListenable: _isHovered,
            builder: (context, isHovered, child) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  splashColor: widget.theme.isDarkMode
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.15),
                  highlightColor: widget.theme.isDarkMode
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
                  onTap: () async {
                    if (_isNavigating) return;
                    try {
                      setState(() => _isNavigating = true);
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        ref
                            .read(marketWatchProvider)
                            .setIsDepthVisibleWeb(false);

                        DepthInputArgs depthArgs = DepthInputArgs(
                          exch: _exch,
                          token: _token,
                          tsym: _tsym,
                          instname: _symbol,
                          symbol: _symbol,
                          expDate: _expDate,
                          option: _option,
                        );

                        widget.marketWatch.scripdepthsize(false);
                        await widget.marketWatch
                            .calldepthApis(context, depthArgs, "");
                      });
                    } catch (e) {
                    } finally {
                      if (mounted) {
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted) {
                            setState(() => _isNavigating = false);
                          }
                        });
                      }
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        color: isHovered
                            ? MyntColors.primary.withOpacity(0.10)
                            : resolveThemeColor(context,
                                dark: MyntColors.backgroundColorDark,
                                light: MyntColors.backgroundColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // First row: Symbol name | LTP
                            SizedBox(
                              height: 24,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          _symbol
                                              .replaceAll("-EQ", "")
                                              .toUpperCase(),
                                          style: MyntWebTextStyles.symbol(
                                            context,
                                            color: resolveThemeColor(context,
                                                dark:
                                                    MyntColors.textPrimaryDark,
                                                light: MyntColors.textPrimary),
                                          ),
                                        ),
                                        if (_option.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 4),
                                            child: Text(
                                              _option,
                                              style: MyntWebTextStyles.symbol(
                                                context,
                                                color: resolveThemeColor(
                                                    context,
                                                    dark: MyntColors
                                                        .textPrimaryDark,
                                                    light:
                                                        MyntColors.textPrimary),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  RepaintBoundary(
                                    child: _LTPWidgetWeb(
                                      token: _token,
                                      initialData: {
                                        'ltp':
                                            widget.position.lp ?? '0.00',
                                        'change':
                                            widget.position.chng ?? '0.00',
                                        'perChange':
                                            widget.position.perChange ?? '0.00',
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Second row: Exchange + Qty | Price Change
                            SizedBox(
                              height: 24,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$_exch ',
                                        style: MyntWebTextStyles.exch(
                                          context,
                                          fontWeight: FontWeight.w500,
                                          color: resolveThemeColor(context,
                                              dark:
                                                  MyntColors.textSecondaryDark,
                                              light:
                                                  MyntColors.textSecondary),
                                        ),
                                      ),
                                      if (_expDate.isNotEmpty)
                                        Text(
                                          _expDate,
                                          style: MyntWebTextStyles.exch(
                                            context,
                                            fontWeight: FontWeight.w500,
                                            color: resolveThemeColor(context,
                                                dark:
                                                    MyntColors.textPrimaryDark,
                                                light: MyntColors.textPrimary),
                                          ),
                                        ),
                                      if (_netQty != "0" &&
                                          _netQty.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        SvgPicture.asset(
                                          assets.suitcase,
                                          height: 16,
                                          width: 16,
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.primaryDark,
                                              light: MyntColors.primary
                                                  .withOpacity(0.8)),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          ref
                                              .watch(privacyProvider)
                                              .mask(_netQty),
                                          style: MyntWebTextStyles.exch(
                                            context,
                                            fontWeight: FontWeight.w500,
                                            color: resolveThemeColor(context,
                                                dark: MyntColors.primaryDark,
                                                light: MyntColors.primary),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const Spacer(),
                                  RepaintBoundary(
                                    child: _PriceChangeWidgetWeb(
                                      token: _token,
                                      initialData: {
                                        'change':
                                            widget.position.chng ?? '0.00',
                                        'perChange':
                                            widget.position.perChange ?? '0.00',
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Positioned hover actions at bottom center
                      if (isHovered)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.backgroundColorDark,
                                  light: MyntColors.backgroundColor,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: HoverActionsContainer(
                                isVisible: true,
                                actions: [
                                  HoverActionButton(
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
                                    onPressed: () async {
                                      try {
                                        await _placeOrderInput(context, true);
                                      } catch (e) {
                                      }
                                    },
                                  ),
                                  HoverActionButton(
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
                                    onPressed: () async {
                                      try {
                                        await _placeOrderInput(context, false);
                                      } catch (e) {
                                      }
                                    },
                                  ),
                                  HoverActionButton(
                                    iconAsset: assets.depthIcon,
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: Colors.black,
                                    ),
                                    backgroundColor: Colors.transparent,
                                    onPressed: () async {
                                      if (_isNavigating) return;
                                      try {
                                        setState(() => _isNavigating = true);
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) async {
                                          DepthInputArgs depthArgs =
                                              DepthInputArgs(
                                            exch: _exch,
                                            token: _token,
                                            tsym: _tsym,
                                            instname: _symbol,
                                            symbol: _symbol,
                                            expDate: _expDate,
                                            option: _option,
                                          );

                                          widget.marketWatch
                                              .scripdepthsize(false);
                                          await widget.marketWatch
                                              .calldepthApis(
                                                  context, depthArgs, "");
                                        });
                                      } catch (e) {
                                      } finally {
                                        if (mounted) {
                                          Future.delayed(
                                              const Duration(
                                                  milliseconds: 500), () {
                                            if (mounted) {
                                              setState(
                                                  () => _isNavigating = false);
                                            }
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _placeOrderInput(BuildContext ctx, bool transType) async {
    try {
      if (_isNavigating) return;

      setState(() => _isNavigating = true);

      await ref
          .read(marketWatchProvider)
          .fetchScripInfo(_token, _exch, context, true);
      await ref
          .read(marketWatchProvider)
          .fetchScripQuote(_token, _exch, context);

      final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
      if (scripInfo == null) {
        throw Exception('Failed to load scrip information');
      }

      final freshQuoteData = ref.read(marketWatchProvider).getQuotes;

      final wsProvider = ref.read(websocketProvider);
      final socketData = wsProvider.socketDatas[_token];

      String? ltp;
      String? perChange;

      bool isValidPrice(String? value) {
        if (value == null || value.isEmpty) return false;
        final normalized = value.trim();
        return normalized != '0' &&
            normalized != '0.0' &&
            normalized != '0.00' &&
            normalized != 'null' &&
            normalized != 'NaN' &&
            normalized != 'Infinity';
      }

      if (socketData != null) {
        final wsLtp = socketData['lp']?.toString();
        final wsPc = socketData['pc']?.toString();
        if (isValidPrice(wsLtp)) {
          ltp = wsLtp;
          perChange = wsPc;
        }
      }

      if (!isValidPrice(ltp) && freshQuoteData != null) {
        final quoteLtp = freshQuoteData.lp ?? freshQuoteData.c;
        if (isValidPrice(quoteLtp)) {
          ltp = quoteLtp;
          perChange = freshQuoteData.pc;
        }
      }

      if (!isValidPrice(ltp)) {
        final posLtp = widget.position.lp?.toString();
        if (isValidPrice(posLtp)) {
          ltp = posLtp;
          perChange = widget.position.perChange?.toString();
        }
      }

      final lotSize =
          _safeParseNumeric(scripInfo.ls, "1");
      final safeLtp = _safeParseNumeric(ltp, "0.00");
      final safePerChange = _safeParseNumeric(perChange, "0.00");

      if (safeLtp == "0.00" || safeLtp.isEmpty) {
        if (mounted) {
          ResponsiveSnackBar.showError(
            context,
            'Price data not available yet. Please wait a moment and try again.',
          );
        }
        return;
      }

      OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: _exch,
        tSym: _tsym,
        isExit: false,
        token: _token,
        transType: transType,
        lotSize: lotSize,
        ltp: safeLtp,
        perChange: safePerChange,
        orderTpye: '',
        holdQty: _netQty,
        isModify: false,
        raw: {},
      );

      await Future.delayed(const Duration(milliseconds: 150));

      ResponsiveNavigation.toPlaceOrderScreen(
        context: context,
        arguments: {
          "orderArg": orderArgs,
          "scripInfo": scripInfo,
          "isBskt": ""
        },
      );
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
            context, 'Error placing order: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _isNavigating = false);
          }
        });
      }
    }
  }

  String _safeParseNumeric(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;
    String stringValue = value.toString().trim();
    if (stringValue.isEmpty ||
        stringValue == 'null' ||
        stringValue == '0.0' ||
        stringValue == '0' ||
        stringValue == 'NaN' ||
        stringValue == 'Infinity') {
      return defaultValue;
    }
    try {
      double.parse(stringValue);
      return stringValue;
    } catch (e) {
      try {
        int.parse(stringValue);
        return stringValue;
      } catch (e) {
        return defaultValue;
      }
    }
  }
}

// Widget for LTP only (used in first row)
class _LTPWidgetWeb extends ConsumerStatefulWidget {
  final String token;
  final Map<String, dynamic> initialData;

  const _LTPWidgetWeb({
    required this.token,
    required this.initialData,
  });

  @override
  ConsumerState<_LTPWidgetWeb> createState() => _LTPWidgetWebState();
}

class _LTPWidgetWebState extends ConsumerState<_LTPWidgetWeb> {
  late String ltp;
  late String change;
  late String perChange;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    ltp = widget.initialData['ltp']?.toString() ?? '0.00';
    change = widget.initialData['change']?.toString() ?? '0.00';
    perChange = widget.initialData['perChange']?.toString() ?? '0.00';

    final socketData = ref.read(websocketProvider).socketDatas[widget.token];
    if (socketData != null) {
      ltp = socketData['lp']?.toString() ?? ltp;
      change = socketData['chng']?.toString() ?? change;
      perChange = socketData['pc']?.toString() ?? perChange;
    }

    _setupSubscription();
  }

  void _setupSubscription() {
    _subscription =
        ref.read(websocketProvider).socketDataStream.listen((rawData) {
      if (!mounted) return;

      final data = Map<String, dynamic>.from(rawData as Map? ?? {});
      if (!data.containsKey(widget.token)) return;

      final rawNewData = data[widget.token];
      if (rawNewData == null) return;

      final newData = Map<String, dynamic>.from(rawNewData as Map);
      bool valueChanged = false;

      final newLtp = newData['lp']?.toString();
      final newChange = newData['chng']?.toString();
      final newPerChange = newData['pc']?.toString();

      if (newLtp != null &&
          newLtp != ltp &&
          newLtp != '0.00' &&
          newLtp != '0.0' &&
          newLtp != 'null') {
        ltp = newLtp;
        valueChanged = true;
      }

      if (newChange != null &&
          newChange != change &&
          newChange != '0.0' &&
          newChange != 'null') {
        change = newChange;
        valueChanged = true;
      }

      if (newPerChange != null &&
          newPerChange != perChange &&
          newPerChange != '0.0' &&
          newPerChange != 'null') {
        perChange = newPerChange;
        valueChanged = true;
      }

      if (valueChanged && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _safeFormatPrice(String value) {
    if (value == 'null' ||
        value.isEmpty ||
        value == '0.0' ||
        value == 'NaN' ||
        value == 'Infinity') {
      return '0.00';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final displayLtp = _safeFormatPrice(ltp);
    final displayChange = _safeFormatPrice(change);
    final displayPerChange = _safeFormatPrice(perChange);

    final changeColor =
        displayChange.startsWith("-") || displayPerChange.startsWith('-')
            ? resolveThemeColor(
                context,
                dark: MyntColors.lossDark,
                light: MyntColors.loss,
              )
            : (displayChange == "0.00" || displayPerChange == "0.00")
                ? resolveThemeColor(
                    context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary,
                  )
                : resolveThemeColor(
                    context,
                    dark: MyntColors.profitDark,
                    light: MyntColors.profit,
                  );
    return Text(
      displayLtp,
      style: MyntWebTextStyles.price(
        context,
        color: changeColor,
      ),
    );
  }
}

// Widget for Price Change only (used in second row)
class _PriceChangeWidgetWeb extends ConsumerStatefulWidget {
  final String token;
  final Map<String, dynamic> initialData;

  const _PriceChangeWidgetWeb({
    required this.token,
    required this.initialData,
  });

  @override
  ConsumerState<_PriceChangeWidgetWeb> createState() =>
      _PriceChangeWidgetWebState();
}

class _PriceChangeWidgetWebState extends ConsumerState<_PriceChangeWidgetWeb> {
  late String change;
  late String perChange;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    change = widget.initialData['change']?.toString() ?? '0.00';
    perChange = widget.initialData['perChange']?.toString() ?? '0.00';

    final socketData = ref.read(websocketProvider).socketDatas[widget.token];
    if (socketData != null) {
      change = socketData['chng']?.toString() ?? change;
      perChange = socketData['pc']?.toString() ?? perChange;
    }

    _setupSubscription();
  }

  void _setupSubscription() {
    _subscription =
        ref.read(websocketProvider).socketDataStream.listen((rawData) {
      if (!mounted) return;

      final data = Map<String, dynamic>.from(rawData as Map? ?? {});
      if (!data.containsKey(widget.token)) return;

      final rawNewData = data[widget.token];
      if (rawNewData == null) return;

      final newData = Map<String, dynamic>.from(rawNewData as Map);
      bool valueChanged = false;

      final newChange = newData['chng']?.toString();
      final newPerChange = newData['pc']?.toString();

      if (newChange != null &&
          newChange != change &&
          newChange != '0.0' &&
          newChange != 'null') {
        change = newChange;
        valueChanged = true;
      }

      if (newPerChange != null &&
          newPerChange != perChange &&
          newPerChange != '0.0' &&
          newPerChange != 'null') {
        perChange = newPerChange;
        valueChanged = true;
      }

      if (valueChanged && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _safeFormatPrice(String value) {
    if (value == 'null' ||
        value.isEmpty ||
        value == '0.0' ||
        value == 'NaN' ||
        value == 'Infinity') {
      return '0.00';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final displayChange = _safeFormatPrice(change);
    final displayPerChange = _safeFormatPrice(perChange);

    return Text(
      "$displayChange ($displayPerChange%)",
      style: MyntWebTextStyles.priceChange(
        context,
        fontWeight: FontWeight.w500,
        color: resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary),
      ),
    );
  }
}

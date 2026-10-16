import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../provider/web_subscription_manager.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';

/// Market depth panel shown beside the web order window (Task #9168).
///
/// Mirrors the Overview depth ladder in scrip_depth_info_web.dart
/// (Quantity | Bid | Ask | Quantity, totals with buy/sell share and the
/// blue/red bar) but reads the live socket data for one [token], so it
/// does not depend on the Overview's single depth slot.
///
/// While open it holds the depth ("d") feed for [exch]|[token] through
/// WebSubscriptionManager.acquireOrderDepth / releaseOrderDepth, which never
/// stops a feed another screen (Overview, chart) is using.
class OrderDepthPanelWeb extends ConsumerStatefulWidget {
  final String token;
  final String exch;

  /// Called with the tapped bid/ask price ("2075.90").
  final ValueChanged<String>? onPriceTap;
  final VoidCallback onClose;

  /// Top border (1) + header (44): where the header's bottom line sits.
  static const double headerExtent = 45;

  const OrderDepthPanelWeb({
    super.key,
    required this.token,
    required this.exch,
    required this.onClose,
    this.onPriceTap,
  });

  @override
  ConsumerState<OrderDepthPanelWeb> createState() => _OrderDepthPanelWebState();
}

class _OrderDepthPanelWebState extends ConsumerState<OrderDepthPanelWeb> {
  static const _levels = 5;

  StreamSubscription<Map>? _sub;
  Map<String, String> _depth = const {};

  // Cached so dispose() does not touch ref.
  late final WebSubscriptionManager _subs;
  String? _heldSymbol;

  String get _symbol => '${widget.exch}|${widget.token}';

  @override
  void initState() {
    super.initState();
    _subs = ref.read(webSubscriptionManagerProvider);
    _readSnapshot();
    _listen();
    _hold();
  }

  void _hold() {
    if (widget.token.isEmpty || widget.exch.isEmpty) return;
    final symbol = _symbol;
    _heldSymbol = symbol;
    _subs.acquireOrderDepth(symbol, context);
  }

  void _letGo() {
    final symbol = _heldSymbol;
    _heldSymbol = null;
    if (symbol != null) _subs.releaseOrderDepth(symbol);
  }

  @override
  void didUpdateWidget(OrderDepthPanelWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // NSE/BSE switch in the order window changes the token.
    if (oldWidget.token != widget.token || oldWidget.exch != widget.exch) {
      _sub?.cancel();
      _letGo();
      _readSnapshot();
      _listen();
      _hold();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _letGo();
    super.dispose();
  }

  static List<String> get _keys => [
        for (int i = 1; i <= _levels; i++) ...['bp$i', 'bq$i', 'sp$i', 'sq$i'],
        'tbq',
        'tsq',
        // Market info row (same fields as the Overview's Market Info)
        'o',
        'h',
        'l',
        'c',
      ];

  Map<String, String> _pick(Map? data) {
    if (data == null) return const {};
    return {
      for (final k in _keys)
        if (data[k] != null && data[k].toString() != 'null') k: data[k].toString(),
    };
  }

  void _readSnapshot() {
    final data = ref.read(websocketProvider).socketDatas[widget.token];
    _depth = _pick(data is Map ? data : null);
  }

  void _listen() {
    _sub = ref.read(websocketProvider).socketDataStream.listen((all) {
      if (!mounted || !all.containsKey(widget.token)) return;
      final data = all[widget.token];
      final next = _pick(data is Map ? data : null);
      if (next.isEmpty || _sameAs(next)) return;
      setState(() => _depth = {..._depth, ...next});
    });
  }

  bool _sameAs(Map<String, String> next) {
    for (final e in next.entries) {
      if (_depth[e.key] != e.value) return false;
    }
    return true;
  }

  String _price(String key) => _depth[key] ?? '0.00';
  String _qty(String key) => _depth[key] ?? '0';

  // tsq can arrive as "327057.00"; the Overview drops the decimals too.
  int _int(String key) =>
      int.tryParse((_depth[key] ?? '0').split('.').first) ?? 0;

  @override
  Widget build(BuildContext context) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final bidColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final askColor = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.tertiary);
    final divider = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);

    final tbq = _int('tbq');
    final tsq = _int('tsq');
    final total = tbq + tsq;
    final buyPer = total == 0 ? 0.0 : tbq / total * 100;
    final sellPer = total == 0 ? 0.0 : tsq / total * 100;

    // Same card as the order window beside it: 5px corners, divider border,
    // elevation 8, window background.
    // return Container(
    //   width: 330,
    //   decoration: BoxDecoration(
    //     color: resolveThemeColor(context,
    //         dark: MyntColors.dialogDark, light: MyntColors.dialog),
    //     borderRadius: BorderRadius.circular(8),
    //     boxShadow: [
    //       BoxShadow(
    //         color: Colors.black.withValues(alpha: 0.16),
    //         blurRadius: 28,
    //         offset: const Offset(0, 8),
    //       ),
    //     ],
    //   ),
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(5),
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      child: Container(
      width: 330,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            height: 44,
            padding: const EdgeInsets.only(left: 16, right: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Market depth',
                      style: MyntWebTextStyles.body(context,
                          fontWeight: MyntFonts.semiBold,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary)),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                  splashRadius: 16,
                  icon: Icon(Icons.close, size: 18, color: secondary),
                ),
              ],
            ),
          ),

          // Open / High / Low / P.Close (client ask), laid out like the
          // Overview's Market Info on a narrow width.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _info('Open', _price('o'), secondary)),
                    const SizedBox(width: 16),
                    Expanded(child: _info('High', _price('h'), secondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _info('Low', _price('l'), secondary)),
                    const SizedBox(width: 16),
                    Expanded(child: _info('P.Close', _price('c'), secondary)),
                  ],
                ),
              ],
            ),
          ),

          // Ladder
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _cell(Text('Quantity',
                        style: MyntWebTextStyles.para(context,
                            fontWeight: MyntFonts.medium, color: secondary))),
                    _cell(
                        Text('Bid',
                            style: MyntWebTextStyles.para(context,
                                fontWeight: MyntFonts.medium, color: bidColor)),
                        align: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 12)),
                    _cell(
                        Text('Ask',
                            style: MyntWebTextStyles.para(context,
                                fontWeight: MyntFonts.medium, color: askColor)),
                        padding: const EdgeInsets.only(left: 12)),
                    _cell(
                        Text('Quantity',
                            style: MyntWebTextStyles.para(context,
                                fontWeight: MyntFonts.medium, color: secondary)),
                        align: Alignment.centerRight),
                  ],
                ),
                const SizedBox(height: 6),
                // for (int i = 1; i <= _levels; i++)
                //   SizedBox(
                //     height: 38,
                //     child: Row(
                //       children: [
                //         _cell(_qtyText(_qty('bq$i'), secondary)),
                //         _cell(_priceButton(_price('bp$i'), bidColor),
                //             align: Alignment.centerRight,
                //             padding: const EdgeInsets.only(right: 12)),
                //         _cell(_priceButton(_price('sp$i'), askColor),
                //             padding: const EdgeInsets.only(left: 12)),
                //         _cell(_qtyText(_qty('sq$i'), secondary),
                //             align: Alignment.centerRight),
                //       ],
                //     ),
                //   ),
                // Kite style: the whole bid half (qty + bid) or ask half
                // (ask + qty) of a row is the click target, not just the price.
                for (int i = 1; i <= _levels; i++)
                  SizedBox(
                    height: 38,
                    child: Row(
                      children: [
                        Expanded(
                          child: _side(
                            price: _price('bp$i'),
                            hover: bidColor,
                            child: Row(
                              children: [
                                _cell(_qtyText(_qty('bq$i'), secondary),
                                    padding: const EdgeInsets.only(left: 4)),
                                _cell(
                                    Text(_price('bp$i'),
                                        style: _numStyle(context, bidColor)),
                                    align: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 12)),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: _side(
                            price: _price('sp$i'),
                            hover: askColor,
                            child: Row(
                              children: [
                                _cell(
                                    Text(_price('sp$i'),
                                        style: _numStyle(context, askColor)),
                                    padding: const EdgeInsets.only(left: 12)),
                                _cell(_qtyText(_qty('sq$i'), secondary),
                                    align: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 4)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Totals + buy/sell bar (same as the Overview)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$tbq (${buyPer.toStringAsFixed(2)}%)',
                        style: _numStyle(context, secondary)),
                    Text('(${sellPer.toStringAsFixed(2)}%) $tsq',
                        style: _numStyle(context, secondary)),
                  ],
                ),
                if (total > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 5,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (buyPer * 100).round(),
                            child: Container(color: bidColor),
                          ),
                          Expanded(
                            flex: (sellPer * 100).round(),
                            child: Container(
                                color: resolveThemeColor(context,
                                    dark: MyntColors.errorDark,
                                    light: MyntColors.tertiary)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (widget.onPriceTap != null) ...[
                  const SizedBox(height: 10),
                  Text('Click a bid or ask price to use it as the order price.',
                      style: MyntWebTextStyles.caption(context,
                          color: secondary)),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _cell(Widget child,
      {Alignment align = Alignment.centerLeft,
      EdgeInsets padding = EdgeInsets.zero}) {
    return Expanded(
      child: Padding(
        padding: padding,
        child: Align(alignment: align, child: child),
      ),
    );
  }

  TextStyle _numStyle(BuildContext context, Color color) =>
      MyntWebTextStyles.body(context,
              fontWeight: MyntFonts.medium, color: color)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  Widget _qtyText(String qty, Color color) =>
      Text(qty, style: _numStyle(context, color));

  Widget _info(String label, String value, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: MyntWebTextStyles.para(context, color: labelColor)),
        const SizedBox(height: 6),
        Text(value,
            style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: 4),
        Divider(
          height: 8,
          color: resolveThemeColor(context,
              dark: MyntColors.dividerDark, light: MyntColors.divider),
        ),
      ],
    );
  }

  /// One half of a ladder row as a click target for [price].
  Widget _side(
      {required String price, required Color hover, required Widget child}) {
    if (widget.onPriceTap == null || price == '0.00' || price == '0') {
      return child;
    }
    return _DepthSide(
      hoverColor: hover,
      onTap: () => widget.onPriceTap!(price),
      child: child,
    );
  }

  // Replaced by _side: the whole half row is the click target now.
  // Widget _priceButton(String price, Color color) {
  //   final text = Text(price, style: _numStyle(context, color));
  //   if (widget.onPriceTap == null || price == '0.00' || price == '0') {
  //     return text;
  //   }
  //   return Tooltip(
  //     message: 'Use this price',
  //     waitDuration: const Duration(milliseconds: 400),
  //     child: MouseRegion(
  //       cursor: SystemMouseCursors.click,
  //       child: GestureDetector(
  //         onTap: () => widget.onPriceTap!(price),
  //         child: text,
  //       ),
  //     ),
  //   );
  // }
}

/// Half of a depth row (bid side or ask side) that uses its price on click,
/// with a hand cursor and a light tint of the side's colour on hover.
class _DepthSide extends StatefulWidget {
  final Color hoverColor;
  final VoidCallback onTap;
  final Widget child;

  const _DepthSide({
    required this.hoverColor,
    required this.onTap,
    required this.child,
  });

  @override
  State<_DepthSide> createState() => _DepthSideState();
}

class _DepthSideState extends State<_DepthSide> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // No "Use this price" tooltip (user: it got in the way); the hand cursor,
    // hover tint and the hint line under the bar say the row is clickable.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hover
                ? widget.hoverColor.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared wiring for the order windows (place order, modify order, modify GTT).
// ---------------------------------------------------------------------------

/// Depth panel state shared by an order form and its window shell. The form
/// reports the scrip (following any NSE/BSE switch) and whether a tapped
/// price can be used; the shell draws the panel beside the 450px window.
class OrderDepthController extends ChangeNotifier {
  /// Open/closed as the user last left it, for the next order window this
  /// session (place, modify and modify GTT share it).
  static bool rememberedOpen = false;

  OrderDepthController() : _open = rememberedOpen;

  bool _open;
  bool get open => _open;

  String token = '';
  String exch = '';

  /// False for indices / commodity spot, which have no depth (same rule as
  /// the Overview depth in scrip_depth_info_web.dart).
  bool available = false;

  /// Null where a tapped price has nowhere to go (GTT).
  ValueChanged<String>? onPriceTap;

  /// Key on the order window's card, so the depth icon can measure where it
  /// sits inside the window.
  final GlobalKey windowKey = GlobalKey();

  /// Key on the row that holds the depth icon (Place order: the tab row;
  /// Modify / Modify GTT: the header), so the panel's header line can sit on
  /// the same y as that row's bottom line.
  final GlobalKey anchorRowKey = GlobalKey();

  /// Distance from the window's top to where the panel starts (its header
  /// line meets the icon row's bottom line).
  double anchorOffset = 0;

  void setAnchor(double dy) {
    if ((dy - anchorOffset).abs() < 0.5) return;
    anchorOffset = dy;
    notifyListeners();
  }

  bool get showing => _open && available && token.isNotEmpty;

  void toggle() {
    _open = !_open;
    rememberedOpen = _open;
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    rememberedOpen = false;
    notifyListeners();
  }

  void sync({
    required String token,
    required String exch,
    required String? instname,
    required ValueChanged<String>? onPriceTap,
  }) {
    final available = instname != "UNDIND" && instname != "COM";
    final changed = token != this.token ||
        exch != this.exch ||
        available != this.available ||
        (onPriceTap == null) != (this.onPriceTap == null);
    this.token = token;
    this.exch = exch;
    this.available = available;
    this.onPriceTap = onPriceTap;
    if (changed) notifyListeners();
  }

  /// Call from the form's build: reports after the frame so the shell is not
  /// rebuilt mid-build.
  static void syncFrom(
    BuildContext context, {
    required String token,
    required String exch,
    required String? instname,
    required ValueChanged<String>? onPriceTap,
  }) {
    final c = OrderDepthScope.of(context);
    if (c == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      c.sync(
          token: token, exch: exch, instname: instname, onPriceTap: onPriceTap);
    });
  }
}

class OrderDepthScope extends InheritedWidget {
  final OrderDepthController controller;

  const OrderDepthScope({
    super.key,
    required this.controller,
    required super.child,
  });

  // Read without a dependency: listeners use ListenableBuilder instead.
  static OrderDepthController? of(BuildContext context) => context
      .getInheritedWidgetOfExactType<OrderDepthScope>()
      ?.controller;

  @override
  bool updateShouldNotify(OrderDepthScope oldWidget) =>
      controller != oldWidget.controller;
}

/// The depth icon placed in an order window (tab row or header).
class OrderDepthToggle extends StatelessWidget {
  final EdgeInsets padding;

  const OrderDepthToggle({super.key, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final depth = OrderDepthScope.of(context);
    if (depth == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: depth,
      builder: (context, _) {
        if (!depth.available) return const SizedBox.shrink();
        // Tell the shell where the panel should start inside the window:
        // header line on the icon row's bottom line, else level with the icon.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final window = depth.windowKey.currentContext?.findRenderObject();
          if (window is! RenderBox || !window.attached) return;
          final row = depth.anchorRowKey.currentContext?.findRenderObject();
          if (row is RenderBox && row.attached) {
            final rowBottom = row
                .localToGlobal(Offset(0, row.size.height), ancestor: window)
                .dy;
            depth.setAnchor((rowBottom - OrderDepthPanelWeb.headerExtent)
                .clamp(0.0, double.infinity));
            return;
          }
          final icon = context.findRenderObject();
          if (icon is! RenderBox || !icon.attached) return;
          depth.setAnchor(
              icon.localToGlobal(Offset.zero, ancestor: window).dy);
        });
        final active = depth.open;
        final color = active
            ? resolveThemeColor(context,
                dark: MyntColors.primaryDark, light: MyntColors.primary)
            : resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary);
        return Padding(
          padding: padding,
          child: Tooltip(
            message: active ? 'Hide market depth' : 'Market depth',
            child: Material(
              // color:
              //     active ? color.withValues(alpha: 0.10) : Colors.transparent,
              // Closed: light grey chip (same as the hover look) so the icon
              // stands out at rest; open: light blue.
              color: color.withValues(alpha: active ? 0.10 : 0.08),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: depth.toggle,
                // child: SizedBox(
                //   width: 28,
                //   height: 26,
                //   child: Icon(Icons.stacked_bar_chart_rounded,
                //       size: 18, color: color),
                // ),
                // Order-book ladder: bid bars in blue, ask bars in red.
                child: SizedBox(
                  width: 28,
                  height: 26,
                  child: Center(
                    child: CustomPaint(
                      size: const Size(18, 18),
                      painter: _DepthIconPainter(
                        bid: resolveThemeColor(context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary),
                        ask: resolveThemeColor(context,
                            dark: MyntColors.lossDark,
                            light: MyntColors.tertiary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Depth icon: bid bars to the left in blue, ask bars to the right in red
/// (drawn on a 24-unit grid, scaled to the given size).
class _DepthIconPainter extends CustomPainter {
  final Color bid;
  final Color ask;

  const _DepthIconPainter({required this.bid, required this.ask});

  // [y, bid bar start x, ask bar end x]; bars meet near the centre (11 / 13).
  static const _rows = [
    [6.0, 6.0, 19.0],
    [10.0, 3.0, 16.0],
    [14.0, 7.0, 21.0],
    [18.0, 5.0, 18.0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Paint pen(Color c) => Paint()
      ..color = c
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round;
    final bidPen = pen(bid);
    final askPen = pen(ask);
    for (final r in _rows) {
      final y = r[0] * s;
      canvas.drawLine(Offset(11 * s, y), Offset(r[1] * s, y), bidPen);
      canvas.drawLine(Offset(13 * s, y), Offset(r[2] * s, y), askPen);
    }
  }

  @override
  bool shouldRepaint(_DepthIconPainter old) =>
      old.bid != bid || old.ask != ask;
}

/// Where a window and its depth panel go. The panel sits on the right when it
/// fits, else on the left; if neither fits, the window slides left so the
/// panel stays on screen at the right.
class OrderDepthPlacement {
  static const double panelWidth = 330;
  // static const double gap = 8;
  static const double gap = 4;

  final double windowLeft;

  /// Null when the panel is not shown.
  final double? panelLeft;

  const OrderDepthPlacement._(this.windowLeft, this.panelLeft);

  factory OrderDepthPlacement.of({
    required double screenWidth,
    required double windowLeft,
    required double windowWidth,
    required bool showPanel,
  }) {
    if (!showPanel) return OrderDepthPlacement._(windowLeft, null);
    final rightFits =
        windowLeft + windowWidth + gap + panelWidth <= screenWidth;
    if (rightFits) {
      return OrderDepthPlacement._(windowLeft, windowLeft + windowWidth + gap);
    }
    if (windowLeft - gap - panelWidth >= 0) {
      return OrderDepthPlacement._(windowLeft, windowLeft - gap - panelWidth);
    }
    final left = (screenWidth - windowWidth - gap - panelWidth)
        .clamp(0.0, windowLeft);
    return OrderDepthPlacement._(left, left + windowWidth + gap);
  }
}

/// The panel as the window shell draws it, fed by [controller].
class OrderDepthDock extends StatelessWidget {
  final OrderDepthController controller;

  const OrderDepthDock({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: OrderDepthPanelWeb(
        token: controller.token,
        exch: controller.exch,
        // onPriceTap: controller.onPriceTap,
        // Look the handler up at tap time: the form may have re-registered a
        // new one (new State) without the shell rebuilding, and a captured
        // handler from a disposed form silently does nothing.
        onPriceTap: controller.onPriceTap == null
            ? null
            : (price) => controller.onPriceTap?.call(price),
        onClose: controller.close,
      ),
    );
  }
}

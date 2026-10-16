part of 'strategy_builder_screen.dart';

// Strategy Builder v2 layout (landing page + builder workspace), built from
// strategy_builder_v2.html. Every action calls the same StrategyBuilderProvider
// methods the previous panel used; the option chain still opens through
// _showOptionChainDialog.

/// Default underlying for a new strategy and for landing-page presets.
const Map<String, String> _kSbNifty = {'displayName': 'NIFTY 50', 'token': '26000', 'exch': 'NSE'};

/// Display order of the predefined strategies (matches the v2 design).
const List<String> _kSbPresetOrder = [
  'Long Call', 'Long Put', 'Bull Call Spread', 'Bear Put Spread',
  'Long Straddle', 'Long Strangle', 'Iron Condor', 'Bull Put Spread',
  'Bear Call Spread', 'Iron Butterfly', 'Short Straddle', 'Short Strangle',
  'Short Put', 'Short Call', 'Long Combo (Risk Reversal)', 'Short Combo (Risk Reversal)',
  'Long Synthetic Future', 'Short Synthetic Future', 'Long Iron Condor', 'Long Iron Butterfly',
];

const Map<String, String> _kSbRisk = {
  'Long Call': 'Limited loss',
  'Long Put': 'Limited loss',
  'Bull Call Spread': 'Limited risk',
  'Bear Put Spread': 'Limited risk',
  'Long Straddle': 'Big move expected',
  'Long Strangle': 'Big move expected',
  'Iron Condor': 'Range bound',
  'Bull Put Spread': 'Limited risk',
  'Bear Call Spread': 'Limited risk',
  'Iron Butterfly': 'Range bound',
  'Short Straddle': 'Unlimited risk',
  'Short Strangle': 'Unlimited risk',
  'Short Put': 'High risk',
  'Short Call': 'Unlimited risk',
  'Long Combo (Risk Reversal)': 'High risk',
  'Short Combo (Risk Reversal)': 'High risk',
  'Long Synthetic Future': 'Unlimited risk',
  'Short Synthetic Future': 'Unlimited risk',
  'Long Iron Condor': 'Big move expected',
  'Long Iron Butterfly': 'Big move expected',
};

const Map<String, String> _kSbGloss = {
  'maxP': 'The most this strategy can make if held until expiry.',
  'maxL': 'The most this strategy can lose if held until expiry.',
  'be': 'Price of the underlying at expiry where you neither make nor lose money.',
  'net': 'Net option premium per contract. Positive = you receive premium (selling), negative = you pay (buying).',
  'margin': 'Funds blocked to hold this position (NRML).',
  'pop': 'Chance the underlying ends in a profit zone at expiry, based on implied volatility. Also called POP. An estimate, not a guarantee.',
  'rr': 'Reward / risk: max profit divided by max loss.',
  'mult': 'Multiplies the lots of every leg. 2× turns 1 lot into 2 lots on each leg.',
};

const String _kSbMinus = '−';
const List<String> _kSbMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Colour tokens from strategy_builder_v2.html, with dark-mode equivalents.
class _SbC {
  final bool d;
  const _SbC(this.d);
  Color get blue => d ? MyntColors.primaryDark : const Color(0xFF0037B7);
  Color get btnBg => d ? MyntColors.secondary : const Color(0xFF0037B7);
  Color get blueTint => d ? const Color(0xFF14233D) : const Color(0xFFF0F4FC);
  Color get blueTint2 => d ? const Color(0xFF1B2E4F) : const Color(0xFFE3EAFA);
  Color get chainBorder => d ? const Color(0xFF2D4A7A) : const Color(0xFFB8C8EE);
  Color get bg => d ? MyntColors.backgroundColorDark : Colors.white;
  Color get surface => d ? MyntColors.cardDark : Colors.white;
  Color get surface2 => d ? const Color(0xFF1C2128) : const Color(0xFFF8F9FB);
  Color get hover => d ? MyntColors.cardHoverDark : const Color(0xFFF1F3F7);
  Color get line => d ? MyntColors.dividerDark : const Color(0xFFDDE2E7);
  Color get lineSoft => d ? const Color(0xFF242A31) : const Color(0xFFECEFF3);
  Color get cardBorder => d ? MyntColors.dividerDark : const Color(0xFFE3E7EC);
  Color get text => d ? MyntColors.textPrimaryDark : const Color(0xFF0B1220);
  Color get text2 => d ? const Color(0xFFADB5BF) : const Color(0xFF3B4558);
  Color get text3 => d ? MyntColors.textSecondaryDark : const Color(0xFF5F697C);
  Color get profit => d ? MyntColors.profitDark : const Color(0xFF00873F);
  Color get loss => d ? MyntColors.lossDark : const Color(0xFFD0222C);
  Color get profitTint => d ? const Color(0xFF12261A) : const Color(0xFFEBF7F0);
  Color get lossTint => d ? const Color(0xFF2D1517) : const Color(0xFFFCEFEF);
  Color get profitFill => const Color(0xFF00B14F).withValues(alpha: d ? .18 : .13);
  Color get lossFill => const Color(0xFFFF1717).withValues(alpha: d ? .14 : .08);
  Color get buyTint => d ? const Color(0xFF12261A) : const Color(0xFFE6F5EC);
  Color get sellTint => d ? const Color(0xFF2D1517) : const Color(0xFFFCEBEC);
  Color get zero => d ? const Color(0xFF6E7681) : const Color(0xFF9AA3B2);
  Color get strikeLine => d ? const Color(0xFF3A414A) : const Color(0xFFCFD5DE);
  Color get cross => d ? const Color(0xFF8B949E) : const Color(0xFF7D8697);
  Color get halo => d ? MyntColors.cardDark : Colors.white;
  Color get scrim => const Color(0xFF0B1220).withValues(alpha: .4);
}

// ---------------------------------------------------------------------------
// Pure helpers (formatting, interpolation, mini payoff maths)
// ---------------------------------------------------------------------------

String _sbN0(double v) => v.abs().toIndianFormat(decimalPlaces: 0);
String _sbN2(double v) => v.abs().toIndianFormat();
String _sbSigned2(double v) => '${v < 0 ? _kSbMinus : ''}${_sbN2(v)}';

String _sbPct(double v, [int d = 2]) =>
    '${v > 0 ? '+' : v < 0 ? _kSbMinus : ''}${v.abs().toStringAsFixed(d)}%';

/// Parses the provider's expiry format ("27-FEB-2025").
DateTime? _sbParseExpiry(String s) {
  final parts = s.split('-');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final mi = _kSbMonths.indexWhere((m) => m.toUpperCase() == parts[1].toUpperCase());
  var year = int.tryParse(parts[2]);
  if (day == null || mi < 0 || year == null) return null;
  if (year < 100) year += 2000;
  return DateTime(year, mi + 1, day);
}

String _sbFmtDate(DateTime d, {bool year = false}) =>
    '${d.day.toString().padLeft(2, '0')} ${_kSbMonths[d.month - 1]}${year ? ' ${d.year}' : ''}';

String _sbFmtExpiry(String s, {bool year = false}) {
  final d = _sbParseExpiry(s);
  return d == null ? s : _sbFmtDate(d, year: year);
}

/// Linear interpolation on a price-sorted series (clamped at the ends).
double _sbInterp(List<double> xs, List<double> ys, double x) {
  if (xs.isEmpty || ys.isEmpty) return 0;
  final n = math.min(xs.length, ys.length);
  if (x <= xs.first) return ys.first;
  if (x >= xs[n - 1]) return ys[n - 1];
  var lo = 0, hi = n - 1;
  while (hi - lo > 1) {
    final m = (lo + hi) >> 1;
    if (xs[m] <= x) {
      lo = m;
    } else {
      hi = m;
    }
  }
  final dx = xs[hi] - xs[lo];
  if (dx.abs() < 1e-9) return ys[lo];
  return ys[lo] + (ys[hi] - ys[lo]) * (x - xs[lo]) / dx;
}

double _sbNiceStep(double range, int count) {
  final raw = range / count;
  if (raw <= 0) return 1;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final n = raw / mag;
  return (n < 1.5 ? 1 : n < 3 ? 2 : n < 7 ? 5 : 10) * mag;
}

double _sbNcdf(double x) {
  final t = 1 / (1 + 0.2316419 * x.abs());
  final d = 0.3989422804014327 * math.exp(-x * x / 2);
  final p = d * t * (0.31938153 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
  return x > 0 ? 1 - p : p;
}

/// Black-Scholes price — only used to shape the small decorative payoff
/// pictures on strategy cards. Real numbers always come from the payoff API.
double _sbBsPrice(String type, double s, double k, double t, double v) {
  const r = 0.065;
  if (t <= 0 || v <= 0) return type == 'CE' ? math.max(s - k, 0) : math.max(k - s, 0);
  final sq = math.sqrt(t);
  final d1 = (math.log(s / k) + (r + v * v / 2) * t) / (v * sq);
  final d2 = d1 - v * sq;
  final df = math.exp(-r * t);
  return type == 'CE' ? s * _sbNcdf(d1) - k * df * _sbNcdf(d2) : k * df * _sbNcdf(-d2) - s * _sbNcdf(-d1);
}

class _SbMiniLeg {
  final double s; // +1 buy, -1 sell
  final String t; // CE / PE
  final double k;
  final double q;
  final double e;
  const _SbMiniLeg(this.s, this.t, this.k, this.q, this.e);
}

const double _kSbShapeSpot = 22700, _kSbShapeStep = 50, _kSbShapeT = 7 / 365, _kSbShapeIv = .142;

List<_SbMiniLeg> _sbShapeFromSteps(List<(String action, String type, int steps, int lots)> legs) => [
      for (final l in legs)
        _SbMiniLeg(
          l.$1 == 'BUY' ? 1 : -1,
          l.$2,
          _kSbShapeSpot + l.$3 * _kSbShapeStep,
          l.$4.toDouble(),
          _sbBsPrice(l.$2, _kSbShapeSpot, _kSbShapeSpot + l.$3 * _kSbShapeStep, _kSbShapeT, _kSbShapeIv),
        ),
    ];

List<_SbMiniLeg> _sbPresetShape(PredefinedStrategy s) =>
    _sbShapeFromSteps([for (final l in s.legs) (l.action, l.optionType, l.strikeOffset, 1)]);

/// Saved strategies hold abstract legs (strike_type + strike_offset), so the
/// picture is drawn from those, the same way presets are.
List<_SbMiniLeg> _sbSavedShape(PredefinedStrategy s) {
  final legs = <(String, String, int, int)>[];
  for (final entry in s.savedApiLegs ?? const <Map<String, dynamic>>[]) {
    final leg = entry['leg'] as Map<String, dynamic>? ?? const {};
    final type = leg['option_type'] as String? ?? 'CE';
    final kind = leg['strike_type'] as String? ?? 'ATM';
    final off = (leg['strike_offset'] as num?)?.toInt() ?? 0;
    int steps = 0;
    if (kind == 'OTM') steps = type == 'CE' ? off : -off;
    if (kind == 'ITM') steps = type == 'CE' ? -off : off;
    legs.add((entry['action'] as String? ?? 'BUY', type, steps, (entry['ordlot'] as num?)?.toInt() ?? 1));
  }
  return _sbShapeFromSteps(legs);
}

String _sbSavedUnderlying(PredefinedStrategy s) {
  final legs = s.savedApiLegs;
  if (legs == null || legs.isEmpty) return '';
  final leg = legs.first['leg'] as Map<String, dynamic>? ?? const {};
  return (leg['symbol'] ?? '').toString();
}

// ---------------------------------------------------------------------------
// Small reusable widgets
// ---------------------------------------------------------------------------

/// Hover-aware tap target, used to mirror the CSS :hover states.
class _SbHover extends StatefulWidget {
  final Widget Function(bool hovered) builder;
  final VoidCallback? onTap;
  // Report hover even without onTap (e.g. the strategy name field)
  final bool trackHover;
  const _SbHover({required this.builder, this.onTap, this.trackHover = false});

  @override
  State<_SbHover> createState() => _SbHoverState();
}

class _SbHoverState extends State<_SbHover> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(_h && (enabled || widget.trackHover)),
      ),
    );
  }
}

/// Wraps the target-date box so tapping it opens the Option Analysis calendar
/// ([DashCalendarCard]) anchored just below the field.
class _SbDatePopover extends StatefulWidget {
  final DateTime selected;
  final List<DateTime> available;
  final ValueChanged<DateTime> onPick;
  final Widget Function(VoidCallback? onTap) builder;
  const _SbDatePopover({required this.selected, required this.available, required this.onPick, required this.builder});

  @override
  State<_SbDatePopover> createState() => _SbDatePopoverState();
}

class _SbDatePopoverState extends State<_SbDatePopover> {
  final OverlayPortalController _ctrl = OverlayPortalController();
  final LayerLink _link = LayerLink();

  // DashCalendarCard is 300 wide; ~300 tall with six week rows.
  static const double _cardW = 300, _cardH = 300, _gap = 6, _margin = 8;

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _ctrl,
      overlayChildBuilder: (overlayCtx) {
        // Keep the card on screen: open below the field, flip above when there
        // is no room, and shift sideways so it never crosses the screen edges.
        final screen = MediaQuery.sizeOf(overlayCtx);
        final box = context.findRenderObject() as RenderBox?;
        final pos = box != null && box.hasSize ? box.localToGlobal(Offset.zero) : Offset.zero;
        final size = box != null && box.hasSize ? box.size : Size.zero;
        final above = pos.dy + size.height + _gap + _cardH > screen.height - _margin && pos.dy - _gap - _cardH >= _margin;
        final left = (pos.dx + size.width / 2 - _cardW / 2)
            .clamp(_margin, math.max(_margin, screen.width - _cardW - _margin))
            .toDouble();
        return Stack(children: [
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _ctrl.hide, child: const SizedBox.expand()),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: above ? Alignment.topLeft : Alignment.bottomLeft,
            followerAnchor: above ? Alignment.bottomLeft : Alignment.topLeft,
            offset: Offset(left - pos.dx, above ? -_gap : _gap),
            child: DashCalendarCard(
              selected: widget.selected,
              available: widget.available,
              markToday: false,
              // Days outside today → expiry read as disabled.
              disabledDayColor: resolveThemeColor(context,
                      dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary)
                  .withValues(alpha: .4),
              onPick: (d) {
                _ctrl.hide();
                widget.onPick(d);
              },
            ),
          ),
        ]);
      },
      child: CompositedTransformTarget(
        link: _link,
        child: widget.builder(widget.available.isEmpty ? null : _ctrl.toggle),
      ),
    );
  }
}

/// Click-to-open card anchored under the widget from [builder], right edges
/// aligned; an outside click closes it. Holds the target price / date controls.
class _SbPopover extends StatefulWidget {
  final double width;
  final WidgetBuilder content;
  final Widget Function(VoidCallback toggle, bool open) builder;
  const _SbPopover({required this.width, required this.content, required this.builder});

  @override
  State<_SbPopover> createState() => _SbPopoverState();
}

class _SbPopoverState extends State<_SbPopover> {
  final OverlayPortalController _ctrl = OverlayPortalController();
  final LayerLink _link = LayerLink();
  static const double _gap = 6, _margin = 8;

  void _toggle() => setState(_ctrl.toggle);

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _ctrl,
      overlayChildBuilder: (overlayCtx) {
        final screen = MediaQuery.sizeOf(overlayCtx);
        final box = context.findRenderObject() as RenderBox?;
        final pos = box != null && box.hasSize ? box.localToGlobal(Offset.zero) : Offset.zero;
        final size = box != null && box.hasSize ? box.size : Size.zero;
        final left = (pos.dx + size.width - widget.width)
            .clamp(_margin, math.max(_margin, screen.width - widget.width - _margin))
            .toDouble();
        final maxH = math.max(120.0, screen.height - pos.dy - size.height - _gap - _margin);
        return Stack(children: [
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _toggle, child: const SizedBox.expand()),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: Offset(left - pos.dx, _gap),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.width, maxHeight: maxH),
              child: SingleChildScrollView(child: widget.content(overlayCtx)),
            ),
          ),
        ]);
      },
      child: CompositedTransformTarget(link: _link, child: widget.builder(_toggle, _ctrl.isShowing)),
    );
  }
}

/// Text input that only reports on Enter / blur, and re-syncs from [value]
/// while it is not focused (used for lots, multiplier, premium, target price).
class _SbCommitField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onCommit;
  final TextStyle style;
  final bool enabled;
  final bool decimal;
  const _SbCommitField({
    required this.value,
    required this.onCommit,
    required this.style,
    this.enabled = true,
    this.decimal = false,
  });

  @override
  State<_SbCommitField> createState() => _SbCommitFieldState();
}

class _SbCommitFieldState extends State<_SbCommitField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  void _commit() {
    if (_ctrl.text != widget.value) widget.onCommit(_ctrl.text);
  }

  @override
  void didUpdateWidget(covariant _SbCommitField old) {
    super.didUpdateWidget(old);
    // A new value from outside (e.g. the − / + buttons) always wins, even
    // while the field is focused; otherwise re-sync once focus has left.
    if (widget.value != old.value || (!_focus.hasFocus && _ctrl.text != widget.value)) {
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      enabled: widget.enabled,
      style: widget.style,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(widget.decimal ? r'[0-9.]' : r'[0-9]'))],
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),
      onSubmitted: (_) => _focus.unfocus(),
    );
  }
}

/// Search field used across the Strategy Builder — the same shared
/// MyntSearchTextField.withSmartClear the Positions page uses (search icon
/// asset, smart clear button, 40px height, radius 5).
class _SbSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  // Called when the field gains focus (e.g. select the current symbol).
  final VoidCallback? onFocus;
  // Solid background instead of the shared field's faint grey tint.
  final Color? fillColor;
  const _SbSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.focusNode,
    this.inputFormatters,
    this.onFocus,
    this.fillColor,
  });

  @override
  State<_SbSearchField> createState() => _SbSearchFieldState();
}

class _SbSearchFieldState extends State<_SbSearchField> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  void _onFocusChange() {
    if (_focus.hasFocus && widget.onFocus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFocus?.call());
    }
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Very light border with a soft 6px radius around the Positions search field.
    const radius = 6.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: resolveThemeColor(context, dark: const Color(0xFF262C34), light: const Color(0xFFE8EBF0)),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: _fill(MyntSearchTextField.withSmartClear(
          controller: widget.controller,
          focusNode: _focus,
          placeholder: widget.hint,
          leadingIcon: assets.searchIcon,
          borderRadius: radius - 1,
          height: 38,
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.inputFormatters != null ? TextCapitalization.characters : TextCapitalization.none,
          onChanged: widget.onChanged,
          onClear: () {
            widget.controller.clear();
            widget.onChanged('');
          },
        )),
      ),
    );
  }

  /// The shared field paints shadcn's `input` colour at 30% as its background;
  /// clearing it here (inherited by the field's own Theme copy) lets [fillColor] show.
  Widget _fill(Widget field) {
    final fill = widget.fillColor;
    if (fill == null) return field;
    final theme = shadcn.Theme.of(context);
    return ColoredBox(
      color: fill,
      child: shadcn.Theme(
        data: theme.copyWith(colorScheme: () => theme.colorScheme.copyWith(input: () => Colors.transparent)),
        child: field,
      ),
    );
  }
}

/// Dashed rounded border (CSS `border: 1px dashed`).
class _SbDashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _SbDashedBorderPainter(this.color, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < m.length) {
        canvas.drawPath(m.extractPath(dist, math.min(dist + 4, m.length)), paint);
        dist += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SbDashedBorderPainter old) => old.color != color || old.radius != radius;
}

void _sbDashedLine(Canvas canvas, Offset a, Offset b, Paint paint, double dash, double gap) {
  final total = (b - a).distance;
  if (total <= 0) return;
  final dir = (b - a) / total;
  var d = 0.0;
  while (d < total) {
    final e = math.min(d + dash, total);
    canvas.drawLine(a + dir * d, a + dir * e, paint);
    d += dash + gap;
  }
}

/// Draws [text] with its baseline at [y]; [anchor] is 'start' | 'middle' | 'end'.
void _sbPaintText(Canvas canvas, String text, double x, double y, TextStyle style,
    {String anchor = 'start', Color? halo}) {
  TextPainter mk(TextStyle st) => TextPainter(text: TextSpan(text: text, style: st), textDirection: TextDirection.ltr)..layout();
  final tp = mk(style);
  final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final dx = anchor == 'middle' ? x - tp.width / 2 : anchor == 'end' ? x - tp.width : x;
  final off = Offset(dx, y - base);
  if (halo != null) {
    mk(TextStyle(
      fontFamily: style.fontFamily,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..color = halo,
    )).paint(canvas, off);
  }
  tp.paint(canvas, off);
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

const int _kSbMiniPoints = 64;

/// Expiry payoff of [legs], sampled evenly around their strikes (presets).
List<double> _sbShapeYs(List<_SbMiniLeg> legs) {
  if (legs.isEmpty) return const [];
  final ks = legs.map((l) => l.k).toList();
  final center = ks.reduce((a, b) => a + b) / ks.length;
  final spread = ks.reduce(math.max) - ks.reduce(math.min);
  final unit = ks.reduce(math.max) * 0.007;
  final half = math.max(spread * 1.6, unit * 3);
  final lo = center - half, hi = center + half;
  return [
    for (var i = 0; i <= _kSbMiniPoints; i++)
      legs.fold(0.0, (a, l) {
        final p = lo + (hi - lo) * i / _kSbMiniPoints;
        return a + l.s * l.q * ((l.t == 'CE' ? math.max(p - l.k, 0) : math.max(l.k - p, 0)) - l.e);
      }),
  ];
}

/// The payoff API's expiry curve over the same price window the builder chart
/// opens with (middle 60% of the API range, see _sbOldAxes), sampled evenly.
List<double> _sbCurveYs(List<PayoffDataPoint> pts) {
  if (pts.length < 2) return const [];
  final xs = pts.map((d) => d.price).toList(), ys = pts.map((d) => d.profit).toList();
  final lo = xs.reduce(math.min), hi = xs.reduce(math.max);
  final from = (lo + hi) / 2 - (hi - lo) * .3, to = (lo + hi) / 2 + (hi - lo) * .3;
  return [for (var i = 0; i <= _kSbMiniPoints; i++) _sbInterp(xs, ys, from + (to - from) * i / _kSbMiniPoints)];
}

/// Mini payoff picture: green fill + line above zero, red below.
class _SbMiniPayoffPainter extends CustomPainter {
  final List<double> ys;
  final _SbC c;
  const _SbMiniPayoffPainter(this.ys, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    if (ys.length < 2 || size.width <= 0 || size.height <= 0) return;
    final w = size.width, h = size.height;
    final n = ys.length - 1;
    var mn = math.min(0.0, ys.reduce(math.min)), mx = math.max(0.0, ys.reduce(math.max));
    if (mx - mn < 1e-6) {
      mx = 1;
      mn = -1;
    }
    final pad = math.max(3.0, h * .12);
    double x(int i) => i / n * w;
    double y(double v) => pad + (mx - v) / (mx - mn) * (h - 2 * pad);
    final y0 = y(0);
    final line = Path()..moveTo(x(0), y(ys[0]));
    for (var i = 1; i <= n; i++) {
      line.lineTo(x(i), y(ys[i]));
    }
    final area = Path.from(line)
      ..lineTo(w, y0)
      ..lineTo(0, y0)
      ..close();
    final up = Rect.fromLTWH(0, 0, w, y0), dn = Rect.fromLTWH(0, y0, w, h);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.clipRect(up);
    canvas.drawPath(area, Paint()..color = const Color(0xFF00B14F).withValues(alpha: .13));
    canvas.drawPath(line, stroke..color = const Color(0xFF00A046));
    canvas.restore();
    canvas.save();
    canvas.clipRect(dn);
    canvas.drawPath(area, Paint()..color = const Color(0xFFFF1717).withValues(alpha: .08));
    canvas.drawPath(line, stroke..color = const Color(0xFFE5383B));
    canvas.restore();
    _sbDashedLine(canvas, Offset(0, y0), Offset(w, y0), Paint()..color = c.d ? const Color(0xFF4A525C) : const Color(0xFFC9CED8), 2, 3);
  }

  @override
  bool shouldRepaint(covariant _SbMiniPayoffPainter old) => old.ys != ys || old.c.d != c.d;
}

/// The bull-call-spread picture on the "Create your strategy" card.
class _SbCreateVisualPainter extends CustomPainter {
  final _SbC c;
  final double fs;
  const _SbCreateVisualPainter(this.c, this.fs);

  @override
  void paint(Canvas canvas, Size size) {
    // Same view box as the design (400 x 150), scaled to fit.
    const vw = 400.0, vh = 150.0;
    final s = math.min(size.width / vw, size.height / vh);
    canvas.save();
    canvas.translate((size.width - vw * s) / 2, (size.height - vh * s) / 2);
    canvas.scale(s);
    final legs = _sbShapeFromSteps([('BUY', 'CE', 0, 1), ('SELL', 'CE', 1, 1)]);
    const lo = 22450.0, hi = 23000.0, n = 60;
    final ys = <double>[];
    for (var i = 0; i <= n; i++) {
      final p = lo + (hi - lo) * i / n;
      ys.add(legs.fold(0.0, (a, l) => a + l.s * ((l.t == 'CE' ? math.max(p - l.k, 0) : math.max(l.k - p, 0)) - l.e)));
    }
    final mn = ys.reduce(math.min) * 1.7, mx = ys.reduce(math.max) * 1.7;
    double x(int i) => 10 + i / n * (vw - 20);
    double y(double v) => 16 + (mx - v) / (mx - mn) * (vh - 40);
    final y0 = y(0);
    final blue = c.blue;
    _sbDashedLine(canvas, Offset(10, y0), Offset(vw - 10, y0), Paint()..color = c.d ? const Color(0xFF3A4A66) : const Color(0xFFB7C5E6), 3, 4);
    final line = Path()..moveTo(x(0), y(ys[0]));
    for (var i = 1; i <= n; i++) {
      line.lineTo(x(i), y(ys[i]));
    }
    final area = Path.from(line)
      ..lineTo(vw - 10, y0)
      ..lineTo(10, y0)
      ..close();
    canvas.drawPath(area, Paint()..color = blue.withValues(alpha: .05));
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = blue.withValues(alpha: .55));
    final beX = x(math.max(0, ys.indexWhere((v) => v >= 0)));
    canvas.drawCircle(Offset(beX, y0), 5, Paint()..color = c.surface);
    canvas.drawCircle(
        Offset(beX, y0),
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = blue.withValues(alpha: .6));
    final st = TextStyle(fontFamily: MyntFonts.fontFamily, fontSize: 11, fontWeight: FontWeight.w500, color: c.text3);
    _sbPaintText(canvas, 'Breakeven', beX + 9, y0 + 17, st);
    _sbPaintText(canvas, 'Max profit', vw - 10, y(ys[n]) - 9, st, anchor: 'end');
    _sbPaintText(canvas, 'Max loss', 10, y(ys[0]) + 18, st);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SbCreateVisualPainter old) => old.c.d != c.d || old.fs != fs;
}

/// Soft colour blobs the frosted landing cards sit on.
class _SbGlassBackdropPainter extends CustomPainter {
  final bool dark;
  const _SbGlassBackdropPainter(this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    void blob(double cx, double cy, double rx, double ry, Color col) {
      final rect = Rect.fromCenter(center: Offset(size.width * cx, size.height * cy), width: size.width * rx * 2, height: size.height * ry * 2);
      canvas.drawOval(
          rect,
          Paint()
            ..shader = RadialGradient(colors: [col, col.withValues(alpha: 0)], stops: const [0, .7]).createShader(rect));
    }

    final k = dark ? .6 : 1.0;
    blob(.16, .5, .34, .8, const Color(0xFF0052CC).withValues(alpha: .09 * k));
    blob(.62, .5, .24, .75, const Color(0xFF10AA6E).withValues(alpha: .08 * k));
    blob(.89, .5, .24, .75, const Color(0xFF6D4AE0).withValues(alpha: .08 * k));
  }

  @override
  bool shouldRepaint(covariant _SbGlassBackdropPainter old) => old.dark != dark;
}

// ---------------------------------------------------------------------------
// The v2 UI, written as an extension so it shares the panel's State
// (controllers, option-chain dialog, skeletons).
// ---------------------------------------------------------------------------

extension _SbV2 on _StrategyBuilderPanelWebState {
  TextStyle _ts(double size, {FontWeight w = FontWeight.w400, Color? c, double? h}) =>
      webText(context, size: size, weight: w, color: c, height: h);

  double get _fs => context.fontScaleFactor;

  // ------------------------------------------------------------------ state

  List<PredefinedStrategy> _sbPresets(StrategyBuilderProvider p) {
    final list = [...p.predefinedStrategies];
    int idx(PredefinedStrategy s) {
      final i = _kSbPresetOrder.indexOf(s.title);
      return i < 0 ? 999 : i;
    }

    list.sort((a, b) => idx(a).compareTo(idx(b)));
    return list;
  }

  String _sbAutoName(StrategyBuilderProvider p) =>
      p.editingCustomBuilderName ??
      p.activePredefinedStrategy ??
      (p.basket.isEmpty ? 'New strategy' : 'Custom strategy');

  String _sbDisplayName(StrategyBuilderProvider p) => _customStrategyName ?? _sbAutoName(p);

  /// Strike interval of the loaded chain (fallback: 0.2% of spot).
  double _sbStep(StrategyBuilderProvider p) {
    final ks = <double>{
      for (final o in p.optionChain) double.tryParse(o.strprc ?? '') ?? 0,
    }.where((k) => k > 0).toList()
      ..sort();
    var best = double.infinity;
    for (var i = 1; i < ks.length; i++) {
      final d = ks[i] - ks[i - 1];
      if (d > 0 && d < best) best = d;
    }
    if (best.isFinite) return best;
    return p.spotPrice > 0 ? math.max(1, (p.spotPrice * 0.002).roundToDouble()) : 50;
  }

  String _sbSymbolShort(StrategyBuilderProvider p) => p.selectedSymbol.split(' ').first;

  double _sbTargetPrice(StrategyBuilderProvider p) =>
      p.isTargetSpotActive && p.targetSpotPrice > 0 ? p.targetSpotPrice : p.spotPrice;

  bool get _sbAnalyzeLoading {
    final p = ref.read(strategyBuilderProvider);
    return p.isLoading && p.isAnalyzeMode;
  }

  void _sbOpenBuilder() {
    _sbSet(() {
      _view = 'builder';
      _leftTab = 'legs';
      _legsFromApply = false;
      _customStrategyName = null;
    });
  }

  /// New empty strategy: opens the builder with the option chain on top, so
  /// legs can be picked straight away (the chain shows a loader until ready).
  /// Always starts on NIFTY 50; the user can switch symbol from there.
  void _sbCreateNew(StrategyBuilderProvider p) {
    p.clearBasket();
    _sbOpenBuilder();
    if (!_sbIsNifty(p)) {
      // Loads NIFTY 50 and raises shouldShowOptionChain, which opens the chain.
      p.selectStock(_kSbNifty, context);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showOptionChainDialog(context, p, ref.read(themeProvider).isDarkMode);
    });
  }

  bool _sbIsNifty(StrategyBuilderProvider p) =>
      p.selectedToken == _kSbNifty['token'] && p.selectedExch == _kSbNifty['exch'];

  /// Landing-page preset: always built on NIFTY 50 (the user can switch symbol
  /// afterwards). Inside the builder, presets use the selected symbol.
  Future<void> _sbOpenPresetOnNifty(StrategyBuilderProvider p, PredefinedStrategy s) async {
    _sbOpenBuilder();
    if (!_sbIsNifty(p)) await p.selectStock(_kSbNifty, context, showChain: false);
    if (mounted) await p.setActivePredefinedStrategy(s, context);
  }

  /// Copies the basket's API legs into the Custom builder rows, so the
  /// current legs can be edited as rules or saved (same rule fields the
  /// provider stores on every leg it builds).
  bool _sbDraftsFromBasket(StrategyBuilderProvider p) {
    final legs = p.basket.where((b) => b.checkbox && b.apiLeg != null).toList();
    if (legs.isEmpty) return false;
    p.toggleAllDraftLegCheckboxes(true);
    p.clearDraftLegs();
    for (final item in legs) {
      final a = item.apiLeg!;
      // The provider saves every rule with one expiry type (W for weekly
      // underlyings, M otherwise), so count the offset in the listed expiries.
      final listed = p.expiryDates.indexOf(item.expdate);
      p.addDraftLeg();
      final i = p.draftLegs.length - 1;
      p.updateDraftLeg(
        i,
        CustomStrategyLegDraft(
          action: item.buySell,
          ordlot: item.ordlot,
          optionType: a.optionType,
          expiryOffset: listed >= 0 ? listed : a.optionExpiryOffset,
          strikeType: a.strikeType ?? 'ATM',
          strikeOffset: a.strikeOffset,
          premiumValue: a.nearestPrice ?? 0,
        ),
      );
    }
    return true;
  }

  // =================================================================== root

  Widget _sbRoot(StrategyBuilderProvider p, bool isDark) {
    final c = _SbC(isDark);
    final builder = p.isAnalyzeMode || _view == 'builder';
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _sbUnfocusIfOutside,
      child: Container(
      color: c.bg,
      // Expand so the Stack (only positioned content) always fills the panel.
      constraints: const BoxConstraints.expand(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: builder ? _sbBuilder(p, c) : _sbLanding(p, c)),
          if (p.searchDropdownVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => p.dismissSearchDropdown(),
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
          if (builder) _sbSymbolDropdown(p, c),
        ],
      ),
      ),
    );
  }

  /// Any click outside the focused text field (search boxes, name, inputs)
  /// drops its focus. Done here because TextField.onTapOutside does not fire
  /// in this app shell.
  void _sbUnfocusIfOutside(PointerDownEvent e) {
    final node = FocusManager.instance.primaryFocus;
    final box = node?.context?.findRenderObject();
    if (node == null || box is! RenderBox || !box.attached || !box.hasSize) return;
    final local = box.globalToLocal(e.position);
    if (!(Offset.zero & box.size).contains(local)) node.unfocus();
  }

  // ================================================================ landing

  Widget _sbLanding(StrategyBuilderProvider p, _SbC c) {
    return LayoutBuilder(builder: (context, outer) {
      final padH = outer.maxWidth <= 640 ? 16.0 : 28.0;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(padH, 20, padH, 40),
        child: LayoutBuilder(builder: (context, cons) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Option Strategy '),
                    TextSpan(text: 'Builder', style: TextStyle(color: c.blue)),
                    const TextSpan(text: '.'),
                  ]),
                  style: _ts(30, w: FontWeight.w800, c: c.text, h: 1.2).copyWith(letterSpacing: -.45),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Text(
                  'Build, visualise and trade options strategies — understand the risk before placing them.',
                  style: _ts(14, c: c.text2, h: 1.5),
                ),
              ),
              _sbHeroCards(p, c, cons.maxWidth),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.only(top: 18),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
                child: _landingTab == 'strategies' ? _sbLandingStrategies(p, c, cons.maxWidth) : _sbLandingSaved(p, c, cons.maxWidth),
              ),
            ],
          );
        }),
      );
    });
  }

  Widget _sbHeroCards(StrategyBuilderProvider p, _SbC c, double w) {
    final presets = p.predefinedStrategies;
    final saved = p.customStrategies;
    int count(String t) => presets.where((s) => s.type == t).length;

    // No LayoutBuilder here: these cards sit inside IntrinsicHeight.
    // Each card is [content, action]: the action is pinned to the bottom so
    // buttons line up across cards of equal height.
    final showVis = w >= 700;
    final createBody = _sbCardBody(
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _sbCardTitle(c, 'Create your ', 'strategy', c.blue),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              'Add legs from the option chain or define them relative to ATM. Payoff, POP and margin update as you build, then every leg is placed in one step.',
              style: _ts(13.5, c: c.text2, h: 1.55),
            ),
          ),
        ),
      ]),
      _sbBtn(c, 'Create Strategy  →', primary: true, height: 36, fontSize: 14, onTap: () => _sbCreateNew(p)),
    );
    Widget create = _sbGlassCard(
      c,
      accent: c.blue,
      light: const [Color(0xE6F7F9FE), Color(0xB3F0F4FC)],
      child: !showVis
          ? createBody
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 58, child: createBody),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 42,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: (c.d ? Colors.black : Colors.white).withValues(alpha: c.d ? .2 : .7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: CustomPaint(painter: _SbCreateVisualPainter(c, _fs)),
                    ),
                  ),
                ],
              ),
            ),
    );

    const green = Color(0xFF0B7A52);
    const violet = Color(0xFF5A3BD0);
    final greenText = c.d ? const ui.Color(0xFF1B5C42) : green;
    final violetText = c.d ? const ui.Color(0xFF4B3C83) : violet;

    // Template / saved cards act as tabs for the list below: the whole card is
    // the click target and the active one is outlined.
    final templateOn = _landingTab == 'strategies';
    Widget template = _sbGlassCard(
      c,
      accent: green,
      light: const [Color(0xE6F6FCF9), Color(0xB3ECF9F2)],
      selected: templateOn,
      onTap: () => _sbSet(() {
        _landingTab = 'strategies';
        _landingSearchController.clear();
      }),
      child: _sbCardBody(
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _sbCardTitle(c, 'Start from a ', 'template', greenText),
          _sbCardFigure(c, '${presets.length}', 'ready-made strategies'),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${count('Bullish')}', style: TextStyle(color: c.profit, fontWeight: FontWeight.w600)),
                const TextSpan(text: ' bullish · '),
                TextSpan(text: '${count('Bearish')}', style: TextStyle(color: c.loss, fontWeight: FontWeight.w600)),
                const TextSpan(text: ' bearish · '),
                TextSpan(text: '${count('Neutral')}', style: TextStyle(color: c.blue, fontWeight: FontWeight.w600)),
                const TextSpan(text: ' neutral'),
              ]),
              style: _ts(13, c: c.text2, h: 1.5),
            ),
          ),
        ]),
        _sbCardHint(c, templateOn, c.d ? const Color(0xFF3FCF96) : green),
      ),
    );

    final last = saved.isNotEmpty ? saved.last : null;
    final savedOn = _landingTab == 'saved';
    Widget savedCard = _sbGlassCard(
      c,
      accent: violet,
      light: const [Color(0xE6FAF8FF), Color(0xB3F3F0FE)],
      selected: savedOn,
      onTap: () => _sbSet(() {
        _landingTab = 'saved';
        _landingSearchController.clear();
      }),
      child: _sbCardBody(
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _sbCardTitle(c, 'Your ', 'strategies', violetText),
          _sbCardFigure(c, '${saved.length}', 'saved'),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(last != null ? 'Last saved' : 'Nothing saved yet', style: _ts(13, c: c.text2, h: 1.5)),
                Text(last?.title ?? 'Save a strategy to reopen it here',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: _ts(13, w: FontWeight.w500, c: c.text, h: 1.5)),
              ],
            ),
          ),
        ]),
        _sbCardHint(c, savedOn, c.d ? const Color(0xFFA48BFF) : violet),
      ),
    );

    Widget layout;
    if (w > 1100) {
      layout = IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 6, child: create),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: template),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: savedCard),
        ]),
      );
    } else if (w > 700) {
      layout = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        create,
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: template),
            const SizedBox(width: 12),
            Expanded(child: savedCard),
          ]),
        ),
      ]);
    } else {
      layout = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        create,
        const SizedBox(height: 12),
        template,
        const SizedBox(height: 12),
        savedCard,
      ]);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(left: -10, right: -10, top: -20, bottom: -20, child: IgnorePointer(child: CustomPaint(painter: _SbGlassBackdropPainter(c.d)))),
        layout,
      ],
    );
  }

  /// Card content on top, [action] pinned to the bottom. In a stretched row
  /// (bounded height) spaceBetween lines the actions up; stacked (unbounded)
  /// it just stacks them.
  Widget _sbCardBody(Widget content, Widget action) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [content, action],
      );

  /// Borderless frosted card. [light] is the light-mode gradient (top-left →
  /// bottom-right); dark mode tints the card surface with [accent].
  /// With [onTap] the whole card is clickable; [selected] outlines it in [accent].
  Widget _sbGlassCard(_SbC c,
      {required Color accent, required List<Color> light, required Widget child, bool selected = false, VoidCallback? onTap}) {
    final colors = c.d
        ? [
            Color.alphaBlend(accent.withValues(alpha: .14), MyntColors.cardDark).withValues(alpha: .9),
            Color.alphaBlend(accent.withValues(alpha: .05), MyntColors.cardDark).withValues(alpha: .75),
          ]
        : light;
    Widget card(bool h) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
              ),
              // Outline drawn on top so selecting a card never shifts its layout.
              foregroundDecoration: onTap == null
                  ? null
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        width: 1.5,
                        color: selected ? accent : (h ? accent.withValues(alpha: .35) : Colors.transparent),
                      ),
                    ),
              child: child,
            ),
          ),
        );
    return onTap == null ? card(false) : _SbHover(onTap: onTap, builder: card);
  }

  /// Bottom line of a selectable landing card: tells the user the card swaps
  /// the list below (it does not open a new page).
  Widget _sbCardHint(_SbC c, bool selected, Color accent) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(selected ? 'Showing below' : 'View list',
            style: _ts(13, w: FontWeight.w600, c: selected ? accent : c.text2)),
        const SizedBox(width: 4),
        Icon(Icons.arrow_downward, size: 14, color: selected ? accent : c.text2),
      ]);

  Widget _sbCardTitle(_SbC c, String a, String b, Color accent) => Text.rich(
        TextSpan(children: [TextSpan(text: a), TextSpan(text: b, style: TextStyle(color: accent))]),
        style: _ts(18, w: FontWeight.w600, c: c.text, h: 1.25).copyWith(letterSpacing: -.18),
      );

  /// Key figure ("15 ready-made strategies") under a card title.
  Widget _sbCardFigure(_SbC c, String fig, String label) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(fig, style: _ts(32, w: FontWeight.w700, c: c.text, h: 1).copyWith(letterSpacing: -.96)),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ts(13, c: c.text3))),
          ],
        ),
      );

  Widget _sbSectionHead(_SbC c, String title, String sub, Widget? tools, double w) {
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: _ts(17, w: FontWeight.w600, c: c.text)),
      const SizedBox(height: 2),
      Text(sub, style: _ts(13, c: c.text3)),
    ]);
    if (tools == null) return text;
    if (w < 900) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [text, const SizedBox(height: 14), tools]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: text), tools]);
  }

  Widget _sbSearchBox(_SbC c, TextEditingController ctrl, String hint, VoidCallback onChanged,
      {double? width, bool compact = false, Color? fillColor}) {
    final field = _SbSearchField(
      controller: ctrl,
      hint: hint,
      onChanged: (_) => onChanged(),
      fillColor: fillColor,
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }

  Widget _sbLandingStrategies(StrategyBuilderProvider p, _SbC c, double w) {
    final q = _landingSearchController.text.trim().toLowerCase();
    final all = _sbPresets(p);
    final list = q.isNotEmpty
        ? all.where((s) => [s.title, s.type, _kSbRisk[s.title] ?? ''].any((x) => x.toLowerCase().contains(q))).toList()
        : _landingFilter == 'All'
            ? all
            : all.where((s) => s.type == _landingFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sbSectionHead(
          c,
          'Explore strategies',
          'Start quickly with commonly used options strategies.',
          _sbSearchBox(c, _landingSearchController, 'Search strategies', () => _sbSet(() {}),
              width: w < 900 ? null : 300, compact: true, fillColor: c.surface),
          w,
        ),
        const SizedBox(height: 12),
        _sbSegmented(c, ['All', 'Bullish', 'Bearish', 'Neutral'], q.isEmpty ? _landingFilter : null, (f) {
          _sbSet(() {
            _landingFilter = f;
            _landingSearchController.clear();
          });
        }),
        const SizedBox(height: 14),
        list.isEmpty
            ? _sbEmptyBox(c, 'No strategy matches “${_landingSearchController.text.trim()}”',
                'Try a name like Straddle, or a view like Bullish.', null)
            : _sbGrid(
                minItem: 240,
                gap: 14,
                children: [
                  for (final s in list)
                    _sbPresetCard(c, s, small: false, active: false, onTap: () {
                      _sbOpenPresetOnNifty(p, s);
                    }),
                ],
              ),
      ],
    );
  }

  Widget _sbLandingSaved(StrategyBuilderProvider p, _SbC c, double w) {
    final saved = p.customStrategies;
    final q = _landingSearchController.text.trim().toLowerCase();
    final list = saved
        .where((s) => q.isEmpty || s.title.toLowerCase().contains(q) || _sbSavedUnderlying(s).toLowerCase().contains(q))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sbSectionHead(
          c,
          'Saved strategies',
          'Strategies you saved. Open one to edit it or place the order.',
          saved.isEmpty
              ? null
              : _sbSearchBox(c, _landingSearchController, 'Search saved strategies', () => _sbSet(() {}),
                  width: w < 900 ? null : 300, compact: true, fillColor: c.surface),
          w,
        ),
        const SizedBox(height: 12),
        _sbSavedList(p, c, list, minItem: 240, gap: 14, onCreate: () => _sbCreateNew(p)),
      ],
    );
  }

  Widget _sbSavedList(StrategyBuilderProvider p, _SbC c, List<PredefinedStrategy> list,
      {required double minItem, required double gap, required VoidCallback onCreate, String? query}) {
    final all = p.customStrategies;
    final q = (query ?? _landingSearchController.text).trim();
    if (list.isEmpty) {
      if (q.isNotEmpty && all.isNotEmpty) {
        return _sbEmptyBox(c, 'No saved strategy matches “$q”', null, null);
      }
      return _sbEmptyBox(c, 'Your saved strategies will appear here.', null,
          _sbBtn(c, 'Create strategy', primary: true, onTap: onCreate));
    }
    return _sbGrid(minItem: minItem, gap: gap, children: [
      for (final s in list) _sbSavedCard(p, c, s),
    ]);
  }

  Widget _sbSegmented(_SbC c, List<String> items, String? selected, ValueChanged<String> onTap) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++)
              _SbHover(
                onTap: () => onTap(items[i]),
                builder: (_) {
                  final on = items[i] == selected;
                  return Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? c.btnBg : null,
                      border: i > 0 ? Border(left: BorderSide(color: c.line)) : null,
                    ),
                    child: Text(items[i],
                        style: _ts(13, w: on ? FontWeight.w600 : FontWeight.w500, c: on ? Colors.white : c.text2)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _sbGrid({required double minItem, required double gap, required List<Widget> children}) {
    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth;
      final cols = math.max(1, ((w + gap) / (minItem + gap)).floor());
      final itemW = (w - gap * (cols - 1)) / cols - 0.01;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: itemW, child: ch)],
      );
    });
  }

  Widget _sbEmptyBox(_SbC c, String title, String? sub, Widget? action, {bool column = false}) {
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(title, style: _ts(14, w: FontWeight.w600, c: c.text)),
      if (sub != null) ...[const SizedBox(height: 2), Text(sub, style: _ts(13, c: c.text3))],
    ]);
    return CustomPaint(
      painter: _SbDashedBorderPainter(c.d ? c.line : const Color(0xFFB9C3D1), 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(8)),
        child: action == null
            ? text
            : column
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 12), action])
                : Row(children: [Expanded(child: text), const SizedBox(width: 16), action]),
      ),
    );
  }

  Widget _sbActiveBadge(_SbC c) => Positioned(
        top: 5,
        left: 5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(color: c.btnBg, borderRadius: BorderRadius.circular(4)),
          child: Text('Active', style: _ts(10.5, w: FontWeight.w700, c: Colors.white, h: 1.6).copyWith(letterSpacing: .2)),
        ),
      );

  Widget _sbPresetCard(_SbC c, PredefinedStrategy s,
      {required bool small, required bool active, required VoidCallback onTap}) {
    final dirColor = s.type == 'Bullish' ? c.profit : s.type == 'Bearish' ? c.loss : c.blue;
    final arrow = s.type == 'Bullish' ? '↗' : s.type == 'Bearish' ? '↘' : '→';
    final metaSize = small ? 11.5 : 12.5;
    return _SbHover(
      onTap: onTap,
      builder: (_) => Container(
        padding: small ? const EdgeInsets.fromLTRB(8, 8, 8, 10) : const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? c.blue : c.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(children: [
              Container(
                height: small ? 42 : 60,
                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(6)),
                clipBehavior: Clip.antiAlias,
                child: CustomPaint(painter: _SbMiniPayoffPainter(_sbShapeYs(_sbPresetShape(s)), c), size: Size.infinite),
              ),
              if (active) _sbActiveBadge(c),
            ]),
            Padding(
              padding: small ? const EdgeInsets.fromLTRB(2, 8, 2, 0) : const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ts(small ? 13 : 14.5, w: FontWeight.w600, c: c.text)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: small ? 4 : 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '$arrow ', style: TextStyle(color: dirColor)),
                      TextSpan(text: s.type),
                    ]), style: _ts(metaSize, w: FontWeight.w600, c: c.text2)),
                    Text('·', style: _ts(metaSize, c: c.text3)),
                    Text(_kSbRisk[s.title] ?? '', style: _ts(metaSize, c: c.text3)),
                  ],
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sbSavedCard(StrategyBuilderProvider p, _SbC c, PredefinedStrategy s, {bool small = false}) {
    final cur = _view == 'builder' && p.editingCustomBuilderName == s.title;
    final n = s.savedApiLegs?.length ?? s.legs.length;
    final und = _sbSavedUnderlying(s);
    final metaSize = small ? 11.5 : 12.5;
    final metaStyle = _ts(metaSize, c: c.text3);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cur ? c.blue : c.cardBorder),
      ),
      child: Stack(
        children: [
          _SbHover(
            onTap: () => _sbOpenSaved(p, s),
            builder: (_) => Padding(
              padding: small ? const EdgeInsets.fromLTRB(8, 8, 8, 10) : const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(children: [
                    Container(
                      height: small ? 42 : 60,
                      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(6)),
                      clipBehavior: Clip.antiAlias,
                      child: _sbSavedPicture(p, c, s),
                    ),
                    if (cur) _sbActiveBadge(c),
                  ]),
                  Padding(
                    padding: small ? const EdgeInsets.fromLTRB(2, 8, 30, 0) : const EdgeInsets.fromLTRB(4, 12, 34, 0),
                    child: Row(children: [
                      Flexible(
                        child: Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _ts(small ? 13 : 14.5, w: FontWeight.w600, c: c.text)),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(color: c.blueTint2, borderRadius: BorderRadius.circular(6)),
                        child: Text('Custom', style: _ts(11, w: FontWeight.w600, c: c.blue)),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: small ? const EdgeInsets.fromLTRB(2, 4, 2, 0) : const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Wrap(spacing: small ? 4 : 6, children: [
                      if (und.isNotEmpty) ...[
                        Text(und, style: _ts(metaSize, w: FontWeight.w600, c: c.text2)),
                        Text('·', style: metaStyle),
                      ],
                      Text('$n leg${n == 1 ? '' : 's'}', style: metaStyle),
                      if (cur) ...[Text('·', style: metaStyle), Text('Editing', style: metaStyle)],
                    ]),
                  ),
                ],
              ),
            ),
          ),
          Positioned(top: small ? 50 : 74, right: small ? 4 : 6, child: _sbSavedMenu(p, c, s)),
        ],
      ),
    );
  }

  /// Saved card picture: the real payoff the strategy opens with. Shimmer
  /// while it loads; the rule-based sketch only if it could not be computed.
  Widget _sbSavedPicture(StrategyBuilderProvider p, _SbC c, PredefinedStrategy s) {
    final pts = p.savedPreview(s);
    if (pts == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => p.loadSavedPreview(s));
      return const MyntShimmerLoader(width: double.infinity, height: double.infinity, borderRadius: 6);
    }
    final ys = pts.length >= 2 ? _sbCurveYs(pts) : _sbShapeYs(_sbSavedShape(s));
    return CustomPaint(painter: _SbMiniPayoffPainter(ys, c), size: Size.infinite);
  }

  Widget _sbSavedMenu(StrategyBuilderProvider p, _SbC c, PredefinedStrategy s) {
    return PopupMenuButton<String>(
      tooltip: 'More actions for ${s.title}',
      padding: EdgeInsets.zero,
      color: c.surface,
      elevation: 0,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 170),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: c.line)),
      onSelected: (v) {
        if (v == 'open') _sbOpenSaved(p, s);
        if (v == 'del') _sbDeleteDialog(p, c, s.title);
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'open', height: 36, child: Text('Open', style: _ts(13.5, c: c.text))),
        PopupMenuItem(value: 'del', height: 36, child: Text('Delete', style: _ts(13.5, c: c.loss))),
      ],
      child: SizedBox(
        width: 30,
        height: 30,
        // Material icon, not the '⋯' glyph: Geist has no U+22EF, and the
        // runtime font fallback would need Google's font CDN.
        child: Center(child: Icon(Icons.more_horiz, size: 20, color: c.text3)),
      ),
    );
  }

  void _sbOpenSaved(StrategyBuilderProvider p, PredefinedStrategy s) {
    final already = _view == 'builder' && p.editingCustomBuilderName == s.title && p.basket.isNotEmpty;
    _sbOpenBuilder();
    if (!already) p.setActivePredefinedStrategy(s, context);
  }

  // ================================================================ builder

  Widget _sbBuilder(StrategyBuilderProvider p, _SbC c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!p.isAnalyzeMode || widget.onBack != null) _sbTopBar(p, c),
        Expanded(
          child: LayoutBuilder(builder: (context, cons) {
            final w = cons.maxWidth, h = cons.maxHeight;
            if (w <= 1023) return _sbNarrowLayout(p, c, w);
            final mid = w <= 1240;
            final legsCap = math.min(900.0, w * (mid ? .46 : .38));
            final legsW = _StrategyBuilderPanelWebState._legsPanelWidth.clamp(math.min(400.0, legsCap), legsCap).toDouble();

            Widget right;
            if (!mid) {
              right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _sbKpis(p, c, 7),
                Expanded(child: _sbChartCol(p, c)),
              ]);
            } else {
              right = SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _sbKpis(p, c, 3),
                  SizedBox(height: math.max(380.0, h - 160), child: _sbChartCol(p, c)),
                ]),
              );
            }

            return Stack(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(width: legsW, child: _sbLegsPanel(p, c)),
                Expanded(child: right),
              ]),
              Positioned(top: 0, bottom: 0, left: legsW - 4, width: 9, child: _sbResizer(c, w)),
            ]);
          }),
        ),
      ],
    );
  }

  Widget _sbNarrowLayout(StrategyBuilderProvider p, _SbC c, double w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _legsScrollController,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _sbKpis(p, c, w < 640 ? 2 : 4),
              Container(
                height: w < 640 ? 300 : 360,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                child: _sbChartCol(p, c),
              ),
              // Fixed-height block so the legs table scrolls inside it.
              Container(color: c.surface, height: 460, child: _sbLegsContent(p, c)),
            ]),
          ),
        ),
        if (!p.isAnalyzeMode) _sbLegsFoot(p, c),
      ],
    );
  }

  /// Drag handle between the legs panel and the chart.
  Widget _sbResizer(_SbC c, double totalW) {
    return _SbResizeHandle(
      color: c.blue,
      onDrag: (dx) {
        _sbSet(() {
          final cap = math.min(900.0, totalW * (totalW <= 1240 ? .46 : .38));
          final lo = math.min(400.0, cap);
          _StrategyBuilderPanelWebState._legsPanelWidth =
              (_StrategyBuilderPanelWebState._legsPanelWidth.clamp(lo, cap) + dx).clamp(lo, cap).toDouble();
        });
      },
      onReset: () => _sbSet(() => _StrategyBuilderPanelWebState._legsPanelWidth = 620),
    );
  }

  Widget _sbTopBar(StrategyBuilderProvider p, _SbC c) {
    final name = _sbDisplayName(p);
    if (!_nameFocus.hasFocus && _nameController.text != name) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_nameFocus.hasFocus) _nameController.text = _sbDisplayName(ref.read(strategyBuilderProvider));
      });
    }
    // Analyze mode (embedded in Positions): back returns to Positions; the
    // panel ending ends analyze mode (see dispose).
    final analyze = p.isAnalyzeMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Tooltip(
            message: analyze ? 'Back to Positions' : 'Back',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: analyze ? widget.onBack : () => _sbSet(() => _view = 'landing'),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.arrow_back, size: 20, color: c.text),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (analyze)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('Analyze positions', style: _ts(17, w: FontWeight.w700, c: c.text)),
            )
          else
          SizedBox(
            width: 260,
            child: _SbHover(
              trackHover: true,
              builder: (h) => TextField(
                controller: _nameController,
                focusNode: _nameFocus,
                style: _ts(17, w: FontWeight.w700, c: c.text),
                maxLength: 60,
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 3),
                  border: InputBorder.none,
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: h ? c.text3 : Colors.transparent, style: BorderStyle.solid)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.text3)),
                ),
                onChanged: (v) => _sbSet(() => _customStrategyName = v.trim().isEmpty ? null : v),
                onSubmitted: (_) => _nameFocus.unfocus(),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ legs panel

  Widget _sbLegsPanel(StrategyBuilderProvider p, _SbC c) {
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(right: BorderSide(color: c.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _sbLegsContent(p, c)),
          if (!p.isAnalyzeMode) _sbLegsFoot(p, c),
        ],
      ),
    );
  }

  /// Tabs stay fixed; inside each pane only the table / grid scrolls.
  /// Needs a bounded height.
  Widget _sbLegsContent(StrategyBuilderProvider p, _SbC c) {
    final analyze = p.isAnalyzeMode;
    final tab = analyze ? 'legs' : _leftTab;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sbLeftTabs(p, c, analyze),
        Expanded(
          child: tab == 'pre'
              ? _sbPredefPane(p, c)
              : tab == 'cus'
                  ? _sbCustomPane(p, c)
                  : tab == 'saved'
                      ? _sbSavedPane(p, c)
                      : _sbLegsPane(p, c),
        ),
      ],
    );
  }

  Widget _sbLeftTabs(StrategyBuilderProvider p, _SbC c, bool analyze) {
    Widget tab(String id, String label, int count) {
      final on = (analyze ? 'legs' : _leftTab) == id;
      return _SbHover(
        onTap: analyze
            ? null
            : () {
                if (id == 'cus' && p.draftLegs.isEmpty && p.basket.isNotEmpty) _sbDraftsFromBasket(p);
                _sbSet(() {
                  _leftTab = id;
                  _legsFromApply = false;
                });
              },
        builder: (h) => Container(
          padding: const EdgeInsets.only(top: 6, bottom: 7),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: on ? c.blue : Colors.transparent, width: 2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: _ts(13.5, w: FontWeight.w600, c: on || h ? c.text : c.text3)),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: c.blueTint2, borderRadius: BorderRadius.circular(6)),
                child: Text('$count', style: _ts(11.5, w: FontWeight.w600, c: c.blue)),
              ),
          ]),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.lineSoft))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          tab('legs', 'Strategy legs', p.basket.length),
          if (!analyze) ...[
            const SizedBox(width: 18),
            tab('pre', 'Predefined', p.predefinedStrategies.length),
            const SizedBox(width: 18),
            tab('cus', 'Custom builder', p.draftLegs.length),
            const SizedBox(width: 18),
            tab('saved', 'Saved', p.customStrategies.length),
          ],
        ]),
      ),
    );
  }

  Widget _sbLegsPane(StrategyBuilderProvider p, _SbC c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.isAnalyzeMode)
          buildStrategyAnalyzeHeader(context: context, provider: p, isDark: c.d)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              Expanded(child: _sbSymbolField(p, c)),
              const SizedBox(width: 8),
              _sbBtn(c, 'Chain',
                  height: 40,
                  fontWeight: FontWeight.w600,
                  textColor: c.blue,
                  borderColor: c.chainBorder,
                  onTap: p.optionChain.isNotEmpty ? () => _showOptionChainDialog(context, p, c.d) : null),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Refresh entry prices to LTP',
                child: _sbBtn(c, '',
                    height: 40,
                    width: 40,
                    padH: 0,
                    icon: Icon(Icons.refresh, size: 18, color: c.text2),
                    onTap: p.basket.isNotEmpty ? () => p.refreshEntryPrices(context) : null),
              ),
            ]),
          ),
        Expanded(child: _sbLegsTable(p, c)),
      ],
    );
  }

  /// Table whose header stays put while only the rows scroll vertically;
  /// header and rows scroll horizontally together when the panel is narrow.
  Widget _sbScrollTable(_SbC c, double tableW, Widget header, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      // Table is only as tall as its rows (up to the pane), so the thin
      // always-visible thumb sits right under the last row. It only paints
      // when the table overflows sideways.
      child: Align(
        alignment: Alignment.topCenter,
        child: RawScrollbar(
          controller: _tableHScroll,
          thumbVisibility: true,
          thickness: 6,
          radius: const Radius.circular(3),
          crossAxisMargin: 2,
          mainAxisMargin: 4,
          thumbColor: c.text3.withValues(alpha: .45),
          child: SingleChildScrollView(
            controller: _tableHScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableW,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                header,
                Flexible(
                  child: ListView(primary: false, shrinkWrap: true, padding: EdgeInsets.zero, children: rows),
                ),
                // Room for the thumb so it doesn't cover the last row.
                const SizedBox(height: 10),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sbSymbolField(StrategyBuilderProvider p, _SbC c) {
    return CompositedTransformTarget(
      link: _searchLayerLink,
      child: SizedBox(
        key: _searchFieldKey,
        child: _SbSearchField(
          controller: _searchController,
          focusNode: _symbolFocus,
          hint: 'Search underlying',
          inputFormatters: [
            TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
          ],
          onFocus: () {
            if (_searchController.text == p.selectedSymbol) {
              _searchController.selection = TextSelection(baseOffset: 0, extentOffset: _searchController.text.length);
            }
          },
          onChanged: (v) => p.searchStocks(v),
        ),
      ),
    );
  }

  Widget _sbSymbolDropdown(StrategyBuilderProvider p, _SbC c) {
    if (!p.searchDropdownVisible) return const SizedBox.shrink();
    return CompositedTransformFollower(
      link: _searchLayerLink,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 4),
      child: Builder(builder: (context) {
        final width = (_searchFieldKey.currentContext?.findRenderObject() as RenderBox?)?.size.width ?? 300;
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: p.searchLoading
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    : p.searchResults.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Text('No symbol matches.', style: _ts(13, c: c.text3)),
                          )
                        : ListView(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: [
                              for (final r in p.searchResults)
                                _SbHover(
                                  onTap: () async {
                                    final name = (r['displayName'] ?? r['tsym'] ?? '').toString();
                                    _searchController.text = name;
                                    _lastSelectedSymbol = name;
                                    FocusScope.of(context).unfocus();
                                    await p.selectStock(r, this.context);
                                  },
                                  builder: (h) => Container(
                                    color: h ? c.blueTint : null,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(children: [
                                      Expanded(
                                        child: Text((r['displayName'] ?? r['tsym'] ?? '').toString().toUpperCase(),
                                            overflow: TextOverflow.ellipsis, style: _ts(13.5, w: FontWeight.w600, c: c.text)),
                                      ),
                                      const SizedBox(width: 10),
                                      Text((r['exch'] ?? '').toString(), style: _ts(12, w: FontWeight.w500, c: c.text3)),
                                    ]),
                                  ),
                                ),
                            ],
                          ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Total row width for [widths] (cells + gaps + row padding of _sbRowWrap).
  double _sbRowWidth(List<double> widths) => widths.fold(0.0, (a, b) => a + b) + 6 * (widths.length - 1) + 24;

  /// Splits [total] into fixed + flexible column widths (CSS grid minmax/fr).
  List<double> _sbColumns(double total, List<double> fixed, List<double> fr, List<double> mins, double gap, double padL, double padR) {
    final fixedSum = fixed.where((f) => f > 0).fold(0.0, (a, b) => a + b);
    final cols = fixed.length;
    final free = total - padL - padR - gap * (cols - 1) - fixedSum;
    final frSum = fr.fold(0.0, (a, b) => a + b);
    var j = 0;
    return [
      for (var i = 0; i < cols; i++)
        if (fixed[i] > 0) fixed[i] else math.max(mins[j], free * fr[j++] / frSum),
    ];
  }

  Widget _sbRowWrap(_SbC c, List<double> widths, List<Widget> cells,
      {bool header = false, double opacity = 1, int keepOpaque = -1, Color? bg}) {
    return Container(
      constraints: BoxConstraints(minHeight: header ? 30 : 44),
      padding: const EdgeInsets.only(left: 14, right: 10),
      decoration: BoxDecoration(
        color: bg ?? (header ? c.surface2 : null),
        border: Border(bottom: BorderSide(color: c.lineSoft)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            SizedBox(
              width: widths[i],
              child: opacity < 1 && i != keepOpaque ? Opacity(opacity: opacity, child: cells[i]) : cells[i],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sbHead(_SbC c, String t, {TextAlign align = TextAlign.left, String? tip}) {
    final text = Text(t, textAlign: align, style: _ts(11.5, w: FontWeight.w600, c: c.text3));
    return tip == null ? text : Tooltip(message: tip, child: text);
  }

  Widget _sbLegsTable(StrategyBuilderProvider p, _SbC c) {
    if (p.basket.isEmpty) {
      if (_sbAnalyzeLoading) return SingleChildScrollView(child: _buildBasketTableSkeleton(c.d));
      return Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line), bottom: BorderSide(color: c.lineSoft))),
          padding: const EdgeInsets.all(14),
          child: Text('No legs yet. Open the Chain to add legs, or pick one from Predefined or Saved.', style: _ts(13, c: c.text3)),
        ),
      );
    }
    final lotSize = p.basket.first.lotSize;
    return LayoutBuilder(builder: (context, cons) {
      final widths = _sbColumns(math.max(cons.maxWidth, 560.0), const [34, 0, 0, 36, 0, 0, 0, 28, 24], const [.9, 1.2, 1, .8, .7],
          const [72, 92, 80, 84, 52], 6, 14, 10);
      final tableW = math.max(cons.maxWidth, _sbRowWidth(widths));
      final header = _sbRowWrap(c, widths, [
        _sbHead(c, 'B/S'),
        _sbHead(c, 'Expiry'),
        _sbHead(c, 'Strike'),
        _sbHead(c, 'Type'),
        _sbHead(c, 'Lots', tip: '1 lot = $lotSize qty'),
        _sbHead(c, 'Entry', align: TextAlign.right),
        _sbHead(c, 'LTP', align: TextAlign.right),
        const SizedBox(),
        const SizedBox(),
      ], header: true);
      return Stack(children: [
        Positioned.fill(
          child: _sbScrollTable(c, tableW, header, [
            for (var i = 0; i < p.basket.length; i++) _sbLegRow(p, c, i, widths),
          ]),
        ),
        if (p.isPayoffLoading)
          Positioned.fill(
            child: Container(
              color: c.surface.withValues(alpha: .4),
              alignment: Alignment.center,
              child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
      ]);
    });
  }

  Widget _sbSideChip(_SbC c, bool buy, VoidCallback onTap, {double height = 26}) => Tooltip(
        message: 'Click to switch Buy / Sell',
        child: _SbHover(
          onTap: onTap,
          builder: (h) {
            final col = buy ? c.profit : c.loss;
            return Container(
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: buy ? c.buyTint : c.sellTint,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: h ? col : Colors.transparent),
              ),
              child: Text(buy ? 'B' : 'S', style: _ts(11.5, w: FontWeight.w800, c: col).copyWith(letterSpacing: .2)),
            );
          },
        ),
      );

  Widget _sbTypeChip(_SbC c, String type, VoidCallback onTap) => Tooltip(
        message: 'Click to switch Call / Put',
        child: _SbHover(
          onTap: onTap,
          builder: (h) => Container(
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: h ? c.blue : c.line),
            ),
            child: Text(type, style: _ts(12, w: FontWeight.w700, c: h ? c.blue : c.text)),
          ),
        ),
      );

  Widget _sbStepBtn(_SbC c, String glyph, VoidCallback? onTap, {double w = 22, double h = 26}) => _SbHover(
        onTap: onTap,
        builder: (hv) => Container(
          width: w,
          height: h,
          alignment: Alignment.center,
          color: hv ? c.hover : null,
          child: Text(glyph, style: _ts(14, c: hv ? c.blue : c.text3, h: 1)),
        ),
      );

  Widget _sbStepper(_SbC c, {required Widget value, VoidCallback? onDown, VoidCallback? onUp,
      String down = '−', String up = '+', double height = 28, String? tip}) {
    final box = Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        _sbStepBtn(c, down, onDown, h: height - 2),
        Expanded(child: Center(child: value)),
        _sbStepBtn(c, up, onUp, h: height - 2),
      ]),
    );
    return tip == null ? box : Tooltip(message: tip, child: box);
  }

  Widget _sbSelect<T>(_SbC c, {required T? value, required List<T> items, required String Function(T) label,
      required ValueChanged<T> onChanged, String? hint, double height = 28, double fontSize = 12.5, double maxMenuHeight = 320}) {
    return PopupMenuButton<T>(
      tooltip: '',
      padding: EdgeInsets.zero,
      color: c.surface,
      elevation: 2,
      position: PopupMenuPosition.under,
      // Opens with the current value highlighted (scrolled into view).
      initialValue: value,
      constraints: BoxConstraints(maxHeight: maxMenuHeight, minWidth: 110),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: c.line)),
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final it in items)
          PopupMenuItem<T>(
            value: it,
            height: 32,
            child: Text(label(it), style: _ts(fontSize, w: it == value ? FontWeight.w700 : FontWeight.w500, c: it == value ? c.blue : c.text)),
          ),
      ],
      child: Container(
        height: height,
        padding: const EdgeInsets.only(left: 7, right: 6),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          Expanded(
            child: Text(value != null ? label(value as T) : (hint ?? ''),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: _ts(fontSize, w: FontWeight.w600, c: c.text)),
          ),
          Icon(Icons.keyboard_arrow_down, size: 14, color: c.text3),
        ]),
      ),
    );
  }

  Widget _sbEye(_SbC c, bool on, VoidCallback onTap, {required String onTip, required String offTip}) => Tooltip(
        message: on ? onTip : offTip,
        child: _SbHover(
          onTap: onTap,
          builder: (h) => SizedBox(
            width: 28,
            height: 28,
            child: Icon(on ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: h ? c.text : c.text3),
          ),
        ),
      );

  Widget _sbRemove(_SbC c, VoidCallback onTap, String tip) => Tooltip(
        message: tip,
        // Same look as the eye toggle: plain outlined icon, darker on hover.
        child: _SbHover(
          onTap: onTap,
          builder: (h) => SizedBox(
            width: 24,
            height: 28,
            child: Icon(Icons.close_rounded, size: 18, color: h ? c.text : c.text3),
          ),
        ),
      );

  Widget _sbLegRow(StrategyBuilderProvider p, _SbC c, int i, List<double> widths) {
    final item = p.basket[i];
    final mult = p.lotMultiplier;
    final expiries = p.expiryDates.contains(item.expdate) ? p.expiryDates : [item.expdate, ...p.expiryDates];
    // Same source as the previous strike dropdown: the loaded chain's strikes
    // (+ basket strikes and the current one), sorted ascending.
    final strikes = p.getStrikesForExpiry(item.expdate, currentStrike: item.strprc);
    final curStrike = StrategyBuilderProvider.normalizeStrike(item.strprc);
    final numStyle = _ts(13.5, w: FontWeight.w700, c: c.text);
    final market = item.isMarket;
    return _sbRowWrap(
      c,
      widths,
      [
        _sbSideChip(c, item.buySell == 'BUY', () => p.toggleBuySell(i, context)),
        _sbSelect<String>(c,
            value: item.expdate,
            items: expiries,
            label: (e) => _sbFmtExpiry(e),
            onChanged: (v) {
              if (v != item.expdate) p.updateExpiry(i, v, context);
            }),
        _sbSelect<String>(c,
            value: curStrike,
            items: strikes,
            label: (s) => s,
            fontSize: 13,
            maxMenuHeight: 250,
            onChanged: (v) {
              if (v != curStrike) p.updateStrike(i, v, context);
            }),
        _sbTypeChip(c, item.optt, () => p.toggleCePe(i, context)),
        _sbStepper(c,
            tip: '${item.ordlot * item.lotSize * mult} qty',
            value: Text('${item.ordlot * mult}', style: numStyle),
            onDown: item.ordlot > 1 ? () => p.updateLots(i, item.ordlot - 1, context) : null,
            onUp: () => p.updateLots(i, item.ordlot + 1, context)),
        EntryPriceTableInput(
          value: item.entryPrice,
          onChanged: (price) => p.updateEntryPrice(i, price, context),
          market: market,
          marketTip: market
              ? 'Market price ${item.entryPrice.toIndianFormat()} · click to enter your own price'
              : 'Use market price (${item.ltp.toIndianFormat()})',
          // ⇆ toggles: Market uses the LTP; clicking again restores the typed price.
          onToggleMarket: () {
            // Ticks replace the leg object, so flip the flag on the current one.
            // updateEntryPrice refetches the payoff with the new isMarket state.
            final leg = p.basket[i];
            if (leg.isMarket) {
              final prev = _marketEntryPrev.remove(leg.token);
              leg.isMarket = false;
              p.updateEntryPrice(i, prev ?? leg.entryPrice, context);
            } else {
              _marketEntryPrev[leg.token] = leg.entryPrice;
              leg.isMarket = true;
              p.updateEntryPrice(i, leg.ltp, context);
            }
          },
        ),
        Tooltip(
          message: 'Last traded price',
          child: Text(item.ltp.toIndianFormat(), textAlign: TextAlign.right, style: _ts(13, c: c.text2)),
        ),
        _sbEye(c, item.checkbox, () => p.toggleCheckbox(i, context),
            onTip: 'Included · click to hide', offTip: 'Hidden · click to include'),
        _sbRemove(c, () => p.removeFromBasket(i, context), 'Remove leg'),
      ],
      opacity: item.checkbox ? 1 : .45,
      keepOpaque: 7,
    );
  }

  // --------------------------------------------------------- predefined tab

  Widget _sbPredefPane(StrategyBuilderProvider p, _SbC c) {
    final q = _predefSearchController.text.trim().toLowerCase();
    final presets = _sbPresets(p);
    // 'All' plus every category the presets have (Bullish, Bearish, Neutral, …).
    final categories = ['All', ...{for (final s in presets) s.type}];
    final filter = categories.contains(_predefFilter) ? _predefFilter : 'All';
    int count(String cat) => cat == 'All' ? presets.length : presets.where((s) => s.type == cat).length;
    final list = presets
        .where((s) => filter == 'All' || s.type == filter)
        .where((s) => q.isEmpty || [s.title, s.type, _kSbRisk[s.title] ?? ''].any((x) => x.toLowerCase().contains(q)))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Row(children: [
          Expanded(child: _sbSearchBox(c, _predefSearchController, 'Search strategies', () => _sbSet(() {}))),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: _sbSelect<String>(c,
                value: filter,
                items: categories,
                label: (cat) => '$cat (${count(cat)})',
                height: 40,
                fontSize: 13,
                onChanged: (v) => _sbSet(() => _predefFilter = v)),
          ),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: list.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                    q.isEmpty
                        ? 'No $filter strategies.'
                        : 'No ${filter == 'All' ? '' : '$filter '}strategy matches “${_predefSearchController.text.trim()}”.',
                    style: _ts(13, c: c.text3)),
              )
            : _sbGrid(minItem: 150, gap: 8, children: [
                for (final s in list)
                  _sbPresetCard(c, s,
                      small: true,
                      active: p.activePredefinedStrategy == s.title && p.basket.isNotEmpty,
                      onTap: () {
                        _sbSet(() {
                          _leftTab = 'legs';
                          _customStrategyName = null;
                        });
                        p.setActivePredefinedStrategy(s, context);
                      }),
              ]),
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------ custom tab

  Widget _sbCustomPane(StrategyBuilderProvider p, _SbC c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: _SbHover(
            onTap: () => p.addDraftLeg(),
            builder: (h) => CustomPaint(
              painter: _SbDashedBorderPainter(c.blue, 6),
              child: Container(
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: h ? c.blueTint2 : c.blueTint, borderRadius: BorderRadius.circular(6)),
                child: Text('+ Add leg', style: _ts(13.5, w: FontWeight.w700, c: c.blue)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Define legs relative to the market: strikes from ATM and expiries by position. '),
              TextSpan(text: 'Apply', style: TextStyle(fontWeight: FontWeight.w700, color: c.text2)),
              const TextSpan(text: " turns them into contracts at today's prices."),
            ]),
            style: _ts(12.5, c: c.text3, h: 1.45),
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, cons) {
            final widths = _sbColumns(
                math.max(cons.maxWidth, 520.0), const [34, 40, 0, 0, 0, 0, 28, 24], const [1, 1, .9, 1], const [84, 84, 78, 84], 6, 14, 10);
            final tableW = math.max(cons.maxWidth, _sbRowWidth(widths));
            final header = _sbRowWrap(c, widths, [
              _sbHead(c, 'B/S'),
              _sbHead(c, 'CE/PE'),
              _sbHead(c, 'Lots'),
              _sbHead(c, 'Exp offset', tip: '0 = current expiry, 1 = next, …'),
              _sbHead(c, 'Strike type'),
              _sbHead(c, 'Offset / Premium'),
              const SizedBox(),
              const SizedBox(),
            ], header: true);
            return _sbScrollTable(c, tableW, header, [
              if (p.draftLegs.isEmpty)
                Container(
                  width: tableW,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.lineSoft))),
                  child: Text('No rows yet. Add a leg and set it relative to ATM.', style: _ts(13, c: c.text3)),
                ),
              for (var i = 0; i < p.draftLegs.length; i++) _sbDraftRow(p, c, i, widths),
            ]);
          }),
        ),
      ],
    );
  }

  /// ATM premium for a PREMIUM row's starting value (nearest strike to spot).
  double _sbAtmLtp(StrategyBuilderProvider p, String type) {
    OptionValues? best;
    var diff = double.infinity;
    for (final o in p.optionChain) {
      if (o.optt != type) continue;
      final d = ((double.tryParse(o.strprc ?? '') ?? 0) - p.spotPrice).abs();
      if (d < diff) {
        diff = d;
        best = o;
      }
    }
    return (double.tryParse((best?.lp ?? '0').replaceAll(',', '')) ?? 0).roundToDouble();
  }

  Widget _sbDraftRow(StrategyBuilderProvider p, _SbC c, int i, List<double> widths) {
    final d = p.draftLegs[i];
    void upd(void Function() fn) {
      fn();
      p.updateDraftLeg(i, d);
    }

    final numStyle = _ts(13.5, w: FontWeight.w700, c: c.text);
    final expLbl = d.expiryOffset == 0 ? 'Current' : d.expiryOffset == 1 ? 'Next' : '+${d.expiryOffset}';
    final expDate = d.expiryOffset < p.expiryDates.length ? ' · ${_sbFmtExpiry(p.expiryDates[d.expiryOffset])}' : '';
    return _sbRowWrap(c, widths, [
      _sbSideChip(c, d.action == 'BUY', () => upd(() => d.action = d.action == 'BUY' ? 'SELL' : 'BUY')),
      _sbTypeChip(c, d.optionType, () => upd(() => d.optionType = d.optionType == 'CE' ? 'PE' : 'CE')),
      _sbStepper(c,
          value: Text('${d.ordlot}', style: numStyle),
          onDown: d.ordlot > 1 ? () => upd(() => d.ordlot--) : null,
          onUp: () => upd(() => d.ordlot++)),
      _sbStepper(c,
          tip: '$expLbl$expDate',
          value: Text('${d.expiryOffset}', style: numStyle),
          onDown: d.expiryOffset > 0 ? () => upd(() => d.expiryOffset--) : null,
          onUp: () => upd(() => d.expiryOffset++)),
      _sbSelect<String>(c,
          value: d.strikeType,
          items: const ['ATM', 'ITM', 'OTM', 'PREMIUM'],
          label: (t) => t == 'PREMIUM' ? 'Premium' : t,
          onChanged: (v) => upd(() {
                d.strikeType = v;
                if (v == 'ATM' || v == 'PREMIUM') d.strikeOffset = 0;
                if ((v == 'ITM' || v == 'OTM') && d.strikeOffset == 0) d.strikeOffset = 1;
                if (v == 'PREMIUM' && d.premiumValue <= 0) d.premiumValue = _sbAtmLtp(p, d.optionType);
              })),
      d.strikeType == 'PREMIUM'
          ? SizedBox(
              height: 28,
              child: EntryPriceTableInput(value: d.premiumValue, onChanged: (v) => upd(() => d.premiumValue = v)),
            )
          : _sbStepper(c,
              value: Text('${d.strikeOffset}', style: numStyle),
              onDown: d.strikeOffset > 0
                  ? () => upd(() {
                        d.strikeOffset--;
                        if (d.strikeOffset == 0) d.strikeType = 'ATM';
                      })
                  : null,
              onUp: () => upd(() {
                    if (d.strikeType == 'ATM') d.strikeType = 'OTM';
                    d.strikeOffset++;
                  })),
      _sbEye(c, d.checkbox, () => upd(() => d.checkbox = !d.checkbox),
          onTip: 'Enabled · click to disable (skipped by Apply and Save)', offTip: 'Disabled · click to enable'),
      _sbRemove(c, () => p.removeDraftLeg(i), 'Remove row'),
    ],
        // Disabled rows are dimmed like hidden legs; the eye stays fully visible.
        opacity: d.checkbox ? 1 : .45,
        keepOpaque: 6);
  }

  // ------------------------------------------------------------- saved tab

  Widget _sbSavedPane(StrategyBuilderProvider p, _SbC c) {
    final all = p.customStrategies;
    final q = _savedSearchController.text.trim().toLowerCase();
    final list = all
        .where((s) => q.isEmpty || s.title.toLowerCase().contains(q) || _sbSavedUnderlying(s).toLowerCase().contains(q))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (all.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: _sbSearchBox(c, _savedSearchController, 'Search saved strategies', () => _sbSet(() {})),
        ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: list.isEmpty && q.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No saved strategy matches “${_savedSearchController.text.trim()}”.', style: _ts(13, c: c.text3)),
              )
            : list.isEmpty
                ? _sbEmptyBox(c, 'Your saved strategies will appear here.', null,
                    _sbBtn(c, 'Create strategy', primary: true, onTap: () => _sbSet(() => _leftTab = 'legs')),
                    column: true)
                : _sbGrid(minItem: 150, gap: 8, children: [for (final s in list) _sbSavedCard(p, c, s, small: true)]),
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------- footer

  Widget _sbLegsFoot(StrategyBuilderProvider p, _SbC c) {
    final cus = _leftTab == 'cus';
    final included = p.basket.where((b) => b.checkbox).length;
    final hasDrafts = p.draftLegs.isNotEmpty;
    // Apply / Save use only enabled rows (eye on).
    final hasEnabledDrafts = p.draftLegs.any((d) => d.checkbox);
    final busy = p.isOrderLoading || (cus && p.isLoading);
    final placeLabel = cus ? 'Apply' : included > 1 ? 'Place $included orders' : 'Place order';
    // Current value stays listed even if it was set above 50 elsewhere.
    final multOptions = {for (var i = 1; i <= 50; i++) i, p.lotMultiplier}.toList()..sort();
    final left = <Widget>[
            _sbBtn(c, 'Clear',
                ghost: true,
                height: 38,
                // Each tab clears only its own rows; Custom builder clears all its rows.
                onTap: (cus ? hasDrafts : p.basket.isNotEmpty)
                    ? () {
                        if (cus) {
                          p.toggleAllDraftLegCheckboxes(true);
                          p.clearDraftLegs();
                        } else {
                          p.clearBasket(keepDrafts: true);
                        }
                      }
                    : null),
            if (!cus) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: _kSbGloss['mult']!,
                child: Text('Lot multiplier',
                    style: _ts(12.5, c: c.text3).copyWith(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: _sbSelect<int>(c,
                    value: p.lotMultiplier,
                    items: multOptions,
                    label: (v) => '$v',
                    height: 30,
                    fontSize: 13.5,
                    maxMenuHeight: 280,
                    onChanged: (v) {
                      if (v != p.lotMultiplier) p.setLotMultiplier(v, context);
                    }),
              ),
            ],
    ];
    final right = <Widget>[
            // Like the old UI, only Custom builder rows can be saved.
            // Also shown on Strategy legs, but only right after Apply from the Custom builder.
            if (cus || (_leftTab == 'legs' && _legsFromApply)) ...[
              _sbBtn(c, 'Save', height: 38, onTap: hasEnabledDrafts ? () => _sbSave(p, c) : null),
              const SizedBox(width: 8),
            ],
            _sbBtn(c, placeLabel,
                primary: true,
                height: 38,
                fontSize: 14.5,
                padH: 22,
                busy: busy,
                onTap: busy
                    ? null
                    : cus
                        ? (hasEnabledDrafts
                            ? () async {
                                await p.applyCustomStrategy(context);
                                if (mounted) {
                                  _sbSet(() {
                                    _leftTab = 'legs';
                                    _legsFromApply = true;
                                  });
                                }
                              }
                            : null)
                        : (included > 0 ? () => _sbPlaceDialog(p, c) : null)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: LayoutBuilder(builder: (context, cons) {
        if (cus || cons.maxWidth >= 480) return Row(children: [...left, const Spacer(), ...right]);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: left),
          const SizedBox(height: 8),
          Row(children: [const Spacer(), ...right]),
        ]);
      }),
    );
  }

  // ------------------------------------------------------------------ KPIs

  Widget _sbKpis(StrategyBuilderProvider p, _SbC c, int cols) {
    if (_sbAnalyzeLoading) {
      return Container(
        decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.line))),
        child: _buildMetricsSkeleton(c.d),
      );
    }
    final empty = p.basket.where((b) => b.checkbox).isEmpty || p.payoffData.isEmpty;
    String m(String v) => v == '--' ? '—' : v;
    final net = p.netPremium;
    final bes = p.metrics.breakevens;
    final spot = p.spotPrice;

    // Single-value tiles, in order: (text, colour).
    final vals = <(String, Color)>[
      (m(p.metrics.maxProfit), c.profit),
      (m(p.metrics.maxLoss), c.loss),
      (_sbSigned2(net), net > 0 ? c.profit : net < 0 ? c.loss : c.text),
      (m(p.totalMargin), c.text),
      ('${p.metrics.popPercent.toStringAsFixed(0)}%', c.text),
      (m(p.metrics.riskRewardRatio), c.text),
    ].map((v) => empty ? ('—', c.text3) : v).toList();

    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.line))),
      child: LayoutBuilder(builder: (context, cons) {
        // Breakeven gets double width on the single wide row, and its own full
        // row when tiles wrap, so 3–4 values fit.
        final units = cols == 7 ? 8 : cols;
        final unitW = cons.maxWidth / units;

        // One shared value size: if any value is too wide for its tile, every
        // value shrinks to the same size, so the strip stays uniform.
        // Measured exactly as Text renders it (incl. the app's text scaler);
        // 28 = tile padding, +2 for the divider and rounding.
        final avail = unitW - 30;
        final scaler = MediaQuery.textScalerOf(context);
        var k = 1.0;
        for (final v in vals) {
          final tp = TextPainter(
            text: TextSpan(text: v.$1, style: _ts(17, w: FontWeight.w700, h: 1.3)),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (tp.width > avail && avail > 0) k = math.min(k, avail / tp.width);
        }
        k = math.max(k, .6);

        Widget be;
        if (empty) {
          be = _sbKpiVal('—', c.text3, 17 * k);
        } else if (bes.isEmpty) {
          be = Text('None', style: _ts(15.5 * k, w: FontWeight.w700, c: c.text));
        } else {
          // 3–4 breakevens are possible: each value with its % from spot, wrapping if needed.
          be = Wrap(spacing: 12, runSpacing: 2, children: [
            for (final b in bes)
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: _sbN0(b)),
                  if (spot > 0)
                    TextSpan(text: ' ${_sbPct((b / spot - 1) * 100)}', style: _ts(11.5 * k, w: FontWeight.w500, c: c.text3)),
                ]),
                style: _ts(15.5 * k, w: FontWeight.w700, c: c.text, h: 1.3),
              ),
          ]);
        }

        Widget val(int i) => _sbKpiVal(vals[i].$1, vals[i].$2, 17 * k);
        final items = <Widget>[
          _sbKpi(c, 'Max profit', _kSbGloss['maxP']!, val(0), tone: 1),
          _sbKpi(c, 'Max loss', _kSbGloss['maxL']!, val(1), tone: -1),
          _sbKpi(c, 'Net premium', _kSbGloss['net']!, val(2)),
          _sbKpi(c, 'Margin', _kSbGloss['margin']!, val(3),
              onInfo: p.basketMarginModel != null ? () => showMarginInfoDialog(context, c.d) : null),
          _sbKpi(c, 'POP', _kSbGloss['pop']!, val(4)),
          _sbKpi(c, 'Reward/Risk', _kSbGloss['rr']!, val(5)),
          _sbKpi(c, 'Breakeven', _kSbGloss['be']!, be),
        ];
        int span(int i) => i == items.length - 1 ? (cols == 7 ? 2 : units) : 1;
        final rowsOfItems = <List<int>>[[]];
        var used = 0;
        for (var i = 0; i < items.length; i++) {
          if (used + span(i) > units) {
            rowsOfItems.add([]);
            used = 0;
          }
          rowsOfItems.last.add(i);
          used += span(i);
        }
        return Column(children: [
          for (var r = 0; r < rowsOfItems.length; r++)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var k = 0; k < rowsOfItems[r].length; k++)
                  Container(
                    width: unitW * span(rowsOfItems[r][k]),
                    decoration: BoxDecoration(
                      border: Border(
                        right: k < rowsOfItems[r].length - 1 ? BorderSide(color: c.lineSoft) : BorderSide.none,
                        bottom: r < rowsOfItems.length - 1 ? BorderSide(color: c.lineSoft) : BorderSide.none,
                      ),
                    ),
                    child: items[rowsOfItems[r][k]],
                  ),
              ]),
            ),
        ]);
      }),
    );
  }

  /// [size] is shared by all tiles (see [_sbKpis]); FittedBox only guards rounding.
  Widget _sbKpiVal(String v, Color col, double size) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(v, maxLines: 1, style: _ts(size, w: FontWeight.w700, c: col, h: 1.3)),
      );

  Widget _sbKpi(_SbC c, String label, String tip, Widget value, {int tone = 0, VoidCallback? onInfo}) {
    final tint = tone > 0 ? c.profitTint : tone < 0 ? c.lossTint : null;
    final top = tone > 0 ? c.profit : tone < 0 ? c.loss : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 8),
      decoration: BoxDecoration(
        color: tint,
        border: top != null ? Border(top: BorderSide(color: top, width: 2)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Tooltip(
                message: tip,
                preferBelow: false,
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(11.5, w: FontWeight.w500, c: c.text3).copyWith(
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                        decorationColor: const Color(0xFF8B94A6))),
              ),
            ),
            if (onInfo != null) ...[
              const SizedBox(width: 4),
              _SbHover(onTap: onInfo, builder: (h) => Icon(Icons.info_outline, size: 13, color: h ? c.blue : c.text3)),
            ],
          ]),
          const SizedBox(height: 1),
          value,
        ],
      ),
    );
  }

  // --------------------------------------------------------- chart column

  Widget _sbChartCol(StrategyBuilderProvider p, _SbC c) {
    Widget body;
    if (_analysisTab == 'overview') {
      body = _sbChartHost(p, c);
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: _sbGreeksTable(p, c),
      );
    }
    return Container(
      color: c.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sbTabsRow(p, c),
        Expanded(child: body),
        _sbGreeksBar(p, c),
      ]),
    );
  }

  /// Net Greeks under the chart. Same height as the legs footer
  /// (10 + 38 + 10 padding/buttons + 1 border) so the two bottoms line up.
  Widget _sbGreeksBar(StrategyBuilderProvider p, _SbC c) {
    if (_sbAnalyzeLoading) {
      return Container(
        height: 59,
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
        child: _buildGreeksRowSkeleton(c.d),
      );
    }
    final has = p.basket.any((b) => b.checkbox);
    Widget item(String label, String key) {
      final v = p.greeksTotal(key);
      return Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: _ts(11, w: FontWeight.w500, c: c.text3)),
          const SizedBox(height: 2),
          Text(has ? '${v < 0 ? _kSbMinus : ''}${v.abs().toStringAsFixed(4)}' : '—',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: _ts(15, w: FontWeight.w700, c: has ? c.text : c.text3)),
        ]),
      );
    }

    return Container(
      height: 59,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: Row(children: [
        item('Δ DELTA', 'delta'),
        item('Θ THETA', 'theta'),
        item('Γ GAMMA', 'gamma'),
        item('ν VEGA', 'vega'),
      ]),
    );
  }

  Widget _sbTabsRow(StrategyBuilderProvider p, _SbC c) {
    Widget tab(String id, String label) {
      final on = _analysisTab == id;
      return _SbHover(
        onTap: () => _sbSet(() => _analysisTab = id),
        builder: (h) => Container(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? c.blue : Colors.transparent, width: 2))),
          child: Text(label, style: _ts(13.5, w: on ? FontWeight.w600 : FontWeight.w500, c: on ? c.blue : h ? c.text : c.text3)),
        ),
      );
    }

    final vr = Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 4), color: c.line);
    final overview = _analysisTab == 'overview';
    final tools = Visibility(
      visible: overview,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          _sbUnitSwitch(c),
          vr,
          _sbTg(c, '±σ', p.showSDLines, () => p.toggleSDLines(), tip: 'Expected move bands (1 and 2 standard deviations)'),
          _sbTg(c, '', false, () => _sbSet(() => _chartZoom = math.min(4, _chartZoom * 1.25)),
              tip: 'Zoom out', square: true, icon: Icons.zoom_out),
          _sbTg(c, '', false, () => _sbSet(() => _chartZoom = math.max(.25, _chartZoom * .8)),
              tip: 'Zoom in', square: true, icon: Icons.zoom_in),
          _sbTg(c, 'Reset', false, () => _sbSet(() => _chartZoom = 1), tip: 'Reset zoom'),
        ],
      ),
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.only(left: 16, right: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.lineSoft))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            tab('overview', 'Overview'),
            const SizedBox(width: 20),
            tab('greeks', 'Greeks'),
          ]),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
            tools,
            vr,
            // Target price / date open in a floating card; the button stays
            // highlighted while a target is set, so it is never hidden.
            _SbPopover(
              width: 320,
              content: (_) => Material(
                color: c.surface,
                elevation: 6,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: c.line)),
                child: _sbSideCol(p, c),
              ),
              builder: (toggle, open) => _sbTg(
                  c, 'Target', open || p.isTargetSpotActive || p.targetDaysToExpiry > 0, toggle,
                  tip: 'Target price and target date',
                  lead: Icon(Icons.tune, size: 15, color: c.text3)),
            ),
          ]),
        ],
      ),
    );
  }

  /// P&L ₹ | Payoff pts — segmented tab switch for the chart's Y units.
  Widget _sbUnitSwitch(_SbC c) {
    // Static segments: no animation and no hover change.
    Widget seg(String label, bool on, VoidCallback onTap) => MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: on ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: on ? c.line : Colors.transparent),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: _ts(12.5, w: on ? FontWeight.w600 : FontWeight.w500, c: on ? c.blue : c.text3)),
              ]),
            ),
          ),
        );
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.lineSoft),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('P&L ₹', !_payoffInPoints, () => _sbSet(() => _payoffInPoints = false)),
        const SizedBox(width: 4),
        seg('Payoff pts', _payoffInPoints, () => _sbSet(() => _payoffInPoints = true)),
      ]),
    );
  }

  Widget _sbTg(_SbC c, String label, bool pressed, VoidCallback onTap,
      {Widget? lead, String? tip, bool square = false, IconData? icon}) {
    final btn = _SbHover(
      onTap: onTap,
      builder: (h) => Container(
        height: 26,
        constraints: square ? const BoxConstraints(minWidth: 26) : null,
        padding: square ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: pressed ? c.surface2 : null,
          border: Border.all(color: pressed ? c.line : Colors.transparent),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          if (lead != null) ...[lead, const SizedBox(width: 6)],
          // [icon] replaces the text label (zoom buttons).
          if (icon != null)
            Icon(icon, size: 21, color: pressed || h ? c.text : c.text3)
          else
            Text(label, style: _ts(square ? 14 : 12.5, c: pressed || h ? c.text : c.text3)),
        ]),
      ),
    );
    return tip == null ? btn : Tooltip(message: tip, child: btn);
  }

  Widget _sbChartHost(StrategyBuilderProvider p, _SbC c) {
    if (_sbAnalyzeLoading) return _buildPayoffChartSkeleton(c.d);
    final included = p.basket.where((b) => b.checkbox).toList();
    if (included.isEmpty || p.payoffData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: p.isPayoffLoading && included.isNotEmpty
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Your payoff will appear here', style: _ts(16, w: FontWeight.w700, c: c.text)),
                  const SizedBox(height: 4),
                  Text('Pick a quick strategy or add a leg to start.', textAlign: TextAlign.center, style: _ts(14, c: c.text3)),
                ]),
        ),
      );
    }

    final div = _sbUnitDivisor(p, included);
    final stockPrices = p.payoffData.map((d) => d.price).toList();
    final payoffsExpiry = p.payoffData.map((d) => d.profit / div).toList();
    final payoffsTarget = p.targetPayoffData.length == p.payoffData.length
        ? p.targetPayoffData.map((d) => d.profit / div).toList()
        : <double>[];
    // Toolbar toggles: Expiry / Today lines (at least one stays visible).
    final showT = _showTargetCurve && payoffsTarget.isNotEmpty;
    final showE = _showExpiryCurve || !showT;
    final axes = _sbOldAxes(p, stockPrices, showE ? payoffsExpiry : const [], showT ? payoffsTarget : const []);

    return Stack(children: [
      Positioned.fill(
        child: LayoutBuilder(builder: (context, cons) {
          return MouseRegion(
            onExit: (_) => _chartHover.value = null,
            child: Listener(
              onPointerHover: (e) => _chartHover.value = e.localPosition,
              onPointerDown: (e) => _chartHover.value = e.localPosition,
              onPointerMove: (e) => _chartHover.value = e.localPosition,
              // Only the chart rebuilds on hover (for the marker dot), not the panel.
              child: ValueListenableBuilder<Offset?>(
                valueListenable: _chartHover,
                builder: (context, h, _) {
                  final price = h == null ? null : _sbPriceAtPixel(h, axes, cons.maxWidth);
                  return Stack(children: [
                    Positioned.fill(
                      child: _sbPayoffChart(p, stockPrices, payoffsExpiry, payoffsTarget, showE, showT, axes, price),
                    ),
                    if (h != null && price != null)
                      _sbPayoffTooltip(p, h, price, stockPrices, payoffsExpiry, payoffsTarget, showE, showT, cons.maxWidth, cons.maxHeight),
                  ]);
                },
              ),
            ),
          );
        }),
      ),
      if (p.isPayoffLoading)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: c.surface.withValues(alpha: .5),
                alignment: Alignment.center,
                child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          ),
    ]);
  }

  double _sbUnitDivisor(StrategyBuilderProvider p, List<StrategyBasketItem> included) {
    if (!_payoffInPoints || included.isEmpty) return 1;
    // API payoff is in ₹ for the whole quantity; per unit = ÷ (lot size × lots × multiplier).
    final b = included.first;
    return math.max(1, b.lotSize * b.ordlot * p.lotMultiplier).toDouble();
  }

  /// Axis ranges — same maths as the previous payoff chart: Y padded 15% and
  /// rounded to 10k / 5k / 1k, zero always visible, at least 4 steps tall;
  /// X = 60% of the API price range around its middle (widened to fit the
  /// ±2σ lines when ±σ is on), kept inside the data. Zoom scales that 60%.
  ({double minX, double maxX, double minY, double maxY}) _sbOldAxes(
      StrategyBuilderProvider p, List<double> stockPrices, List<double> expiry, List<double> target) {
    final all = [...expiry, ...target];
    double minPayoff = all.isEmpty ? 0 : all.reduce(math.min);
    double maxPayoff = all.isEmpty ? 0 : all.reduce(math.max);

    double yRange = maxPayoff - minPayoff;
    if (yRange <= 0) yRange = _payoffInPoints ? 100 : 10000;
    minPayoff = minPayoff - (yRange * 0.15);
    maxPayoff = maxPayoff + (yRange * 0.15);

    double roundingFactor = 10000;
    if ((maxPayoff - minPayoff).abs() < 50000) roundingFactor = 5000;
    if ((maxPayoff - minPayoff).abs() < 10000) roundingFactor = 1000;
    // Payoff in points is per unit (small numbers), so round to a nice step instead.
    if (_payoffInPoints) roundingFactor = _sbNiceStep(maxPayoff - minPayoff, 4);

    minPayoff = (minPayoff / roundingFactor).floor() * roundingFactor;
    maxPayoff = (maxPayoff / roundingFactor).ceil() * roundingFactor;
    if (minPayoff > 0) {
      minPayoff = -roundingFactor;
    } else if (maxPayoff < 0) {
      maxPayoff = roundingFactor;
    }
    if ((maxPayoff - minPayoff) < roundingFactor * 4) maxPayoff = minPayoff + roundingFactor * 4;

    final actualMinPrice = stockPrices.reduce(math.min);
    final actualMaxPrice = stockPrices.reduce(math.max);
    final centerPrice = (actualMinPrice + actualMaxPrice) / 2;
    double zoomedRange = (actualMaxPrice - actualMinPrice) * 0.6;
    if (p.showSDLines && p.sdPrices.isNotEmpty) {
      final sdRange = (p.sdPrices['+2σ'] ?? actualMaxPrice) - (p.sdPrices['-2σ'] ?? actualMinPrice);
      if (sdRange * 1.15 > zoomedRange) zoomedRange = sdRange * 1.15;
    }
    zoomedRange *= _chartZoom;
    double minPrice = centerPrice - zoomedRange / 2;
    double maxPrice = centerPrice + zoomedRange / 2;
    if (minPrice < actualMinPrice) {
      maxPrice += actualMinPrice - minPrice;
      minPrice = actualMinPrice;
    }
    if (maxPrice > actualMaxPrice) {
      minPrice -= maxPrice - actualMaxPrice;
      maxPrice = actualMaxPrice;
      if (minPrice < actualMinPrice) minPrice = actualMinPrice;
    }
    return (minX: minPrice, maxX: maxPrice, minY: minPayoff, maxY: maxPayoff);
  }

  /// Price under the cursor, read from the chart's own axis (exact), with the
  /// old plot-area estimate as a fallback before the series is laid out.
  double? _sbPriceAtPixel(Offset pos, ({double minX, double maxX, double minY, double maxY}) axes, double width) {
    double? price;
    try {
      final x = _payoffSeriesController?.pixelToPoint(pos).x;
      if (x != null && x.isFinite) price = x;
    } catch (_) {}
    final v = price ?? axes.minX + ((pos.dx - width * 0.075) / (width * 0.85)).clamp(0.0, 1.0) * (axes.maxX - axes.minX);
    return v.clamp(axes.minX, axes.maxX).toDouble();
  }

  List<_PayoffData> _sbSeries(List<double> xs, List<double> ys, {bool? positiveOnly}) => [
        for (var i = 0; i < xs.length && i < ys.length; i++)
          _PayoffData(
            price: xs[i],
            payoff: positiveOnly == null ? ys[i] : positiveOnly ? math.max(0, ys[i]) : math.min(0, ys[i]),
          ),
      ];

  /// Expiry line split into green (>= 0) and red (< 0) parts at the zero crossings.
  List<CartesianSeries<_PayoffData, double>> _sbSegmentedLine(List<double> xs, List<double> ys) {
    final pos = <_PayoffData>[], neg = <_PayoffData>[];
    for (var i = 0; i < xs.length && i < ys.length; i++) {
      if (i > 0) {
        final py = ys[i - 1], px = xs[i - 1];
        if ((py >= 0 && ys[i] < 0) || (py < 0 && ys[i] >= 0)) {
          final cross = _PayoffData(price: px + (xs[i] - px) * (py / (py - ys[i])), payoff: 0);
          pos.add(cross);
          neg.add(cross);
        }
      }
      (ys[i] >= 0 ? pos : neg).add(_PayoffData(price: xs[i], payoff: ys[i]));
    }
    LineSeries<_PayoffData, double> line(List<_PayoffData> d, Color col, String n) => LineSeries<_PayoffData, double>(
          dataSource: d,
          xValueMapper: (_PayoffData v, _) => v.price,
          yValueMapper: (_PayoffData v, _) => v.payoff,
          color: col,
          width: 2.5,
          animationDuration: 0,
          name: n,
          enableTooltip: false,
        );
    return [
      if (pos.isNotEmpty) line(pos, MyntColors.profit, 'Expiry (Positive)'),
      if (neg.isNotEmpty) line(neg, MyntColors.loss, 'Expiry (Negative)'),
    ];
  }

  Widget _sbPayoffChart(StrategyBuilderProvider p, List<double> xs, List<double> expiry, List<double> target, bool showE,
      bool showT, ({double minX, double maxX, double minY, double maxY}) axes, double? hoverPrice) {
    final isDark = ref.read(themeProvider).isDarkMode;
    final labelStyle = TextStyle(
      fontFamily: MyntFonts.fontFamily,
      fontSize: MyntFonts.caption,
      color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
    );
    final currentPrice = p.isTargetSpotActive ? p.targetSpotPrice : p.spotPrice;
    final fill = showE ? expiry : target;
    PlotBand sdBand(String key) => PlotBand(
          start: p.sdPrices[key]!,
          end: p.sdPrices[key]!,
          color: Colors.transparent,
          borderColor: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
          borderWidth: 1.5,
          dashArray: const <double>[6, 4],
          text: key,
          textStyle: labelStyle.copyWith(fontWeight: MyntFonts.medium),
          verticalTextAlignment: TextAnchor.start,
          horizontalTextAlignment: TextAnchor.middle,
          verticalTextPadding: '2%',
        );

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      enableAxisAnimation: false,
      primaryXAxis: NumericAxis(
        minimum: axes.minX,
        maximum: axes.maxX,
        rangePadding: ChartRangePadding.none,
        axisLine: const AxisLine(width: 0),
        majorGridLines: MajorGridLines(width: 1, color: Colors.grey.withValues(alpha: 0.15)),
        desiredIntervals: 5,
        axisLabelFormatter: (AxisLabelRenderDetails args) => ChartAxisLabel(args.value.toStringAsFixed(0), labelStyle),
        plotBands: <PlotBand>[
          // Current (or target) price
          PlotBand(start: currentPrice, end: currentPrice, borderColor: const Color(0xFF2962FF), borderWidth: 1.5),
          // Breakevens
          ...p.metrics.breakevens.map((be) => PlotBand(
                start: be,
                end: be,
                color: Colors.transparent,
                borderColor: Colors.grey.withValues(alpha: 0.5),
                borderWidth: 1.5,
                dashArray: const <double>[5, 5],
              )),
          // ±σ lines (toolbar ±σ)
          if (p.showSDLines && p.sdPrices.isNotEmpty) ...[sdBand('-2σ'), sdBand('-1σ'), sdBand('+1σ'), sdBand('+2σ')],
        ],
      ),
      primaryYAxis: NumericAxis(
        minimum: axes.minY,
        maximum: axes.maxY,
        rangePadding: ChartRangePadding.none,
        axisLine: const AxisLine(width: 0),
        majorGridLines: MajorGridLines(width: 1, color: isDark ? MyntColors.dividerDark : MyntColors.divider),
        title: AxisTitle(
          text: _payoffInPoints ? 'Payoff (pts)' : 'Profit/Loss',
          textStyle: labelStyle.copyWith(fontWeight: MyntFonts.medium),
        ),
        desiredIntervals: 6,
        axisLabelFormatter: (AxisLabelRenderDetails args) {
          final v = args.value;
          final sign = v >= 0 ? '+' : '';
          return ChartAxisLabel(
              _payoffInPoints ? '$sign${v.toStringAsFixed(v.abs() < 10 ? 1 : 0)}' : '$sign₹${v.toInt()}', labelStyle);
        },
        plotBands: <PlotBand>[
          PlotBand(start: 0, end: 0, borderColor: isDark ? MyntColors.textPrimaryDark : Colors.black, borderWidth: 1),
        ],
      ),
      series: <CartesianSeries<dynamic, dynamic>>[
        // Loss shade (below zero). Also gives the controller used for pixel → price.
        AreaSeries<_PayoffData, double>(
          dataSource: _sbSeries(xs, fill, positiveOnly: false),
          xValueMapper: (_PayoffData d, _) => d.price,
          yValueMapper: (_PayoffData d, _) => d.payoff,
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
          borderWidth: 0,
          animationDuration: 0,
          name: 'Loss',
          enableTooltip: false,
          onRendererCreated: (ctrl) => _payoffSeriesController = ctrl,
        ),
        // Profit shade (above zero)
        AreaSeries<_PayoffData, double>(
          dataSource: _sbSeries(xs, fill, positiveOnly: true),
          xValueMapper: (_PayoffData d, _) => d.price,
          yValueMapper: (_PayoffData d, _) => d.payoff,
          color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
          borderWidth: 0,
          animationDuration: 0,
          name: 'Profit',
          enableTooltip: false,
        ),
        // Target / Today line (blue)
        if (showT)
          LineSeries<_PayoffData, double>(
            dataSource: _sbSeries(xs, target),
            xValueMapper: (_PayoffData d, _) => d.price,
            yValueMapper: (_PayoffData d, _) => d.payoff,
            color: const Color(0xFF2962FF),
            width: 2.5,
            animationDuration: 0,
            name: 'Target',
            enableTooltip: false,
          ),
        // Expiry line (green above zero, red below)
        if (showE) ..._sbSegmentedLine(xs, expiry),
        // Marker on the Target line at the hovered price
        if (hoverPrice != null && showT)
          ScatterSeries<_PayoffData, double>(
            dataSource: [_PayoffData(price: hoverPrice, payoff: _sbInterp(xs, target, hoverPrice))],
            xValueMapper: (_PayoffData d, _) => d.price,
            yValueMapper: (_PayoffData d, _) => d.payoff,
            pointColorMapper: (_PayoffData d, _) => const Color(0xFF2962FF),
            markerSettings: MarkerSettings(
              isVisible: true,
              height: 10,
              width: 10,
              shape: DataMarkerType.circle,
              borderWidth: 2,
              borderColor: isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack,
            ),
            animationDuration: 0,
            name: 'Target Marker',
            enableTooltip: false,
          ),
      ],
    );
  }

  /// Hover tooltip — same card and rows as the previous chart.
  Widget _sbPayoffTooltip(StrategyBuilderProvider p, Offset h, double price, List<double> xs, List<double> expiry,
      List<double> target, bool showE, bool showT, double chartW, double chartH) {
    const tooltipOffset = 20.0, tooltipWidth = 200.0, tooltipHeight = 150.0, edge = 8.0;
    final maxX = chartW - tooltipWidth - edge, maxY = chartH - tooltipHeight - edge;
    double x;
    if (h.dx + tooltipOffset + tooltipWidth <= maxX) {
      x = h.dx + tooltipOffset;
    } else if (h.dx - tooltipWidth - tooltipOffset >= edge) {
      x = h.dx - tooltipWidth - tooltipOffset;
    } else {
      x = (maxX - h.dx) > (h.dx - edge) ? maxX : edge;
    }
    x = x.clamp(edge, math.max(edge, maxX)).toDouble();
    final y = (h.dy - tooltipHeight / 2).clamp(edge, math.max(edge, maxY)).toDouble();

    final spot = p.spotPrice;
    double pct(double v) => spot > 0 ? v / spot * 100 : 0;
    final ev = _sbInterp(xs, expiry, price), tv = _sbInterp(xs, target, price);
    String money(double v) => _payoffInPoints ? '${v.toIndianFormat()} pts' : '₹${v.toIndianFormat()}';

    Widget row(String label, String value, double percent, Color col) {
      final base = MyntWebTextStyles.bodySmall(context, color: col, fontWeight: MyntFonts.medium);
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label ', style: MyntWebTextStyles.bodySmall(context, color: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        Text.rich(TextSpan(children: [
          TextSpan(text: value, style: base),
          TextSpan(
            text: ' (${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%)',
            style: base.copyWith(fontSize: (base.fontSize ?? 14) - 3, color: Colors.grey),
          ),
        ])),
      ]);
    }

    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            row('Underlying Price:', price.toIndianFormat(), spot > 0 ? (price - spot) / spot * 100 : 0, MyntColors.textBlack),
            if (showE) ...[
              const SizedBox(height: 6),
              row('Expiry P&L:', money(ev), pct(ev), ev >= 0 ? MyntColors.profit : MyntColors.loss),
            ],
            if (showT) ...[
              const SizedBox(height: 6),
              row('Target P&L:', money(tv), pct(tv), tv >= 0 ? MyntColors.profit : MyntColors.loss),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _sbGreeksTable(StrategyBuilderProvider p, _SbC c) {
    if (_sbAnalyzeLoading) return _buildGreeksRowSkeleton(c.d);
    final included = p.basket.where((b) => b.checkbox).toList();
    if (included.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('Add legs to see Greeks.', style: _ts(12.5, c: c.text3)),
      );
    }
    final mult = p.lotMultiplier;
    String f(double v, int d) => '${v < 0 ? _kSbMinus : ''}${v.abs().toStringAsFixed(d)}';
    Widget th(String t, String tip) => Tooltip(
          message: tip,
          child: Text(t,
              style: _ts(12, w: FontWeight.w600, c: c.text3)
                  .copyWith(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted)),
        );
    final cell = _ts(13, c: c.text);
    final rows = <List<Widget>>[
      for (final b in included)
        () {
          final k = (b.ordlot * mult).toDouble();
          final theta = (b.theta ?? 0) * k;
          return <Widget>[
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: '${b.buySell}  ',
                  style: _ts(11, w: FontWeight.w800, c: b.buySell == 'BUY' ? c.profit : c.loss)),
              TextSpan(text: b.tsym),
              TextSpan(text: '  ${b.ordlot * mult} ${b.ordlot * mult == 1 ? 'lot' : 'lots'}', style: _ts(12, c: c.text3)),
            ]), style: cell),
            Text('${b.ordlot * b.lotSize * mult}', style: cell),
            // IV per contract (not multiplied by lots), 2 decimals
            Text(b.iv == null ? '—' : b.iv!.toStringAsFixed(2), style: cell),
            Text(f((b.delta ?? 0) * k, 4), style: cell),
            Text(f((b.gamma ?? 0) * k, 4), style: cell),
            Text(f(theta, 4), style: _ts(13, c: theta > 0 ? c.profit : theta < 0 ? c.loss : c.text)),
            Text(f((b.vega ?? 0) * k, 4), style: cell),
          ];
        }(),
    ];
    final tTheta = p.greeksTotal('theta');
    final bold = _ts(13, w: FontWeight.w700, c: c.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text('Greeks per leg, multiplied by its lots. Net is the sum across included legs.', style: _ts(12.5, c: c.text3)),
      ),
      _sbTableWithHeaders(c, [
        Text('Instruments', style: _ts(12, w: FontWeight.w600, c: c.text3)),
        Text('Qty', style: _ts(12, w: FontWeight.w600, c: c.text3)),
        th('IV', 'Implied volatility of the contract.'),
        th('Delta', 'Change in option price for a 1-point move in the underlying.'),
        th('Gamma', 'How much Delta changes for a 1-point move.'),
        th('Theta / day', 'Change in option price per day from time decay.'),
        th('Vega', 'Change in option price for a 1% change in implied volatility.'),
      ], rows, footer: [
        Text('Net', style: bold),
        const SizedBox(),
        const SizedBox(),
        Text(f(p.greeksTotal('delta'), 4), style: bold),
        Text(f(p.greeksTotal('gamma'), 4), style: bold),
        Text(f(tTheta, 4), style: _ts(13, w: FontWeight.w700, c: tTheta > 0 ? c.profit : tTheta < 0 ? c.loss : c.text)),
        Text(f(p.greeksTotal('vega'), 4), style: bold),
      ]),
    ]);
  }

  Widget _sbTableWithHeaders(_SbC c, List<Widget> headers, List<List<Widget>> rows, {List<Widget>? footer}) {
    TableRow mk(List<Widget> cells, {bool head = false, bool foot = false}) => TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: foot ? BorderSide.none : BorderSide(color: head ? c.line : c.lineSoft),
              top: foot ? BorderSide(color: c.line) : BorderSide.none,
            ),
          ),
          children: [
            for (var i = 0; i < cells.length; i++)
              Padding(
                padding: EdgeInsets.fromLTRB(i == 0 ? 0 : 8, head ? 6 : 7, 8, head ? 6 : 7),
                child: Align(alignment: i == 0 ? Alignment.centerLeft : Alignment.centerRight, child: cells[i]),
              ),
          ],
        );
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {0: FlexColumnWidth(2)},
      children: [
        mk(headers, head: true),
        for (final r in rows) mk(r),
        if (footer != null) mk(footer, foot: true),
      ],
    );
  }

  // ---------------------------------------------------------- target panel

  Widget _sbSideCol(StrategyBuilderProvider p, _SbC c) {
    if (_sbAnalyzeLoading) return _buildChartControlsSkeleton(c.d);
    final hasData = p.payoffData.isNotEmpty;
    final sp = p.spotPrice;
    final st = _sbStep(p);
    final tp = _sbTargetPrice(p);
    final dte = p.daysToExpiry;
    final td = math.min(p.targetDaysToExpiry, dte);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final targetDate = today.add(Duration(days: td));
    final labelStyle = _ts(13, c: c.text2);

    Widget reset(VoidCallback? onTap) => _SbHover(
          onTap: onTap,
          builder: (h) => Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text('Reset',
                style: _ts(12, w: FontWeight.w500, c: c.blue).copyWith(decoration: h ? TextDecoration.underline : null, decorationColor: c.blue)),
          ),
        );

    Widget stepBtn(String glyph, VoidCallback? onTap) => _SbHover(
          onTap: onTap,
          builder: (h) => Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: h ? c.blue : c.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(glyph, style: _ts(14, c: h ? c.blue : c.text2, h: 1)),
          ),
        );

    Widget box(Widget child, {VoidCallback? onTap}) => _SbHover(
          onTap: onTap,
          builder: (_) => Container(
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: child,
          ),
        );

    Widget slider({required double value, required double min, required double max, int? divisions, ValueChanged<double>? onChanged}) {
      return SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          activeTrackColor: c.blue,
          inactiveTrackColor: c.line,
          thumbShape: _TradingSliderThumbShape(enabledThumbRadius: 7, borderColor: c.blue),
          overlayColor: c.blue.withValues(alpha: .08),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: SizedBox(
          height: 20,
          child: Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, divisions: divisions, onChanged: onChanged),
        ),
      );
    }

    final pMin = sp > 0 ? (sp * .9 / st).floor() * st : 0.0;
    final pMax = sp > 0 ? (sp * 1.1 / st).ceil() * st : 1.0;
    void setPrice(double v) {
      if (v > 0 && hasData) p.setTargetSpotPrice((v * 20).round() / 20);
    }

    final price = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text('${_sbSymbolShort(p)} Target', style: labelStyle),
          reset(hasData && p.isTargetSpotActive ? () => p.resetTargetSpotPrice() : null),
          const Spacer(),
          Text(sp > 0 ? _sbPct((tp / sp - 1) * 100) : '—', style: _ts(13, w: FontWeight.w700, c: c.text)),
        ]),
      ),
      Row(children: [
        stepBtn('−', hasData ? () => setPrice(tp - st) : null),
        const SizedBox(width: 6),
        Expanded(
          child: box(_SbCommitField(
            value: tp.toStringAsFixed(2),
            decimal: true,
            enabled: hasData,
            style: _ts(13.5, w: FontWeight.w600, c: c.text),
            onCommit: (v) {
              final d = double.tryParse(v);
              d != null ? setPrice(d) : _sbSet(() {});
            },
          )),
        ),
        const SizedBox(width: 6),
        stepBtn('+', hasData ? () => setPrice(tp + st) : null),
      ]),
      const SizedBox(height: 6),
      slider(value: tp, min: pMin, max: pMax <= pMin ? pMin + 1 : pMax, onChanged: hasData && sp > 0 ? setPrice : null),
    ]);

    final date = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Flexible(child: Text('Target Date: ${dte - td}D - Expiry', overflow: TextOverflow.ellipsis, style: labelStyle)),
          reset(hasData && td > 0 ? () => p.setTargetDaysToExpiry(0) : null),
        ]),
      ),
      Row(children: [
        stepBtn('−', hasData && td > 0 ? () => p.setTargetDaysToExpiry(td - 1) : null),
        const SizedBox(width: 6),
        Expanded(
          child: _SbDatePopover(
            selected: targetDate,
            available: hasData && dte > 0 ? [for (var i = 0; i <= dte; i++) today.add(Duration(days: i))] : const [],
            onPick: (d) => p.setTargetDaysToExpiry(d.difference(today).inDays.clamp(0, dte)),
            builder: (onTap) => box(
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_sbFmtDate(targetDate, year: true), style: _ts(13.5, w: FontWeight.w600, c: c.text)),
                const SizedBox(width: 6),
                Icon(Icons.calendar_today_outlined, size: 13, color: c.text3),
              ]),
              onTap: onTap,
            ),
          ),
        ),
        const SizedBox(width: 6),
        stepBtn('+', hasData && td < dte ? () => p.setTargetDaysToExpiry(td + 1) : null),
      ]),
      const SizedBox(height: 6),
      slider(
        value: td.toDouble(),
        min: 0,
        max: dte > 0 ? dte.toDouble() : 1,
        divisions: dte > 0 ? dte : 1,
        onChanged: hasData && dte > 0 ? (v) => p.setTargetDaysToExpiry(v.round()) : null,
      ),
    ]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [price, const SizedBox(height: 14), date]),
    );
  }

  // ---------------------------------------------------------------- buttons

  Widget _sbBtn(_SbC c, String label,
      {bool primary = false,
      bool ghost = false,
      double height = 36,
      double? width,
      double padH = 16,
      double fontSize = 14,
      FontWeight? fontWeight,
      Color? textColor,
      Color? borderColor,
      Widget? icon,
      bool busy = false,
      VoidCallback? onTap}) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled || busy ? 1 : .45,
      child: _SbHover(
        onTap: onTap,
        builder: (h) {
          final bg = primary
              ? (h ? (c.d ? MyntColors.secondaryDark : const Color(0xFF002A8F)) : c.btnBg)
              : ghost
                  ? (h ? c.hover : Colors.transparent)
                  : (h ? c.hover : c.surface);
          final border = primary ? bg : ghost ? Colors.transparent : (borderColor ?? (h ? (c.d ? c.text3 : const Color(0xFFC7CDD6)) : c.line));
          final fg = primary ? Colors.white : (textColor ?? (ghost && !h ? c.text2 : c.text));
          // No Container.alignment: it would stretch the button to the full parent width.
          return Container(
            height: height,
            width: width,
            padding: EdgeInsets.symmetric(horizontal: padH),
            decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : icon ??
                      Text(label,
                          maxLines: 1,
                          style: _ts(fontSize, w: fontWeight ?? (primary ? FontWeight.w600 : FontWeight.w500), c: fg)),
            ]),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------------- modals

  Future<void> _sbModal(_SbC c,
      {required String title, required Widget Function(BuildContext ctx, StateSetter set) body, required List<Widget> Function(BuildContext ctx, StateSetter set) actions, bool wide = false, bool inlineActions = false}) {
    // Same shell as the app's other web dialogs: shadcn card, bordered title
    // row with MyntCloseButton, full-width action buttons under the content.
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final acts = actions(ctx, set);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Colors.transparent,
                child: shadcn.Card(
                  borderRadius: BorderRadius.circular(8),
                  padding: EdgeInsets.zero,
                  child: Container(
                    width: wide ? 640 : 400,
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height - 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: shadcn.Theme.of(ctx).colorScheme.border)),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Text(
                                title,
                                overflow: TextOverflow.ellipsis,
                                style: MyntWebTextStyles.title(ctx,
                                    color: resolveThemeColor(ctx, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)),
                              ),
                            ),
                            MyntCloseButton(onPressed: () => Navigator.of(ctx).pop()),
                          ]),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              body(ctx, set),
                              const SizedBox(height: 24),
                              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                for (var i = 0; i < acts.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  inlineActions ? acts[i] : Expanded(child: acts[i]),
                                ],
                              ]),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  TextStyle _sbDlgText(BuildContext ctx, {Color? color, FontWeight? w}) => MyntWebTextStyles.body(ctx,
      fontWeight: w,
      color: color ?? resolveThemeColor(ctx, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary));

  TextStyle _sbDlgSub(BuildContext ctx) =>
      MyntWebTextStyles.para(ctx, color: resolveThemeColor(ctx, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary));

  /// Saves the Custom builder rows (the provider's rule-leg save).
  void _sbSave(StrategyBuilderProvider p, _SbC c) {
    final editing = p.editingCustomBuilderName;
    final nameCtrl = TextEditingController(text: editing ?? (_customStrategyName ?? _sbAutoName(p)));
    final panelContext = context;
    bool nameTaken(String n) => p.customStrategies.any((s) => s.title.toLowerCase() == n.trim().toLowerCase());

    void doSave(BuildContext ctx, String name) {
      Navigator.of(ctx).pop();
      _sbSet(() => _customStrategyName = name);
      p.saveCustomStrategy(name, panelContext);
    }

    _sbModal(
      c,
      title: editing != null ? 'Save changes' : 'Save strategy',
      body: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MyntFormTextField(
          controller: nameCtrl,
          placeholder: 'Enter strategy name',
          autofocus: true,
          onChanged: (_) => set(() {}),
          onSubmitted: (v) {
            final n = v.trim();
            if (n.isEmpty) return;
            doSave(ctx, editing ?? n);
          },
        ),
        if (editing != null && nameCtrl.text.trim().toLowerCase() != editing.toLowerCase() && nameTaken(nameCtrl.text))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('A saved strategy already has this name.',
                style: MyntWebTextStyles.para(ctx, color: resolveThemeColor(ctx, dark: MyntColors.lossDark, light: MyntColors.loss))),
          ),
      ]),
      actions: (ctx, set) {
        final n = nameCtrl.text.trim();
        if (editing != null) {
          return [
            MyntOutlinedButton(
                size: MyntButtonSize.large,
                label: 'Save as new',
                isFullWidth: true,
                onPressed: n.isEmpty || nameTaken(n) ? null : () => doSave(ctx, n)),
            MyntPrimaryButton(
                size: MyntButtonSize.large, label: 'Update', isFullWidth: true, onPressed: () => doSave(ctx, editing)),
          ];
        }
        return [
          MyntPrimaryButton(
              size: MyntButtonSize.large, label: 'Save', isFullWidth: true, onPressed: n.isEmpty ? null : () => doSave(ctx, n)),
        ];
      },
    );
  }

  void _sbDeleteDialog(StrategyBuilderProvider p, _SbC c, String name) {
    final panelContext = context;
    _sbModal(
      c,
      title: 'Delete Strategy',
      body: (ctx, set) => Text('Are you sure you want to delete "$name"?',
          textAlign: TextAlign.center, style: _sbDlgText(ctx, w: FontWeight.w500)),
      actions: (ctx, set) => [
        MyntButton(
          type: MyntButtonType.primary,
          size: MyntButtonSize.large,
          label: 'Delete',
          isFullWidth: true,
          backgroundColor: resolveThemeColor(ctx, dark: MyntColors.errorDark, light: MyntColors.tertiary),
          onPressed: () {
            Navigator.of(ctx).pop();
            p.deleteCustomStrategy(name, panelContext);
          },
        ),
      ],
    );
  }

  /// Order confirmation, then the provider's existing placeOrder (one LMT
  /// NRML order per included leg, in basket order).
  void _sbPlaceDialog(StrategyBuilderProvider p, _SbC c) {
    final legs = p.basket.where((b) => b.checkbox).toList();
    if (legs.isEmpty) return;
    final mult = p.lotMultiplier;
    final panelContext = context;
    final net = p.netPremium;
    String m(String v) => v == '--' ? '—' : v;
    _sbModal(
      c,
      wide: true,
      inlineActions: true,
      title: 'Place order · ${_sbDisplayName(p)}',
      body: (ctx, set) {
        final head = MyntWebTextStyles.tableHeader(ctx,
            color: resolveThemeColor(ctx, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary));
        final cell = MyntWebTextStyles.tableCell(ctx,
            color: resolveThemeColor(ctx, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sbTableWithHeaders(c, [
            Text('Contract', style: head),
            Text('Qty', style: head),
            Text('Price', style: head),
            Text('Order', style: head),
          ], [
            for (final b in legs)
              [
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${b.buySell}  ',
                      style: cell.copyWith(
                          fontWeight: FontWeight.w700,
                          color: b.buySell == 'BUY'
                              ? resolveThemeColor(ctx, dark: MyntColors.profitDark, light: MyntColors.profit)
                              : resolveThemeColor(ctx, dark: MyntColors.lossDark, light: MyntColors.loss))),
                  TextSpan(text: b.tsym),
                ]), style: cell),
                Text('${b.ordlot * b.lotSize * mult}', style: cell),
                // Same rule as placeOrder: Market legs go as MKT, the rest as LMT.
                Text(b.isMarket ? 'Market' : '₹${b.entryPrice.toIndianFormat()}', style: cell),
                Text(b.isMarket ? 'Market · NRML' : 'Limit · NRML', style: cell),
              ],
          ]),
          const SizedBox(height: 14),
          Text(
            'Margin ${m(p.totalMargin)} · Net premium ${_sbSigned2(net)} ${net >= 0 ? 'received' : 'paid'} · Max loss ${m(p.metrics.maxLoss)}',
            style: _sbDlgSub(ctx),
          ),
          const SizedBox(height: 6),
          Text(
            legs.any((b) => b.isMarket)
                ? 'Each leg is sent as a separate order: Market legs at market price (5% protection), others as limit at their entry price.'
                : 'Each leg is sent as a separate limit order at its entry price.',
            style: _sbDlgSub(ctx),
          ),
        ]);
      },
      actions: (ctx, set) => [
        MyntPrimaryButton(
          size: MyntButtonSize.large,
          label: 'Place ${legs.length} order${legs.length > 1 ? 's' : ''}',
          onPressed: () {
            Navigator.of(ctx).pop();
            p.placeOrder(panelContext);
          },
        ),
      ],
    );
  }
}

/// Drag handle between columns (drag to resize, double-click to reset).
class _SbResizeHandle extends StatefulWidget {
  final Color color;
  final ValueChanged<double> onDrag;
  final VoidCallback onReset;
  const _SbResizeHandle({required this.color, required this.onDrag, required this.onReset});

  @override
  State<_SbResizeHandle> createState() => _SbResizeHandleState();
}

class _SbResizeHandleState extends State<_SbResizeHandle> {
  bool _hover = false, _drag = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Drag to resize · double-click to reset',
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => setState(() => _drag = true),
          onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
          onHorizontalDragEnd: (_) => setState(() => _drag = false),
          onDoubleTap: widget.onReset,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 3,
              decoration: BoxDecoration(
                color: _hover || _drag ? widget.color : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/charts/oi_timeline.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Compact popover multi-select over the chain's strikes for the Trending OI
/// chart. Edits a local working set (ATM ±3 / Clear quick actions + per-strike
/// toggles) and commits on Apply, so a bulk change is a single refetch.
class StrikeMultiSelect extends StatefulWidget {
  final List<StrikeOption> available;
  final List<double> selected;
  final ValueChanged<List<double>> onChanged;

  const StrikeMultiSelect({
    super.key,
    required this.available,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<StrikeMultiSelect> createState() => _StrikeMultiSelectState();
}

class _StrikeMultiSelectState extends State<StrikeMultiSelect> {
  final OverlayPortalController _ctrl = OverlayPortalController();
  final LayerLink _link = LayerLink();
  late Set<double> _working;

  // Checklist geometry — fixed row height makes the open-at-ATM jump exact.
  static const double _kItemExtent = 34;
  static const double _kListHeight = 280;
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _working = {...widget.selected});
    // Fresh controller seeded to centre the ATM strike, so the user lands on
    // the relevant strikes instead of the lowest one.
    _scroll?.dispose();
    _scroll = ScrollController(initialScrollOffset: _atmOffset());
    _ctrl.show();
  }

  double _atmOffset() {
    final n = widget.available.length;
    if (n == 0) return 0;
    var atm = widget.available.indexWhere((s) => s.isAtm);
    if (atm < 0) atm = n ~/ 2;
    final maxOffset =
        (n * _kItemExtent - _kListHeight).clamp(0.0, double.infinity);
    final target = atm * _kItemExtent - _kListHeight / 2 + _kItemExtent / 2;
    return target.clamp(0.0, maxOffset);
  }

  void _apply() {
    _ctrl.hide();
    final out = _working.toList()..sort();
    widget.onChanged(out);
  }

  Set<double> _atmBandSet() {
    final n = widget.available.length;
    if (n == 0) return {};
    var atm = widget.available.indexWhere((s) => s.isAtm);
    if (atm < 0) atm = n ~/ 2;
    final lo = (atm - 3).clamp(0, n - 1);
    final hi = (atm + 3).clamp(0, n - 1);
    return {for (var i = lo; i <= hi; i++) widget.available[i].strike};
  }

  /// True when the working selection is exactly the ATM ±3 band — drives the
  /// chip's active (toggled-on) state.
  bool get _isAtmBand {
    final band = _atmBandSet();
    return band.isNotEmpty &&
        _working.length == band.length &&
        _working.containsAll(band);
  }

  /// Toggle: apply the ATM ±3 band, or clear it again when it's already the
  /// active selection.
  void _atmBand() {
    final band = _atmBandSet();
    if (band.isEmpty) return;
    setState(() {
      if (_isAtmBand) {
        _working.clear();
      } else {
        _working = {...band};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final n = widget.selected.length;

    return OverlayPortal(
      controller: _ctrl,
      overlayChildBuilder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _ctrl.hide,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: _panel(context),
          ),
        ],
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _open,
            behavior: HitTestBehavior.opaque,
            child: Container(
              // Matches the NIFTY underlying dropdown above (Scalper style).
              width: 150,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: resolveThemeColor(context,
                    dark: MyntColors.transparent,
                    light: const Color(0xffF1F3F8)),
                border: Border.all(
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.primary),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text('Strikes',
                            style: MyntWebTextStyles.body(context,
                                darkColor: MyntColors.textWhite,
                                lightColor: MyntColors.textBlack,
                                fontWeight: MyntFonts.medium)),
                        const SizedBox(width: 6),
                        // Count badge — blue-tinted rounded square with the
                        // number in the accent colour (EQUITY-tab style).
                        Container(
                          height: 18,
                          constraints: const BoxConstraints(minWidth: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: resolveThemeColor(context,
                                    dark: MyntColors.secondaryDark,
                                    light: MyntColors.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('$n',
                              style: MyntWebTextStyles.caption(context,
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.secondaryDark,
                                          light: MyntColors.primary),
                                      fontWeight: MyntFonts.semiBold)
                                  .copyWith(fontSize: 11, height: 1)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down,
                      size: 20, color: secondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    // Scanner index-filter panel frame: card fill, shadcn border, radius 6.
    final card = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final border = shadcn.Theme.of(context).colorScheme.border;
    final accent = resolveThemeColor(context,
        dark: MyntColors.secondaryDark, light: MyntColors.primary);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  _quick(context, 'ATM ±3', _atmBand, active: _isAtmBand),
                  const Spacer(),
                  Text('${_working.length} selected',
                      style: MyntWebTextStyles.para(context,
                      fontWeight: MyntFonts.semiBold,
                          darkColor: MyntColors.textTertiaryDark,
                          lightColor: MyntColors.textTertiary)),
                ],
              ),
            ),
            Divider(height: 1, color: border),
            SizedBox(
              height: _kListHeight,
              child: ListView.builder(
                controller: _scroll,
                itemExtent: _kItemExtent,
                itemCount: widget.available.length,
                itemBuilder: (context, i) => _row(context, widget.available[i]),
              ),
            ),
            Divider(height: 1, color: border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  // Plain text buttons: Clear all flush left, Apply right.
                  // No Cancel — clicking outside the popover already
                  // dismisses without applying.
                  _textBtn(context, 'Clear all',
                      enabled: _working.isNotEmpty,
                      color: accent,
                      onTap: () => setState(_working.clear)),
                  const Spacer(),
                  _textBtn(context, 'Apply',
                      enabled: _working.isNotEmpty,
                      color: accent,
                      onTap: _apply),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, StrikeOption s) {
    final on = _working.contains(s.strike);
    final accent = resolveThemeColor(context,
        dark: MyntColors.secondaryDark, light: MyntColors.primary);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return InkWell(
      onTap: () => setState(() {
        if (on) {
          _working.remove(s.strike);
        } else {
          _working.add(s.strike);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            // Custom small checkbox — same as the scanner index-filter rows.
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: on ? accent : Colors.transparent,
                border: Border.all(
                  color: on ? accent : secondary.withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: on
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(s.strike.toInt().toString(),
                style: MyntWebTextStyles.body(context,
                    color: fg,
                    fontWeight: on ? MyntFonts.semiBold : MyntFonts.regular)),
            if (s.isAtm) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('ATM',
                    style: MyntWebTextStyles.caption(context,
                            color: accent, fontWeight: MyntFonts.bold)
                        .copyWith(fontSize: 9, letterSpacing: 0.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Borderless text button for the footer actions — accent (or given colour)
  /// text, greyed out when disabled.
  Widget _textBtn(BuildContext context, String label,
      {required bool enabled, required Color color, required VoidCallback onTap}) {
    final disabled = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Text(label,
            style: MyntWebTextStyles.para(context,
                color: enabled ? color : disabled,
                fontWeight: MyntFonts.semiBold)),
      ),
    );
  }

  /// Quick-action chip; [active] = toggled-on look (blue tint + accent text),
  /// so re-clicking reads as "undo".
  Widget _quick(BuildContext context, String label, VoidCallback? onTap,
      {bool active = false}) {
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.secondaryDark, light: MyntColors.primary);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
                color: active ? accent : border, width: active ? 1 : 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: MyntWebTextStyles.caption(context,
                  color: active ? accent : fg,
                  fontWeight: active ? MyntFonts.semiBold : MyntFonts.medium)),
        ),
      ),
    );
  }
}

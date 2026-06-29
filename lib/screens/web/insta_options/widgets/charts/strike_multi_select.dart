import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/charts/oi_timeline.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

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

  void _atmBand() {
    final n = widget.available.length;
    if (n == 0) return;
    var atm = widget.available.indexWhere((s) => s.isAtm);
    if (atm < 0) atm = n ~/ 2;
    final lo = (atm - 3).clamp(0, n - 1);
    final hi = (atm + 3).clamp(0, n - 1);
    setState(() {
      _working = {
        for (var i = lo; i <= hi; i++) widget.available[i].strike,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: resolveThemeColor(context,
                    dark: MyntColors.cardDark, light: MyntColors.card),
                border: Border.all(color: border, width: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, size: 15, color: fg),
                  const SizedBox(width: 8),
                  Text('Strikes · $n',
                      style: MyntWebTextStyles.bodySmall(context,
                          color: fg, fontWeight: MyntFonts.semiBold)),
                  const SizedBox(width: 8),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final card = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: card,
          border: Border.all(color: border, width: 0.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Row(
                children: [
                  _quick(context, 'ATM ±3', _atmBand),
                  const SizedBox(width: 8),
                  _quick(context, 'Clear', () => setState(_working.clear)),
                  const Spacer(),
                  Text('${_working.length} sel',
                      style: MyntWebTextStyles.caption(context,
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
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Spacer(),
                  _quick(context, 'Cancel', _ctrl.hide),
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _working.isEmpty ? null : _apply,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _working.isEmpty
                              ? accent.withValues(alpha: 0.4)
                              : accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Apply',
                            style: MyntWebTextStyles.caption(context,
                                color: Colors.white,
                                fontWeight: MyntFonts.semiBold)),
                      ),
                    ),
                  ),
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
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
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
            Icon(on ? Icons.check_box : Icons.check_box_outline_blank,
                size: 16, color: on ? accent : muted),
            const SizedBox(width: 10),
            Text(s.strike.toInt().toString(),
                style: MyntWebTextStyles.bodySmall(context,
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

  Widget _quick(BuildContext context, String label, VoidCallback? onTap) {
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: MyntWebTextStyles.caption(context,
                  color: fg, fontWeight: MyntFonts.medium)),
        ),
      ),
    );
  }
}

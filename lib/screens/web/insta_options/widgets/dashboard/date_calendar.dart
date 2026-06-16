import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';

/// Date chip that opens a calendar **popover anchored to the chip** — built on
/// `OverlayPortal`, so it works under the app's `ShadcnApp` (Flutter's
/// `showDatePicker` needs Material plumbing this app doesn't provide, and
/// positioned itself wrongly in the split panel).
///
/// Only [availableDates] are selectable (others greyed); defaults to
/// [selectedDate].
class DashDateButton extends StatefulWidget {
  final String? tradeDate;
  final DateTime? selectedDate;
  final List<DateTime> availableDates;
  final void Function(DateTime) onSelected;

  const DashDateButton({
    super.key,
    required this.tradeDate,
    required this.selectedDate,
    required this.availableDates,
    required this.onSelected,
  });

  @override
  State<DashDateButton> createState() => _DashDateButtonState();
}

class _DashDateButtonState extends State<DashDateButton> {
  final OverlayPortalController _ctrl = OverlayPortalController();
  final LayerLink _link = LayerLink();

  void _toggle() => _ctrl.isShowing ? _ctrl.hide() : _ctrl.show();

  void _pick(DateTime d) {
    _ctrl.hide();
    widget.onSelected(d);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.availableDates.isNotEmpty;
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

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
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 6),
            child: _CalendarCard(
              selected: widget.selectedDate,
              available: widget.availableDates,
              onPick: _pick,
            ),
          ),
        ],
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: GestureDetector(
            onTap: enabled ? _toggle : null,
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
                  Icon(Icons.calendar_today, size: 14, color: fg),
                  const SizedBox(width: 8),
                  Text(
                    InstaOptionsFormat.dateLabel(widget.tradeDate),
                    style: MyntWebTextStyles.bodySmall(context,
                        color: fg, fontWeight: MyntFonts.semiBold),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarCard extends StatefulWidget {
  final DateTime? selected;
  final List<DateTime> available;
  final void Function(DateTime) onPick;

  const _CalendarCard({
    required this.selected,
    required this.available,
    required this.onPick,
  });

  @override
  State<_CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<_CalendarCard> {
  late Set<DateTime> _availSet;
  late DateTime _minMonth;
  late DateTime _maxMonth;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _availSet = {
      for (final d in widget.available) DateTime(d.year, d.month, d.day)
    };
    final sorted = [...widget.available]..sort();
    final first = sorted.isNotEmpty ? sorted.first : DateTime(2026);
    final last = sorted.isNotEmpty ? sorted.last : DateTime(2026);
    _minMonth = DateTime(first.year, first.month);
    _maxMonth = DateTime(last.year, last.month);
    final sel = widget.selected ?? last;
    _month = DateTime(sel.year, sel.month);
  }

  bool get _canPrev => _month.isAfter(_minMonth);
  bool get _canNext => _month.isBefore(_maxMonth);

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final card = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 300,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
            Row(
              children: [
                _navBtn(Icons.chevron_left, _canPrev ? () => _shift(-1) : null,
                    fg, muted),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_month),
                    textAlign: TextAlign.center,
                    style: MyntWebTextStyles.bodySmall(context,
                        color: fg, fontWeight: MyntFonts.semiBold),
                  ),
                ),
                _navBtn(Icons.chevron_right, _canNext ? () => _shift(1) : null,
                    fg, muted),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final w in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  Expanded(
                    child: Text(w,
                        textAlign: TextAlign.center,
                        style:
                            MyntWebTextStyles.caption(context, color: muted)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ..._weeks(context),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap, Color fg, Color muted) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 20, color: onTap != null ? fg : muted),
        ),
      ),
    );
  }

  List<Widget> _weeks(BuildContext context) {
    final offset = _month.weekday % 7; // Sun = 0
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <Widget>[];
    for (var i = 0; i < offset; i++) {
      cells.add(const SizedBox(height: 34));
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final available = _availSet.contains(date);
      final selected = widget.selected != null &&
          DateTime(widget.selected!.year, widget.selected!.month,
                  widget.selected!.day) ==
              date;
      cells.add(_DayCell(
        day: d,
        available: available,
        selected: selected,
        onTap: available ? () => widget.onPick(date) : null,
      ));
    }
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(Row(
        children: [
          for (var j = 0; j < 7; j++)
            Expanded(child: i + j < cells.length ? cells[i + j] : const SizedBox()),
        ],
      ));
    }
    return rows;
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool available;
  final bool selected;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.available,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    Color? bg;
    Color textColor;
    if (selected) {
      bg = accent;
      textColor = Colors.white;
    } else if (available) {
      bg = accent.withValues(alpha: 0.12);
      textColor = fg;
    } else {
      bg = null;
      textColor = muted;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Text(
              '$day',
              style: MyntWebTextStyles.caption(
                context,
                color: textColor,
                fontWeight: selected ? MyntFonts.bold : MyntFonts.medium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

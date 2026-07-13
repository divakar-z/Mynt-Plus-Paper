import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dates_response.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/date_calendar.dart';

/// One date control for every InstaOptions screen: a **LIVE / Today** pill
/// (shown only when the backend holds today's intraday data) next to the
/// historical calendar. Tapping LIVE switches to polling today's snapshot
/// (with its `as of HH:mm` time); picking a finalized day from the calendar
/// switches to that immutable day. When [liveChannel] is null it degrades to
/// the plain calendar.
class LiveDateSelector extends StatelessWidget {
  final bool liveMode;
  final LiveChannel? liveChannel;

  /// `HH:mm` of the current live snapshot (`freshness.as_of`); falls back to the
  /// `/dates` live channel time before the first screen payload lands.
  final String? freshnessHm;

  final String? tradeDate; // historical label
  final DateTime? selectedDate;
  final List<DateTime> availableDates;
  final VoidCallback onSelectLive;
  final void Function(DateTime) onSelectDate;

  const LiveDateSelector({
    super.key,
    required this.liveMode,
    required this.liveChannel,
    required this.freshnessHm,
    required this.tradeDate,
    required this.selectedDate,
    required this.availableDates,
    required this.onSelectLive,
    required this.onSelectDate,
  });

  static String? _iso(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  DateTime? get _latestFinalized => availableDates.isEmpty
      ? null
      : availableDates.reduce((a, b) => a.isAfter(b) ? a : b);

  @override
  Widget build(BuildContext context) {
    final hasLive = liveChannel != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // if (hasLive) ...[
        //   _LivePill(
        //     active: liveMode,
        //     time: liveMode ? (freshnessHm ?? liveChannel!.hm) : null,
        //     onTap: onSelectLive,
        //   ),
        //   const SizedBox(width: 8),
        // ],
        Opacity(
          opacity: hasLive && liveMode ? 0.6 : 1.0,
          child: DashDateButton(
            // In live mode the calendar invites "pick a past day" — label it
            // with the latest finalized day and highlight nothing.
            tradeDate: liveMode ? _iso(_latestFinalized) : tradeDate,
            selectedDate: liveMode ? null : selectedDate,
            availableDates: availableDates,
            onSelected: onSelectDate,
          ),
        ),
      ],
    );
  }
}

class _LivePill extends StatelessWidget {
  final bool active;
  final String? time;
  final VoidCallback onTap;

  const _LivePill({required this.active, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final live = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final fg = active ? live : muted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active ? live.withValues(alpha: 0.12) : Colors.transparent,
            border: Border.all(color: active ? live : border, width: active ? 1 : 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(color: fg, pulsing: active),
              const SizedBox(width: 6),
              Text('LIVE',
                  style: MyntWebTextStyles.bodySmall(context,
                          color: fg, fontWeight: MyntFonts.bold)
                      .copyWith(letterSpacing: 0.4)),
              if (active && time != null) ...[
                const SizedBox(width: 6),
                Text(time!,
                    style: MyntWebTextStyles.caption(context, color: fg)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final bool pulsing;
  const _Dot({required this.color, required this.pulsing});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Dot old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.pulsing && _c.isAnimating) {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.pulsing
          ? Tween<double>(begin: 0.35, end: 1.0).animate(_c)
          : const AlwaysStoppedAnimation(1),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

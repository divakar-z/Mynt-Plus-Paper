import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/date_calendar.dart';

/// §5.1 App bar — title + date picker (anchored calendar limited to available
/// trading days, default `latest`) + refresh.
class DashboardAppBar extends StatelessWidget {
  final String? tradeDate;
  final DateTime? selectedDate;
  final List<DateTime> availableDates;
  final bool loading;
  final void Function(DateTime) onDateSelected;
  final VoidCallback onRefresh;

  const DashboardAppBar({
    super.key,
    required this.tradeDate,
    required this.selectedDate,
    required this.availableDates,
    required this.loading,
    required this.onDateSelected,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Markets Dashboard',
          style: MyntWebTextStyles.head(
            context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.bold,
          ),
        ),
        const Spacer(),
        DashDateButton(
          tradeDate: tradeDate,
          selectedDate: selectedDate,
          availableDates: availableDates,
          onSelected: onDateSelected,
        ),
        const SizedBox(width: 10),
        _RefreshButton(loading: loading, onRefresh: onRefresh),
      ],
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onRefresh;

  const _RefreshButton({required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: loading ? null : onRefresh,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.cardDark, light: MyntColors.card),
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: loading
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: accent),
                )
              : Icon(Icons.refresh, size: 18, color: fg),
        ),
      ),
    );
  }
}

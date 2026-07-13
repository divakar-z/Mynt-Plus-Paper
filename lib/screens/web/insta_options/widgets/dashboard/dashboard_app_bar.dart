import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dates_response.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/live_date_selector.dart';

/// §5.1 App bar — title + LIVE/date selector (Live-Today when held, else the
/// calendar limited to finalized days) + refresh.
class DashboardAppBar extends StatelessWidget {
  final String? tradeDate;
  final DateTime? selectedDate;
  final List<DateTime> availableDates;
  final bool liveMode;
  final LiveChannel? liveChannel;
  final String? freshnessHm;
  final bool loading;
  final VoidCallback onSelectLive;
  final void Function(DateTime) onDateSelected;
  final VoidCallback onRefresh;

  const DashboardAppBar({
    super.key,
    required this.tradeDate,
    required this.selectedDate,
    required this.availableDates,
    required this.liveMode,
    required this.liveChannel,
    required this.freshnessHm,
    required this.loading,
    required this.onSelectLive,
    required this.onDateSelected,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Text(
        //   'Market Dashboard',
        //   style: MyntWebTextStyles.head(
        //     context,
        //     darkColor: MyntColors.textPrimaryDark,
        //     lightColor: MyntColors.textPrimary,
        //     fontWeight: MyntFonts.bold,
        //   ),
        // ),
        // const Spacer(),
        const Spacer(), // push the date selector + refresh to the right
        LiveDateSelector(
          liveMode: liveMode,
          liveChannel: liveChannel,
          freshnessHm: freshnessHm,
          tradeDate: tradeDate,
          selectedDate: selectedDate,
          availableDates: availableDates,
          onSelectLive: onSelectLive,
          onSelectDate: onDateSelected,
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
    // Borderless icon button matching the Holdings screen refresh button.
    final dark = isDarkMode(context);
    final iconColor = resolveThemeColor(context,
        dark: MyntColors.textWhite, light: MyntColors.textPrimary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor:
              (dark ? Colors.white : Colors.black).withValues(alpha: 0.15),
          highlightColor:
              (dark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          onTap: loading ? null : onRefresh,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accent),
                  )
                : Icon(Icons.refresh, size: 28, color: iconColor),
          ),
        ),
      ),
    );
  }
}

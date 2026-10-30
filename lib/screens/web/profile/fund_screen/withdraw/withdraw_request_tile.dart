import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../models/fund_model_testing_copy/withdraw_request_model.dart';
import '../../../../../provider/privacy_provider.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../sharedWidget/functions.dart';

/// One withdraw request: details on the left, amount and status on the right.
/// Used by the withdraw screen's Active withdrawals list.
class WithdrawRequestTile extends ConsumerWidget {
  final WithdrawRequest request;

  /// Shows "Cancel" on PLACED requests when set.
  final VoidCallback? onCancel;
  final bool cancelling;

  const WithdrawRequestTile({
    super.key,
    required this.request,
    this.onCancel,
    this.cancelling = false,
  });

  static Color statusColor(BuildContext context, WithdrawRequest r) {
    switch (r.group) {
      case WithdrawStatusGroup.processed:
        return resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
      case WithdrawStatusGroup.failed:
        return resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);
      case WithdrawStatusGroup.pending:
      case WithdrawStatusGroup.review:
        return MyntColors.pending;
      case WithdrawStatusGroup.cancelled:
      case WithdrawStatusGroup.replaced:
        return resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary);
    }
  }

  static String formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    try {
      final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parseStrict(raw.trim());
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  /// Status pill, shared with the Transaction History Withdraw tab.
  static Widget statusChip(BuildContext context, WithdrawRequest r) {
    final color = statusColor(context, r);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        r.statusLabel.toUpperCase(),
        style: MyntWebTextStyles.bodySmall(
          context,
          color: color,
          fontWeight: MyntFonts.medium,
        ),
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(privacyProvider);
    final r = request;

    String money(double v) => privacy.mask(
        getFormatter(value: v, v4d: false, noDecimal: false),
        prefix: '₹ ');

    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final textSecondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final lossColor = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final remarks = (r.remarks ?? '').trim();
    final segment = (r.companyCode ?? '').trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatDate(r.createdAt),
                      style: MyntWebTextStyles.body(context,
                          color: textPrimary, fontWeight: MyntFonts.medium),
                    ),
                    if (segment.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: resolveThemeColor(context,
                              dark: MyntColors.listItemBgDark,
                              light: MyntColors.listItemBg),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          segment,
                          style: MyntWebTextStyles.caption(context,
                              color: textSecondary,
                              fontWeight: MyntFonts.medium),
                        ),
                      ),
                  ],
                ),
                // Processed amount only exists once the payout is done.
                if (r.isCompleted) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Processed: ${money(r.amount)}',
                    style: MyntWebTextStyles.bodySmall(context,
                        color: textSecondary, fontWeight: MyntFonts.medium),
                  ),
                ],
                if (remarks.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    remarks,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MyntWebTextStyles.bodySmall(context,
                        color: textSecondary, fontWeight: MyntFonts.medium),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(r.amount),
                style: MyntWebTextStyles.body(context,
                    color: textPrimary, fontWeight: MyntFonts.semiBold),
              ),
              const SizedBox(height: 4),
              statusChip(context, r),
              if (r.isCancellable && (onCancel != null || cancelling)) ...[
                const SizedBox(height: 6),
                cancelling
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: lossColor),
                      )
                    : MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: InkWell(
                          onTap: onCancel,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'Cancel',
                              style: MyntWebTextStyles.bodySmall(context,
                                  color: lossColor,
                                  fontWeight: MyntFonts.semiBold),
                            ),
                          ),
                        ),
                      ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

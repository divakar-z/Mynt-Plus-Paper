import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../provider/portfolio_provider.dart';
import '../../../../provider/privacy_provider.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';

class PositionListGrpCard extends ConsumerWidget {
  final Map<String, dynamic> groupData;

  const PositionListGrpCard({super.key, required this.groupData});

  // Get color for P&L values
  Color _getPnlColor(String? value, BuildContext context) {
    if (value == null || value == "0.00") {
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    }
    if (value.startsWith("-")) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    }
    return resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = ref.watch(portfolioProvider);
    // Privacy Mode: qty, avg price and P&L are masked; LTP stays visible.
    final privacy = ref.watch(privacyProvider);

    // Check both qty and netqty to determine if position is closed
    final rawQty = int.tryParse(groupData['qty']?.toString() ?? '0') ?? 0;
    final netQty = "${groupData['netqty'] ?? groupData['qty']}";
    final isClosedPosition = rawQty == 0 || netQty == "0";

    // For MCX, divide qty by lotSize for display
    final exchange = groupData['exch']?.toString() ?? '';
    final lotSize = double.tryParse(groupData['ls']?.toString() ?? '1') ?? 1.0;
    final qty = privacy.mask(
        exchange == 'MCX' ? (rawQty / lotSize).toInt().toString() : rawQty.toString());

    // Get PNL and determine its color
    final pnlValue = privacy.mask(positions.isNetPnl
        ? "${groupData['profitNloss'] ?? groupData['rpnl']}"
        : "${groupData['mTm']}");

    final pnlColor = privacy.isPrivate
        ? _getPnlColor("0.00", context)
        : _getPnlColor(
            positions.isNetPnl
                ? (groupData['profitNloss'] ?? groupData['rpnl'])?.toString()
                : groupData['mTm']?.toString(),
            context);

    // Get average price display value
    final avgPrice = privacy.mask(positions.isDay
        ? "${groupData['avgPrc']}"
        : positions.isNetPnl
            ? "${groupData['netupldprc'] ?? groupData['avgPrc']}"
            : "${groupData['netavgprc'] ?? groupData['avgPrc']}");

    // Calculate background color for closed positions
    final backgroundColor = isClosedPosition
        ? resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark.withValues(alpha: 0.2),
            light: MyntColors.textSecondary.withValues(alpha: 0.2))
        : Colors.transparent;

    return ColoredBox(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildHeaderRow(context),
              const SizedBox(height: 8),
              _buildQuantityRow(qty, pnlValue, pnlColor, avgPrice, context),
              const SizedBox(height: 8),
              _buildAveragePriceRow(context),
            ]),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(
                "${groupData['symbol']} ${groupData['expDate']} ",
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              "${groupData['option']} ",
              style: MyntWebTextStyles.body(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.medium,
              ),
            ),
          ]),
        ),
        Text(
          "${groupData['exch']}",
          style: MyntWebTextStyles.para(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
            fontWeight: MyntFonts.medium,
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityRow(String qty, String pnlValue, Color pnlColor,
      String avgPrice, BuildContext context) {
    final secondaryStyle = MyntWebTextStyles.para(
      context,
      darkColor: MyntColors.textSecondaryDark,
      lightColor: MyntColors.textSecondary,
      fontWeight: MyntFonts.medium,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side: Qty and Avg
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("QTY ", style: secondaryStyle),
            Text(qty, style: secondaryStyle),
            const SizedBox(width: 4),
            Text("AVG ", style: secondaryStyle),
            Text(avgPrice, style: secondaryStyle),
          ],
        ),
        // Right side: P&L value
        RepaintBoundary(
          child: Text(
            pnlValue,
            style: MyntWebTextStyles.title(
              context,
              color: pnlColor,
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAveragePriceRow(BuildContext context) {
    final secondaryStyle = MyntWebTextStyles.para(
      context,
      darkColor: MyntColors.textSecondaryDark,
      lightColor: MyntColors.textSecondary,
      fontWeight: MyntFonts.medium,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "${groupData['s_prdt_ali']}",
          overflow: TextOverflow.ellipsis,
          style: secondaryStyle,
        ),
        // Wrap LTP in RepaintBoundary as it changes frequently
        RepaintBoundary(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("LTP ", style: secondaryStyle),
              Text("${groupData['lp']}", style: secondaryStyle),
            ],
          ),
        ),
      ],
    );
  }
}

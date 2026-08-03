import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../provider/rupeecase_provider.dart';
import '../../res/mynt_web_color_styles.dart';
import '../../res/mynt_web_text_styles.dart';
import '../../sharedWidget/custom_back_btn.dart';
import 'strategy_card_web.dart';

/// Full listing of every algo (automated) strategy basket, laid out as the same
/// outlined [StrategyCard]s in a responsive grid — the "Algo" counterpart to
/// [AllStrategiesScreenWeb]. Rendered inside the split panel, so it is a plain
/// content widget with its own header. Data comes from [rupeeCaseProvider],
/// already fetched by the dashboard / Strategies section.
class AllAlgoStrategiesScreenWeb extends ConsumerWidget {
  const AllAlgoStrategiesScreenWeb({super.key, this.onBack});

  /// Invoked when the header back button is tapped. When null the back button
  /// is hidden (e.g. if the page is ever shown as a standalone route).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(rupeeCaseProvider);
    final strategies = provider.algoStrategies;

    final Color bg = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor);
    final Color muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                CustomBackBtn(onBack: onBack),
                const SizedBox(width: 4),
              ],
              Text(
                'Algo Strategies',
                style: MyntWebTextStyles.head(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: strategies.isEmpty
                ? Center(
                    child: provider.algoLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            'No strategies available',
                            style:
                                MyntWebTextStyles.para(context, color: muted),
                          ),
                  )
                : _buildGrid(context, strategies),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List strategies) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double gap = 16;
        const double minCardWidth = 360;
        final double maxWidth = constraints.maxWidth;

        final int columns =
            (maxWidth / (minCardWidth + gap)).floor().clamp(1, 4);
        final double cardWidth = (maxWidth - gap * (columns - 1)) / columns;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (int i = 0; i < strategies.length; i++)
                SizedBox(
                  width: cardWidth,
                  child: StrategyCard(
                    data: StrategyCardData.fromAlgo(strategies[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/utils/technical_interpretations.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/metric_card.dart';

class TechnicalsTab extends ConsumerStatefulWidget {
  final String ticker;
  const TechnicalsTab({super.key, required this.ticker});

  @override
  ConsumerState<TechnicalsTab> createState() => _TechnicalsTabState();
}

class _TechnicalsTabState extends ConsumerState<TechnicalsTab> {
  /// Own scroll controller so we can attach an always-visible scrollbar.
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(technicalsProvider(widget.ticker));
    return async.when(
      loading: () => Center(child: MyntLoader.simple()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load technicals',
        message: e.toString(),
        onRetry: () => ref.invalidate(technicalsProvider(widget.ticker)),
      ),
      data: (resp) {
        if (resp.indicators.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.insufficientData,
            title: 'No indicator values for this symbol',
          );
        }
        // Always-visible scrollbar in its own gutter (matches the market depth
        // section): the grid keeps a right inset so the bar never overlaps the
        // cards.
        return ScrollConfiguration(
          behavior:
              const MaterialScrollBehavior().copyWith(scrollbars: false),
          child: RawScrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            thickness: 6,
            radius: const Radius.circular(8),
            thumbColor: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary)
                .withValues(alpha: 0.5),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final e in resp.indicators.entries)
                    MetricCard(
                      label: indicatorLabel(e.key),
                      value: e.value == null
                          ? kEmDash
                          : e.value!.toStringAsFixed(2),
                      badge: interpretIndicator(
                        key: e.key,
                        value: e.value,
                        allIndicators: resp.indicators,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

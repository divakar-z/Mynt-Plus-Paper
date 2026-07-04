import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/utils/technical_interpretations.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/metric_card.dart';

class TechnicalsTab extends ConsumerWidget {
  final String ticker;
  const TechnicalsTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(technicalsProvider(ticker));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load technicals',
        message: e.toString(),
        onRetry: () => ref.invalidate(technicalsProvider(ticker)),
      ),
      data: (resp) {
        if (resp.indicators.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.insufficientData,
            title: 'No indicator values for this symbol',
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
        );
      },
    );
  }
}

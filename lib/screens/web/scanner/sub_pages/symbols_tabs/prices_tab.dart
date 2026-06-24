import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class PricesTab extends ConsumerWidget {
  final String ticker;
  const PricesTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ohlcvProvider((ticker: ticker, from: null)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load prices',
        message: e.toString(),
        onRetry: () =>
            ref.invalidate(ohlcvProvider((ticker: ticker, from: null))),
      ),
      data: (resp) {
        final bars = resp.bars.reversed.take(90).toList();
        if (bars.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No price data available',
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Open'), numeric: true),
                DataColumn(label: Text('High'), numeric: true),
                DataColumn(label: Text('Low'), numeric: true),
                DataColumn(label: Text('Close'), numeric: true),
                DataColumn(label: Text('Volume'), numeric: true),
              ],
              rows: [
                for (final b in bars)
                  DataRow(cells: [
                    DataCell(Text(formatDate(b.date),
                        style: MyntWebTextStyles.body(context))),
                    DataCell(Text(b.open?.toStringAsFixed(2) ?? kEmDash)),
                    DataCell(Text(b.high?.toStringAsFixed(2) ?? kEmDash)),
                    DataCell(Text(b.low?.toStringAsFixed(2) ?? kEmDash)),
                    DataCell(Text(b.close?.toStringAsFixed(2) ?? kEmDash)),
                    DataCell(Text(b.volume?.toString() ?? kEmDash)),
                  ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

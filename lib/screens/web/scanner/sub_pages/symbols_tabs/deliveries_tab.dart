import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class DeliveriesTab extends ConsumerWidget {
  final String ticker;
  const DeliveriesTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deliveriesProvider(ticker));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load deliveries',
        message: e.toString(),
        onRetry: () => ref.invalidate(deliveriesProvider(ticker)),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.insufficientData,
            title: 'No delivery data available',
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
                DataColumn(label: Text('Deliverable Qty'), numeric: true),
                DataColumn(label: Text('Delivery %'), numeric: true),
              ],
              rows: [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(Text(formatDate(r['date']?.toString() ?? ''),
                        style: MyntWebTextStyles.body(context))),
                    DataCell(
                        Text(r['deliverable_qty']?.toString() ?? kEmDash)),
                    DataCell(Text(r['delivery_pct']?.toString() ?? kEmDash)),
                  ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

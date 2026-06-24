import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class PeersTab extends ConsumerWidget {
  final String ticker;
  final ValueChanged<String> onPeerTap;
  const PeersTab({super.key, required this.ticker, required this.onPeerTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(peersProvider(ticker));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load peers',
        message: e.toString(),
        onRetry: () => ref.invalidate(peersProvider(ticker)),
      ),
      data: (resp) {
        if (resp.peers.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No peer data available',
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Ticker')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Market Cap'), numeric: true),
                DataColumn(label: Text('P/E (TTM)'), numeric: true),
              ],
              rows: [
                for (final p in resp.peers)
                  DataRow(
                    onSelectChanged: (_) => onPeerTap(p.ticker),
                    cells: [
                      DataCell(Text(p.ticker,
                          style: MyntWebTextStyles.body(context,
                              fontWeight: MyntFonts.medium))),
                      DataCell(Text(p.name)),
                      DataCell(Text(formatCurrencyINR(p.marketCap))),
                      DataCell(
                          Text(p.peTrailing?.toStringAsFixed(2) ?? kEmDash)),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

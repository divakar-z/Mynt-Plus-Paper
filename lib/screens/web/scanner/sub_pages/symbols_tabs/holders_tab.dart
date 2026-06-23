import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class HoldersTab extends ConsumerWidget {
  final String ticker;
  const HoldersTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            title: 'Major holders',
            async: ref.watch(holdersProvider(ticker)),
            renderRow: (m) => '${m['holder'] ?? '—'}  ·  ${m['pct'] ?? '—'}%',
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Latest news',
            async: ref.watch(newsProvider(ticker)),
            renderRow: (m) => m['title']?.toString() ?? '—',
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Dividends',
            async: ref.watch(dividendsProvider(ticker)),
            renderRow: (m) => '${m['date'] ?? '—'}  ·  ₹${m['amount'] ?? '—'}',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final AsyncValue<List<Map<String, dynamic>>> async;
  final String Function(Map<String, dynamic>) renderRow;

  const _Section({
    required this.title,
    required this.async,
    required this.renderRow,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(title,
          style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
      children: [
        async.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => EmptyState(
            kind: EmptyStateKind.error,
            title: 'Could not load',
            message: e.toString(),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const EmptyState(
                kind: EmptyStateKind.insufficientData,
                title: 'Insufficient data for this stock',
              );
            }
            return Column(
              children: [
                for (final row in rows)
                  ListTile(
                    dense: true,
                    title: Text(renderRow(row),
                        style: MyntWebTextStyles.body(context)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class ScansTab extends ConsumerWidget {
  final String ticker;
  const ScansTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(symbolScannersProvider(ticker));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load scanner matches',
        message: e.toString(),
        onRetry: () => ref.invalidate(symbolScannersProvider(ticker)),
      ),
      data: (codes) {
        if (codes.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No active scanner matches today',
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final code in codes)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => ref
                        .read(scannerShellProvider.notifier)
                        .navigateToScannerDetail(code),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: MyntColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: MyntColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(code,
                              style: MyntWebTextStyles.caption(context,
                                  fontWeight: MyntFonts.medium,
                                  color: MyntColors.primary)),
                          const SizedBox(width: 4),
                          const Icon(shadcn.LucideIcons.arrowUpRight,
                              size: 12, color: MyntColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

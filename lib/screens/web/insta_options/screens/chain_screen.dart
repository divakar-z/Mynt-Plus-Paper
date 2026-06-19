import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/insta_options/option_chain/option_chain_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_app_bar.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_balance_bar.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_key_walls.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_ladder.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_range_axis.dart';

/// Option Chain (Screen 2) — the NSE-style `CALLS | STRIKE | PUTS` ladder on the
/// date-based backend. The app bar (underlying / date / expiry) stays put; only
/// the body switches between loading / error / empty / chain.
class ChainScreen extends ConsumerStatefulWidget {
  const ChainScreen({super.key});

  @override
  ConsumerState<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends ConsumerState<ChainScreen> {
  final GlobalKey<ChainLadderState> _ladderKey = GlobalKey<ChainLadderState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(optionChainProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(optionChainProvider);
    final bg = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor);

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChainAppBar(
              onRecenter: () => _ladderKey.currentState?.centerOnAtm()),
          Expanded(child: _body(context, p)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, OptionChainProvider p) {
    if (p.isInitialLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: resolveThemeColor(context,
              dark: MyntColors.primaryDark, light: MyntColors.primary),
        ),
      );
    }
    if (p.isFatalError) {
      return _ErrorState(
        message: p.error ?? 'Failed to load the option chain.',
        onRetry: () => ref.read(optionChainProvider).refresh(),
      );
    }
    final data = p.data;
    if (data == null || data.isEmpty) {
      return const _EmptyState();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChainRangeAxis(data: data),
          const SizedBox(height: 16),
          ChainBalanceBar(
              totalCeOi: data.totalCeOi,
              totalPeOi: data.totalPeOi,
              pcr: data.pcr),
          const SizedBox(height: 18),
          ChainKeyWalls(data: data),
          const SizedBox(height: 16),
          Expanded(child: ChainLadder(key: _ladderKey, data: data)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: loss.withValues(alpha: 0.1),
            border: Border.all(color: loss, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_off, color: loss, size: 20),
                  const SizedBox(width: 8),
                  Text('Chain failed to load',
                      style: MyntWebTextStyles.body(context,
                          color: loss, fontWeight: MyntFonts.semiBold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(message,
                  style: MyntWebTextStyles.caption(context,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_rows_outlined, size: 44, color: muted),
          const SizedBox(height: 12),
          Text('No chain for this selection',
              style: MyntWebTextStyles.title(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 4),
          Text('Try another underlying, date, or expiry.',
              style: MyntWebTextStyles.caption(context, color: muted)),
        ],
      ),
    );
  }
}

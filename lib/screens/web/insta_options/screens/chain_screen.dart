import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/models/insta_options/option_chain/option_chain_data.dart';
import 'package:mynt_plus/provider/insta_options/option_chain/option_chain_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
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

  // Collapsing the overview gives the ladder ~230px more height on short
  // screens. Remembered across tab switches so it's a once-off, not per-visit.
  static bool _overviewExpandedPref = true;
  bool _overviewExpanded = _overviewExpandedPref;
  static final NumberFormat _grp = NumberFormat('#,##0');

  void _toggleOverview() => setState(() {
        _overviewExpanded = !_overviewExpanded;
        _overviewExpandedPref = _overviewExpanded;
      });

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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _overviewHeader(context, data),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _overviewExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      ChainRangeAxis(data: data),
                      const SizedBox(height: 16),
                      ChainBalanceBar(
                          totalCeOi: data.totalCeOi,
                          totalPeOi: data.totalPeOi,
                          pcr: data.pcr),
                      const SizedBox(height: 18),
                      ChainKeyWalls(data: data),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 12),
          Expanded(child: ChainLadder(key: _ladderKey, data: data)),
        ],
      ),
    );
  }

  /// Slim tappable bar that collapses the overview block. When collapsed it
  /// keeps a one-line digest so the key levels aren't lost.
  Widget _overviewHeader(BuildContext context, OptionChainData data) {
    final fg = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleOverview,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: _overviewExpanded
                ? null
                : Border(bottom: BorderSide(color: border, width: 0.5)),
          ),
          child: Row(
            children: [
              Icon(
                  _overviewExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: fg),
              const SizedBox(width: 4),
              Text('Overview',
                  style: MyntWebTextStyles.caption(context,
                      color: fg, fontWeight: MyntFonts.semiBold)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _overviewExpanded ? '' : _compactSummary(data),
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.caption(context, color: muted),
                ),
              ),
              const SizedBox(width: 8),
              Text(_overviewExpanded ? 'Hide' : 'Show',
                  style: MyntWebTextStyles.caption(context,
                      color: muted, fontWeight: MyntFonts.medium)),
            ],
          ),
        ),
      ),
    );
  }

  String _compactSummary(OptionChainData data) {
    String s(double? v) => v == null ? '—' : _grp.format(v);
    return 'Spot ${InstaOptionsFormat.price(data.underlyingValue)}'
        '  ·  ATM ${s(data.atmStrike)}'
        '  ·  PCR ${InstaOptionsFormat.pcr(data.pcr)}'
        '  ·  Max pain ${s(data.maxPain)}';
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/streaming_dot.dart';

/// Top bar with Exchange / Symbol / Expiry dropdowns + connection indicator.
///
/// Phase 1 ships a static bar populated from the current selection; live
/// symbol/expiry lists arrive from `/symbols` and `/expiries` in Phase 2.
class SymbolExpiryBar extends ConsumerWidget {
  final StreamingStatus streamingStatus;
  final String? streamingTooltip;
  final bool disableSymbol;
  final bool disableExpiry;

  const SymbolExpiryBar({
    super.key,
    this.streamingStatus = StreamingStatus.disconnected,
    this.streamingTooltip,
    this.disableSymbol = false,
    this.disableExpiry = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = InstaOptionsTokens.of(context);
    final selection = ref.watch(instaOptionsSelectionProvider).selection;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border(bottom: BorderSide(color: tokens.border, width: 1)),
      ),
      child: Row(
        children: [
          _BarLabel(
            label: 'Exchange',
            value: selection.exchange,
            tokens: tokens,
          ),
          const SizedBox(width: 20),
          _BarLabel(
            label: 'Symbol',
            value: selection.symbol,
            tokens: tokens,
            disabled: disableSymbol,
          ),
          const SizedBox(width: 20),
          _BarLabel(
            label: 'Expiry',
            value: selection.expiry.isEmpty ? '—' : selection.expiry,
            tokens: tokens,
            disabled: disableExpiry,
          ),
          const Spacer(),
          StreamingDot(status: streamingStatus, tooltip: streamingTooltip),
          const SizedBox(width: 12),
          Icon(Icons.refresh, size: 20, color: tokens.textSecondary),
        ],
      ),
    );
  }
}

class _BarLabel extends StatelessWidget {
  final String label;
  final String value;
  final InstaOptionsTokens tokens;
  final bool disabled;

  const _BarLabel({
    required this.label,
    required this.value,
    required this.tokens,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final fadeColor = disabled ? tokens.textMuted : tokens.textPrimary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MyntWebTextStyles.caption(context, color: tokens.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: MyntWebTextStyles.body(
            context,
            color: fadeColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

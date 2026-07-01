import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/models/insta_options/option_chain/chain_strike_row.dart';
import 'package:mynt_plus/models/insta_options/option_chain/option_chain_data.dart';
import 'package:mynt_plus/models/insta_options/option_chain/option_leg.dart';
import 'package:mynt_plus/provider/insta_options/insta_live_ticks.dart';
import 'package:mynt_plus/provider/insta_options/option_chain/option_chain_provider.dart';
import 'package:mynt_plus/provider/insta_options/symbols_provider.dart';
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
  Set<String> _lastSubKeys = const <String>{};

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
    ref.watch(instaLiveTicksProvider); // rebuild the overlay on each socket tick
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
    // Overlay live socket ticks onto the snapshot (price fields only) and keep
    // this section's subscriptions in sync. OI / PCR / walls stay snapshot.
    final effective = _liveOverlay(context, p, data);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _overviewHeader(context, effective),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _overviewExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      ChainRangeAxis(data: effective),
                      const SizedBox(height: 16),
                      ChainBalanceBar(
                          totalCeOi: effective.totalCeOi,
                          totalPeOi: effective.totalPeOi,
                          pcr: effective.pcr),
                      const SizedBox(height: 18),
                      ChainKeyWalls(data: effective),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 12),
          Expanded(child: ChainLadder(key: _ladderKey, data: effective)),
        ],
      ),
    );
  }

  /// Live-tick overlay: leg LTP / chg% and the underlying value take the socket
  /// value once a tick arrives (else the snapshot); OI / OIΔ% / PCR / max-pain /
  /// walls stay the API snapshot. Also keeps the section's socket subscriptions
  /// in sync (live mode only).
  OptionChainData _liveOverlay(
      BuildContext context, OptionChainProvider p, OptionChainData data) {
    final sym = ref.read(symbolsProvider).byId(data.underlying);
    final isIndex = sym?.isIndex ?? false;
    // Underlying live price: index → its spot token; stock → near-future token.
    final underToken = isIndex ? sym?.token : data.futureToken;
    final underKey = isIndex ? sym?.tickKey : data.futureTickKey;

    final keys = <String>{if (underKey != null) underKey};
    for (final r in data.rows) {
      final ce = r.ce?.tickKey;
      final pe = r.pe?.tickKey;
      if (ce != null) keys.add(ce);
      if (pe != null) keys.add(pe);
    }
    _syncSubs(context, p.liveMode ? keys : const <String>{});

    if (!p.liveMode) return data; // finalized day → no live ticks

    final t = ref.read(instaLiveTicksProvider);
    OptionLeg? overlay(OptionLeg? l) => l == null
        ? null
        : OptionLeg(
            ltp: t.ltpOr(l.token, l.ltp),
            change: t.liveChange(l.token) ?? l.change,
            changePct: t.liveChangePct(l.token) ?? l.changePct,
            volume: l.volume,
            oi: l.oi,
            oiChangePct: l.oiChangePct,
            token: l.token,
            exchange: l.exchange,
          );
    return OptionChainData(
      underlying: data.underlying,
      tradeDate: data.tradeDate,
      expiry: data.expiry,
      availableExpiries: data.availableExpiries,
      underlyingValue: t.ltpOr(underToken, data.underlyingValue),
      atmStrike: data.atmStrike,
      totalCeOi: data.totalCeOi,
      totalPeOi: data.totalPeOi,
      pcr: data.pcr,
      maxPain: data.maxPain,
      support: data.support,
      resistance: data.resistance,
      rows: [
        for (final r in data.rows)
          ChainStrikeRow(
              strike: r.strike,
              isAtm: r.isAtm,
              ce: overlay(r.ce),
              pe: overlay(r.pe))
      ],
      futureToken: data.futureToken,
      futureExchange: data.futureExchange,
      freshness: data.freshness,
    );
  }

  /// Diff-and-apply the section's live subscriptions (post-frame, off the build).
  void _syncSubs(BuildContext context, Set<String> keys) {
    if (keys.length == _lastSubKeys.length &&
        keys.containsAll(_lastSubKeys)) {
      return;
    }
    _lastSubKeys = keys;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(instaLiveTicksProvider).setActive(keys, context);
    });
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

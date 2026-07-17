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
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/insta_tab_chip.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_range_axis.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';

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

  // 0 = the Overview analytics, 1 = the ladder.
  // Remembered across tab switches so it's a once-off, not per-visit.
  static int _tabPref = 0;
  int _tab = _tabPref;
  static final NumberFormat _grp = NumberFormat('#,##0');

  void _selectTab(int i) => setState(() {
        _tab = i;
        _tabPref = i;
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
          // Overview and Ladder as separate tabs; the key-levels digest stays
          // visible on the right of the tab row from both tabs.
          Row(
            children: [
              InstaTabChip(
                label: 'Overview',
                selected: _tab == 0,
                onTap: () => _selectTab(0),
              ),
              const SizedBox(width: 6),
              InstaTabChip(
                label: 'Option chain',
                selected: _tab == 1,
                onTap: () => _selectTab(1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _compactSummary(context, effective),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _tab == 1
                ? ChainLadder(key: _ladderKey, data: effective)
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ChainRangeAxis(data: effective),
                        const SizedBox(height: 16),
                        ChainBalanceBar(
                            totalCeOi: effective.totalCeOi,
                            totalPeOi: effective.totalPeOi,
                            pcr: effective.pcr),
                        const SizedBox(height: 18),
                        ChainKeyWalls(data: effective),
                      ],
                    ),
                  ),
          ),
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

  /// Key-levels digest — grey labels, semiBold values, PCR in its band colour.
  Widget _compactSummary(BuildContext context, OptionChainData data) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    String s(double? v) => v == null ? '—' : _grp.format(v);
    TextSpan label(String t) => TextSpan(
        text: t, style: MyntWebTextStyles.body(context, color: muted));
    TextSpan value(String t, {Color? color}) => TextSpan(
        text: t,
        style: MyntWebTextStyles.body(context,
            color: color ?? fg, fontWeight: MyntFonts.semiBold));

    return Text.rich(
      TextSpan(children: [
        label('Spot '),
        value(InstaOptionsFormat.price(data.underlyingValue)),
        label('  ·  ATM '),
        value(s(data.atmStrike)),
        label('  ·  PCR '),
        value(InstaOptionsFormat.pcr(data.pcr),
            color: _pcrColor(context, data.pcr)),
        label('  ·  Max pain '),
        value(s(data.maxPain)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// PCR band colour: 0.70 or below bearish red, above 1.30 bullish green,
  /// in between neutral amber — same bands as the rest of the module.
  Color _pcrColor(BuildContext context, double? pcr) {
    if (pcr == null) {
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    }
    if (pcr <= 0.7) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    }
    if (pcr > 1.3) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    }
    return kDashOrange;
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // App-standard error state (same widget Positions / Holdings / Scanner
    // use) instead of the bespoke red panel.
    return Center(
      child: NoDataFoundWeb(
        title: 'Chain failed to load',
        subtitle: message,
        primaryEnabled: true,
        onPrimary: onRetry,
        primaryLabel: 'Retry',
        secondaryEnabled: false,
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

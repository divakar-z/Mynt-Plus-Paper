import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/provider/insta_options/contribution/contribution_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_live_ticks.dart';
import 'package:mynt_plus/provider/insta_options/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/concentration_card.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/contribution_app_bar.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/contribution_detail_tabs.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/contribution_header.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/contribution_movers.dart';

/// Index Contribution (Screen 3) — how each constituent moved the index that
/// day, on the date-based backend. The app bar (index / date) + header (level,
/// PCR, max-pain, basis, OI walls) stay put; the constituent breakdown
/// (waterfall, concentration, sectors, table) renders when the weightage feed
/// is available, else an informative unavailable state.
class IndexContributorsScreen extends ConsumerStatefulWidget {
  const IndexContributorsScreen({super.key});

  @override
  ConsumerState<IndexContributorsScreen> createState() =>
      _IndexContributorsScreenState();
}

class _IndexContributorsScreenState
    extends ConsumerState<IndexContributorsScreen> {
  Set<String> _lastSubKeys = const <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(contributionProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(contributionProvider);
    ref.watch(instaLiveTicksProvider); // rebuild overlay on each socket tick
    final bg = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor);

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ContributionAppBar(),
          Expanded(child: _body(context, p)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, ContributionProvider p) {
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
        message: p.error ?? 'Failed to load index contribution.',
        onRetry: () => ref.read(contributionProvider).refresh(),
      );
    }
    final data = p.data;
    if (data == null) return const _EmptyState();
    final effective = _liveOverlay(context, p, data);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContributionHeader(data: effective),
          const SizedBox(height: 16),
          if (effective.hasConstituents) ...[
            ContributionMovers(data: effective),
            const SizedBox(height: 16),
            ConcentrationCard(data: effective),
            const SizedBox(height: 16),
            ContributionDetailTabs(data: effective),
          ] else
            _ContributionUnavailable(data: effective),
        ],
      ),
    );
  }

  /// Live-tick overlay: the index level / point-change / change% (index token)
  /// and each constituent's LTP / price% (its token) take the socket value once
  /// a tick arrives; point-contribution / share / weight / OI / PCR / sector /
  /// concentration stay the API snapshot. Also keeps subscriptions in sync.
  IndexContribution _liveOverlay(
      BuildContext context, ContributionProvider p, IndexContribution data) {
    final idx = ref.read(symbolsProvider).byId(data.underlyingId);
    final idxToken = idx?.token;

    final keys = <String>{if (idx?.tickKey != null) idx!.tickKey!};
    for (final c in data.constituents) {
      final k = c.tickKey;
      if (k != null) keys.add(k);
    }
    _syncSubs(context, p.liveMode ? keys : const <String>{});

    if (!p.liveMode) return data;

    final t = ref.read(instaLiveTicksProvider);
    return data.copyWith(
      level: t.ltpOr(idxToken, data.level),
      pointChange: t.liveChange(idxToken) ?? data.pointChange,
      changePct: t.liveChangePct(idxToken) ?? data.changePct,
      constituents: [
        for (final c in data.constituents)
          c.copyWith(
            ltp: t.ltpOr(c.token, c.ltp),
            priceChangePct: t.liveChangePct(c.token) ?? c.priceChangePct,
          )
      ],
    );
  }

  void _syncSubs(BuildContext context, Set<String> keys) {
    if (keys.length == _lastSubKeys.length && keys.containsAll(_lastSubKeys)) {
      return;
    }
    _lastSubKeys = keys;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(instaLiveTicksProvider).setActive(keys, context);
    });
  }
}

/// Shown when `weightage_available` is false: the index header above is live,
/// but the constituent breakdown has no data for this day.
class _ContributionUnavailable extends StatelessWidget {
  final IndexContribution data;

  const _ContributionUnavailable({required this.data});

  @override
  Widget build(BuildContext context) {
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insights_outlined, size: 42, color: muted),
              const SizedBox(height: 12),
              Text(
                'Contribution breakdown unavailable',
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.title(context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                    fontWeight: MyntFonts.semiBold),
              ),
              const SizedBox(height: 6),
              Text(
                'The constituent weightage feed has no data for '
                '${InstaOptionsFormat.dateLabel(data.tradeDate)}. '
                'The index level, futures OI and options above are live — the '
                'per-stock waterfall, concentration, sectors and table will '
                'appear here once the feed is populated.',
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.bodySmall(context, color: muted)
                    .copyWith(height: 1.4),
              ),
              const SizedBox(height: 14),
              Text(
                'Try another date from the calendar.',
                style: MyntWebTextStyles.caption(context, color: primary),
              ),
            ],
          ),
        ),
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
                  Text('Contribution failed to load',
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
          Icon(Icons.insights_outlined, size: 44, color: muted),
          const SizedBox(height: 12),
          Text('No contribution data',
              style: MyntWebTextStyles.title(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 4),
          Text('Try another index or date.',
              style: MyntWebTextStyles.caption(context, color: muted)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/models/insta_options/buildup_symbol.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_markets_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/buildup_quadrant.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/index_ticker_tile.dart';

/// Markets Dashboard (README §10.1). 4 index ticker tiles + 2×2 buildup grid.
class MarketsDashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenChain;

  const MarketsDashboardScreen({super.key, required this.onOpenChain});

  @override
  ConsumerState<MarketsDashboardScreen> createState() =>
      _MarketsDashboardScreenState();
}

class _MarketsDashboardScreenState
    extends ConsumerState<MarketsDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(instaOptionsMarketsProvider).start();
    });
  }

  @override
  void dispose() {
    ref.read(instaOptionsMarketsProvider).stop();
    super.dispose();
  }

  void _openChain(BuildupSymbol row) {
    ref.read(instaOptionsSelectionProvider).update(symbol: row.symbol);
    widget.onOpenChain();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final markets = ref.watch(instaOptionsMarketsProvider);

    final initialLoad = markets.loading && markets.snapshot.indices.isEmpty;
    if (initialLoad) {
      return Container(
        color: tokens.bgPrimary,
        child: Center(child: CircularProgressIndicator(color: tokens.accent)),
      );
    }

    final fatalError = markets.error != null &&
        markets.snapshot.indices.isEmpty &&
        markets.buildup.isAllEmpty;
    if (fatalError) {
      return _ErrorState(
        message: markets.error!,
        tokens: tokens,
        onRetry: markets.refresh,
      );
    }

    return Container(
      color: tokens.bgPrimary,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(markets: markets, tokens: tokens),
          const SizedBox(height: 16),
          _TickerRow(markets: markets),
          const SizedBox(height: 16),
          Expanded(
            child: _BuildupGrid(markets: markets, onRowTap: _openChain),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final InstaOptionsMarketsProvider markets;
  final InstaOptionsTokens tokens;

  const _Header({required this.markets, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final ts = markets.lastUpdated;
    final stamp = ts == null ? '—' : DateFormat.Hm().format(ts);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Markets Dashboard',
          style: MyntWebTextStyles.hero(context, color: tokens.textPrimary),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Updated $stamp IST',
            style: MyntWebTextStyles.caption(
              context,
              color: tokens.textSecondary,
            ),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: markets.loading ? null : markets.refresh,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _TickerRow extends StatelessWidget {
  final InstaOptionsMarketsProvider markets;

  const _TickerRow({required this.markets});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minTileWidth = 200.0;
        const gap = 12.0;
        final indices = InstaOptionsMarketsProvider.tileIndices;
        final fits = constraints.maxWidth >=
            indices.length * minTileWidth + (indices.length - 1) * gap;

        final tiles = indices
            .map((name) => IndexTickerTile(
                  indexName: name,
                  quote: markets.quoteFor(name),
                  bars: markets.sparklineFor(name),
                ))
            .toList(growable: false);

        if (fits) {
          return Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: tiles
              .map((t) => SizedBox(width: minTileWidth, child: t))
              .toList(growable: false),
        );
      },
    );
  }
}

class _BuildupGrid extends StatelessWidget {
  final InstaOptionsMarketsProvider markets;
  final void Function(BuildupSymbol row) onRowTap;

  const _BuildupGrid({required this.markets, required this.onRowTap});

  @override
  Widget build(BuildContext context) {
    final buckets = BuildupBucket.values;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final twoCol = constraints.maxWidth >= 800;
        final cols = twoCol ? 2 : 1;
        final rows = (buckets.length / cols).ceil();
        final cellWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        final cellHeight = twoCol
            ? (constraints.maxHeight - gap * (rows - 1)) / rows
            : 320.0;
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemCount: buckets.length,
          itemBuilder: (context, i) {
            final b = buckets[i];
            return BuildupQuadrant(
              bucket: b,
              rows: markets.buildup.rowsFor(b),
              onRowTap: onRowTap,
            );
          },
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final InstaOptionsTokens tokens;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.tokens,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.bgPrimary,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: tokens.loss.withValues(alpha: 0.1),
            border: Border.all(color: tokens.loss, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_off, color: tokens.loss, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Markets Dashboard failed to load',
                    style: MyntWebTextStyles.body(
                      context,
                      color: tokens.loss,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: MyntWebTextStyles.caption(
                  context,
                  color: tokens.textSecondary,
                ),
              ),
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

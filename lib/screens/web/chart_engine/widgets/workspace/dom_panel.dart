import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import '../../state/chart_engine_store.dart';

/// Phase 25 — Depth of Market panel.
/// Reads the active pane's scrip from [chartEngineSessionProvider] and renders
/// a 5-level bid/ask ladder sourced from [websocketProvider]'s socketDatas map.
/// The panel live-updates whenever the websocket notifies — no manual refresh
/// needed because we use ref.watch on the ChangeNotifierProvider.
class DomPanel extends ConsumerWidget {
  final ValueChanged<ChartScrip> onSymbolPick;

  const DomPanel({super.key, required this.onSymbolPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(chartEngineSessionProvider);
    final scrip = session.active.scrip;

    // Watch the websocket provider so the widget rebuilds on every push.
    final ws = ref.watch(websocketProvider);

    if (scrip == null) {
      return const _DomEmpty(message: 'Pick a symbol first');
    }

    final rawData = ws.socketDatas[scrip.token];
    if (rawData is! Map) {
      return _DomEmpty(message: 'No depth data for ${scrip.dispName}');
    }

    final data = rawData;

    // Build 5 depth rows from bp1-5 / bq1-5 / sp1-5 / sq1-5.
    final rows = <_DomRow>[];
    for (var i = 1; i <= 5; i++) {
      final bp = double.tryParse(data['bp$i']?.toString() ?? '0') ?? 0;
      final bq = int.tryParse(data['bq$i']?.toString() ?? '0') ?? 0;
      final sp = double.tryParse(data['sp$i']?.toString() ?? '0') ?? 0;
      final sq = int.tryParse(data['sq$i']?.toString() ?? '0') ?? 0;
      rows.add(_DomRow(bp: bp, bq: bq, sp: sp, sq: sq));
    }

    final maxQty = rows.fold<int>(
      0,
      (m, r) => [m, r.bq, r.sq].reduce((a, b) => a > b ? a : b),
    );

    return Column(children: [
      _DomHeader(scrip: scrip),
      const Divider(height: 1),
      // Column headers
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Expanded(
            child: Text(
              'Bid Qty',
              style: MyntWebTextStyles.caption(context),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Bid',
              style: MyntWebTextStyles.caption(context),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Ask',
              style: MyntWebTextStyles.caption(context),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'Ask Qty',
              style: MyntWebTextStyles.caption(context),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      ),
      const Divider(height: 1),
      // Depth rows
      for (final r in rows) _DomRowTile(row: r, maxQty: maxQty),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class _DomRow {
  final double bp;
  final int bq;
  final double sp;
  final int sq;

  const _DomRow({
    required this.bp,
    required this.bq,
    required this.sp,
    required this.sq,
  });
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _DomHeader extends StatelessWidget {
  final ChartScrip scrip;

  const _DomHeader({required this.scrip});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        'DOM · ${scrip.dispName}',
        style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single depth row tile with proportional background bars
// ---------------------------------------------------------------------------

class _DomRowTile extends StatelessWidget {
  final _DomRow row;
  final int maxQty;

  const _DomRowTile({required this.row, required this.maxQty});

  @override
  Widget build(BuildContext context) {
    final bidPct = maxQty > 0 ? (row.bq / maxQty) : 0.0;
    final askPct = maxQty > 0 ? (row.sq / maxQty) : 0.0;

    // Use profit/loss colors as stand-ins for bullSoft/bearSoft (which don't
    // exist in MyntColors). A low-opacity fill keeps the bars subtle.
    final bidBg = MyntColors.profit.withValues(alpha: 0.18);
    final askBg = MyntColors.loss.withValues(alpha: 0.18);

    return SizedBox(
      height: 28,
      child: Row(children: [
        // Bid quantity — bar grows from right to left
        Expanded(
          child: Stack(children: [
            Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: bidPct.clamp(0.0, 1.0),
                heightFactor: 1.0,
                child: Container(color: bidBg),
              ),
            ),
            Center(
              child: Text(
                row.bq.toString(),
                style: MyntWebTextStyles.body(context),
              ),
            ),
          ]),
        ),
        // Bid price
        Expanded(
          child: Center(
            child: Text(
              row.bp.toStringAsFixed(2),
              style:
                  MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold),
            ),
          ),
        ),
        // Ask price
        Expanded(
          child: Center(
            child: Text(
              row.sp.toStringAsFixed(2),
              style:
                  MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold),
            ),
          ),
        ),
        // Ask quantity — bar grows from left to right
        Expanded(
          child: Stack(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: askPct.clamp(0.0, 1.0),
                heightFactor: 1.0,
                child: Container(color: askBg),
              ),
            ),
            Center(
              child: Text(
                row.sq.toString(),
                style: MyntWebTextStyles.body(context),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _DomEmpty extends StatelessWidget {
  final String message;

  const _DomEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        height: 40,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'DOM',
          style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold),
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              message,
              style: MyntWebTextStyles.caption(context),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ]);
  }
}

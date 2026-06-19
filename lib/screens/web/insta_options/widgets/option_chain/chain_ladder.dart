import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/option_chain/option_chain_data.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_columns.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_header_row.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_spot_row.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_strike_row.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// The option-chain ladder (market-watch style): a pinned header over a
/// virtualized 56px-row `ListView`, with the spot row inserted between the two
/// strikes that bracket the underlying price, and the spot/ATM centred on load
/// and on data change. Expose [ChainLadderState] via a `GlobalKey` to recenter.
class ChainLadder extends StatefulWidget {
  final OptionChainData data;

  const ChainLadder({super.key, required this.data});

  @override
  ChainLadderState createState() => ChainLadderState();
}

class ChainLadderState extends State<ChainLadder> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<int?> _hovered = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    centerOnAtm();
  }

  @override
  void didUpdateWidget(covariant ChainLadder oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = !identical(oldWidget.data, widget.data) &&
        (oldWidget.data.underlying != widget.data.underlying ||
            oldWidget.data.tradeDate != widget.data.tradeDate ||
            oldWidget.data.expiry != widget.data.expiry);
    if (changed) centerOnAtm();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _hovered.dispose();
    super.dispose();
  }

  /// List index of the spot row — inserted after the strike just below spot.
  int? _spotLineIndex() {
    final v = widget.data.underlyingValue;
    final rows = widget.data.rows;
    if (v == null || rows.isEmpty) return null;
    for (var i = 0; i < rows.length - 1; i++) {
      if (v >= rows[i].strike && v < rows[i + 1].strike) return i + 1;
    }
    if (v < rows.first.strike) return 0;
    return rows.length;
  }

  bool get _showSpot =>
      _spotLineIndex() != null && (widget.data.underlyingValue ?? 0) > 0;

  /// Jump so the spot row (or ATM, if spot isn't shown) is centred.
  void centerOnAtm() {
    final int? target = _showSpot ? _spotLineIndex() : widget.data.atmIndex;
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final vp = _scroll.position.viewportDimension;
      final off = (target * kChainRowH) - (vp / 2) + (kChainRowH / 2);
      _scroll.jumpTo(off.clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.data.rows;
    final spotIdx = _spotLineIndex();
    final showSpot = _showSpot;
    final itemCount = rows.length + (showSpot ? 1 : 0);

    return shadcn.OutlinedContainer(
      child: Column(
        children: [
          const ChainHeaderRow(),
          Expanded(
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _scroll,
                itemExtent: kChainRowH,
                itemCount: itemCount,
                itemBuilder: (context, i) {
                  if (showSpot && i == spotIdx) {
                    return ChainSpotRow(spot: widget.data.underlyingValue!);
                  }
                  final di = (showSpot && i > spotIdx!) ? i - 1 : i;
                  if (di < 0 || di >= rows.length) {
                    return const SizedBox.shrink();
                  }
                  return ChainStrikeRowTile(
                    row: rows[di],
                    index: di,
                    hovered: _hovered,
                    maxOi: widget.data.maxOiInView,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

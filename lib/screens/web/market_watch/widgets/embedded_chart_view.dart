import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/marketwatch_model/get_quotes.dart';
import 'package:mynt_plus/screens/web/chart_engine/chart_engine_shell_screen.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';

/// In-house chart engine embedded in the symbol details screen as the
/// "Trade from Chart" mode replacement for the TradingView portal.
///
/// **Symbol mirror.** The details screen's `wlValue` drives the symbol;
/// whenever it changes (user picked a new symbol from search / watchlist /
/// option chain) we push the scrip into the chart engine's ACTIVE pane.
/// This keeps multi-pane layouts working in embedded mode: the user can
/// split the chart, click a pane to focus it, then pick a symbol and it
/// lands on that pane — instead of collapsing back to a single pane.
/// The shell's own postMessage pipeline then reloads the iframe's chart.
class EmbeddedChartView extends ConsumerStatefulWidget {
  final DepthInputArgs wlValue;

  /// Scrip picked from the chart's own search box — lets the details page
  /// follow the chart. The page's resulting `wlValue` update comes back
  /// through [_ensureSync] as the same symbol, which setPaneSymbol no-ops.
  final void Function(ChartScrip scrip)? onSymbolPicked;

  const EmbeddedChartView(
      {super.key, required this.wlValue, this.onSymbolPicked});

  @override
  ConsumerState<EmbeddedChartView> createState() => _EmbeddedChartViewState();
}

class _EmbeddedChartViewState extends ConsumerState<EmbeddedChartView> {
  String? _lastSyncedKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSync());
  }

  @override
  void didUpdateWidget(covariant EmbeddedChartView old) {
    super.didUpdateWidget(old);
    if (widget.wlValue.token != old.wlValue.token ||
        widget.wlValue.exch != old.wlValue.exch) {
      _ensureSync();
    }
  }

  ChartScrip _buildScrip(DepthInputArgs v) => ChartScrip(
        exch: v.exch,
        token: v.token,
        tsym: v.tsym,
        dispName: (DerivativeMaster.nameFor(v.exch, v.token) ?? v.tsym)
            .replaceAll('-EQ', ''),
        // Lot size + tick size aren't on `DepthInputArgs`. Defaults here
        // are conservative; the chart engine's own GetSecurityInfo fetch
        // (kicked off by `setPaneSymbol`) backfills correct values + the
        // tradable flag.
        ls: 1,
        ti: 0.05,
        instname: v.instname,
      );

  void _ensureSync() {
    if (!mounted) return;
    final scrip = _buildScrip(widget.wlValue);
    // Dedup on the details symbol ALONE — never on the active pane index.
    // `_ensureSync` runs on every rebuild (incl. after a pane click changes
    // the active pane). If the key included the pane, focusing a different
    // pane would re-push the details symbol onto it and clobber whatever it
    // already held — e.g. clicking the NIFTY pane would overwrite it with
    // the SENSEX the details header currently shows. Keying on the symbol
    // means a pane switch with an unchanged details symbol is a no-op; the
    // push only happens when the user actually picks a new symbol, and it
    // lands on whichever pane is focused at that moment.
    final key = '${scrip.exch}|${scrip.token}';
    if (_lastSyncedKey == key) return;
    _lastSyncedKey = key;
    final session = ref.read(chartEngineSessionProvider);
    final target = session.panes.isEmpty
        ? 0
        : session.activePaneIndex.clamp(0, session.panes.length - 1);
    ref.read(chartEngineSessionProvider.notifier).setPaneSymbol(target, scrip);
  }

  @override
  Widget build(BuildContext context) {
    // Hot-trigger any pending sync (covers the case where the iframe
    // mounted before our didUpdateWidget fired).
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSync());
    return ChartEngineShellScreen(
      embedded: true,
      onSymbolPicked: widget.onSymbolPicked,
    );
  }
}

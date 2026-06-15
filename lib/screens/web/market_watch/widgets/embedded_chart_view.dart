import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/marketwatch_model/get_quotes.dart';
import 'package:mynt_plus/screens/web/chart_engine/chart_engine_shell_screen.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';

/// In-house chart engine embedded in the symbol details screen as the
/// "Trade from Chart" mode replacement for the TradingView portal.
///
/// Owns two integrations with the shared chart-engine session:
///   1) **Single-pane lock.** If the user previously used the /chart-engine
///      workspace with a multi-pane layout, that's collapsed back to a
///      single pane while we're embedded — the details screen is a
///      single-symbol surface.
///   2) **Symbol mirror.** The details screen's `wlValue` is the source of
///      truth; whenever it changes (user picked a new symbol from search
///      / watchlist / option chain) we push the scrip into pane 0 of the
///      chart engine session. The shell's own postMessage pipeline then
///      reloads the iframe's chart.
class EmbeddedChartView extends ConsumerStatefulWidget {
  final DepthInputArgs wlValue;
  const EmbeddedChartView({super.key, required this.wlValue});

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
        dispName: v.tsym,
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
    final key = '${scrip.exch}|${scrip.token}';
    if (_lastSyncedKey == key) return;
    _lastSyncedKey = key;
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    final session = ref.read(chartEngineSessionProvider);
    // Force single-pane — multi-pane is the /chart-engine workspace's
    // domain. Per spec: embedded mode always single.
    if (session.layout != ChartLayout.single) {
      notifier.setLayout(ChartLayout.single);
    }
    notifier.setPaneSymbol(0, scrip);
  }

  @override
  Widget build(BuildContext context) {
    // Hot-trigger any pending sync (covers the case where the iframe
    // mounted before our didUpdateWidget fired).
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSync());
    return const ChartEngineShellScreen(embedded: true);
  }
}

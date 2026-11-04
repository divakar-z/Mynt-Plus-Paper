import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/marketwatch_model/get_quotes.dart';
import 'package:mynt_plus/provider/market_watch_provider.dart';
import 'package:mynt_plus/screens/web/chart_engine/chart_engine_shell_screen.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';

/// `'EXCH|TOKEN'` of the symbol on the chart engine's currently-FOCUSED pane,
/// or `''` when that pane has no symbol yet. Used as a `select()` key so the
/// Market Info sync below only wakes on a real change of focused symbol: the
/// engine posts `paneActivated` on EVERY mousedown inside a pane (pans,
/// drawings, buy/sell strip clicks), and all of those collapse to the same
/// key and cost nothing.
String _focusedScripKey(ChartEngineSession s) {
  if (s.panes.isEmpty) return '';
  final scrip = s.panes[s.activePaneIndex.clamp(0, s.panes.length - 1)].scrip;
  return scrip == null ? '' : '${scrip.exch}|${scrip.token}';
}

/// In-house chart engine embedded in the symbol details screen as the
/// "Trade from Chart" mode replacement for the TradingView portal.
///
/// **Symbol mirror (details → chart).** The details screen's `wlValue` drives
/// the symbol; whenever it changes (user picked a new symbol from search /
/// watchlist / option chain) we push the scrip into the chart engine's ACTIVE
/// pane. This keeps multi-pane layouts working in embedded mode: the user can
/// split the chart, click a pane to focus it, then pick a symbol and it
/// lands on that pane — instead of collapsing back to a single pane.
/// The shell's own postMessage pipeline then reloads the iframe's chart.
///
/// **Panel sync (chart → details).** The reverse direction: focusing a
/// different pane — or re-symboling the focused pane from the chart's own
/// search — re-points the details screen (and with it the Market Info depth
/// panel) at that pane's symbol, so Market Info always describes the chart the
/// user is looking at. See [_syncPanelToFocusedPane].
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
  Timer? _panelSyncDebounce;

  /// Key of the panel sync currently waiting on its quote. Only the newest
  /// sync may finish, and `_ensureSync` holds off while one is running.
  String? _panelSyncKey;

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
      // The details screen moved to a new symbol — that pick beats any panel
      // sync still waiting on its quote.
      _panelSyncKey = null;
      _ensureSync();
    }
  }

  @override
  void dispose() {
    _panelSyncDebounce?.cancel();
    super.dispose();
  }

  String get _detailsKey => '${widget.wlValue.exch}|${widget.wlValue.token}';

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
    // A rebuild during the panel sync's quote fetch still carries the old
    // `wlValue`; pushing it now would overwrite the focused pane.
    if (_panelSyncKey != null) return;
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

  /// Focused pane's symbol changed. Debounced so click-through across several
  /// panes settles into ONE quote fetch + depth resubscribe instead of a burst
  /// — the depth feed is a single slot (`currentDepthSymbol`), so every
  /// intermediate symbol would otherwise cost a forced `ud` + a fresh `d` on
  /// the wire for a pane the user has already left.
  void _onFocusedScripChanged(String key) {
    _panelSyncDebounce?.cancel();
    _panelSyncKey = null;
    // Only the main details panel follows the chart — Scanner hosts its own
    // copy and must not be pulled into the main panel.
    if (widget.onSymbolPicked == null) return;
    if (key.isEmpty) return;
    // Already what the details screen shows — the common multi-pane case
    // (several panes on the same symbol) does no work at all.
    if (key == _detailsKey) return;
    _panelSyncDebounce = Timer(
      const Duration(milliseconds: 200),
      () => _syncPanelToFocusedPane(key),
    );
  }

  /// Re-point the details screen — and with it the Market Info depth panel —
  /// at the focused pane's symbol.
  ///
  /// `openScripInWebPanel` is the whole lever: it swaps the host screen's
  /// current depth args, whose rebuild already drives everything downstream
  /// (`ChartWithDepthWeb.didUpdateWidget` releases the old depth "d" and
  /// subscribes the new one, then `_ensureDataLoaded(force: true)` runs the
  /// full `calldepthApis` fetch; `ScripDepthInfoWeb.didUpdateWidget` re-points
  /// `regtoken` so the ladder can't render a mixed symbol mid-switch). Calling
  /// `calldepthApis` here as well would just run that chain twice per click.
  Future<void> _syncPanelToFocusedPane(String key) async {
    if (!mounted) return;
    final session = ref.read(chartEngineSessionProvider);
    if (session.panes.isEmpty) return;
    final scrip =
        session.panes[session.activePaneIndex.clamp(0, session.panes.length - 1)]
            .scrip;
    if (scrip == null) return;
    // Focus moved again while the timer was pending — the newer key owns the
    // panel; this stale one must not overwrite it.
    if ('${scrip.exch}|${scrip.token}' != key || key == _detailsKey) return;

    _panelSyncKey = key;

    final mw = ref.read(marketWatchProvider);
    // `ChartScrip` carries no symbol / expDate / option, which the details
    // header and the F&O contract line need — so resolve the full quote first,
    // the same order the index strip uses in watchlist_screen_web.dart. Results
    // are cached in `storeQuotes`, so re-focusing a pane is free.
    try {
      await mw.fetchScripQuote(scrip.token, scrip.exch, context);
    } catch (_) {
      // Fall through — the pane's own fields are enough for a basic sync.
    }
    if (!mounted) return;
    // A newer focus change or symbol pick took over during the fetch. This late
    // response still replaced the shared `getQuotes` that Market Info reads, and
    // `calldepthApis` won't refetch a cached quote, so put the details symbol's
    // quote back — unless a newer sync is still running and will set its own.
    if (_panelSyncKey != key) {
      if (_panelSyncKey == null) {
        await mw.fetchScripQuote(
            widget.wlValue.token, widget.wlValue.exch, context);
      }
      return;
    }
    _panelSyncKey = null;

    // Claim the key BEFORE the panel rebuilds. That rebuild hands us a new
    // `wlValue`, and `_ensureSync` would otherwise push this symbol straight
    // back onto the very pane it came from.
    _lastSyncedKey = key;

    final quote = mw.getQuotes;
    final resolved = quote != null && quote.token?.toString() == scrip.token;
    // Same fallback as the chart search path if the quote didn't resolve.
    final split = spilitTsym(value: scrip.tsym);
    mw.openScripInWebPanel(
      context,
      DepthInputArgs(
        exch: scrip.exch,
        token: scrip.token,
        tsym: (resolved ? quote.tsym?.toString() : null) ?? scrip.tsym,
        instname:
            (resolved ? quote.instname?.toString() : null) ?? scrip.instname,
        symbol: (resolved ? quote.symbol?.toString() : null) ??
            split['symbol']?.toString() ??
            scrip.tsym,
        expDate: (resolved ? quote.expDate?.toString() : null) ??
            split['expDate']?.toString() ??
            '',
        option: (resolved ? quote.option?.toString() : null) ??
            split['option']?.toString() ??
            '',
        // `isOption` is a tab-NAVIGATION intent, not a property of the symbol
        // (`ChartWithDepthWeb.didUpdateWidget` animates to the Options tab when
        // it flips, and the search dialog sets it true on every pick). Focusing
        // another pane must not move the user's tab, so carry the current
        // intent through unchanged — publishing a bare `false` would yank a
        // searched symbol off the Chart tab back to Overview.
        isOption: widget.wlValue.isOption,
      ),
      '',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Chart → details. Keyed on the focused pane's SYMBOL rather than its
    // index, so this also covers the user re-symboling the focused pane from
    // the chart's own search, and ignores the mousedown-driven pane-activation
    // traffic that doesn't change what's on screen.
    ref.listen<String>(
      chartEngineSessionProvider.select(_focusedScripKey),
      (_, next) => _onFocusedScripChanged(next),
    );
    // Hot-trigger any pending sync (covers the case where the iframe
    // mounted before our didUpdateWidget fired).
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSync());
    return ChartEngineShellScreen(
      embedded: true,
      onSymbolPicked: widget.onSymbolPicked == null
          ? null
          : (scrip) {
              // The host reloads the page for this pick itself, so the panel
              // sync the same symbol change just scheduled isn't needed.
              _panelSyncDebounce?.cancel();
              _panelSyncKey = null;
              widget.onSymbolPicked!(scrip);
            },
    );
  }
}

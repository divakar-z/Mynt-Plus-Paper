import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/screens/web/chart_engine/chart_engine_shell_screen.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';
import 'package:mynt_plus/screens/web/chart_engine/utils/popout_feed_client.dart';

/// Detached, view-only chart window served at `/chart-popout`. It is a SECOND
/// Flutter instance opened via `window.open` from the logged-in app, so instead
/// of re-implementing the chart host in JS (the old `web/chart-popout/` loopback
/// shell) it reuses the REAL host — [ChartEngineShellScreen] — in `popout` mode:
///
///  * **No trading.** The iframe boots `?popout=1`, which hides the order-click
///    surfaces and the INSTANT / Order-Defaults controls; the shell skips the
///    GTT/order book and all order handlers.
///  * **Throwaway session.** [kChartPopoutMode] (flipped in `main.dart` before
///    the ProviderScope mounts) makes the session store neither hydrate from nor
///    persist to the main window's saved layout, so opening / closing the popout
///    can never clobber it. This screen seeds the one pane from the URL.
///  * **Alternate feed.** Live ticks come from [PopoutFeedClient]
///    (`wss://ws.zebull.in`), NOT the shared `websocketProvider` — the main
///    window owns the single allowed `go.mynt.in` Noren socket, and a second
///    connection with the same uid would kick it. The per-popout slot `n` keeps
///    the mint uid (`<clientId>_<n>_TA`) unique across windows.
///
/// URL contract — everything is a query param and the broker jKey is NEVER in
/// the URL (the feed mints its own token; history + search reuse the app session
/// already in this origin's localStorage):
///
///   /chart-popout?exch=NSE&token=26000&tsym=NIFTY&tf=5&n=1
class ChartPopoutScreen extends ConsumerStatefulWidget {
  final String exch;
  final String token;
  final String tsym;
  final int timeframeMinutes;

  /// Per-popout slot (`n` in the URL) — keeps the alternate-feed uid unique so
  /// multiple popouts (and the main socket) never collide.
  final int slot;

  const ChartPopoutScreen({
    super.key,
    required this.exch,
    required this.token,
    required this.tsym,
    required this.timeframeMinutes,
    required this.slot,
  });

  @override
  ConsumerState<ChartPopoutScreen> createState() => _ChartPopoutScreenState();
}

class _ChartPopoutScreenState extends ConsumerState<ChartPopoutScreen> {
  late final PopoutFeedClient _feed;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    // The alternate feed's base uid is the app's clientId (same value the old
    // JS loopback read from localStorage `flutter.clientId`). SharedPreferences
    // is already initialised in main() for every route, popout included.
    final baseUid = (locator<Preferences>().clientId ?? '').trim();
    _feed = PopoutFeedClient(baseUid, widget.slot);
    // Seed the single pane AFTER the first frame so the session notifier (which
    // built a fresh popout session — see [kChartPopoutMode]) exists to receive
    // it. The shell's own postMessage pipeline then loads history + subscribes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedSymbol());
  }

  void _seedSymbol() {
    if (!mounted || _seeded) return;
    if (widget.exch.isEmpty || widget.token.isEmpty) return;
    _seeded = true;
    // Conservative ls/ti placeholders; the shell's GetSecurityInfo backfill
    // (kicked off by setPaneSymbol) corrects lot size + tick size.
    final scrip = ChartScrip(
      exch: widget.exch,
      token: widget.token,
      tsym: widget.tsym,
      dispName: widget.tsym.replaceAll('-EQ', ''),
      ls: 1,
      ti: 0.05,
    );
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    notifier.setPaneSymbol(0, scrip);
    notifier.setPaneTimeframe(0, widget.timeframeMinutes);
    _carryOverFromMainSession(notifier);
  }

  /// One-time, read-only carry-over: copy the popped-out symbol's drawings and
  /// the main chart's active-pane indicators from the SAVED session into this
  /// throwaway popout session, so the detached window opens with the same
  /// analysis the user was looking at. Reads the prefs blob DIRECTLY — the
  /// notifier itself never hydrates in popout mode (see [kChartPopoutMode]) —
  /// and only seeds via add* (persistence is a no-op here), so it can never
  /// write back to or clobber the main window's saved session.
  void _carryOverFromMainSession(ChartEngineSessionNotifier notifier) {
    try {
      final raw = locator<Preferences>().getChartEngineSession();
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final saved = ChartEngineSession.fromJson(decoded);
      // Drawings are keyed by 'EXCH|TOKEN' (symbol-scoped) — copy this symbol's.
      final scripKey = '${widget.exch}|${widget.token}';
      final savedDrawings = saved.drawings[scripKey];
      if (savedDrawings != null) {
        for (final d in savedDrawings) {
          notifier.addDrawing(scripKey, d);
        }
      }
      // Indicators are per-pane (symbol-agnostic). Copy the pane the user popped
      // out from — the saved ACTIVE pane, i.e. what was on screen — onto our
      // single pane 0.
      if (saved.panes.isNotEmpty) {
        final idx = saved.activePaneIndex.clamp(0, saved.panes.length - 1);
        for (final ind in saved.panes[idx].indicators) {
          notifier.addIndicator(0, ind);
        }
      }
    } catch (_) {
      // Best-effort — a clean popout is an acceptable fallback.
    }
  }

  @override
  void dispose() {
    // Idempotent — the shell also stops the feed on its own dispose, but the
    // screen owns it, so stop here too in case the shell never mounted.
    _feed.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChartEngineShellScreen(
        embedded: true,
        popout: true,
        feed: _feed,
      ),
    );
  }
}

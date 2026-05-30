import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One option-chain strike, normalized for chart-side render.
class ChartOiStrike {
  final double strike;
  final double callOi;
  final double putOi;
  final double callOiChgPct;
  final double putOiChgPct;
  const ChartOiStrike({
    required this.strike,
    required this.callOi,
    required this.putOi,
    required this.callOiChgPct,
    required this.putOiChgPct,
  });

  Map<String, Object?> toJson() => {
        'strike': strike,
        'callOi': callOi,
        'putOi': putOi,
        'callOiChgPct': callOiChgPct,
        'putOiChgPct': putOiChgPct,
      };
}

/// Transient (non-persisted) per-pane OI data fetched from the option-chain
/// API. Refreshed every 120s by the shell screen while a supported index
/// spot is shown with the "Show option-chain OI" toggle ON.
class ChartOiData {
  final Map<int, List<ChartOiStrike>> byPane;
  final Map<int, int> fetchedAtByPane; // epoch ms
  const ChartOiData({
    this.byPane = const {},
    this.fetchedAtByPane = const {},
  });

  ChartOiData copyWith({
    Map<int, List<ChartOiStrike>>? byPane,
    Map<int, int>? fetchedAtByPane,
  }) =>
      ChartOiData(
        byPane: byPane ?? this.byPane,
        fetchedAtByPane: fetchedAtByPane ?? this.fetchedAtByPane,
      );
}

class ChartOiDataNotifier extends Notifier<ChartOiData> {
  @override
  ChartOiData build() => const ChartOiData();

  /// Set / overwrite OI strikes for [paneIndex]. Stamps [fetchedAt] (epoch ms)
  /// so the shell's refresh-cadence check (120s window) sees the freshness.
  void setForPane(
      int paneIndex, List<ChartOiStrike> strikes, int fetchedAt) {
    if (paneIndex < 0) return;
    final nextBy = Map<int, List<ChartOiStrike>>.from(state.byPane);
    nextBy[paneIndex] = strikes;
    final nextAt = Map<int, int>.from(state.fetchedAtByPane);
    nextAt[paneIndex] = fetchedAt;
    state = state.copyWith(byPane: nextBy, fetchedAtByPane: nextAt);
  }

  /// Drop cached OI for [paneIndex] (toggle OFF, symbol change, pane removed).
  void clearForPane(int paneIndex) {
    if (!state.byPane.containsKey(paneIndex) &&
        !state.fetchedAtByPane.containsKey(paneIndex)) {
      return;
    }
    final nextBy = Map<int, List<ChartOiStrike>>.from(state.byPane)
      ..remove(paneIndex);
    final nextAt = Map<int, int>.from(state.fetchedAtByPane)
      ..remove(paneIndex);
    state = state.copyWith(byPane: nextBy, fetchedAtByPane: nextAt);
  }
}

final chartOiDataProvider =
    NotifierProvider<ChartOiDataNotifier, ChartOiData>(
  ChartOiDataNotifier.new,
);

/// Phase 20.1 — Per-pane cached expiry list + nearest-expiry pick from
/// `getLinkedScrip`. Used by the OI fetcher to pass the right `tradeSym`
/// (an expiry-specific tsym like "NIFTY30SEP25") to `getOptionChain`.
class ChartOptionExpiry {
  final String tsym; // e.g. "NIFTY30SEP25" — used as tradeSym
  final String exd; // e.g. "30-SEP-2025"
  final String exch; // exchange to call getOptionChain against (NFO / BFO / MCX)
  const ChartOptionExpiry({
    required this.tsym,
    required this.exd,
    required this.exch,
  });
}

class ChartOptionExpiryCache {
  final Map<int, ChartOptionExpiry> nearestByPane;
  // Keyed by paneIndex; we also stamp the scrip token+exch the expiry was
  // fetched for, so a symbol change clears the stale cache.
  final Map<int, String> scripKeyByPane;
  const ChartOptionExpiryCache({
    this.nearestByPane = const {},
    this.scripKeyByPane = const {},
  });
  ChartOptionExpiryCache copyWith({
    Map<int, ChartOptionExpiry>? nearestByPane,
    Map<int, String>? scripKeyByPane,
  }) =>
      ChartOptionExpiryCache(
        nearestByPane: nearestByPane ?? this.nearestByPane,
        scripKeyByPane: scripKeyByPane ?? this.scripKeyByPane,
      );
}

class ChartOptionExpiryCacheNotifier
    extends Notifier<ChartOptionExpiryCache> {
  @override
  ChartOptionExpiryCache build() => const ChartOptionExpiryCache();

  void setForPane(int paneIndex, ChartOptionExpiry expiry, String scripKey) {
    if (paneIndex < 0) return;
    final next = Map<int, ChartOptionExpiry>.from(state.nearestByPane);
    next[paneIndex] = expiry;
    final nextK = Map<int, String>.from(state.scripKeyByPane);
    nextK[paneIndex] = scripKey;
    state = state.copyWith(nearestByPane: next, scripKeyByPane: nextK);
  }

  void clearForPane(int paneIndex) {
    if (!state.nearestByPane.containsKey(paneIndex) &&
        !state.scripKeyByPane.containsKey(paneIndex)) {
      return;
    }
    final next = Map<int, ChartOptionExpiry>.from(state.nearestByPane)
      ..remove(paneIndex);
    final nextK = Map<int, String>.from(state.scripKeyByPane)
      ..remove(paneIndex);
    state = state.copyWith(nearestByPane: next, scripKeyByPane: nextK);
  }
}

final chartOptionExpiryProvider =
    NotifierProvider<ChartOptionExpiryCacheNotifier, ChartOptionExpiryCache>(
  ChartOptionExpiryCacheNotifier.new,
);

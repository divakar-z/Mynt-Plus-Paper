import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A one-shot request to apply a symbol to the chart engine's CURRENTLY-active
/// pane. Used by the watchlist so a pick lands on the focused pane reliably:
/// instead of reading Flutter's `activePaneIndex` (which can be momentarily
/// stale relative to the iframe's own focus marker), the shell forwards this to
/// the engine, which applies it to its live `.pane.active` and reports back the
/// exact pane index to sync the store.
///
/// `seq` bumps on every request so the shell's listener fires even when the
/// same symbol is requested twice (e.g. putting a symbol already shown in
/// another pane onto the focused one).
class ActivePaneSymbolRequest {
  final Map<String, dynamic>? scrip;
  final int seq;
  const ActivePaneSymbolRequest({this.scrip, this.seq = 0});
}

class ActivePaneSymbolRequestNotifier
    extends Notifier<ActivePaneSymbolRequest> {
  @override
  ActivePaneSymbolRequest build() => const ActivePaneSymbolRequest();

  void request(Map<String, dynamic> scrip) {
    state = ActivePaneSymbolRequest(scrip: scrip, seq: state.seq + 1);
  }
}

final activePaneSymbolRequestProvider = NotifierProvider<
    ActivePaneSymbolRequestNotifier, ActivePaneSymbolRequest>(
  ActivePaneSymbolRequestNotifier.new,
);

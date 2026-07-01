import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/provider/web_subscription_manager.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';

/// InstaOptions' live-tick layer over the existing Noren socket
/// ([websocketProvider]).
///
/// The **active section** declares the full set of `exchange|token` keys it
/// wants live via [setActive]; we diff against what's already subscribed —
/// subscribing the new ones and unsubscribing the ones the section no longer
/// needs. Moving to the next section calls [setActive] with *its* keys, so the
/// previous section's unique tokens are dropped and the new ones added. Leaving
/// the module calls [clear].
///
/// Reads are by the bare numeric `token` (the socket data map's key). Overlays
/// use [ltpOr] — the live price once a tick has arrived, else the API snapshot
/// value; it never returns a phantom `0` (the socket provider sanitises those).
/// OI / PCR / max-pain / buildup stay snapshot — never read here.
final instaLiveTicksProvider =
    ChangeNotifierProvider((ref) => InstaLiveTicks(ref));

class InstaLiveTicks extends ChangeNotifier {
  final Ref ref;

  /// `exchange|token` keys currently subscribed on behalf of InstaOptions.
  final Set<String> _subscribed = <String>{};
  BuildContext? _ctx;
  VoidCallback? _wsListener;

  InstaLiveTicks(this.ref) {
    // Re-emit on every socket tick so overlay widgets watching us rebuild.
    final ws = ref.read(websocketProvider);
    _wsListener = notifyListeners;
    ws.addListener(_wsListener!);
  }

  Set<String> get subscribed => Set.unmodifiable(_subscribed);

  /// Replace the active section's subscriptions with [tickKeys] (each
  /// `exchange|token`). Unsubscribes what's no longer needed, subscribes what's
  /// new. Idempotent — safe to call on every data refresh.
  void setActive(Set<String> tickKeys, BuildContext context) {
    _ctx = context;
    final keys = tickKeys.where((k) => k.isNotEmpty).toSet();
    final toAdd = keys.difference(_subscribed);
    final toRemove = _subscribed.difference(keys);
    if (toRemove.isNotEmpty) _unsubscribe(toRemove, context);
    if (toAdd.isNotEmpty) _subscribe(toAdd, context);
    _subscribed
      ..removeAll(toRemove)
      ..addAll(toAdd);
  }

  /// Drop every InstaOptions subscription (module unmounted).
  void clear() {
    if (_subscribed.isEmpty) return;
    final ctx = _ctx;
    if (ctx != null) _unsubscribe(_subscribed.toSet(), ctx);
    _subscribed.clear();
  }

  void _subscribe(Set<String> keys, BuildContext context) {
    try {
      ref
          .read(websocketProvider)
          .connectTouchLine(task: 'd', input: keys.join('#'), context: context);
    } catch (_) {}
  }

  void _unsubscribe(Set<String> keys, BuildContext context) {
    try {
      // Protected-symbol-aware: won't unsubscribe tokens the watchlist /
      // positions / ticker / index header still need.
      ref.read(webSubscriptionManagerProvider).unsubscribeTokens(
            tokensToCheck: keys,
            context: context,
            source: 'instaOptions',
          );
    } catch (_) {}
  }

  // ---- live reads (by numeric token) ----
  Map get _data => ref.read(websocketProvider).socketDatas;

  double? _num(Object? v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty || s == 'null') return null;
    return double.tryParse(s);
  }

  /// Live last price, or null if no (non-zero) tick has arrived yet.
  double? liveLtp(String? token) {
    if (token == null || token.isEmpty) return null;
    final v = _num(_data[token]?['lp']);
    return (v == null || v == 0) ? null : v;
  }

  /// Live last price if available, else the snapshot [fallback].
  double? ltpOr(String? token, double? fallback) => liveLtp(token) ?? fallback;

  /// Live absolute day-change (socket `chng`), from the instrument's own lp/c.
  double? liveChange(String? token) =>
      token == null ? null : _num(_data[token]?['chng']);

  /// Live day-change % (socket `pc`), from the instrument's own lp/c.
  double? liveChangePct(String? token) =>
      token == null ? null : _num(_data[token]?['pc']);

  /// A live tick has arrived for [token].
  bool isLive(String? token) => liveLtp(token) != null;

  @override
  void dispose() {
    try {
      if (_wsListener != null) {
        ref.read(websocketProvider).removeListener(_wsListener!);
      }
    } catch (_) {}
    _wsListener = null;
    super.dispose();
  }
}

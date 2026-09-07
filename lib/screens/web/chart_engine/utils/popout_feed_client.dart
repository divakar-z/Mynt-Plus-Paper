// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

/// Live-feed client for the chart POPOUT (the second Flutter instance served on
/// the `/chart-popout` route). The broker allows exactly ONE `go.mynt.in` Noren
/// socket per session and the MAIN window holds it, so the popout must NOT use
/// the app's shared `websocketProvider` — a second connection with the same uid
/// would kick the main one.
///
/// This is a 1:1 Dart port of the proven JS `FeedManager`
/// (`web/chart-popout/popout-shell.js`): it mints a per-popout socket token and
/// connects to the ALTERNATE feed `wss://ws.zebull.in/NorenWS/` with a
/// `<baseUid>_<n>_TA` / `<baseUid>_<n>_TA_TV` uid, so it never collides with the
/// main socket or with other popouts (the `<n>` is the per-popout slot).
///
/// Ticks are delivered via [onTick] in the SAME `{token, packet}` shape the
/// chart engine's `tick` message expects (lp/v/ft/bp1/sp1/o/h/l) — the caller
/// posts `encodeTick(token, packet)` into the engine iframe.
class PopoutFeedClient {
  PopoutFeedClient(this.baseUid, this.n);

  final String baseUid;
  final int n;

  /// (token, packet) for every applied tick.
  void Function(String token, Map<String, dynamic> packet)? onTick;

  /// Session permanently dead (3 consecutive empty mints) — the host can show a
  /// "session expired" overlay.
  void Function()? onExpired;

  static const String _mintUrl =
      'https://sess.mynt.in/generateSocketSession';
  static const String _wsUrl = 'wss://ws.zebull.in/NorenWS/';

  final Set<String> _subs = <String>{}; // "EXCH|TOKEN"
  html.WebSocket? _ws;
  int _gen = 0; // invalidates stale client callbacks
  bool _up = false; // true once the current socket acked 'ck'
  int _backoffMs = 1000; // doubles per failure, cap 15000
  int _lastTickAtMs = 0;
  int _emptyMintCount = 0;
  Timer? _watchdog;
  Timer? _heartbeat;
  bool _stopped = false;

  String get _feedUid => '${baseUid}_${n}_TA';
  String get _connectUid => '${baseUid}_${n}_TA_TV';

  void start() {
    _stopped = false;
    // Stall watchdog: if acked but no tick for >10s, force a reconnect.
    _watchdog ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (_up &&
          _lastTickAtMs != 0 &&
          DateTime.now().millisecondsSinceEpoch - _lastTickAtMs > 10000) {
        _reconnect();
      }
    });
    _open();
  }

  void subscribe(String exch, String token) {
    final key = '$exch|$token';
    _subs.add(key);
    if (_up && _ws != null) _send({'t': 't', 'k': key});
  }

  void unsubscribe(String exch, String token) {
    final key = '$exch|$token';
    _subs.remove(key);
    if (_up && _ws != null) _send({'t': 'u', 'k': key});
  }

  void stop() {
    _stopped = true;
    _gen++;
    _watchdog?.cancel();
    _watchdog = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    _up = false;
  }

  Future<String> _mint() async {
    try {
      final res = await html.HttpRequest.request(
        _mintUrl,
        method: 'POST',
        requestHeaders: const {'Content-Type': 'application/json'},
        sendData: jsonEncode({'uid': _feedUid, 'src': 'TV', 'source': 'TV'}),
      );
      final j = jsonDecode(res.responseText ?? '');
      if (j is Map && j['session'] is String) return j['session'] as String;
    } catch (_) {}
    return '';
  }

  Future<void> _open() async {
    if (_stopped) return;
    _gen++;
    final gen = _gen;
    _up = false;
    try {
      _ws?.close();
    } catch (_) {}
    final token = await _mint();
    if (gen != _gen || _stopped) return; // superseded by a newer generation
    if (token.isEmpty) {
      _emptyMintCount++;
      if (_emptyMintCount >= 3) {
        stop();
        onExpired?.call();
        return;
      }
      _reconnect();
      return;
    }
    _emptyMintCount = 0;
    final ws = html.WebSocket(_wsUrl);
    _ws = ws;
    ws.onOpen.listen((_) {
      if (gen != _gen) return;
      _send({
        't': 'c',
        'uid': _connectUid,
        'actid': _connectUid,
        'source': 'TV',
        'susertoken': token,
      });
    });
    ws.onMessage.listen((html.MessageEvent e) {
      if (gen != _gen) return;
      _onFrame(e.data);
    });
    ws.onClose.listen((_) {
      if (gen == _gen) _reconnect();
    });
    ws.onError.listen((_) {
      if (gen == _gen) _reconnect();
    });
  }

  void _onFrame(dynamic raw) {
    Map<String, dynamic>? frame;
    try {
      final d = raw is String ? jsonDecode(raw) : raw;
      if (d is Map) frame = Map<String, dynamic>.from(d);
    } catch (_) {}
    if (frame == null) return;
    if (frame['t'] == 'ck') {
      _onAck();
      return;
    }
    final t = frame['t'];
    if (t != 'tf' && t != 'tk' && t != 'df' && t != 'dk') return;
    final tk = frame['tk'];
    final lp = frame['lp'];
    if (tk == null || lp == null) return;
    // Build the same packet the main host's tickPacket forwards. Unlike the JS
    // loopback (which hardcoded v:0 + ft:now and dropped o/h/l), forward the
    // real superset when present so the popout bar/volume/session-OHLC match.
    final packet = <String, dynamic>{'lp': _num(lp)};
    if (frame['v'] != null) packet['v'] = _num(frame['v']);
    if (frame['ft'] != null) packet['ft'] = _int(frame['ft']);
    if (frame['bp1'] != null) packet['bp1'] = _num(frame['bp1']);
    if (frame['sp1'] != null) packet['sp1'] = _num(frame['sp1']);
    if (frame['o'] != null) packet['o'] = _num(frame['o']);
    if (frame['h'] != null) packet['h'] = _num(frame['h']);
    if (frame['l'] != null) packet['l'] = _num(frame['l']);
    final exch = frame['exch'] ?? frame['e'];
    if (exch != null) packet['exch'] = exch;
    _lastTickAtMs = DateTime.now().millisecondsSinceEpoch;
    onTick?.call(tk.toString(), packet);
  }

  void _onAck() {
    _up = true;
    _backoffMs = 1000; // reset backoff on a good connection
    // Re-send the whole tracked set in one '#'-joined frame.
    if (_subs.isNotEmpty) _send({'t': 't', 'k': _subs.join('#')});
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
        const Duration(seconds: 5), (_) => _send({'t': 'h'}));
  }

  void _reconnect() {
    if (_stopped) return;
    _gen++;
    _heartbeat?.cancel();
    _heartbeat = null;
    try {
      _ws?.close();
    } catch (_) {}
    _up = false;
    final wait = _backoffMs;
    _backoffMs = (_backoffMs * 2) > 15000 ? 15000 : _backoffMs * 2;
    Timer(Duration(milliseconds: wait), () {
      if (!_stopped) _open();
    });
  }

  void _send(Map<String, dynamic> obj) {
    try {
      _ws?.send(jsonEncode(obj));
    } catch (_) {}
  }

  static num _num(dynamic v) =>
      v is num ? v : (num.tryParse(v.toString()) ?? 0);
  static int _int(dynamic v) =>
      v is int ? v : (int.tryParse(v.toString()) ?? 0);
}

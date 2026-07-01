import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';

/// Drop-in intraday polling for the date-based providers. While a screen is in
/// **live mode**, call [startPolling] with a silent refetch; it fires every
/// [interval] (default 90s, within the API's 60–120s guidance), **pauses while
/// the browser tab is hidden/backgrounded**, and cancels itself on dispose. The
/// server caches today's snapshot and only advances `freshness.as_of` ~every
/// 5 min, so a missed/extra tick costs nothing.
mixin LivePolling on DefaultChangeNotifier {
  Timer? _pollTimer;
  Future<void> Function()? _pollAction;
  Duration _pollInterval = const Duration(seconds: 90);
  _LifecycleHook? _lifecycle;
  bool _appHidden = false;

  bool get isPolling => _pollTimer != null;

  void startPolling(
    Future<void> Function() action, {
    Duration interval = const Duration(seconds: 90),
  }) {
    _pollAction = action;
    _pollInterval = interval;
    _lifecycle ??= _LifecycleHook(onHidden: _onAppHidden);
    _armTimer();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollAction = null;
  }

  void _armTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_pollAction == null || _appHidden || disposed) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      final action = _pollAction;
      if (disposed || action == null) return;
      action();
    });
  }

  void _onAppHidden(bool hidden) {
    if (_appHidden == hidden) return;
    _appHidden = hidden;
    _armTimer(); // hidden → cancel; visible again → re-arm
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollAction = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    super.dispose();
  }
}

/// Bridges Flutter's app-lifecycle to a `hidden` flag. On web, `hidden` /
/// `paused` fire when the tab is backgrounded (Page Visibility); we ignore
/// `inactive` so a transient focus blur doesn't stop polling.
class _LifecycleHook with WidgetsBindingObserver {
  final void Function(bool hidden) onHidden;

  _LifecycleHook({required this.onHidden}) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onHidden(state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached);
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}

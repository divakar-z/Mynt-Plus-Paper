import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../res/app_release.dart';
import '../utils/web_build_update.dart' as web_update;
import 'core/default_change_notifier.dart';

/// Watches the hosted site for a newer web build than the one running in
/// this tab, and drives the "new update available" banner in the shell.
///
/// Detection: at startup the provider captures the RUNNING build's identity
/// (version.json and flutter_bootstrap.js fetched plainly, which the Flutter
/// service worker answers from the cache belonging to this build) and then
/// re-fetches the same two files cache-busted — straight from the server —
/// every [_pollInterval] and whenever the tab regains focus. A server copy
/// that differs from the running copy means a newer build is hosted, whether
/// it was deployed before this tab opened (stale-cache start) or while it
/// was open. flutter_bootstrap.js changes on every `flutter build web` (the
/// tool stamps a random service-worker version into it), so a release is
/// detected even when the pubspec version was not bumped; version.json is
/// compared as well because it carries the human-readable number when the
/// pubspec WAS bumped.
///
/// Responses are validated before comparison (a captive portal answering
/// every URL with its own 200 page must not look like a release), and the
/// flag is recomputed on every valid poll, so a transient bad read or a
/// server rollback heals itself.
///
/// Every step logs to the browser console with a [BuildUpdate] prefix, so
/// the whole flow can be verified on a hosted release build via F12.
final webBuildUpdateProvider =
    ChangeNotifierProvider((ref) => WebBuildUpdateProvider(ref));

class WebBuildUpdateProvider extends DefaultChangeNotifier {
  final Ref ref;

  WebBuildUpdateProvider(this.ref) {
    _init();
  }

  static const Duration _pollInterval = Duration(minutes: 5);
  static const Duration _snoozeDuration = Duration(minutes: 30);

  /// What this tab is actually running, captured once at startup and never
  /// re-read (a background service-worker update must not shift it).
  String? _runningVersionJson;
  String? _runningBootstrap;

  /// Last server state adopted as reference for the rare case where no
  /// running copy could be captured (then only in-session deploys are
  /// detectable).
  String? _baselineVersionJson;
  String? _baselineBootstrap;

  bool _updateAvailable = false;
  String? _serverVersionLabel;
  DateTime? _snoozedUntil;
  bool _applying = false;
  bool _checkInFlight = false;
  int _checkCount = 0;
  Timer? _pollTimer;
  Timer? _snoozeTimer;
  Future<void> Function()? _cancelVisibilityListener;

  bool get updateAvailable => _updateAvailable;
  bool get applying => _applying;

  /// The server's version.json identity, set only when it differs from the
  /// running build. Often null even when an update is available: releases
  /// that bump only AppRelease (not the pubspec version) are still detected
  /// via flutter_bootstrap.js, but bring no new number to show.
  String? get serverVersionLabel => _serverVersionLabel;

  bool get showStrip =>
      _updateAvailable &&
      (_snoozedUntil == null || DateTime.now().isAfter(_snoozedUntil!));

  void _log(String message) => debugPrint('[BuildUpdate] $message');

  /// Accepts a body only if it parses as the version.json shape; anything
  /// else (portal page, proxy error) is treated like an unreachable server.
  String? _sanitizeVersionJson(String? raw) {
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is Map && data.containsKey('version')) return raw;
    } catch (_) {}
    return null;
  }

  /// Accepts a body only if it looks like a Flutter bootstrap script.
  String? _sanitizeBootstrap(String? raw) {
    if (raw == null) return null;
    if (raw.contains('_flutter') || raw.contains('serviceWorkerVersion')) {
      return raw;
    }
    return null;
  }

  Future<void> _init() async {
    if (!kIsWeb) return;
    _log('Running release: ${AppRelease.version} build ${AppRelease.build} '
        '(released ${AppRelease.releasedOn})');
    // Plain (un-busted) reads: with the Flutter service worker in control
    // they are served from its cache, which belongs to the running build —
    // not to whatever the server hosts now.
    _runningVersionJson = _sanitizeVersionJson(
        await web_update.fetchCachedFile('version.json'));
    _runningBootstrap = _sanitizeBootstrap(
        await web_update.fetchCachedFile('flutter_bootstrap.js'));
    if (disposed) return;
    _log('Running copy — version.json: '
        '${_describeVersionJson(_runningVersionJson)}, '
        'flutter_bootstrap.js: ${_describeBlob(_runningBootstrap)}');
    // First server read doubles as the startup staleness check: a tab that
    // OPENED on a stale cache — the very complaint this feature exists for —
    // is flagged immediately.
    await checkForUpdate('startup');
    if (disposed) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => checkForUpdate('timer'));
    _cancelVisibilityListener =
        web_update.addTabVisibleListener(() => checkForUpdate('tab focus'));
  }

  Future<void> checkForUpdate(String trigger) async {
    if (!kIsWeb || _applying || disposed || _checkInFlight) return;
    _checkInFlight = true;
    try {
      _checkCount++;
      final versionJson = _sanitizeVersionJson(
          await web_update.fetchServerFile('version.json'));
      final bootstrap = _sanitizeBootstrap(
          await web_update.fetchServerFile('flutter_bootstrap.js'));
      if (disposed) return;
      if (versionJson == null && bootstrap == null) {
        _log('Check #$_checkCount ($trigger): '
            'server unreachable or answered garbage — skipped');
        return;
      }
      // No running copy captured (e.g. first visit with no service worker,
      // or startup while offline): adopt the first good server read as the
      // reference, so at least in-session deploys are detected.
      if (_runningVersionJson == null &&
          _baselineVersionJson == null &&
          versionJson != null) {
        _baselineVersionJson = versionJson;
        _log('Reference (server, late) — version.json: '
            '${_describeVersionJson(versionJson)}');
      }
      if (_runningBootstrap == null &&
          _baselineBootstrap == null &&
          bootstrap != null) {
        _baselineBootstrap = bootstrap;
        _log('Reference (server, late) — flutter_bootstrap.js: '
            '${_describeBlob(bootstrap)}');
      }
      final versionRef = _runningVersionJson ?? _baselineVersionJson;
      final bootstrapRef = _runningBootstrap ?? _baselineBootstrap;
      final versionChanged = versionJson != null &&
          versionRef != null &&
          versionJson != versionRef;
      final bootstrapChanged =
          bootstrap != null && bootstrapRef != null && bootstrap != bootstrapRef;
      final wasAvailable = _updateAvailable;
      // Recomputed every valid poll — a transient portal page or a server
      // rollback must not latch the banner forever.
      _updateAvailable = versionChanged || bootstrapChanged;
      _serverVersionLabel =
          versionChanged ? _describeVersionJson(versionJson) : null;
      if (_updateAvailable) {
        final reasons = [
          if (versionChanged)
            'server version.json is ${_describeVersionJson(versionJson)}',
          if (bootstrapChanged) 'flutter_bootstrap.js differs from this build',
        ].join(', ');
        _log('Check #$_checkCount ($trigger): '
            '${wasAvailable ? 'update still available' : 'UPDATE AVAILABLE'}'
            ' — $reasons');
        notifyListeners();
      } else if (wasAvailable) {
        _log('Check #$_checkCount ($trigger): server matches this build '
            'again — banner cleared');
        notifyListeners();
      } else {
        _log('Check #$_checkCount ($trigger): up to date '
            '(server version.json: ${_describeVersionJson(versionJson)})');
      }
    } finally {
      _checkInFlight = false;
    }
  }

  /// Close-button action: hides the strip for [_snoozeDuration], then shows
  /// it again — closing only delays the update, it never cancels it.
  void snooze() {
    _snoozedUntil = DateTime.now().add(_snoozeDuration);
    _log('Banner closed — snoozed for ${_snoozeDuration.inMinutes} minutes');
    _snoozeTimer?.cancel();
    _snoozeTimer = Timer(_snoozeDuration + const Duration(seconds: 1), () {
      if (disposed) return;
      _log('Snooze over — showing the banner again');
      notifyListeners();
    });
    notifyListeners();
  }

  /// Update-now action: downloads and activates the new build, then reloads.
  Future<void> applyUpdate() async {
    if (_applying) return;
    _applying = true;
    notifyListeners();
    _log('Update clicked — downloading and activating the new build');
    await web_update.applyUpdateAndReload(_log);
    // applyUpdateAndReload always ends in location.reload(); if navigation
    // somehow never happens, don't leave a dead 'Updating…' strip behind.
    Timer(const Duration(seconds: 5), () {
      if (disposed || !_applying) return;
      _applying = false;
      _log('Page did not reload — banner re-enabled');
      notifyListeners();
    });
  }

  String _describeVersionJson(String? raw) {
    if (raw == null) return 'unavailable';
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return '${data['version']}+${data['build_number']}';
    } catch (_) {
      return '${raw.length} bytes';
    }
  }

  String _describeBlob(String? raw) =>
      raw == null ? 'unavailable' : '${raw.length} bytes (hash ${raw.hashCode})';

  @override
  void dispose() {
    _pollTimer?.cancel();
    _snoozeTimer?.cancel();
    _cancelVisibilityListener?.call();
    super.dispose();
  }
}

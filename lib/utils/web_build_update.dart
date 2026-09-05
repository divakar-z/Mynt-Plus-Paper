// Web-only plumbing for the "new build available" banner
// (see lib/provider/web_build_update_provider.dart for the detection logic).
//
// Direct dart:html import is the accepted pattern for web-only code in this
// repo (lib/provider/web_subscription_manager.dart is the precedent).
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Fetches [path] from our own origin with a cache-busting query parameter,
/// so the response bypasses both the service-worker cache (whose resource
/// keys carry no query string) and the browser HTTP cache — it is always
/// what the server is hosting right now. Returns null on any failure.
Future<String?> fetchServerFile(String path) async {
  try {
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    final separator = path.contains('?') ? '&' : '?';
    return await html.HttpRequest.getString('$path${separator}cb=$cacheBuster');
  } catch (_) {
    return null;
  }
}

/// Fetches [path] exactly the way the app itself loads it — no cache-buster —
/// so with the Flutter service worker in control the response comes from its
/// cache and identifies the RUNNING build. Returns null on any failure.
Future<String?> fetchCachedFile(String path) async {
  try {
    return await html.HttpRequest.getString(path);
  } catch (_) {
    return null;
  }
}

/// Runs [onVisible] every time this tab becomes visible again. Returns a
/// cancel callback so the caller can detach the listener on dispose.
Future<void> Function() addTabVisibleListener(void Function() onVisible) {
  final subscription = html.document.onVisibilityChange.listen((_) {
    if (html.document.visibilityState == 'visible') onVisible();
  });
  return subscription.cancel;
}

/// Downloads and activates the freshly hosted build, then reloads the page.
///
/// The only download path in the whole system that bypasses the browser HTTP
/// cache for main.dart.js is the Flutter service worker's install step (it
/// fetches every core file with cache:'reload'). So instead of nudging
/// whatever worker happens to own the root scope — often the
/// firebase-messaging one that index.html registers over the Flutter worker,
/// which knows nothing about our files — this registers
/// flutter_service_worker.js itself under a cache-busted URL, waits for that
/// exact worker to finish installing AND activating (its activate handler
/// copies the fresh files into flutter-app-cache; 'activated' means the copy
/// is complete), and only then reloads. The Flutter worker skipWaiting()s on
/// install, so no message nudging is needed.
///
/// If anything goes wrong (no service-worker support, registration failure,
/// timeout), it falls back to deleting every flutter-* cache so the reload
/// at least cannot serve stale service-worker content, and reloads anyway.
Future<void> applyUpdateAndReload(void Function(String) log) async {
  var freshWorkerActivated = false;
  try {
    final container = html.window.navigator.serviceWorker;
    if (container == null) {
      log('service workers unsupported — using cache-clear fallback');
    } else {
      final buster = 'upd${DateTime.now().millisecondsSinceEpoch}';
      log('registering flutter_service_worker.js?v=$buster '
          'to download the new build');
      final registration =
          await container.register('flutter_service_worker.js?v=$buster');
      final started = DateTime.now();
      const cap = Duration(seconds: 60);
      while (DateTime.now().difference(started) < cap) {
        final active = registration.active;
        final scriptUrl = active?.scriptUrl ?? '';
        if (registration.installing == null &&
            registration.waiting == null &&
            active != null &&
            active.state == 'activated' &&
            scriptUrl.contains(buster)) {
          freshWorkerActivated = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      log(freshWorkerActivated
          ? 'new build downloaded and activated in ${elapsed}ms'
          : 'new worker not activated after ${elapsed}ms — '
              'using cache-clear fallback');
    }
  } catch (e) {
    log('service worker registration failed ($e) — using cache-clear fallback');
  }

  if (!freshWorkerActivated) {
    // Without a freshly activated Flutter worker, stale flutter-* caches are
    // the one thing we can still rule out. (The browser HTTP cache may still
    // serve subresources after reload — logged honestly rather than hidden.)
    try {
      final caches = html.window.caches;
      if (caches != null) {
        final keys = await caches.keys();
        for (final key in List<Object?>.from(keys as List)) {
          final name = key.toString();
          if (name.startsWith('flutter-')) {
            await caches.delete(name);
            log('cleared cache "$name"');
          }
        }
      }
    } catch (e) {
      log('cache clearing skipped ($e)');
    }
  }

  log('reloading now');
  html.window.location.reload();
}

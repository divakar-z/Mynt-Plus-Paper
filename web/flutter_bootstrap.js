// Custom Flutter web bootstrap template.
//
// Flutter uses this file (when present in web/) as the template for the
// generated build/web/flutter_bootstrap.js, substituting its build-time
// placeholders (the flutter-js and flutter-build-config tokens below) in place.
//
// IMPORTANT: do not write those token names with their real double-brace
// delimiters anywhere except the two placeholder lines below. Flutter does a
// naive string replace, so a token mentioned in a comment would also be
// expanded (injecting flutter.js into the comment and breaking the script).
//
// Why this file exists:
//   By default Flutter loads CanvasKit (canvaskit.js + canvaskit.wasm, ~2.2MB
//   brotli) from https://www.gstatic.com/flutter-canvaskit/<engineRevision>/.
//   That puts a large download on a third-party origin in the critical render
//   path, needing an extra DNS + TLS handshake before the first frame.
//
//   `flutter build web` already copies a local CanvasKit into build/web/canvaskit/.
//   Setting `canvasKitBaseUrl` makes the engine load it from our own origin so
//   it is HTTP/2-multiplexed with the rest of the app. The value is relative so
//   it respects the page's <base href>.

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
  // Keep the Flutter service-worker registration that the DEFAULT bootstrap
  // includes. Omitting it means new deploys can't update a previously-installed
  // service worker, leaving stale cached assets that break startup. The token
  // below is substituted by the build (a quoted version string, or null).
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});

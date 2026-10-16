// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Mirrors the accessibility colour adjustments (invert, grayscale, blue-light,
/// smart-contrast, theme-tone) onto the app's HTML chart surfaces.
///
/// The Flutter layer applies these via `ColorFiltered` in `MyApp.build`, but a
/// `ColorFiltered` only affects the canvas Flutter paints. Every chart in the
/// app is an HTML platform view — the TradingView portal iframe, the in-house
/// chart-engine iframe, the scan-explain lite iframe, the mobile-path
/// `flutter_inappwebview` iframe and the scalper TradingView `<div>`s — which
/// the browser composites in the DOM *outside* that canvas. So the Flutter
/// filter never touches them and, without this, enabling "Invert Colours"
/// (or any tone/contrast option) left every chart un-inverted.
///
/// A CSS `filter:` set on the host element does apply to the iframe's rendered
/// output, even cross-origin (it's a visual-only effect, no content access).
/// This service keeps the current filter string and:
///   * applies it to every chart element already in the DOM, and
///   * watches the DOM (via [html.MutationObserver]) so a chart opened *after*
///     the toggle still inherits the active filter.
///
/// The on/off effects (grayscale, invert, smart-contrast) come from
/// `composeChartCssFilter` in `accessibility_provider.dart` as plain CSS filter
/// *functions*. Blue Light and Theme Tone need a full colour matrix, which CSS
/// has no function for, so they are expressed as an SVG `<feColorMatrix>` — but
/// **inlined as a self-contained `data:` URI** (`filter: url("data:…#id")`)
/// rather than a `url(#id)` reference into a DOM `<defs>`.
///
/// Why the data URI matters: a bare `url(#id)` fragment is resolved by the
/// browser against the document's `<base href>` — which Flutter web sets to the
/// site root (`<base href="/">`). Once GoRouter navigates to a sub-path (e.g.
/// `/home`) on the deployed build, the current URL no longer matches that base,
/// so `url(#a11y-chart-tone)` points at a fragment in a *different* document,
/// resolves to nothing, and the browser silently drops the filter — the chart
/// renders untinted. It works in local dev only because there you sit at the
/// root URL. Inlining the `<filter>` in a `data:` URI makes the `#id` resolve
/// *inside the URI itself*, immune to `<base href>` and client-side routing.
class ChartA11yFilter {
  ChartA11yFilter._();
  static final ChartA11yFilter instance = ChartA11yFilter._();

  /// CSS selectors matching every chart host element in the app. Keyed on the
  /// stable id prefixes each chart manager assigns:
  ///   * `web-chart-iframe-*`          → WebChartManager (TradingView portal)
  ///   * `chart-engine-chart-iframe-*` → ChartEngineShellScreen (in-house)
  ///   * `lite-chart-engine-iframe-*`  → LiteChartIframeHost (scan explain)
  ///   * `flutter_inappwebview-*`      → ChartScreenWebView (mobile-path chart)
  ///   * `scalper-*`                   → ScalperChartManager (TradingView divs)
  static const List<String> _selectors = <String>[
    'iframe[id^="web-chart-iframe-"]',
    'iframe[id^="chart-engine-chart-iframe-"]',
    'iframe[id^="lite-chart-engine-iframe-"]',
    'iframe[id^="flutter_inappwebview-"]',
    'div[id^="scalper-"]',
  ];

  /// Fragment id embedded in the Theme Tone data URI (`…#a11y-chart-tone`).
  static const String _toneFilterId = 'a11y-chart-tone';

  /// Fragment id embedded in the Blue Light data URI (`…#a11y-chart-bluelight`).
  static const String _blueLightFilterId = 'a11y-chart-bluelight';

  /// Blue Light matrix in `feColorMatrix` form. This is the SAME transform the
  /// Flutter canvas applies in `MyApp.build` (red +15, green +5, blue ×0.7 on a
  /// 0-255 scale) — the offsets are just rescaled to feColorMatrix's 0-1 range
  /// (15/255 ≈ 0.0588, 5/255 ≈ 0.0196). A flat CSS `sepia()` barely warms a
  /// white chart; this reproduces the app's amber tint exactly.
  static const String _blueLightValues =
      '1 0 0 0 0.0588 '
      '0 1 0 0 0.0196 '
      '0 0 0.7 0 0 '
      '0 0 0 1 0';

  String _filter = '';
  html.MutationObserver? _observer;

  /// Applies the accessibility colour adjustments to every chart surface.
  ///
  /// [filter] is the plain CSS filter chain for the on/off effects that CSS
  /// reproduces faithfully (grayscale, invert, smart-contrast). [toneTint],
  /// when non-null, is the selected Theme Tone as `[r, g, b]` channel scales in
  /// `[0, 1]`; [blueLight] toggles the Blue Light warm tint. Both are applied
  /// as self-contained `data:` URI SVG `feColorMatrix` filters using the EXACT
  /// matrices the Flutter canvas uses in `MyApp.build`, so the chart matches the
  /// rest of the app instead of a loose CSS approximation, and keeps working on
  /// the deployed build regardless of `<base href>` / route (see class doc).
  ///
  /// Idempotent — safe to invoke on every widget rebuild.
  void apply({
    required String filter,
    List<double>? toneTint,
    bool blueLight = false,
  }) {
    _ensureObserver();
    final refs = <String>[];
    if (blueLight) {
      refs.add(_matrixDataUri(_blueLightFilterId, _blueLightValues));
    }
    if (toneTint != null) {
      refs.add(_matrixDataUri(
        _toneFilterId,
        _diagonalMatrix(toneTint[0], toneTint[1], toneTint[2]),
      ));
    }
    final composed = <String>[filter, ...refs]
        .where((s) => s.isNotEmpty)
        .join(' ');
    if (composed == _filter) return;
    _filter = composed;
    for (final el in _chartElements()) {
      _applyTo(el);
    }
  }

  /// Builds a self-contained `filter` reference: an SVG `<filter id=[id]>`
  /// holding a single `<feColorMatrix values=[values]>`, inlined as a
  /// `data:image/svg+xml` URI and referenced by its own `#id` fragment. Because
  /// the fragment resolves *within* the data URI, it is immune to the page's
  /// `<base href>` and to GoRouter route changes — the failure mode that left
  /// `url(#id)` filters unapplied on the deployed build.
  ///
  /// `color-interpolation-filters='sRGB'` (not the linearRGB default) keeps the
  /// transform matching the naive channel maths used on the Flutter canvas, so
  /// the chart tint reads identically to the rest of the app.
  String _matrixDataUri(String id, String values) {
    final svg =
        "<svg xmlns='http://www.w3.org/2000/svg'>"
        "<filter id='$id' color-interpolation-filters='sRGB'>"
        "<feColorMatrix type='matrix' values='$values'/>"
        "</filter></svg>";
    // Percent-encode the markup so quotes/spaces/angle-brackets are always
    // valid inside CSS url("…"); the `#id` fragment is appended raw so it stays
    // a document fragment reference rather than encoded text.
    final encoded = Uri.encodeComponent(svg);
    return 'url("data:image/svg+xml,$encoded#$id")';
  }

  static String _diagonalMatrix(double r, double g, double b) =>
      '$r 0 0 0 0 '
      '0 $g 0 0 0 '
      '0 0 $b 0 0 '
      '0 0 0 1 0';

  List<html.Element> _chartElements() {
    final elements = <html.Element>[];
    for (final selector in _selectors) {
      try {
        elements.addAll(html.document.querySelectorAll(selector));
      } catch (_) {
        // Malformed selector should never happen; guard defensively so one
        // bad match can't stop the others from applying.
      }
    }
    return elements;
  }

  void _applyTo(html.Element el) {
    // Set both the standard and -webkit- prefixed property; some Chromium
    // builds still need the prefixed form for filters on composited iframes.
    el.style.filter = _filter;
    el.style.setProperty('-webkit-filter', _filter);
  }

  bool _isChart(html.Element el) {
    for (final selector in _selectors) {
      try {
        if (el.matches(selector)) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Installs the DOM observer once. It re-applies the current filter to any
  /// chart element (or subtree containing one) added after a toggle, so
  /// opening a chart while a filter is active still filters it.
  void _ensureObserver() {
    if (_observer != null) return;
    final body = html.document.body;
    if (body == null) return;

    final observer = html.MutationObserver((mutations, obs) {
      if (_filter.isEmpty) return;
      for (final mutation in mutations) {
        for (final node in mutation.addedNodes) {
          if (node is! html.Element) continue;
          if (_isChart(node)) _applyTo(node);
          // A platform view is often wrapped in a slot/host element, so the
          // added node may merely contain the chart iframe.
          for (final selector in _selectors) {
            try {
              node.querySelectorAll(selector).forEach(_applyTo);
            } catch (_) {}
          }
        }
      }
    });
    observer.observe(body, childList: true, subtree: true);
    _observer = observer;
  }
}

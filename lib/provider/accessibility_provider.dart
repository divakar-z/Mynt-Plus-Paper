import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../locator/locator.dart';
import '../locator/preference.dart';
import '../services/web_hover_reader.dart';
import '../services/web_speech_service.dart';
import 'core/default_change_notifier.dart';

final accessibilityProvider =
    ChangeNotifierProvider<AccessibilityNotifier>((ref) => AccessibilityNotifier());

/// Default UI font used across the web text-style helpers.
const String defaultUiFontFamily = 'Geist';

/// Font family swapped in when Dyslexia Support is on. The web text-style
/// helpers (WebTextStyles, MyntFonts, ShadcnTextStyles) read this instead of
/// hardcoding 'Geist' so toggling dyslexia actually changes the rendered font
/// — DefaultTextStyle alone cannot override an explicit `fontFamily:` set on
/// each TextStyle. Updated from AccessibilityNotifier.toggleDyslexiaSupport
/// alongside notifyListeners(), so the MyApp rebuild re-runs every helper.
String _uiFontFamily = defaultUiFontFamily;
String get uiFontFamily => _uiFontFamily;

/// Font family forced when Dyslexia Support is on.
const String dyslexiaFontFamily = 'OpenDyslexic';

/// True while Dyslexia Support is active. Mirrored as a top-level flag (kept in
/// sync from AccessibilityNotifier.toggleDyslexiaSupport) so pure text-style
/// helpers — which have no BuildContext/ref — can stay dyslexia-aware.
bool _dyslexiaFontActive = false;
bool get dyslexiaFontActive => _dyslexiaFontActive;

/// Resolves a font family that stays dyslexia-aware: returns [dyslexiaFontFamily]
/// when Dyslexia Support is on, otherwise the caller's own [fallback]. Use this
/// at every call site that would otherwise hardcode a family (`'Geist'`,
/// `'Inter'`, `'tenon'`, …) so the toggle swaps the font app-wide. An explicit
/// `fontFamily:` on a TextStyle does NOT inherit the root DefaultTextStyle, so
/// those sites must opt in through this helper to switch.
String dyslexiaFontOr(String fallback) =>
    _dyslexiaFontActive ? dyslexiaFontFamily : fallback;

/// Overall colour tone applied on top of the existing theme. `none` is the
/// off state; the remaining values map 1:1 to the coloured dots in the panel.
enum ThemeTone { none, blue, warm, cool, sepia }

/// Holds user-facing accessibility preferences.
///
/// When the in-app screen reader is enabled, a browser-level `mousemove`
/// listener observes every hover (including over dialogs), the closest
/// semantics label is hit-tested from Flutter's semantics tree, and the
/// browser's Web Speech API speaks it. Speech is automatically cancelled
/// when the user leaves the tab/window.
class AccessibilityNotifier extends DefaultChangeNotifier {
  AccessibilityNotifier() {
    _reader = WebHoverReader(
      onHover: (x, y) => _scheduleSpeak(Offset(x, y)),
      onLeave: _stopAndReset,
    );
    _load();
  }

  static const _dwell = Duration(milliseconds: 250);

  bool _screenReaderEnabled = false;
  bool _grayscaleEnabled = false;
  bool _invertColoursEnabled = false;
  bool _blueLightFilterEnabled = false;
  bool _smartContrastEnabled = false;
  bool _adhdFocusAssistEnabled = false;
  bool _dyslexiaSupportEnabled = false;
  bool _highlightLinksEnabled = false;
  bool _focusIndicatorEnabled = false;
  ThemeTone _themeTone = ThemeTone.none;

  // Symmetric scale: 4 steps down and 4 steps up from baseline (index 4 = 1.0).
  static const List<double> _textScaleSteps = <double>[
    0.6, 0.7, 0.8,
    1.0,
    1.1, 1.2, 1.3,
  ];
  static const int _textScaleBaseline = 3;
  int _textScaleIndex = _textScaleBaseline;
  SemanticsHandle? _semanticsHandle;
  late final WebHoverReader _reader;

  int? _lastSpokenNodeId;
  Offset? _pendingPosition;
  Timer? _dwellTimer;

  bool get screenReaderEnabled => _screenReaderEnabled;
  bool get grayscaleEnabled => _grayscaleEnabled;
  bool get invertColoursEnabled => _invertColoursEnabled;
  bool get blueLightFilterEnabled => _blueLightFilterEnabled;
  bool get smartContrastEnabled => _smartContrastEnabled;
  bool get adhdFocusAssistEnabled => _adhdFocusAssistEnabled;
  bool get dyslexiaSupportEnabled => _dyslexiaSupportEnabled;
  bool get highlightLinksEnabled => _highlightLinksEnabled;
  bool get focusIndicatorEnabled => _focusIndicatorEnabled;
  ThemeTone get themeTone => _themeTone;
  bool get themeToneEnabled => _themeTone != ThemeTone.none;
  double get textScale => _textScaleSteps[_textScaleIndex];
  bool get textScaleEnabled => _textScaleIndex != _textScaleBaseline;

  /// The colour-adjustment options — Grayscale, Invert Colours, Blue Light
  /// Filter, Smart Contrast and Theme Tone — are mutually exclusive. Each one
  /// applies a full-screen colour matrix in `MyApp.build`; stacking several
  /// (Invert + Grayscale, Theme Tone + Blue Light, …) composites into muddy,
  /// unreadable output, so the group behaves like a single-choice mode:
  /// enabling any one clears the others. Kept in the notifier (not the panel)
  /// so every entry point stays consistent. The text/overlay/audio options
  /// (Screen Reader, Font Size, Dyslexia, Highlight Links, Focus Indicator,
  /// ADHD Focus Assist) are independent and intentionally left combinable.
  void _clearColourFiltersExcept({
    bool grayscale = false,
    bool invert = false,
    bool blueLight = false,
    bool smartContrast = false,
    bool themeTone = false,
  }) {
    if (!grayscale) _grayscaleEnabled = false;
    if (!invert) _invertColoursEnabled = false;
    if (!blueLight) _blueLightFilterEnabled = false;
    if (!smartContrast) _smartContrastEnabled = false;
    if (!themeTone) _themeTone = ThemeTone.none;
  }

  void toggleGrayscale() {
    _grayscaleEnabled = !_grayscaleEnabled;
    if (_grayscaleEnabled) _clearColourFiltersExcept(grayscale: true);
    notifyListeners();
  }

  void toggleInvertColours() {
    _invertColoursEnabled = !_invertColoursEnabled;
    if (_invertColoursEnabled) _clearColourFiltersExcept(invert: true);
    notifyListeners();
  }

  void toggleBlueLightFilter() {
    _blueLightFilterEnabled = !_blueLightFilterEnabled;
    if (_blueLightFilterEnabled) _clearColourFiltersExcept(blueLight: true);
    notifyListeners();
  }

  void toggleSmartContrast() {
    _smartContrastEnabled = !_smartContrastEnabled;
    if (_smartContrastEnabled) _clearColourFiltersExcept(smartContrast: true);
    notifyListeners();
  }

  void toggleAdhdFocusAssist() {
    _adhdFocusAssistEnabled = !_adhdFocusAssistEnabled;
    notifyListeners();
  }

  void toggleDyslexiaSupport() {
    _dyslexiaSupportEnabled = !_dyslexiaSupportEnabled;
    _dyslexiaFontActive = _dyslexiaSupportEnabled;
    _uiFontFamily = _dyslexiaSupportEnabled ? dyslexiaFontFamily : defaultUiFontFamily;
    notifyListeners();
  }

  void toggleHighlightLinks() {
    _highlightLinksEnabled = !_highlightLinksEnabled;
    notifyListeners();
  }

  void toggleFocusIndicator() {
    _focusIndicatorEnabled = !_focusIndicatorEnabled;
    notifyListeners();
  }

  /// Selects a tone directly. Tapping the currently-active tone clears it,
  /// so each coloured dot behaves like an independent toggle.
  void setThemeTone(ThemeTone tone) {
    _themeTone = (_themeTone == tone) ? ThemeTone.none : tone;
    if (_themeTone != ThemeTone.none) _clearColourFiltersExcept(themeTone: true);
    notifyListeners();
  }

  void resetThemeTone() {
    if (_themeTone == ThemeTone.none) return;
    _themeTone = ThemeTone.none;
    notifyListeners();
  }

  bool get canIncreaseTextScale =>
      _textScaleIndex < _textScaleSteps.length - 1;
  bool get canDecreaseTextScale => _textScaleIndex > 0;

  void increaseTextScale() {
    if (!canIncreaseTextScale) return;
    _textScaleIndex++;
    notifyListeners();
  }

  void decreaseTextScale() {
    if (!canDecreaseTextScale) return;
    _textScaleIndex--;
    notifyListeners();
  }

  void resetTextScale() {
    if (_textScaleIndex == _textScaleBaseline) return;
    _textScaleIndex = _textScaleBaseline;
    notifyListeners();
  }

  void toggleScreenReader(BuildContext context) {
    _screenReaderEnabled = !_screenReaderEnabled;
    if (_screenReaderEnabled) {
      _semanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
      _reader.start();
      WebSpeechService.instance
          .speak('Screen reader enabled.');
    } else {
      _reader.stop();
      _stopAndReset();
      _semanticsHandle?.dispose();
      _semanticsHandle = null;
    }
    notifyListeners();
  }

  void speak(String text) {
    if (!_screenReaderEnabled) return;
    WebSpeechService.instance.speak(text);
  }

  void stopSpeaking() => WebSpeechService.instance.stop();

  void _scheduleSpeak(Offset position) {
    _pendingPosition = position;
    _dwellTimer?.cancel();
    _dwellTimer = Timer(_dwell, _speakAtPending);
  }

  void _stopAndReset() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _pendingPosition = null;
    _lastSpokenNodeId = null;
    WebSpeechService.instance.stop();
  }

  void _speakAtPending() {
    // Defer the semantics walk to after the current frame commits so we
    // don't race with tree rebuilds during drawer/dialog animations —
    // mid-animation nodes can briefly expose null transforms/parents.
    SchedulerBinding.instance.addPostFrameCallback((_) => _runSpeak());
  }

  void _runSpeak() {
    final position = _pendingPosition;
    if (position == null || !_screenReaderEnabled) return;

    try {
      SemanticsNode? hit;
      for (final view in RendererBinding.instance.renderViews) {
        final root = view.owner?.semanticsOwner?.rootSemanticsNode;
        if (root == null) continue;
        hit = _hitTestNode(root, position, Matrix4.identity());
        if (hit != null) break;
      }
      if (hit == null) return;

      final target = _resolveLabelNode(hit);
      if (target == null) return;
      if (target.id == _lastSpokenNodeId) return;

      final text = _extractText(target);
      if (text.isEmpty) return;

      _lastSpokenNodeId = target.id;
      WebSpeechService.instance.speak(text);
    } catch (_) {
      // Semantics tree was mid-rebuild; drop this read and let the next
      // hover event retry with a stable tree.
    }
  }

  /// Finds the deepest semantics node whose transformed rect contains
  /// [globalPosition], regardless of whether it carries a label itself.
  SemanticsNode? _hitTestNode(
      SemanticsNode node, Offset globalPosition, Matrix4 parentTransform) {
    final transform = parentTransform.clone();
    if (node.transform != null) transform.multiply(node.transform!);
    final globalRect = MatrixUtils.transformRect(transform, node.rect);
    if (!globalRect.contains(globalPosition)) return null;

    SemanticsNode? deepest;
    node.visitChildren((child) {
      final found = _hitTestNode(child, globalPosition, transform);
      if (found != null) deepest = found;
      return deepest == null;
    });
    return deepest ?? node;
  }

  /// From the hit node, find the nearest labeled node — preferring the hit
  /// itself, then any labeled descendant (covers Row(Icon, Text) rows where
  /// the icon is the deepest hit but the Text sibling holds the label), then
  /// walking up ancestors (covers dropdown/menu entries that label their
  /// wrapper instead of leaves).
  SemanticsNode? _resolveLabelNode(SemanticsNode start) {
    if (_hasText(start)) return start;
    final descendant = _firstLabeledDescendant(start);
    if (descendant != null) return descendant;
    SemanticsNode? cursor = start.parent;
    while (cursor != null) {
      if (_hasText(cursor)) return cursor;
      cursor = cursor.parent;
    }
    return null;
  }

  SemanticsNode? _firstLabeledDescendant(SemanticsNode node) {
    SemanticsNode? found;
    node.visitChildren((child) {
      if (found != null) return false;
      if (_hasText(child)) {
        found = child;
        return false;
      }
      final sub = _firstLabeledDescendant(child);
      if (sub != null) {
        found = sub;
        return false;
      }
      return true;
    });
    return found;
  }

  bool _hasText(SemanticsNode node) =>
      node.label.isNotEmpty || node.value.isNotEmpty || node.hint.isNotEmpty;

  String _extractText(SemanticsNode node) {
    final parts = <String>[];
    if (node.label.isNotEmpty) parts.add(node.label);
    if (node.value.isNotEmpty) parts.add(node.value);
    if (node.hint.isNotEmpty) parts.add(node.hint);
    return parts.join(', ');
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _reader.stop();
    _semanticsHandle?.dispose();
    _semanticsHandle = null;
    WebSpeechService.instance.stop();
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────
  // Preferences.init() runs in main() before runApp, and this notifier is
  // created lazily on first watch — so the saved values are already available
  // and _load() can run synchronously with no first-frame flash of defaults.

  /// Restores the preferences written by [_persist] on construction.
  void _load() {
    final raw = locator<Preferences>().accessibilitySettings;
    if (raw == null || raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _grayscaleEnabled = m['grayscale'] as bool? ?? false;
      _invertColoursEnabled = m['invert'] as bool? ?? false;
      _blueLightFilterEnabled = m['blueLight'] as bool? ?? false;
      _smartContrastEnabled = m['smartContrast'] as bool? ?? false;
      _adhdFocusAssistEnabled = m['adhd'] as bool? ?? false;
      _dyslexiaSupportEnabled = m['dyslexia'] as bool? ?? false;
      _highlightLinksEnabled = m['highlightLinks'] as bool? ?? false;
      _focusIndicatorEnabled = m['focusIndicator'] as bool? ?? false;

      final toneName = m['themeTone'] as String?;
      _themeTone = ThemeTone.values.firstWhere(
        (t) => t.name == toneName,
        orElse: () => ThemeTone.none,
      );

      final idx = m['textScaleIndex'];
      if (idx is int && idx >= 0 && idx < _textScaleSteps.length) {
        _textScaleIndex = idx;
      }

      // Re-apply the side effects the setters normally perform. The dyslexia
      // font globals are read app-wide by the text-style helpers, so they must
      // be in sync before the first build — not just mirrored on the notifier.
      _dyslexiaFontActive = _dyslexiaSupportEnabled;
      _uiFontFamily =
          _dyslexiaSupportEnabled ? dyslexiaFontFamily : defaultUiFontFamily;

      // Screen reader restore: start the hover reader after the first frame so
      // ensureSemantics() doesn't mutate the semantics tree mid-build. Silent —
      // no "Screen reader enabled." announcement, since the user isn't toggling
      // it now, they're just returning to a session where it was already on.
      if (m['screenReader'] as bool? ?? false) {
        _screenReaderEnabled = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_screenReaderEnabled) return;
          _semanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
          _reader.start();
        });
      }
    } catch (_) {
      // Corrupt or outdated payload — ignore and keep the defaults.
    }
  }

  void _persist() {
    final m = <String, dynamic>{
      'grayscale': _grayscaleEnabled,
      'invert': _invertColoursEnabled,
      'blueLight': _blueLightFilterEnabled,
      'smartContrast': _smartContrastEnabled,
      'adhd': _adhdFocusAssistEnabled,
      'dyslexia': _dyslexiaSupportEnabled,
      'highlightLinks': _highlightLinksEnabled,
      'focusIndicator': _focusIndicatorEnabled,
      'screenReader': _screenReaderEnabled,
      'themeTone': _themeTone.name,
      'textScaleIndex': _textScaleIndex,
    };
    locator<Preferences>().setAccessibilitySettings(jsonEncode(m));
  }

  /// Every state change funnels through [notifyListeners], so persisting here
  /// keeps SharedPreferences in lock-step with the UI without threading a
  /// save call through all fourteen mutators. [_load] runs before any listener
  /// exists and never notifies, so this never fires during restore.
  @override
  void notifyListeners() {
    _persist();
    super.notifyListeners();
  }
}

/// Builds the CSS `filter:` value for the on/off chart adjustments that CSS
/// reproduces faithfully (grayscale, invert, smart-contrast) so the iframe
/// inherits the same colour adjustments as the Flutter layer. Shared between
/// the market-watch single chart and the scalper charts so every chart
/// container stays in lock-step with the accessibility panel.
///
/// Theme Tone and Blue Light Filter are intentionally NOT included here — they
/// are applied as inline SVG `feColorMatrix` filters in `ChartA11yFilter.apply`
/// using the EXACT matrices painted on the Flutter canvas, so the chart matches
/// the app instead of a loose CSS `sepia()/hue-rotate()` approximation (which
/// barely tinted a white chart).
String composeChartCssFilter(AccessibilityNotifier a11y) {
  final parts = <String>[];
  if (a11y.grayscaleEnabled) parts.add('grayscale(1)');
  if (a11y.invertColoursEnabled) parts.add('invert(1)');
  if (a11y.smartContrastEnabled) parts.add('contrast(1.3)');
  return parts.join(' ');
}

/// The pale tint colour for each Theme Tone. Multiplied over the content so a
/// white/light background shifts toward the tone while dark text and candles
/// stay legible. Returns null for [ThemeTone.none].
///
/// Single source of truth shared by the Flutter canvas (`ColorFilter.matrix`
/// in `MyApp.build`) and the chart surfaces (`ChartA11yFilter.apply`), so both
/// land on the identical colour.
Color? themeToneTint(ThemeTone tone) {
  switch (tone) {
    case ThemeTone.none:
      return null;
    case ThemeTone.blue:
      return const Color(0xFFCCE5FF);
    case ThemeTone.warm:
      return const Color(0xFFFFF4CC);
    case ThemeTone.cool:
      return const Color(0xFFDEF5E4);
    case ThemeTone.sepia:
      return const Color(0xFFFFD6D9);
  }
}

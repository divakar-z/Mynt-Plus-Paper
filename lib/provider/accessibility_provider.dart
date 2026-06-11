import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/legacy.dart';

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

  void toggleGrayscale() {
    _grayscaleEnabled = !_grayscaleEnabled;
    notifyListeners();
  }

  void toggleInvertColours() {
    _invertColoursEnabled = !_invertColoursEnabled;
    notifyListeners();
  }

  void toggleBlueLightFilter() {
    _blueLightFilterEnabled = !_blueLightFilterEnabled;
    notifyListeners();
  }

  void toggleSmartContrast() {
    _smartContrastEnabled = !_smartContrastEnabled;
    notifyListeners();
  }

  void toggleAdhdFocusAssist() {
    _adhdFocusAssistEnabled = !_adhdFocusAssistEnabled;
    notifyListeners();
  }

  void toggleDyslexiaSupport() {
    _dyslexiaSupportEnabled = !_dyslexiaSupportEnabled;
    _uiFontFamily = _dyslexiaSupportEnabled ? 'OpenDyslexic' : defaultUiFontFamily;
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
}

/// Builds the CSS `filter:` value applied to TradingView chart container divs
/// so the iframe inherits the same colour adjustments as the Flutter layer.
/// Shared between the market-watch single chart and the scalper charts so
/// every chart container stays in lock-step with the accessibility panel.
String composeChartCssFilter(AccessibilityNotifier a11y) {
  final parts = <String>[];
  if (a11y.grayscaleEnabled) parts.add('grayscale(1)');
  if (a11y.invertColoursEnabled) parts.add('invert(1)');
  if (a11y.blueLightFilterEnabled) {
    parts.add('sepia(0.3) saturate(1.1) hue-rotate(-15deg)');
  }
  if (a11y.smartContrastEnabled) parts.add('contrast(1.3)');
  switch (a11y.themeTone) {
    case ThemeTone.none:
      break;
    case ThemeTone.blue:
      parts.add('sepia(0.4) hue-rotate(170deg) saturate(0.9)');
      break;
    case ThemeTone.warm:
      parts.add('sepia(0.35) saturate(1.15) hue-rotate(-10deg)');
      break;
    case ThemeTone.cool:
      parts.add('sepia(0.3) hue-rotate(90deg) saturate(0.85)');
      break;
    case ThemeTone.sepia:
      parts.add('sepia(0.55)');
      break;
  }
  return parts.join(' ');
}

import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('window.speechSynthesis')
external _SpeechSynthesis get _speechSynthesis;

extension type _SpeechSynthesis._(JSObject _) implements JSObject {
  external void speak(_SpeechSynthesisUtterance utterance);
  external void cancel();
  external bool get speaking;
}

@JS('SpeechSynthesisUtterance')
extension type _SpeechSynthesisUtterance._(JSObject _) implements JSObject {
  external factory _SpeechSynthesisUtterance(String text);
  external double rate;
  external double pitch;
  external double volume;
  external String lang;
}

/// Lightweight wrapper around the browser's Web Speech `SpeechSynthesis` API.
///
/// Used by the in-app screen reader so speech stays inside the app and does
/// not depend on an OS-level assistive technology (NVDA, JAWS, VoiceOver).
class WebSpeechService {
  WebSpeechService._();
  static final WebSpeechService instance = WebSpeechService._();

  void speak(String text) {
    if (!kIsWeb) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      _speechSynthesis.cancel();
      final utterance = _SpeechSynthesisUtterance(trimmed)
        ..rate = 1.0
        ..pitch = 1.0
        ..volume = 1.0
        ..lang = 'en-US';
      _speechSynthesis.speak(utterance);
    } catch (_) {
      // SpeechSynthesis unavailable (older browser / privacy mode); silently noop.
    }
  }

  void stop() {
    if (!kIsWeb) return;
    try {
      _speechSynthesis.cancel();
    } catch (_) {}
  }
}

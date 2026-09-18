import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('document')
external _Document get _document;

@JS('window')
external _Window get _window;

extension type _Document._(JSObject _) implements JSObject {
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
  external bool get hidden;
}

extension type _Window._(JSObject _) implements JSObject {
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _MouseEvent._(JSObject _) implements JSObject {
  external double get clientX;
  external double get clientY;
}

/// Browser-level hover/leave observer used by the in-app screen reader.
///
/// Listens directly on `document` and `window` so it fires over every Flutter
/// layer — including dialogs rendered in the root Overlay — and can stop
/// speech when the user tabs away or the page becomes hidden.
class WebHoverReader {
  WebHoverReader({required this.onHover, required this.onLeave});

  final void Function(double x, double y) onHover;
  final void Function() onLeave;

  JSFunction? _mouseMoveJS;
  JSFunction? _visibilityJS;
  JSFunction? _blurJS;
  bool _running = false;

  void start() {
    if (!kIsWeb || _running) return;
    _running = true;

    void handleMove(_MouseEvent event) => onHover(event.clientX, event.clientY);
    void handleVisibility(JSObject _) {
      if (_document.hidden) onLeave();
    }
    void handleBlur(JSObject _) => onLeave();

    _mouseMoveJS = handleMove.toJS;
    _visibilityJS = handleVisibility.toJS;
    _blurJS = handleBlur.toJS;

    _document.addEventListener('mousemove', _mouseMoveJS!);
    _document.addEventListener('visibilitychange', _visibilityJS!);
    _window.addEventListener('blur', _blurJS!);
  }

  void stop() {
    if (!kIsWeb || !_running) return;
    if (_mouseMoveJS != null) {
      _document.removeEventListener('mousemove', _mouseMoveJS!);
    }
    if (_visibilityJS != null) {
      _document.removeEventListener('visibilitychange', _visibilityJS!);
    }
    if (_blurJS != null) {
      _window.removeEventListener('blur', _blurJS!);
    }
    _mouseMoveJS = null;
    _visibilityJS = null;
    _blurJS = null;
    _running = false;
  }
}

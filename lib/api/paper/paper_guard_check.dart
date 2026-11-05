import 'dart:js_interop';

@JS('__paperGuard')
external JSAny? get _paperGuard;

/// True when web/paper_guard.js ran before the app started.
bool get isPaperGuardLoaded => _paperGuard != null;

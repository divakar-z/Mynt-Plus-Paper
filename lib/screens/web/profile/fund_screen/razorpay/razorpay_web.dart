// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

const String _razorpayScriptSrc = 'https://checkout.razorpay.com/v1/checkout.js';

@JS('Razorpay')
extension type RazorpayJS._(JSObject _) implements JSObject {
  external RazorpayJS(JSObject options);
  external void open();
}

typedef RazorpayWebCallback = void Function(String? paymentId, String? orderId, String? signature);
typedef RazorpayWebErrorCallback = void Function(String? code, String? description, String? paymentId);

Future<void>? _razorpayLoader;

Future<void> _ensureRazorpayLoaded() {
  if (globalContext.hasProperty('Razorpay'.toJS).toDart) {
    return Future.value();
  }
  return _razorpayLoader ??= _injectScript();
}

Future<void> _injectScript() async {
  final existing = html.document.querySelector('script[src="$_razorpayScriptSrc"]');
  final script = existing is html.ScriptElement
      ? existing
      : (html.ScriptElement()
        ..src = _razorpayScriptSrc
        ..async = true
        ..type = 'application/javascript');

  final loadCompleter = Completer<void>();
  script.onLoad.first.then((_) {
    if (!loadCompleter.isCompleted) loadCompleter.complete();
  }).catchError((_) {});
  script.onError.first.then((_) {
    if (!loadCompleter.isCompleted) {
      loadCompleter.completeError(StateError('Failed to load Razorpay checkout script'));
    }
  }).catchError((_) {});

  if (existing == null) {
    html.document.head!.append(script);
  }

  try {
    await loadCompleter.future.timeout(const Duration(seconds: 20));
  } catch (e) {
    _razorpayLoader = null;
    rethrow;
  }

  // checkout.js is a chunk loader — wait for window.Razorpay to actually be defined.
  const pollInterval = Duration(milliseconds: 50);
  const maxWait = Duration(seconds: 10);
  final deadline = DateTime.now().add(maxWait);
  while (!globalContext.hasProperty('Razorpay'.toJS).toDart) {
    if (DateTime.now().isAfter(deadline)) {
      _razorpayLoader = null;
      throw StateError('Razorpay global was not defined after script load');
    }
    await Future.delayed(pollInterval);
  }
}

Future<void> openRazorpayWeb({
  required Map<String, dynamic> options,
  required RazorpayWebCallback onSuccess,
  required RazorpayWebErrorCallback onError,
}) async {
  await _ensureRazorpayLoaded();
  final jsOptions = _mapToJSObject(options);

  // Set handler for success
  jsOptions['handler'] = ((JSObject response) {
    final paymentId = (response['razorpay_payment_id'] as JSString?)?.toDart;
    final orderId = (response['razorpay_order_id'] as JSString?)?.toDart;
    final signature = (response['razorpay_signature'] as JSString?)?.toDart;
    onSuccess(paymentId, orderId, signature);
  }).toJS;

  // Set modal dismiss handler
  final modal = JSObject();
  modal['ondismiss'] = (() {
    onError('MODAL_CLOSED', 'Payment cancelled by user', null);
  }).toJS;
  jsOptions['modal'] = modal;

  final rzp = RazorpayJS(jsOptions);
  rzp.open();
}

JSObject _mapToJSObject(Map<String, dynamic> map) {
  final obj = JSObject();
  map.forEach((key, value) {
    if (value is Map<String, dynamic>) {
      obj[key] = _mapToJSObject(value);
    } else if (value is int) {
      obj[key] = value.toJS;
    } else if (value is double) {
      obj[key] = value.toJS;
    } else if (value is bool) {
      obj[key] = value.toJS;
    } else if (value is String) {
      obj[key] = value.toJS;
    }
  });
  return obj;
}

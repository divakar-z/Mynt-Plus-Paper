// Web implementation for CDSL form submission
// Opens CDSL in a popup window and monitors for redirect/close

// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/widgets.dart';

// Store popup reference so it can be closed externally
html.WindowBase? _cdslPopup;
Timer? _popupMonitorTimer;

/// Opens CDSL pledge setup form in a popup window via POST.
/// [onPopupClosed] is called when the popup is closed by user.
void openCdslInPopup(Map data, {Function? onPopupClosed}) {
  const popupName = 'cdsl_verification';

  // Open a sized popup window
  _cdslPopup = html.window.open('about:blank', popupName,
      'width=600,height=700,scrollbars=yes,resizable=yes,left=200,top=100');

  // Submit the POST form targeting the popup
  final form = html.FormElement()
    ..method = 'POST'
    ..action =
        'https://apigt.cdsl.co.in/PledgeServices/MPSetup'
    ..target = popupName;

  final fields = {
    'dpid': data['dpid']?.toString() ?? '',
    'pledgedtls': data['pledgedtls']?.toString() ?? '',
    'reqid': data['reqid']?.toString() ?? '',
    'version': data['version']?.toString() ?? '',
  };

  for (var entry in fields.entries) {
    form.append(html.InputElement()
      ..type = 'hidden'
      ..name = entry.key
      ..value = entry.value);
  }

  html.document.body!.append(form);
  form.submit();
  form.remove();

  // Monitor popup for manual closure by user
  if (onPopupClosed != null) {
    _popupMonitorTimer?.cancel();
    _popupMonitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      try {
        if (_cdslPopup?.closed == true) {
          timer.cancel();
          _popupMonitorTimer = null;
          onPopupClosed();
        }
      } catch (_) {
        timer.cancel();
        _popupMonitorTimer = null;
      }
    });
  }
}

/// Close the CDSL popup window from outside (e.g. after API confirms completion)
void closeCdslPopup() {
  _popupMonitorTimer?.cancel();
  _popupMonitorTimer = null;
  try {
    _cdslPopup?.close();
  } catch (_) {}
  _cdslPopup = null;
}

// Kept for signature compatibility
void openCdslFormInNewTab(Map data) => openCdslInPopup(data);
String setupCdslIframe(Map data) => '';
Widget buildCdslIframeView(String viewId) => const SizedBox();

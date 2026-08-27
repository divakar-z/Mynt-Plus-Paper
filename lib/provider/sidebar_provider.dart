import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Width the sidebar opens at unless a caller asks for more.
///
/// 400 suits Holding Details, which is a column of label/value rows. Wider
/// content asks for its own width rather than everything growing to fit the
/// widest panel in the app.
const double kDefaultSidebarWidth = 400;

class SidebarController extends Notifier<Widget?> {
  GlobalKey<ScaffoldState>? scaffoldKey;

  /// Width of the panel currently in [state].
  double _width = kDefaultSidebarWidth;
  double get width => _width;

  @override
  Widget? build() => null;

  void setScaffoldKey(GlobalKey<ScaffoldState> key) {
    scaffoldKey = key;
  }

  void setSidebar(Widget? content, {double width = kDefaultSidebarWidth}) {
    _width = width;
    state = content;
  }

  void openSidebar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scaffoldKey?.currentState?.openEndDrawer();
    });
  }
}

final sidebarProvider = NotifierProvider<SidebarController, Widget?>(SidebarController.new);

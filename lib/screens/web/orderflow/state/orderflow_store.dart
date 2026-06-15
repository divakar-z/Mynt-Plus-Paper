import 'package:flutter/foundation.dart';

/// Selectable bar timeframe — kept in sync with the JS chart engine
/// (`web/orderflow/chart.js`). The string label is what the iframe expects
/// in its `?tf=` query param and in `setTimeframe` postMessages.
enum Timeframe {
  s5(label: '5s'),
  s15(label: '15s'),
  s30(label: '30s'),
  m1(label: '1m'),
  m5(label: '5m'),
  m15(label: '15m'),
  h1(label: '1h');

  final String label;
  const Timeframe({required this.label});
}

/// User-toggleable chart overlays. All default to on.
class OverlaySettings {
  final bool imbalance;
  final bool poc;
  final bool valueArea;
  final bool vwap;
  final bool gridlines;
  const OverlaySettings({
    this.imbalance = true,
    this.poc = true,
    this.valueArea = true,
    this.vwap = true,
    this.gridlines = true,
  });

  OverlaySettings copyWith({
    bool? imbalance,
    bool? poc,
    bool? valueArea,
    bool? vwap,
    bool? gridlines,
  }) =>
      OverlaySettings(
        imbalance: imbalance ?? this.imbalance,
        poc: poc ?? this.poc,
        valueArea: valueArea ?? this.valueArea,
        vwap: vwap ?? this.vwap,
        gridlines: gridlines ?? this.gridlines,
      );

  /// JSON payload sent to the chart.js iframe via postMessage.
  Map<String, dynamic> toJson() => {
        'imb': imbalance,
        'poc': poc,
        'va': valueArea,
        'vwap': vwap,
        'grid': gridlines,
      };
}

/// Thin selection store for the Orderflow shell.
///
/// All chart rendering, history, websocket and structure work happens inside
/// the embedded canvas at `/footprint-chart/index.html`. This store only holds the
/// user-facing symbol / timeframe selection so the Flutter top bar can drive
/// the iframe via postMessage.
class OrderflowStore extends ChangeNotifier {
  String _symbol;
  Timeframe _timeframe;
  OverlaySettings _overlays;

  OrderflowStore({
    String symbol = 'NIFTY',
    Timeframe timeframe = Timeframe.m1,
    OverlaySettings overlays = const OverlaySettings(),
  })  : _symbol = symbol,
        _timeframe = timeframe,
        _overlays = overlays;

  String get symbol => _symbol;
  Timeframe get timeframe => _timeframe;
  OverlaySettings get overlays => _overlays;

  void setSymbol(String s) {
    if (s == _symbol) return;
    _symbol = s;
    notifyListeners();
  }

  void setTimeframe(Timeframe tf) {
    if (tf == _timeframe) return;
    _timeframe = tf;
    notifyListeners();
  }

  void setOverlays(OverlaySettings o) {
    _overlays = o;
    notifyListeners();
  }
}

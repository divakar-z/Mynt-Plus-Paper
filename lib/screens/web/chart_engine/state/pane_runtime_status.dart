import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Transient (non-persisted) per-pane runtime status pushed FROM the iframe
/// back into Flutter. Today: just the live Renko brick size so the Settings
/// popup can render it as a subtitle under the chart-style dropdown.
class PaneRuntimeStatus {
  /// brickSize keyed by paneIndex; missing entry = unknown (e.g. pane isn't on Renko).
  final Map<int, double> renkoBrickSizeByPane;
  const PaneRuntimeStatus({this.renkoBrickSizeByPane = const {}});

  PaneRuntimeStatus copyWith({Map<int, double>? renkoBrickSizeByPane}) =>
      PaneRuntimeStatus(
          renkoBrickSizeByPane:
              renkoBrickSizeByPane ?? this.renkoBrickSizeByPane);
}

class PaneRuntimeStatusNotifier extends Notifier<PaneRuntimeStatus> {
  @override
  PaneRuntimeStatus build() => const PaneRuntimeStatus();

  /// Push a live Renko brick size from the iframe for `paneIndex`. No-ops if
  /// the value is non-positive, infinite, or unchanged from the cached value
  /// (within 1e-9). Called from the shell's `paneRenkoBrickSize` handler.
  void setRenkoBrickSize(int paneIndex, double brickSize) {
    if (paneIndex < 0) return;
    if (brickSize <= 0 || !brickSize.isFinite) return;
    final cur = state.renkoBrickSizeByPane[paneIndex];
    if (cur != null && (cur - brickSize).abs() < 1e-9) return;
    final next = Map<int, double>.from(state.renkoBrickSizeByPane);
    next[paneIndex] = brickSize;
    state = state.copyWith(renkoBrickSizeByPane: next);
  }

  /// Drop the cached brick size for `paneIndex` (the iframe sends `0` when
  /// the pane leaves Renko style). No-ops if there's nothing to clear.
  void clearRenkoBrickSize(int paneIndex) {
    if (!state.renkoBrickSizeByPane.containsKey(paneIndex)) return;
    final next = Map<int, double>.from(state.renkoBrickSizeByPane)
      ..remove(paneIndex);
    state = state.copyWith(renkoBrickSizeByPane: next);
  }
}

final paneRuntimeStatusProvider =
    NotifierProvider<PaneRuntimeStatusNotifier, PaneRuntimeStatus>(
  PaneRuntimeStatusNotifier.new,
);

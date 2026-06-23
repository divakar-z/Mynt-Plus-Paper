import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chart_engine_shell_screen.dart';
import '../../state/chart_engine_store.dart';
import 'right_tray.dart';

/// Phase 25 — Fullscreen chart workspace.
/// The chart engine fills the entire content area. A vertical icon strip
/// (40px) lives on the right edge; clicking an icon slides out a 320px
/// panel with Watchlist / Positions / Holdings / Orders / DOM content.
/// Any symbol pick inside a tray panel applies to the currently active
/// chart pane via `notifier.setPaneSymbol`.
class ChartWorkspaceScreen extends ConsumerStatefulWidget {
  const ChartWorkspaceScreen({super.key});

  @override
  ConsumerState<ChartWorkspaceScreen> createState() =>
      _ChartWorkspaceScreenState();
}

class _ChartWorkspaceScreenState extends ConsumerState<ChartWorkspaceScreen> {
  RightTrayTab? _openTab; // null = all collapsed

  void _toggleTab(RightTrayTab tab) {
    setState(() => _openTab = _openTab == tab ? null : tab);
  }

  void _applySymbolToActivePane(ChartScrip scrip) {
    final session = ref.read(chartEngineSessionProvider);
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    notifier.setPaneSymbol(session.activePaneIndex, scrip);
    // Optional: auto-collapse the tray after pick. Skip for now — user
    // might want to pick multiple symbols rapidly.
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // --- Chart fills the rest ---
      const Expanded(child: ChartEngineShellScreen()),
      // --- Right-side tray ---
      RightTray(
        openTab: _openTab,
        onTabTap: _toggleTab,
        onSymbolPick: _applySymbolToActivePane,
      ),
    ]);
  }
}

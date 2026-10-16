// The Symbols sub-page is no longer surfaced in the Scanner left rail.
// It stays as a placeholder in the IndexedStack so the enum indexes line up
// (`ScannerSubPage.scanners.index == 1`, etc.) without re-numbering anything
// downstream. Real symbol detail now opens via ChartWithDepthWeb in the
// shell's right area — see `openScannerScrip` and `scanner_shell_screen.dart`.
import 'package:flutter/material.dart';

class SymbolsSubPage extends StatelessWidget {
  const SymbolsSubPage({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

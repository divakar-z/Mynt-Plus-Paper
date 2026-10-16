import 'package:flutter/material.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/scan_explain.dart'
    show ExplainKey;
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart'
    show ScannerSubPage;
import 'package:mynt_plus/screens/web/market_watch/chart_with_depth_web.dart';
import 'sub_pages/custom_scans_sub_page.dart';
import 'sub_pages/fundamentals_new_sub_page.dart';
// Legacy sub-pages — kept on disk but no longer wired into the shell.
// Re-enable both the import and the matching IndexedStack child if the tab
// needs to come back.
// import 'sub_pages/fundamentals_sub_page.dart';
// import 'sub_pages/scanners_sub_page.dart';
// import 'sub_pages/symbols_sub_page.dart';
import 'sub_pages/scan_explain_screen.dart';
import 'sub_pages/scanners_new_sub_page.dart';
import 'widgets/empty_state.dart';
// ignore: unused_import
import 'widgets/scanner_breadcrumb.dart'; // kept for the commented breadcrumb
// ignore: unused_import
import 'widgets/scanner_left_rail.dart';

class ScannerShellScreen extends ConsumerStatefulWidget {
  final ScannerSubPage? initialSubPage;
  /// Deep-link entry point for /scanner/explain/* routes. When non-null,
  /// the shell opens straight into the explain view for this key.
  final ExplainKey? initialExplainArgs;

  const ScannerShellScreen({
    super.key,
    this.initialSubPage,
    this.initialExplainArgs,
  });

  @override
  ConsumerState<ScannerShellScreen> createState() => _ScannerShellScreenState();
}

class _ScannerShellScreenState extends ConsumerState<ScannerShellScreen> {
  @override
  void initState() {
    super.initState();
    final args = widget.initialExplainArgs;
    final sub = widget.initialSubPage;
    if (sub != null || args != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(scannerShellProvider.notifier);
        if (sub != null) notifier.setActiveSubPage(sub);
        if (args != null) notifier.openExplain(args);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerShellProvider);
    final width = MediaQuery.of(context).size.width;

    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      // Sidebar (ScannerLeftRail) intentionally disabled — navigation now
      // happens via the top tab bar. Kept commented for easy re-enable.
      // child: Row(
      //   crossAxisAlignment: CrossAxisAlignment.stretch,
      //   children: [
      //     final collapsed = width < 1100 && width >= 760;
      //     final hidden = width < 760;
      //     if (!hidden)
      //       ScannerLeftRail(
      //         active: state.activeSubPage,
      //         collapsed: collapsed,
      //         onSelect: (p) =>
      //             ref.read(scannerShellProvider.notifier).setActiveSubPage(p),
      //       ),
      //     Expanded(child: _rightArea(state, width)),
      //   ],
      // ),
      child: _rightArea(state, width),
    );
  }

  Widget _rightArea(ScannerShellState state, double width) {
    // Explanation view wins over symbol detail and sub-page — it's the
    // most specific intent (user clicked Explanation on a results row).
    if (state.explainArgs != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _backBar(state),
          Expanded(child: ScanExplainScreen(args: state.explainArgs!)),
        ],
      );
    }
    // If a scrip is selected (clicked from any results table), the right
    // area becomes the full ChartWithDepthWeb. A small back row sits above
    // it for returning to the previous sub-page list.
    if (state.selectedScrip != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _backBar(state),
          Expanded(child: ChartWithDepthWeb(wlValue: state.selectedScrip!)),
        ],
      );
    }

    // Resolving / error states for the SearchScrip lookup.
    if (state.isResolvingScrip) {
      return Column(children: [
        _backBar(state),
        Expanded(child: Center(child: MyntLoader.branded())),
      ]);
    }
    if (state.scripError != null) {
      return Column(children: [
        _backBar(state),
        Expanded(
          child: EmptyState(
            kind: EmptyStateKind.error,
            title: 'Could not open symbol',
            message: state.scripError,
            onRetry: () =>
                ref.read(scannerShellProvider.notifier).clearSelectedScrip(),
          ),
        ),
      ]);
    }

    // Default — show the active sub-page.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ScannerBreadcrumb(
          //   segments: [
          //     const BreadcrumbSegment('Scanner'),
          //     BreadcrumbSegment(_label(state.activeSubPage)),
          //   ],
          // ),
          // const SizedBox(height: 12),
          // _buildTabs(state.activeSubPage),
          // const SizedBox(height: 12),
          // Tab bar removed — the Dashboard is the entry point and links to
          // the other sub-pages; they return here via their own back button,
          // rendered inline with each page's title.
          //
          // KEPT FOR FUTURE USE — currently unreachable by design. The three
          // names below are every value of ScannerSubPage, so the condition is
          // always false and nothing renders. It comes back to life the moment
          // a fourth sub-page is added that does NOT draw its own back button:
          // add it to the enum, leave it out of this list, and it gets this
          // shared one for free.
          // ignore: dead_code
          if (state.activeSubPage != ScannerSubPage.scannersNew &&
              state.activeSubPage != ScannerSubPage.fundamentalsNew &&
              state.activeSubPage != ScannerSubPage.customScans) ...[
            CustomBackBtn(
              onBack: () => ref
                  .read(scannerShellProvider.notifier)
                  .setActiveSubPage(ScannerSubPage.scannersNew),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: IndexedStack(
              // IndexedStack maps `.index` to child order — child list MUST
              // stay aligned with the ScannerSubPage enum declaration order.
              // Commented children mirror the commented enum values in
              // customizable_split_home_screen.dart — re-enable in both places
              // together.
              index: state.activeSubPage.index,
              children: const [
                // SymbolsSubPage(),      // legacy — hidden from tab bar
                // ScannersSubPage(),     // legacy — hidden from tab bar
                // FundamentalsSubPage(), // legacy — hidden from tab bar
                CustomScansSubPage(),
                FundamentalsNewSubPage(),
                ScannersNewSubPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Top tab bar — disabled; kept commented so the Custom Scans tab can be
  // re-enabled. Each tab maps to a ScannerSubPage:
  //   Dashboard    → scannersNew
  //   Fundamentals → fundamentalsNew
  //   Custom Scans → customScans (saved list + full predicate builder)
  // Widget _buildTabs(ScannerSubPage active) {
  //   const tabs = <_ScannerTab>[
  //     _ScannerTab('Dashboard', ScannerSubPage.scannersNew),
  //     _ScannerTab('Fundamentals', ScannerSubPage.fundamentalsNew),
  //     _ScannerTab('Custom Scans', ScannerSubPage.customScans),
  //   ];
  //   final isDark = Theme.of(context).brightness == Brightness.dark;
  //   return Row(
  //     mainAxisSize: MainAxisSize.min,
  //     children: [
  //       for (final t in tabs) _tabChip(t, active == t.page, isDark),
  //     ],
  //   );
  // }
  //
  // Widget _tabChip(_ScannerTab tab, bool selected, bool isDark) {
  //   return MouseRegion(
  //     cursor: SystemMouseCursors.click,
  //     child: GestureDetector(
  //       onTap: () {
  //         if (!selected) {
  //           ref
  //               .read(scannerShellProvider.notifier)
  //               .setActiveSubPage(tab.page);
  //         }
  //       },
  //       child: Container(
  //         margin: const EdgeInsets.only(right: 4),
  //         padding:
  //             const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //         decoration: BoxDecoration(
  //           color: selected
  //               ? (isDark
  //                   ? Colors.white.withOpacity(0.1)
  //                   : Colors.black.withOpacity(0.05))
  //               : Colors.transparent,
  //           borderRadius: BorderRadius.circular(6),
  //         ),
  //         child: Text(
  //           tab.label,
  //           style: MyntWebTextStyles.body(
  //             context,
  //             fontWeight:
  //                 selected ? MyntFonts.semiBold : MyntFonts.medium,
  //           ).copyWith(
  //             color: selected
  //                 ? shadcn.Theme.of(context).colorScheme.foreground
  //                 : shadcn.Theme.of(context).colorScheme.mutedForeground,
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  /// Top bar shown while a scrip is selected (or being resolved): a simple
  /// back button + the symbol name (matches the detail header style).
  Widget _backBar(ScannerShellState state) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final scrip = state.selectedScrip;
    final explain = state.explainArgs;
    final inExplain = explain != null;
    final title = scrip != null
        ? (scrip.symbol.isNotEmpty ? scrip.symbol : scrip.tsym)
        : (explain?.ticker ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(children: [
        CustomBackBtn(
          onBack: () {
            // Same back arrow handles both modes — explain wins because
            // it can only be open when scrip detail is closed.
            if (inExplain) {
              ref.read(scannerShellProvider.notifier).closeExplain();
            } else {
              ref.read(scannerShellProvider.notifier).clearSelectedScrip();
            }
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: MyntWebTextStyles.title(context,
                fontWeight: MyntFonts.semiBold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }

  // Kept for the (currently commented-out) breadcrumb in the default area.
  // ignore: unused_element
  String _label(ScannerSubPage p) {
    switch (p) {
      // Legacy labels kept alongside the commented enum values.
      // case ScannerSubPage.symbols:
      //   return 'Symbols';
      // case ScannerSubPage.scanners:
      //   return 'Scanners';
      // case ScannerSubPage.fundamentals:
      //   return 'Fundamentals';
      case ScannerSubPage.customScans:
        return 'Custom Scans';
      case ScannerSubPage.fundamentalsNew:
        return 'Fundamentals New';
      case ScannerSubPage.scannersNew:
        return 'Scanners New';
    }
  }
}

// Used by the commented-out tab bar above.
// class _ScannerTab {
//   final String label;
//   final ScannerSubPage page;
//   const _ScannerTab(this.label, this.page);
// }

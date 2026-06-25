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
import 'sub_pages/fundamentals_sub_page.dart';
import 'sub_pages/scan_explain_screen.dart';
import 'sub_pages/scanners_sub_page.dart';
import 'sub_pages/symbols_sub_page.dart';
import 'widgets/empty_state.dart';
// ignore: unused_import
import 'widgets/scanner_breadcrumb.dart'; // kept for the commented breadcrumb
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
    final collapsed = width < 1100 && width >= 760;
    final hidden = width < 760;

    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hidden)
            ScannerLeftRail(
              active: state.activeSubPage,
              collapsed: collapsed,
              onSelect: (p) =>
                  ref.read(scannerShellProvider.notifier).setActiveSubPage(p),
            ),
          Expanded(child: _rightArea(state, width)),
        ],
      ),
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
          Expanded(
            child: IndexedStack(
              // Symbols sub-page is no longer shown in the rail, but its
              // IndexedStack slot stays so ScannerSubPage.scanners (index 1)
              // etc. continue to map correctly.
              index: state.activeSubPage.index,
              children: const [
                SymbolsSubPage(),
                ScannersSubPage(),
                FundamentalsSubPage(),
                CustomScansSubPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
      case ScannerSubPage.symbols:
        return 'Symbols';
      case ScannerSubPage.scanners:
        return 'Scanners';
      case ScannerSubPage.fundamentals:
        return 'Fundamentals';
      case ScannerSubPage.customScans:
        return 'Custom Scans';
    }
  }
}

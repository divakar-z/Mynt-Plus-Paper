import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/marketwatch_model/get_quotes.dart'
    show DepthInputArgs;
import 'package:mynt_plus/models/scanner_model/scan_explain.dart'
    show ExplainKey;
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart'
    show ScannerSubPage;

class ScannerShellState {
  final ScannerSubPage activeSubPage;
  final String? pendingScannerCode;
  /// When non-null, the Scanner shell's right area renders the symbol detail
  /// (ChartWithDepthWeb) for this scrip instead of the active sub-page.
  /// Cleared when the user hits back or switches sub-pages from the rail.
  final DepthInputArgs? selectedScrip;
  /// True while we're hitting SearchScrip to resolve a ticker → DepthInputArgs.
  final bool isResolvingScrip;
  /// Set if the lookup fails so the UI can show the error.
  final String? scripError;
  /// When non-null, the right area renders the scan-explanation screen for
  /// this (scope, id, ticker) instead of the sub-page or symbol detail.
  /// Takes precedence over [selectedScrip]. Cleared when the user hits
  /// back, switches sub-pages, or navigates to a different scanner.
  final ExplainKey? explainArgs;

  const ScannerShellState({
    this.activeSubPage = ScannerSubPage.scanners,
    this.pendingScannerCode,
    this.selectedScrip,
    this.isResolvingScrip = false,
    this.scripError,
    this.explainArgs,
  });

  ScannerShellState copyWith({
    ScannerSubPage? activeSubPage,
    String? pendingScannerCode,
    DepthInputArgs? selectedScrip,
    bool? isResolvingScrip,
    String? scripError,
    ExplainKey? explainArgs,
    bool clearPendingScannerCode = false,
    bool clearSelectedScrip = false,
    bool clearScripError = false,
    bool clearExplainArgs = false,
  }) {
    return ScannerShellState(
      activeSubPage: activeSubPage ?? this.activeSubPage,
      pendingScannerCode: clearPendingScannerCode
          ? null
          : (pendingScannerCode ?? this.pendingScannerCode),
      selectedScrip:
          clearSelectedScrip ? null : (selectedScrip ?? this.selectedScrip),
      isResolvingScrip: isResolvingScrip ?? this.isResolvingScrip,
      scripError: clearScripError ? null : (scripError ?? this.scripError),
      explainArgs:
          clearExplainArgs ? null : (explainArgs ?? this.explainArgs),
    );
  }
}

class ScannerShellNotifier extends Notifier<ScannerShellState> {
  @override
  ScannerShellState build() => const ScannerShellState();

  void setActiveSubPage(ScannerSubPage page) {
    // Switching sub-pages closes any open symbol detail OR explanation view.
    state = state.copyWith(
      activeSubPage: page,
      clearSelectedScrip: true,
      clearScripError: true,
      clearExplainArgs: true,
      isResolvingScrip: false,
    );
  }

  void navigateToScannerDetail(String code) {
    state = state.copyWith(
      activeSubPage: ScannerSubPage.scanners,
      pendingScannerCode: code,
      clearSelectedScrip: true,
      clearExplainArgs: true,
    );
  }

  /// Open the scan-explanation screen for the given (scope, id, ticker).
  /// Clears any selected scrip so the back arrow returns to the results
  /// table rather than to a stale symbol detail.
  void openExplain(ExplainKey args) {
    state = state.copyWith(
      explainArgs: args,
      clearSelectedScrip: true,
      clearScripError: true,
      isResolvingScrip: false,
    );
  }

  /// Close the explanation screen — returns to the active sub-page list.
  void closeExplain() {
    state = state.copyWith(clearExplainArgs: true);
  }

  void consumePendingScannerCode() {
    state = state.copyWith(clearPendingScannerCode: true);
  }

  /// Internal — set by the helper after a successful SearchScrip lookup.
  void setSelectedScrip(DepthInputArgs args) {
    state = state.copyWith(
      selectedScrip: args,
      isResolvingScrip: false,
      clearScripError: true,
    );
  }

  void setResolving(bool v) {
    state = state.copyWith(isResolvingScrip: v, clearScripError: true);
  }

  void setScripError(String msg) {
    state = state.copyWith(
      isResolvingScrip: false,
      scripError: msg,
    );
  }

  /// Close the symbol detail and return to the active sub-page list.
  void clearSelectedScrip() {
    state = state.copyWith(
      clearSelectedScrip: true,
      clearScripError: true,
      isResolvingScrip: false,
    );
  }
}

final scannerShellProvider =
    NotifierProvider<ScannerShellNotifier, ScannerShellState>(
  ScannerShellNotifier.new,
);

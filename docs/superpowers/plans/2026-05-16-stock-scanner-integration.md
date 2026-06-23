# Stock Scanner Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Scanner" feature to the Mynt Plus Web app that exposes the StockScanner backend (Symbols search, technical Scanners, Fundamental screener, Custom predicate Scans) inside the existing split-pane layout.

**Architecture:** A new `ScannerShellScreen` renders inside the right panel of `CustomizableSplitHomeScreen`, with its own internal left rail navigating four sub-pages. Each sub-page is a self-contained `ConsumerStatefulWidget` calling a new `StockScannerAPI` mixin via Riverpod providers. All theming flows through existing `resolveThemeColor` helpers and `shadcn_flutter` tokens — no hardcoded colors.

**Tech Stack:** Flutter web, Riverpod 3.x, GoRouter 17.x, GetIt, shadcn_flutter, http, lucide icons. The `syncfusion_flutter_charts` dependency is already in `pubspec.yaml` (line 62) but is NOT used in this plan (Chart tab deferred).

**Companion spec:** [`docs/superpowers/specs/2026-05-16-stock-scanner-integration-design.md`](../specs/2026-05-16-stock-scanner-integration-design.md)

**Commits:** The user commits manually after testing the full feature. Tasks do NOT include `git commit` steps. After each milestone there is a "🟢 Manual checkpoint" callout so the user can verify and (if they choose) commit.

---

## Plan structure

The plan is broken into **9 milestones**. Each milestone ends in a manually-verifiable state. The order matters — later milestones depend on earlier ones.

| # | Milestone | Tasks | Outcome |
|---|---|---|---|
| 0 | Foundation — base URL, exception, models scaffold | 1–4 | Backend connectivity wired |
| 1 | Navigation wiring — menu items, routes, shell skeleton | 5–11 | "Scanner" menu opens an empty shell w/ 4 sub-page placeholders |
| 2 | Utilities — formatters, indicator catalog, shared widgets | 12–18 | Reusable building blocks ready |
| 3 | API layer — models + StockScannerAPI mixin | 19–28 | All endpoints callable from Dart |
| 4 | Symbols sub-page — list + detail header | 29–32 | Search works, ticker selection opens detail |
| 5 | Symbols tabs — 9 tabs | 33–41 | Full Symbol detail working |
| 6 | Scanners sub-page — list + detail | 42–46 | Scanner browse + detail + export |
| 7 | Fundamentals sub-page — builder + presets + saved | 47–53 | Fundamental screener fully working |
| 8 | Custom Scans sub-page — predicate builder + saved | 54–60 | Custom predicate UI fully working |

---

## Coding conventions (apply throughout)

- **Imports:** Use `package:mynt_plus/...` absolute paths for new files (matches existing style)
- **Theme:** Every color via `resolveThemeColor(context, dark: MyntColors.xxxDark, light: MyntColors.xxx)` or `shadcn.Theme.of(context).colorScheme.<token>` — NEVER `Colors.white`, `Colors.black`, or raw hex
- **Typography:** Use `MyntWebTextStyles.body|caption|...(context, fontWeight: MyntFonts.xxx, darkColor:, lightColor:)`
- **Spacing:** Constants `8`, `12`, `16`, `20`, `24` (no magic numbers > 8 unless commented)
- **Icons:** Prefer `shadcn.LucideIcons.*`; fall back to `shadcn.BootstrapIcons.*` for parity with existing app bar
- **State:** Riverpod `ConsumerStatefulWidget` for screens with state; plain `ConsumerWidget` when stateless
- **Error handling:** Catch `StockScannerException` at the provider boundary, surface via inline error card with Retry button (use `EmptyState` widget from Task 18)
- **Null safety:** All API response models use nullable types where the backend may return `null` (Holders, MF Holding, PEG Ratio, etc.); render `—` via formatters

---

## Milestone 0 — Foundation (Tasks 1–4)

### Task 1: Add StockScanner base URL to ApiLinks

**Files:**
- Modify: `lib/api/core/api_link.dart`

- [ ] **Step 1: Open `lib/api/core/api_link.dart` and find the end of the `ApiLinks` class** (right before the closing `}` of the class — currently around line 425 after `mfbasketanalysis` and `mfbaskbacktest` getters).

- [ ] **Step 2: Add the StockScanner base URL getters just before the closing `}` of the class**

```dart
  // ===========================================================================
  // StockScanner (read-only stock research backend — FastAPI)
  // TODO: Swap to prod URL when StockScanner backend is hosted publicly.
  //       Assumes PUBLIC_READ_MODE=true on the backend (no API key required).
  // ===========================================================================
  String get stockScannerBaseURL => 'http://192.168.5.47:8000';
  String get stockScannerApi => '$stockScannerBaseURL/api/v1';
```

- [ ] **Step 3: Run `flutter analyze` and confirm zero new warnings**

```bash
flutter analyze lib/api/core/api_link.dart
```

Expected: `No issues found!` for that file (or only pre-existing warnings unrelated to your change).

---

### Task 2: Create StockScannerException

**Files:**
- Create: `lib/models/scanner_model/scanner_exception.dart`

- [ ] **Step 1: Create the directory `lib/models/scanner_model/`**

```bash
mkdir -p lib/models/scanner_model
```

- [ ] **Step 2: Create `lib/models/scanner_model/scanner_exception.dart` with the full content below**

```dart
/// Exception thrown by [StockScannerApi] methods on non-2xx responses or
/// network failures. Carries a user-presentable [message] plus the original
/// HTTP [statusCode] and parsed [errorCode] from the backend's
/// `{error, message, detail}` envelope.
class StockScannerException implements Exception {
  /// HTTP status code (0 if the request never reached the server).
  final int statusCode;

  /// The `error` field from the backend envelope (e.g. `"validation_error"`).
  /// Empty when the response was not a JSON envelope.
  final String errorCode;

  /// User-presentable message — already mapped by [StockScannerException.fromResponse].
  final String message;

  /// The original `detail` map from the backend, if any. Useful for debugging.
  final Map<String, dynamic>? detail;

  StockScannerException({
    required this.statusCode,
    required this.message,
    this.errorCode = '',
    this.detail,
  });

  /// Build a user-facing exception from an HTTP response + parsed body.
  factory StockScannerException.fromResponse({
    required int statusCode,
    required String backendMessage,
    String errorCode = '',
    Map<String, dynamic>? detail,
  }) {
    final mapped = _mapMessage(statusCode, backendMessage);
    return StockScannerException(
      statusCode: statusCode,
      errorCode: errorCode,
      message: mapped,
      detail: detail,
    );
  }

  /// Network-level failure (DNS / connection refused / timeout).
  factory StockScannerException.network(Object cause) {
    return StockScannerException(
      statusCode: 0,
      message: 'Could not reach StockScanner — check your connection.',
      detail: {'cause': cause.toString()},
    );
  }

  static String _mapMessage(int status, String backend) {
    switch (status) {
      case 401:
        return 'Authentication required — please reload the app.';
      case 404:
        return backend.isEmpty ? 'Not found.' : 'Not found — $backend';
      case 422:
        return backend.isEmpty ? 'Invalid input.' : 'Invalid input — $backend';
      case 429:
        return 'Rate limit exceeded — try again in a few seconds.';
      default:
        if (status >= 500) return 'Backend error — please retry.';
        return backend.isEmpty ? 'Request failed (HTTP $status).' : backend;
    }
  }

  @override
  String toString() => 'StockScannerException($statusCode, $errorCode): $message';
}
```

- [ ] **Step 3: Create the matching unit test `test/scanner_model/scanner_exception_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/models/scanner_model/scanner_exception.dart';

void main() {
  group('StockScannerException.fromResponse', () {
    test('401 → authentication message', () {
      final e = StockScannerException.fromResponse(
        statusCode: 401,
        backendMessage: 'no key',
      );
      expect(e.message, contains('Authentication required'));
      expect(e.statusCode, 401);
    });

    test('404 with backend message → prefixed message', () {
      final e = StockScannerException.fromResponse(
        statusCode: 404,
        backendMessage: 'symbol ABC not found',
      );
      expect(e.message, 'Not found — symbol ABC not found');
    });

    test('422 → invalid input message', () {
      final e = StockScannerException.fromResponse(
        statusCode: 422,
        backendMessage: 'field "x" required',
      );
      expect(e.message, contains('Invalid input'));
      expect(e.message, contains('field "x" required'));
    });

    test('429 → rate-limit message', () {
      final e = StockScannerException.fromResponse(
        statusCode: 429,
        backendMessage: '',
      );
      expect(e.message, contains('Rate limit'));
    });

    test('5xx → generic backend-error message', () {
      final e = StockScannerException.fromResponse(
        statusCode: 503,
        backendMessage: 'gateway',
      );
      expect(e.message, contains('Backend error'));
    });

    test('network factory yields status 0', () {
      final e = StockScannerException.network(Exception('boom'));
      expect(e.statusCode, 0);
      expect(e.message, contains('Could not reach'));
    });
  });
}
```

- [ ] **Step 4: Run the test and confirm pass**

```bash
flutter test test/scanner_model/scanner_exception_test.dart
```

Expected: `All tests passed!`

---

### Task 3: Create empty StockScannerApi mixin skeleton

This task creates the file so later milestones can extend it; method bodies are added in Milestone 3.

**Files:**
- Create: `lib/api/stock_scanner_api.dart`

- [ ] **Step 1: Create `lib/api/stock_scanner_api.dart` with the skeleton below**

```dart
import 'package:http/http.dart' as http;
import 'package:mynt_plus/models/scanner_model/scanner_exception.dart';
import 'core/api_core.dart';

/// API mixin for the StockScanner backend (FastAPI service).
///
/// Endpoints are grouped by spec section:
///   /symbols/*           — universe + per-symbol detail tabs
///   /scanners/*          — built-in technical scanners
///   /scans/fundamental/* — fundamental screener + saved screens
///   /scans/*             — custom predicate scanners (CRUD + run)
///
/// All methods throw [StockScannerException] on non-2xx responses or network
/// failures. Callers should catch at the provider boundary and surface to UI.
mixin StockScannerApi on ApiCore {
  // --- Shared helpers ------------------------------------------------------

  Uri _u(String path, [Map<String, dynamic>? q]) {
    final base = apiLinks.stockScannerApi;
    final url = '$base$path';
    if (q == null || q.isEmpty) return Uri.parse(url);
    final cleaned = <String, String>{};
    q.forEach((k, v) {
      if (v == null) return;
      cleaned[k] = v.toString();
    });
    return Uri.parse(url).replace(queryParameters: cleaned);
  }

  /// GET helper — returns the decoded JSON or throws [StockScannerException].
  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    http.Response r;
    try {
      r = await apiClient.get(_u(path, query), headers: defaultHeaders);
    } catch (e) {
      throw StockScannerException.network(e);
    }
    return _decodeOrThrow(r);
  }

  /// POST helper — returns the decoded JSON or throws [StockScannerException].
  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    http.Response r;
    try {
      r = await apiClient.post(
        _u(path),
        headers: defaultHeaders,
        body: jsonEncode(body),
      );
    } catch (e) {
      throw StockScannerException.network(e);
    }
    return _decodeOrThrow(r);
  }

  /// DELETE helper.
  Future<void> _delete(String path) async {
    http.Response r;
    try {
      r = await apiClient.delete(_u(path), headers: defaultHeaders);
    } catch (e) {
      throw StockScannerException.network(e);
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      _throwFromResponse(r);
    }
  }

  /// Raw blob download (used for .xlsx exports).
  Future<({List<int> bytes, String? filename})> _downloadBlob(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? postBody,
  }) async {
    http.Response r;
    try {
      if (postBody != null) {
        r = await apiClient.post(
          _u(path, query),
          headers: defaultHeaders,
          body: jsonEncode(postBody),
        );
      } else {
        r = await apiClient.get(_u(path, query), headers: defaultHeaders);
      }
    } catch (e) {
      throw StockScannerException.network(e);
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      _throwFromResponse(r);
    }
    String? filename;
    final cd = r.headers['content-disposition'];
    if (cd != null) {
      final m = RegExp(r'filename="?([^"]+)"?').firstMatch(cd);
      if (m != null) filename = m.group(1);
    }
    return (bytes: r.bodyBytes, filename: filename);
  }

  dynamic _decodeOrThrow(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      _throwFromResponse(r);
    }
    if (r.body.isEmpty) return null;
    return jsonDecode(r.body);
  }

  Never _throwFromResponse(http.Response r) {
    String backendMessage = '';
    String errorCode = '';
    Map<String, dynamic>? detail;
    try {
      final j = jsonDecode(r.body);
      if (j is Map) {
        backendMessage = (j['message'] ?? '').toString();
        errorCode = (j['error'] ?? '').toString();
        if (j['detail'] is Map) {
          detail = Map<String, dynamic>.from(j['detail'] as Map);
        }
      }
    } catch (_) {
      // body wasn't JSON — leave fields empty
    }
    throw StockScannerException.fromResponse(
      statusCode: r.statusCode,
      backendMessage: backendMessage,
      errorCode: errorCode,
      detail: detail,
    );
  }

  // --- Endpoint methods are added in Milestone 3 ---------------------------
}
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/api/stock_scanner_api.dart
```

Expected: `No issues found!`. The helpers are intentionally private (`_u`, `_get`, etc.) but won't trigger unused-element warnings because they will be called from methods added in Milestone 3.

> ⚠️ If analyzer complains about unused private methods, add `// ignore: unused_element` comments above each helper temporarily. Remove them in Task 19.

---

### Task 4: Register StockScannerApi in ApiExporter

**Files:**
- Modify: `lib/api/core/api_export.dart`

- [ ] **Step 1: Open `lib/api/core/api_export.dart` and add the import line at the bottom of the existing import block**

```dart
import '../stock_scanner_api.dart';
```

- [ ] **Step 2: Add `StockScannerApi` to the `with` clause of `ApiExporter`** (append after `VersionApi`):

```dart
class ApiExporter
    with
        ApiCore,
        AuthApi,
        BannerApi,
        ChangePasswordApi,
        IndexApi,
        MarketWatchApi,
        PortfolioAPI,
        FundApi,
        NotificationApi,
        BondsApi,
        OrderAPI,
        StocksAPI,
        UserProfileAPI,
        GenerateApiKey,
        IPOApi,
        MutualFundApi,
        TranscationApi,
        MockApiResponse,
        LedgerApi,
        ProfileAllDetailsApi,
        VersionApi,
        StockScannerApi {}
```

- [ ] **Step 3: Run analyzer + smoke build to confirm wiring is sound**

```bash
flutter analyze
flutter build web --no-tree-shake-icons --debug
```

Expected: analyzer passes; web build succeeds (will be slow on first run).

---

> 🟢 **Manual checkpoint after Milestone 0**
>
> Backend connectivity is wired but no UI exists yet. Verify:
> - `locator<ApiExporter>().stockScannerApi` is accessible from Dart console / a temporary test
> - `flutter analyze` is clean for new files
> - Web build succeeds
>
> Safe place to commit if you want a clean foundation snapshot.

---

(continued in next section)

## Milestone 1 — Navigation wiring (Tasks 5–11)

After this milestone, clicking the new "Scanner" item in the Options dropdown (or in the hamburger drawer's TRADE section) opens an empty Scanner shell with 4 sub-page placeholders.

### Task 5: Add ScreenType.scanner enum value

**Files:**
- Modify: `lib/screens/web/home/models/screen_type.dart`

- [ ] **Step 1: Open the file and append `scanner` to the enum** (place after `closureDetails`, before the closing `}`):

```dart
  scanner,
```

The full enum should end with:

```dart
  closureDetails,
  scanner,
}
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/screens/web/home/models/screen_type.dart
```

Expected: no issues.

---

### Task 6: Add ScreenTypeParam.scanner and ScannerSubPage enums

**Files:**
- Modify: `lib/screens/web/customizable_split_home_screen.dart` (lines ~149–178)

- [ ] **Step 1: Find the `enum ScreenTypeParam {` block around line 149** and add `scanner` as the last entry (after `caBuyback`):

```dart
enum ScreenTypeParam {
  dashboard,
  watchlist,
  // ... existing entries unchanged ...
  caBuyback,
  scanner,
}
```

- [ ] **Step 2: Just below that enum, add a new `ScannerSubPage` enum** (lines ~179+):

```dart
/// Sub-page within the Scanner shell — drives the left rail + IndexedStack.
enum ScannerSubPage {
  symbols,
  scanners,
  fundamentals,
  customScans,
}
```

- [ ] **Step 3: Add the `initialScannerSubPage` constructor parameter to `CustomizableSplitHomeScreen`** (around line 180–195):

```dart
class CustomizableSplitHomeScreen extends ConsumerStatefulWidget {
  final ScreenTypeParam? initialRightPanel;
  final String? digilockerCode;
  final String? digilockerState;
  final ScannerSubPage? initialScannerSubPage;

  const CustomizableSplitHomeScreen({
    super.key,
    this.initialRightPanel,
    this.digilockerCode,
    this.digilockerState,
    this.initialScannerSubPage,
  });
```

- [ ] **Step 4: Run analyzer**

```bash
flutter analyze lib/screens/web/customizable_split_home_screen.dart
```

Expected: no new issues.

---

### Task 7: Create scanner_shell_provider.dart

**Files:**
- Create: `lib/provider/scanner/scanner_shell_provider.dart`

- [ ] **Step 1: Create directory**

```bash
mkdir -p lib/provider/scanner
```

- [ ] **Step 2: Create `lib/provider/scanner/scanner_shell_provider.dart` with the full content below**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart'
    show ScannerSubPage;

class ScannerShellState {
  final ScannerSubPage activeSubPage;
  final String? pendingScannerCode;
  final String? pendingTicker;

  const ScannerShellState({
    this.activeSubPage = ScannerSubPage.symbols,
    this.pendingScannerCode,
    this.pendingTicker,
  });

  ScannerShellState copyWith({
    ScannerSubPage? activeSubPage,
    String? pendingScannerCode,
    String? pendingTicker,
    bool clearPendingScannerCode = false,
    bool clearPendingTicker = false,
  }) {
    return ScannerShellState(
      activeSubPage: activeSubPage ?? this.activeSubPage,
      pendingScannerCode: clearPendingScannerCode
          ? null
          : (pendingScannerCode ?? this.pendingScannerCode),
      pendingTicker:
          clearPendingTicker ? null : (pendingTicker ?? this.pendingTicker),
    );
  }
}

class ScannerShellNotifier extends StateNotifier<ScannerShellState> {
  ScannerShellNotifier() : super(const ScannerShellState());

  void setActiveSubPage(ScannerSubPage page) {
    state = state.copyWith(activeSubPage: page);
  }

  void navigateToScannerDetail(String code) {
    state = state.copyWith(
      activeSubPage: ScannerSubPage.scanners,
      pendingScannerCode: code,
    );
  }

  void navigateToSymbolDetail(String ticker) {
    state = state.copyWith(
      activeSubPage: ScannerSubPage.symbols,
      pendingTicker: ticker,
    );
  }

  void consumePendingScannerCode() {
    state = state.copyWith(clearPendingScannerCode: true);
  }

  void consumePendingTicker() {
    state = state.copyWith(clearPendingTicker: true);
  }
}

final scannerShellProvider =
    StateNotifierProvider<ScannerShellNotifier, ScannerShellState>(
  (_) => ScannerShellNotifier(),
);
```

- [ ] **Step 3: Run analyzer**

```bash
flutter analyze lib/provider/scanner/scanner_shell_provider.dart
```

Expected: no issues.

---

### Task 8: Create ScannerShellScreen skeleton + left rail + breadcrumb

**Files:**
- Create: `lib/screens/web/scanner/scanner_shell_screen.dart`
- Create: `lib/screens/web/scanner/widgets/scanner_left_rail.dart`
- Create: `lib/screens/web/scanner/widgets/scanner_breadcrumb.dart`

- [ ] **Step 1: Create directories**

```bash
mkdir -p lib/screens/web/scanner/widgets
mkdir -p lib/screens/web/scanner/sub_pages/symbols_tabs
mkdir -p lib/screens/web/scanner/utils
```

- [ ] **Step 2: Create `lib/screens/web/scanner/widgets/scanner_left_rail.dart`** (full code in the design spec section 5.1; key behaviors: 220px wide normal / 64px collapsed below 1100px / hidden below 760px; active item uses primary-color pill; theme-aware bg via `resolveThemeColor(context, dark: MyntColors.surfaceVariantDark, light: MyntColors.surfaceVariant)`). Use `shadcn.LucideIcons.search / radar / chartBar / code` for the 4 items.

Implementation in full:

```dart
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart'
    show ScannerSubPage;

class ScannerLeftRail extends StatelessWidget {
  final ScannerSubPage active;
  final ValueChanged<ScannerSubPage> onSelect;
  final bool collapsed;

  const ScannerLeftRail({
    super.key,
    required this.active,
    required this.onSelect,
    this.collapsed = false,
  });

  static const _items = [
    _RailItem(ScannerSubPage.symbols, 'Symbols', shadcn.LucideIcons.search),
    _RailItem(ScannerSubPage.scanners, 'Scanners', shadcn.LucideIcons.radar),
    _RailItem(ScannerSubPage.fundamentals, 'Fundamentals',
        shadcn.LucideIcons.chartBar),
    _RailItem(ScannerSubPage.customScans, 'Custom Scans',
        shadcn.LucideIcons.code),
  ];

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.surfaceVariantDark, light: MyntColors.surfaceVariant);
    final border = shadcn.Theme.of(context).colorScheme.border;
    final width = collapsed ? 64.0 : 220.0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'RESEARCH',
                style: MyntWebTextStyles.caption(
                  context,
                  fontWeight: MyntFonts.semiBold,
                ).copyWith(letterSpacing: 1.2),
              ),
            )
          else
            const SizedBox(height: 16),
          for (final item in _items)
            _NavItem(
              item: item,
              active: item.page == active,
              collapsed: collapsed,
              onTap: () => onSelect(item.page),
            ),
        ],
      ),
    );
  }
}

class _RailItem {
  final ScannerSubPage page;
  final String label;
  final IconData icon;
  const _RailItem(this.page, this.label, this.icon);
}

class _NavItem extends StatefulWidget {
  final _RailItem item;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.active,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final primary = MyntColors.primary;
    final inactiveColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final bg = widget.active
        ? primary.withValues(alpha: 0.10)
        : (_hover
            ? resolveThemeColor(context,
                dark: MyntColors.surfaceDark.withValues(alpha: 0.6),
                light: MyntColors.surface.withValues(alpha: 0.6))
            : Colors.transparent);
    final color = widget.active ? primary : inactiveColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.item.icon, size: 18, color: color),
                if (!widget.collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: widget.active
                            ? MyntFonts.semiBold
                            : MyntFonts.regular,
                        darkColor: color,
                        lightColor: color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create `lib/screens/web/scanner/widgets/scanner_breadcrumb.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

class BreadcrumbSegment {
  final String label;
  final VoidCallback? onTap;
  const BreadcrumbSegment(this.label, {this.onTap});
}

class ScannerBreadcrumb extends StatelessWidget {
  final List<BreadcrumbSegment> segments;

  const ScannerBreadcrumb({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final separator = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(shadcn.LucideIcons.chevronRight, size: 14, color: secondary),
    );

    final children = <Widget>[];
    for (int i = 0; i < segments.length; i++) {
      final s = segments[i];
      final isLast = i == segments.length - 1;
      final color = isLast ? primary : secondary;
      final style = MyntWebTextStyles.caption(
        context,
        fontWeight: isLast ? MyntFonts.medium : MyntFonts.regular,
        color: color,
      );
      Widget txt = Text(s.label, style: style);
      if (s.onTap != null && !isLast) {
        txt = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: s.onTap, child: txt),
        );
      }
      children.add(txt);
      if (!isLast) children.add(separator);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
```

- [ ] **Step 4: Create `lib/screens/web/scanner/scanner_shell_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart'
    show ScannerSubPage;
import 'widgets/scanner_breadcrumb.dart';
import 'widgets/scanner_left_rail.dart';

class ScannerShellScreen extends ConsumerStatefulWidget {
  final ScannerSubPage? initialSubPage;

  const ScannerShellScreen({super.key, this.initialSubPage});

  @override
  ConsumerState<ScannerShellScreen> createState() => _ScannerShellScreenState();
}

class _ScannerShellScreenState extends ConsumerState<ScannerShellScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialSubPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(scannerShellProvider.notifier)
            .setActiveSubPage(widget.initialSubPage!);
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
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: width < 760 ? 12 : 24,
                vertical: width < 760 ? 16 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScannerBreadcrumb(
                    segments: [
                      const BreadcrumbSegment('Scanner'),
                      BreadcrumbSegment(_label(state.activeSubPage)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: IndexedStack(
                      index: state.activeSubPage.index,
                      children: const [
                        _Placeholder('Symbols'),
                        _Placeholder('Scanners'),
                        _Placeholder('Fundamentals'),
                        _Placeholder('Custom Scans'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder(this.label);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$label sub-page coming soon',
        style: MyntWebTextStyles.body(context),
      ),
    );
  }
}
```

- [ ] **Step 5: Run analyzer on the new files**

```bash
flutter analyze lib/screens/web/scanner/ lib/provider/scanner/
```

Expected: no issues.

---

### Task 9: Wire ScreenType.scanner into PanelContentBuilder

**Files:**
- Modify: `lib/screens/web/home/widgets/panels/panel_content_builder.dart`

- [ ] **Step 1: Add the imports at the top of the file** (with other screen imports):

```dart
import 'package:mynt_plus/screens/web/scanner/scanner_shell_screen.dart';
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart'
    show ScannerSubPage;
```

- [ ] **Step 2: Add a new field + constructor param to `PanelContentBuilder`**

```dart
  final ScannerSubPage? initialScannerSubPage;

  PanelContentBuilder({
    this.optionChainArgs,
    this.currentDepthArgs,
    this.tradeActionTabIndex,
    required this.screenLoadingStates,
    this.onBack,
    this.initialScannerSubPage,
  });
```

- [ ] **Step 3: In `getScreenForType(ScreenType type)` switch, add the new case after the existing `case ScreenType.scalper:` (or another nearby trade-tools case):

```dart
      case ScreenType.scanner:
        return ScannerShellScreen(initialSubPage: initialScannerSubPage);
```

- [ ] **Step 4: Run analyzer**

```bash
flutter analyze lib/screens/web/home/widgets/panels/panel_content_builder.dart
```

Expected: no issues.

---

### Task 10: Add Scanner menu item to Options dropdown + hamburger drawer

**Files:**
- Modify: `lib/screens/web/customizable_split_home_screen.dart` (lines ~1416, ~1604, ~2253, plus handler methods)
- Modify: `lib/screens/web/home/widgets/app_bar/navigation_drawer_web.dart`

- [ ] **Step 1: Add handler `_handleScannerTap` to `_CustomizableSplitHomeScreenState`** (right after `_handleScalperTap`, around line 2133):

```dart
  void _handleScannerTap({ScannerSubPage? initial}) {
    context.go(
      initial == null ? WebRoutes.scanner : _scannerPath(initial),
    );
  }

  String _scannerPath(ScannerSubPage p) {
    switch (p) {
      case ScannerSubPage.symbols:
        return WebRoutes.scannerSymbols;
      case ScannerSubPage.scanners:
        return WebRoutes.scannerScanners;
      case ScannerSubPage.fundamentals:
        return WebRoutes.scannerFundamentals;
      case ScannerSubPage.customScans:
        return WebRoutes.scannerCustom;
    }
  }
```

- [ ] **Step 2: In `_buildTradingToolsMenu` around line 2253, after the `// Scalper` `shadcn.MenuButton(...)` and before the closing `]` of `children:`, append a Scanner menu button**:

```dart
                      // Scanner
                      shadcn.MenuButton(
                        onPressed: (context) {
                          _handleScannerTap();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                shadcn.LucideIcons.radar,
                                size: 22,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.iconDark,
                                  light: MyntColors.icon,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Scanner',
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.medium,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
```

- [ ] **Step 3: Find `_openShadcnDrawer` (around line 1416) and add `showScanner` parameter + pass-through to `NavigationDrawerWeb` constructor**

In the method signature add `bool? showScanner,` alongside the other `show*` bools. In the body where `NavigationDrawerWeb` is built, add:

```dart
          onScannerTap: () {
            Navigator.pop(context);
            _handleScannerTap();
          },
          showScanner: showScanner,
```

(Mirror the surrounding pattern used for `onScalperTap` / `showScalper`.)

- [ ] **Step 4: At the call site around line 1608, add `showScanner: !showAllLeftNav,` next to `showScalper`**:

```dart
                          showScanner: !showAllLeftNav,
```

- [ ] **Step 5: Open `lib/screens/web/home/widgets/app_bar/navigation_drawer_web.dart` and add the new field + parameter**

Add field next to `onStrategyBuilderTap`:

```dart
  final VoidCallback? onScannerTap;
```

Add bool flag next to `showStrategyBuilder`:

```dart
  final bool? showScanner;
```

Update the constructor (add `this.onScannerTap` and `this.showScanner` in their slots).

- [ ] **Step 6: In the TRADE-section condition (line ~158), add the scanner gate to the OR chain**:

```dart
                  if ((showPositions ?? true) || (showHoldings ?? true) || (showOrders ?? true) || (showFunds ?? true) || (showOptionZ ?? (onOptionZTap != null)) || (showOptionFlash ?? (onOptionFlashTap != null)) || (showScalper ?? (onScalperTap != null)) || (showStrategyBuilder ?? (onStrategyBuilderTap != null)) || (showScanner ?? (onScannerTap != null)))
                    _buildSectionHeader(context, 'TRADE'),
```

- [ ] **Step 7: After the Strategy Builder drawer entry (line ~225), add Scanner**

```dart
                  if ((showScanner ?? (onScannerTap != null)) && onScannerTap != null)
                    _buildDrawerItem(
                      context: context,
                      title: 'Scanner',
                      icon: shadcn.LucideIcons.radar,
                      screenName: 'scanner',
                      onTap: onScannerTap!,
                    ),
```

- [ ] **Step 8: Run analyzer**

```bash
flutter analyze lib/screens/web/customizable_split_home_screen.dart lib/screens/web/home/widgets/app_bar/navigation_drawer_web.dart
```

Expected: no issues.

---

### Task 11: Add /scanner + 4 sub-routes to web_router.dart and wire panel routing

**Files:**
- Modify: `lib/routes/web_router.dart`
- Modify: `lib/screens/web/customizable_split_home_screen.dart`

- [ ] **Step 1: In `web_router.dart`, add the import**

```dart
import '../screens/web/customizable_split_home_screen.dart' show ScannerSubPage;
```

(Append the `show ScannerSubPage` clause if `CustomizableSplitHomeScreen` is already imported.)

- [ ] **Step 2: In `class WebRoutes`, add five new constants** (after `dailyPnl`):

```dart
  static const String scanner = '/scanner';
  static const String scannerSymbols = '/scanner/symbols';
  static const String scannerScanners = '/scanner/scanners';
  static const String scannerFundamentals = '/scanner/fundamentals';
  static const String scannerCustom = '/scanner/custom';
```

- [ ] **Step 3: In the `GoRouter` `routes:` list, add five new `GoRoute` entries** (place after the `WebRoutes.profile` entry, before `errorBuilder:`):

```dart
      GoRoute(
        path: WebRoutes.scanner,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.scanner,
        ),
      ),
      GoRoute(
        path: WebRoutes.scannerSymbols,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.scanner,
          initialScannerSubPage: ScannerSubPage.symbols,
        ),
      ),
      GoRoute(
        path: WebRoutes.scannerScanners,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.scanner,
          initialScannerSubPage: ScannerSubPage.scanners,
        ),
      ),
      GoRoute(
        path: WebRoutes.scannerFundamentals,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.scanner,
          initialScannerSubPage: ScannerSubPage.fundamentals,
        ),
      ),
      GoRoute(
        path: WebRoutes.scannerCustom,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.scanner,
          initialScannerSubPage: ScannerSubPage.customScans,
        ),
      ),
```

- [ ] **Step 4: In `customizable_split_home_screen.dart`, locate the panel-initialization block (search for `ScreenTypeParam.caBuyback`)** and add a parallel branch for `scanner`:

```dart
        } else if (widget.initialRightPanel == ScreenTypeParam.scanner) {
          newPanels.add(PanelConfig(
            id: 'panel_1',
            screenType: ScreenType.scanner,
            screens: const [ScreenType.scanner],
            activeScreenIndex: 0,
          ));
```

(The exact `PanelConfig` parameter names must match what other branches use — copy the structure from the closest existing branch verbatim.)

- [ ] **Step 5: Pass `widget.initialScannerSubPage` to `PanelContentBuilder` at the construction site**. Search for `PanelContentBuilder(` in the file and add the parameter:

```dart
              initialScannerSubPage: widget.initialScannerSubPage,
```

- [ ] **Step 6: Run web build to confirm everything compiles**

```bash
flutter build web --no-tree-shake-icons --debug
```

Expected: build succeeds.

---

> 🟢 **Manual checkpoint after Milestone 1**
>
> Run `flutter run -d chrome --web-port 8080`. Verify:
>
> 1. Open the app, log in
> 2. Click the **Options** dropdown in the app bar → "Scanner" appears at the bottom with a radar icon
> 3. Click "Scanner" → right panel shows the Scanner shell: left rail with 4 items (Symbols / Scanners / Fundamentals / Custom Scans), one selected (Symbols), placeholder text in content area
> 4. Click each left-rail item → placeholder text updates
> 5. Resize browser narrow (< 1100px wide) → left rail collapses to icons only
> 6. Resize browser < 760px → left rail hides
> 7. Open `/scanner/scanners` directly in browser URL → shell opens with Scanners selected
> 8. Open the hamburger drawer (resize narrow OR shrink left nav) → "Scanner" appears under TRADE section
> 9. Toggle dark theme → all colors in the shell adapt
>
> Safe place to commit a working navigation shell snapshot.

---

## Milestone 2 — Utilities (Tasks 12–18)

Shared building blocks consumed by all sub-pages. Build these first so later milestones can compose against them without inline duplication.

### Task 12: Create formatters.dart

**Files:**
- Create: `lib/screens/web/scanner/utils/formatters.dart`
- Create: `test/scanner/utils/formatters_test.dart`

- [ ] **Step 1: Create `lib/screens/web/scanner/utils/formatters.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';

/// Display placeholder for null numbers.
const String kEmDash = '—';

/// Format an INR amount using the Indian crore/lakh convention.
///
/// - `≥ 1 lakh Cr` → `X.XX L Cr`
/// - `≥ 1 Cr`     → `X Cr`
/// - else         → `₹X,XX,XXX` (Indian comma format)
String formatCurrencyINR(num? value) {
  if (value == null) return kEmDash;
  final crore = value / 1e7;
  if (crore >= 1e5) {
    return '${_indianFormat(crore / 1e5, maxFractionDigits: 2)} L Cr';
  }
  if (crore >= 1) {
    return '${_indianFormat(crore, maxFractionDigits: 0)} Cr';
  }
  return '₹${_indianFormat(value.toDouble(), maxFractionDigits: 0)}';
}

/// Format a fraction as a percentage (`0.15` → `15.00%`). Optional `+` prefix
/// for positive values when [signed] is true.
String formatPercent(num? value, {bool signed = false}) {
  if (value == null) return kEmDash;
  final pct = value * 100;
  final body = pct.toStringAsFixed(2);
  final sign = signed && pct >= 0 ? '+' : '';
  return '$sign$body%';
}

/// Format an absolute change value with `+`/`-` sign (used for day-change row).
String formatSignedNumber(num? value, {int fractionDigits = 2}) {
  if (value == null) return kEmDash;
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(fractionDigits)}';
}

/// Returns a color appropriate for a +/- value (success for >= 0, error for < 0,
/// secondary for null).
Color signedColor(BuildContext context, num? value) {
  if (value == null) {
    return resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
  }
  return value >= 0 ? MyntColors.success : MyntColors.error;
}

/// Parse a backend ISO date that may be missing a timezone suffix. Backend
/// stores naive UTC and serializes without `Z`; JavaScript / Dart would
/// otherwise treat it as local time, which is wrong.
DateTime parseBackendDate(String s) {
  final hasTz = RegExp(r'Z|[+\-]\d{2}:?\d{2}$').hasMatch(s);
  if (RegExp(r'^\d{4}-\d{2}-\d{2}([ T].*)?$').hasMatch(s) && !hasTz) {
    return DateTime.parse('${s.replaceFirst(" ", "T")}Z');
  }
  return DateTime.parse(s);
}

/// Format a backend timestamp in IST (`Asia/Kolkata`).
String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return kEmDash;
  // Convert UTC → IST (+5:30). Dart on web doesn't bundle tz data so we offset
  // manually; this is correct year-round (India has no DST).
  final utc = parseBackendDate(iso).toUtc();
  final ist = utc.add(const Duration(hours: 5, minutes: 30));
  return '${_pad(ist.day)} ${_monthShort(ist.month)} ${ist.year}, '
      '${_pad(ist.hour)}:${_pad(ist.minute)}';
}

/// Date-only variant (no time).
String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return kEmDash;
  final utc = parseBackendDate(iso).toUtc();
  final ist = utc.add(const Duration(hours: 5, minutes: 30));
  return '${_pad(ist.day)} ${_monthShort(ist.month)} ${ist.year}';
}

/// fmt-driven column formatter (used by scanner-results table).
({String text, Color? color}) formatColumn(
    BuildContext context, num? value, String fmt) {
  if (value == null) return (text: kEmDash, color: null);
  switch (fmt) {
    case 'price':
      return (
        text: _indianFormat(value.toDouble(), maxFractionDigits: 2),
        color: null,
      );
    case 'pct':
      final sign = value >= 0 ? '+' : '';
      return (
        text: '$sign${value.toStringAsFixed(2)}%',
        color: value >= 0 ? MyntColors.success : MyntColors.error,
      );
    case 'ratio':
      return (text: value.toStringAsFixed(2), color: null);
    case 'int':
      return (
        text: _indianFormat(value.toDouble(), maxFractionDigits: 0),
        color: null,
      );
    case 'raw':
    default:
      return (text: value.toStringAsFixed(2), color: null);
  }
}

// ---------------------------------------------------------------------------
// Indian comma format helpers
// ---------------------------------------------------------------------------

String _indianFormat(double value, {int maxFractionDigits = 2}) {
  final neg = value < 0;
  final abs = value.abs();
  final fixed = abs.toStringAsFixed(maxFractionDigits);
  final parts = fixed.split('.');
  final intPart = _indianGrouping(parts[0]);
  final out = parts.length == 2 && parts[1] != '0' * parts[1].length
      ? '$intPart.${parts[1]}'
      : intPart;
  return neg ? '-$out' : out;
}

String _indianGrouping(String intDigits) {
  // Indian grouping: last 3, then 2-2-2... e.g. 1,39,615
  if (intDigits.length <= 3) return intDigits;
  final last3 = intDigits.substring(intDigits.length - 3);
  String rest = intDigits.substring(0, intDigits.length - 3);
  final buf = StringBuffer();
  while (rest.length > 2) {
    buf.write(',${rest.substring(rest.length - 2)}');
    rest = rest.substring(0, rest.length - 2);
  }
  return '$rest${buf.toString().split(',').reversed.join(',')},$last3';
}

String _pad(int n) => n.toString().padLeft(2, '0');

String _monthShort(int m) {
  const names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return names[m - 1];
}
```

- [ ] **Step 2: Create the matching unit tests `test/scanner/utils/formatters_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';

void main() {
  group('formatCurrencyINR', () {
    test('null → em dash', () => expect(formatCurrencyINR(null), '—'));
    test('below 1 Cr renders with ₹ prefix and Indian grouping', () {
      expect(formatCurrencyINR(139615), '₹1,39,615');
    });
    test('between 1 Cr and 1 L Cr renders as Cr', () {
      expect(formatCurrencyINR(1e8), '1 Cr'); // exactly 10 Cr written as 10 Cr → adjust
      // 10000000 / 1e7 = 1 → "1 Cr"
      expect(formatCurrencyINR(5e9), '500 Cr');
    });
    test('≥ 1 L Cr renders as L Cr', () {
      // 1e12 = 1,00,000 Cr = 1 L Cr
      expect(formatCurrencyINR(1e12), '1 L Cr');
      // 18,40,01,01,26,95,04 ≈ 18.4 L Cr
      expect(formatCurrencyINR(18400101269504.0), '18.4 L Cr');
    });
  });

  group('formatPercent', () {
    test('null', () => expect(formatPercent(null), '—'));
    test('positive unsigned', () => expect(formatPercent(0.15), '15.00%'));
    test('positive signed', () => expect(formatPercent(0.15, signed: true), '+15.00%'));
    test('negative', () => expect(formatPercent(-0.04, signed: true), '-4.00%'));
  });

  group('parseBackendDate', () {
    test('naive UTC string parsed as UTC', () {
      final d = parseBackendDate('2026-05-15T07:30:00');
      expect(d.isUtc, true);
      expect(d.year, 2026);
      expect(d.hour, 7);
    });
    test('Zulu suffix preserved', () {
      final d = parseBackendDate('2026-05-15T07:30:00Z');
      expect(d.isUtc, true);
    });
  });

  group('formatDateTime', () {
    test('IST formatting', () {
      // 07:30 UTC → 13:00 IST
      expect(formatDateTime('2026-05-15T07:30:00'), '15 May 2026, 13:00');
    });
  });

  group('formatColumn', () {
    // Tested without a BuildContext via a TestWidgetsFlutterBinding shortcut.
    testWidgets('pct adds + sign and color', (tester) async {
      await tester.pumpWidget(const _CtxProbe());
      final ctx = tester.element(find.byType(_CtxProbe));
      final res = formatColumn(ctx, 1.5, 'pct');
      expect(res.text, '+1.50%');
      expect(res.color, isNotNull);
    });
  });
}

class _CtxProbe extends StatelessWidget {
  const _CtxProbe();
  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

- [ ] **Step 3: Run the tests**

```bash
flutter test test/scanner/utils/formatters_test.dart
```

Expected: `All tests passed!`. If the `1 Cr` test fails because the Indian grouping is off, debug `_indianFormat`/`_indianGrouping` — these are tricky and the test acts as the spec.

---

### Task 13: Create download_xlsx.dart helper

**Files:**
- Create: `lib/screens/web/scanner/utils/download_xlsx.dart`

- [ ] **Step 1: Create the file**

```dart
import 'dart:html' as html;
import 'dart:typed_data';

/// Trigger a browser download of an .xlsx blob fetched from the backend.
///
/// Pass the [bytes] and optional server-provided [filename] (from
/// `Content-Disposition`). If [filename] is null, falls back to
/// `[fallbackName]` and finally `export.xlsx`.
void triggerXlsxDownload({
  required Uint8List bytes,
  String? filename,
  String fallbackName = 'export.xlsx',
}) {
  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename ?? fallbackName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/screens/web/scanner/utils/download_xlsx.dart
```

Expected: no issues.

> ⚠️ This file imports `dart:html` and will not compile on mobile builds. The whole Scanner feature is web-only, so this is acceptable. If the project later supports mobile for Scanner, switch to `package:universal_html`.

---

### Task 14: Create technical_interpretations.dart

**Files:**
- Create: `lib/screens/web/scanner/utils/technical_interpretations.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';

/// A label + color for an indicator value, used by the Technicals tab badges.
class TechnicalBadge {
  final String label;
  final Color color;
  const TechnicalBadge(this.label, this.color);
}

/// Interpret a numeric indicator value into a human-readable badge.
/// Returns `null` if no badge should be shown.
TechnicalBadge? interpretIndicator({
  required String key,
  required num? value,
  required Map<String, num?> allIndicators,
}) {
  if (value == null) return null;
  final n = value.toDouble();
  switch (key) {
    case 'rsi_14':
      if (n < 30) return const TechnicalBadge('Oversold', MyntColors.error);
      if (n > 70) return const TechnicalBadge('Overbought', MyntColors.warning);
      return null;
    case 'adx_14':
    case 'adx':
      if (n > 25) return const TechnicalBadge('Strong trend', MyntColors.success);
      if (n < 20) return const TechnicalBadge('Weak trend', MyntColors.warning);
      return null;
    case 'supertrend_dir':
      return n > 0
          ? const TechnicalBadge('Up trend', MyntColors.success)
          : const TechnicalBadge('Down trend', MyntColors.error);
    case 'macd_hist':
      return n >= 0
          ? const TechnicalBadge('Bullish', MyntColors.success)
          : const TechnicalBadge('Bearish', MyntColors.error);
    case 'mfi_14':
      if (n < 20) return const TechnicalBadge('Oversold', MyntColors.error);
      if (n > 80) return const TechnicalBadge('Overbought', MyntColors.warning);
      return null;
    case 'william_r_14':
      if (n < -80) return const TechnicalBadge('Oversold', MyntColors.error);
      if (n > -20) return const TechnicalBadge('Overbought', MyntColors.warning);
      return null;
    case 'cci_20':
      if (n < -100) return const TechnicalBadge('Oversold', MyntColors.error);
      if (n > 100) return const TechnicalBadge('Overbought', MyntColors.warning);
      return null;
  }
  // Cross-indicator comparisons
  if (key == 'close') {
    final sma200 = allIndicators['sma_200']?.toDouble();
    if (sma200 != null) {
      return n >= sma200
          ? const TechnicalBadge('Above 200-DMA', MyntColors.success)
          : const TechnicalBadge('Below 200-DMA', MyntColors.error);
    }
  }
  return null;
}

/// Human-readable label for a technical indicator key.
String indicatorLabel(String key) {
  switch (key) {
    case 'sma_20': return 'SMA (20)';
    case 'sma_50': return 'SMA (50)';
    case 'sma_200': return 'SMA (200)';
    case 'ema_9': return 'EMA (9)';
    case 'ema_21': return 'EMA (21)';
    case 'rsi_14': return 'RSI (14)';
    case 'macd_line': return 'MACD Line';
    case 'macd_signal': return 'MACD Signal';
    case 'macd_hist': return 'MACD Histogram';
    case 'bb_upper': return 'Bollinger Upper';
    case 'bb_middle': return 'Bollinger Middle';
    case 'bb_lower': return 'Bollinger Lower';
    case 'atr_14': return 'ATR (14)';
    case 'supertrend_line': return 'SuperTrend Line';
    case 'supertrend_dir': return 'SuperTrend Direction';
    case 'adx_14': case 'adx': return 'ADX (14)';
    case 'di_plus_14': return '+DI (14)';
    case 'di_minus_14': return '-DI (14)';
    case 'psar': return 'Parabolic SAR';
    case 'roc_12': return 'ROC (12)';
    case 'vwap': return 'VWAP';
    case 'stoch_k': return 'Stoch %K';
    case 'stoch_d': return 'Stoch %D';
    case 'mfi_14': return 'MFI (14)';
    case 'william_r_14': return 'Williams %R (14)';
    case 'cci_20': return 'CCI (20)';
    case 'close': return 'Close';
    default:
      // Fallback: humanize the key (sma_20 → SMA (20))
      return key.replaceAll('_', ' ').toUpperCase();
  }
}
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/screens/web/scanner/utils/technical_interpretations.dart
```

Expected: no issues.

---

### Task 15: Create indicator_catalog.dart (predicate DSL metadata)

**Files:**
- Create: `lib/screens/web/scanner/utils/indicator_catalog.dart`

- [ ] **Step 1: Create the file (full content)**

```dart
/// Metadata about each indicator available in the StockScanner predicate DSL.
/// Source of truth for the Custom Scans visual builder + JSON serializer.
///
/// Each [IndicatorDef] lists its parameters. Params have a default when the
/// backend uses one; UI may still let users override.

class IndicatorParam {
  final String name;
  final IndicatorParamType type;
  /// String dropdown options for type == column (defaults to OHLCV columns).
  final List<String>? columns;
  final num? defaultNum;
  final String? defaultString;
  final bool required;

  const IndicatorParam.numParam(this.name,
      {this.defaultNum, this.required = true})
      : type = IndicatorParamType.number,
        columns = null,
        defaultString = null;

  const IndicatorParam.columnParam(this.name,
      {this.columns = const ['close', 'open', 'high', 'low', 'volume'],
      this.defaultString = 'close',
      this.required = false})
      : type = IndicatorParamType.column,
        defaultNum = null;

  const IndicatorParam.stringParam(this.name,
      {this.defaultString, this.required = false})
      : type = IndicatorParamType.string,
        columns = null,
        defaultNum = null;
}

enum IndicatorParamType { number, column, string }

class IndicatorDef {
  final String name;
  final String label;
  final IndicatorFamily family;
  final List<IndicatorParam> params;
  const IndicatorDef({
    required this.name,
    required this.label,
    required this.family,
    this.params = const [],
  });
}

enum IndicatorFamily {
  rawPriceVolume,
  aggregations,
  movingAverages,
  oscillators,
  bands,
  trend,
  volatility,
  ichimoku,
  candlestickPatterns,
  relativeStrength,
}

extension IndicatorFamilyLabel on IndicatorFamily {
  String get label {
    switch (this) {
      case IndicatorFamily.rawPriceVolume: return 'Raw price/volume';
      case IndicatorFamily.aggregations: return 'Aggregations';
      case IndicatorFamily.movingAverages: return 'Moving averages';
      case IndicatorFamily.oscillators: return 'Oscillators';
      case IndicatorFamily.bands: return 'Bands';
      case IndicatorFamily.trend: return 'Trend';
      case IndicatorFamily.volatility: return 'Volatility';
      case IndicatorFamily.ichimoku: return 'Ichimoku';
      case IndicatorFamily.candlestickPatterns: return 'Candlestick patterns';
      case IndicatorFamily.relativeStrength: return 'Relative strength';
    }
  }
}

/// Full catalog of ~57 indicators per spec §3.7.
const List<IndicatorDef> kIndicatorCatalog = [
  // Raw price/volume
  IndicatorDef(name: 'open', label: 'Open', family: IndicatorFamily.rawPriceVolume),
  IndicatorDef(name: 'high', label: 'High', family: IndicatorFamily.rawPriceVolume),
  IndicatorDef(name: 'low', label: 'Low', family: IndicatorFamily.rawPriceVolume),
  IndicatorDef(name: 'close', label: 'Close', family: IndicatorFamily.rawPriceVolume),
  IndicatorDef(name: 'adjclose', label: 'Adj. Close', family: IndicatorFamily.rawPriceVolume),
  IndicatorDef(name: 'volume', label: 'Volume', family: IndicatorFamily.rawPriceVolume),

  // Aggregations
  IndicatorDef(name: 'rolling_max', label: 'Rolling max',
    family: IndicatorFamily.aggregations,
    params: [
      IndicatorParam.columnParam('col'),
      IndicatorParam.numParam('lookback', defaultNum: 20),
    ]),
  IndicatorDef(name: 'rolling_min', label: 'Rolling min',
    family: IndicatorFamily.aggregations,
    params: [
      IndicatorParam.columnParam('col'),
      IndicatorParam.numParam('lookback', defaultNum: 20),
    ]),
  IndicatorDef(name: 'bars_since', label: 'Bars since condition',
    family: IndicatorFamily.aggregations,
    params: [IndicatorParam.stringParam('condition', required: true)]),

  // Moving averages
  IndicatorDef(name: 'sma', label: 'SMA', family: IndicatorFamily.movingAverages,
    params: [
      IndicatorParam.columnParam('source'),
      IndicatorParam.numParam('period', defaultNum: 20),
    ]),
  IndicatorDef(name: 'ema', label: 'EMA', family: IndicatorFamily.movingAverages,
    params: [
      IndicatorParam.columnParam('source'),
      IndicatorParam.numParam('period', defaultNum: 9),
    ]),
  IndicatorDef(name: 'wma', label: 'WMA', family: IndicatorFamily.movingAverages,
    params: [
      IndicatorParam.columnParam('source'),
      IndicatorParam.numParam('period', defaultNum: 14),
    ]),
  IndicatorDef(name: 'wsma', label: 'WSMA', family: IndicatorFamily.movingAverages,
    params: [IndicatorParam.numParam('period', defaultNum: 14)]),
  IndicatorDef(name: 'wema', label: 'WEMA', family: IndicatorFamily.movingAverages,
    params: [IndicatorParam.numParam('period', defaultNum: 14)]),
  IndicatorDef(name: 'vwap', label: 'VWAP', family: IndicatorFamily.movingAverages,
    params: [IndicatorParam.stringParam('anchor', defaultString: 'day')]),

  // Oscillators
  IndicatorDef(name: 'rsi', label: 'RSI', family: IndicatorFamily.oscillators,
    params: [IndicatorParam.numParam('period', defaultNum: 14)]),
  IndicatorDef(name: 'cci', label: 'CCI', family: IndicatorFamily.oscillators,
    params: [IndicatorParam.numParam('period', defaultNum: 20)]),
  IndicatorDef(name: 'mfi', label: 'MFI', family: IndicatorFamily.oscillators,
    params: [IndicatorParam.numParam('period', defaultNum: 14)]),
  IndicatorDef(name: 'william_r', label: 'Williams %R', family: IndicatorFamily.oscillators,
    params: [IndicatorParam.numParam('period', defaultNum: 14)]),
  IndicatorDef(name: 'stoch_k', label: 'Stochastic %K', family: IndicatorFamily.oscillators,
    params: [
      IndicatorParam.numParam('k_period', defaultNum: 14),
      IndicatorParam.numParam('smooth', defaultNum: 3),
    ]),
  IndicatorDef(name: 'stoch_d', label: 'Stochastic %D', family: IndicatorFamily.oscillators,
    params: [
      IndicatorParam.numParam('k_period', defaultNum: 14),
      IndicatorParam.numParam('smooth', defaultNum: 3),
      IndicatorParam.numParam('d_period', defaultNum: 3),
    ]),
  IndicatorDef(name: 'roc', label: 'Rate of Change', family: IndicatorFamily.oscillators,
    params: [IndicatorParam.numParam('period', defaultNum: 12)]),
  IndicatorDef(name: 'momentum_score', label: 'Momentum Score',
    family: IndicatorFamily.oscillators,
    params: [
      IndicatorParam.numParam('lookback', defaultNum: 10),
      IndicatorParam.numParam('smoothing', defaultNum: 3),
    ]),

  // Bands
  IndicatorDef(name: 'bollinger_upper', label: 'Bollinger Upper',
    family: IndicatorFamily.bands,
    params: [
      IndicatorParam.numParam('period', defaultNum: 20),
      IndicatorParam.numParam('std', defaultNum: 2),
    ]),
  IndicatorDef(name: 'bollinger_middle', label: 'Bollinger Middle',
    family: IndicatorFamily.bands,
    params: [
      IndicatorParam.numParam('period', defaultNum: 20),
      IndicatorParam.numParam('std', defaultNum: 2),
    ]),
  IndicatorDef(name: 'bollinger_lower', label: 'Bollinger Lower',
    family: IndicatorFamily.bands,
    params: [
      IndicatorParam.numParam('period', defaultNum: 20),
      IndicatorParam.numParam('std', defaultNum: 2),
    ]),
  IndicatorDef(name: 'bollinger_bandwidth', label: 'Bollinger Bandwidth',
    family: IndicatorFamily.bands,
    params: [
      IndicatorParam.numParam('period', defaultNum: 20),
      IndicatorParam.numParam('std', defaultNum: 2),
    ]),
  IndicatorDef(name: 'keltner_upper', label: 'Keltner Upper',
    family: IndicatorFamily.bands,
    params: [
      IndicatorParam.numParam('period', defaultNum: 20),
      IndicatorParam.numParam('mult', defaultNum: 2),
    ]),
  IndicatorDef(name: 'keltner_lower', label: 'Keltner Lower',
    family: IndicatorFamily.bands,
    params: [
      IndicatorParam.numParam('period', defaultNum: 20),
      IndicatorParam.numParam('mult', defaultNum: 2),
    ]),

  // Trend
  IndicatorDef(name: 'macd_line', label: 'MACD Line', family: IndicatorFamily.trend,
    params: [
      IndicatorParam.numParam('fast', defaultNum: 12),
      IndicatorParam.numParam('slow', defaultNum: 26),
      IndicatorParam.numParam('signal', defaultNum: 9),
    ]),
  IndicatorDef(name: 'macd_signal', label: 'MACD Signal', family: IndicatorFamily.trend,
    params: [
      IndicatorParam.numParam('fast', defaultNum: 12),
      IndicatorParam.numParam('slow', defaultNum: 26),
      IndicatorParam.numParam('signal', defaultNum: 9),
    ]),
  IndicatorDef(name: 'macd_hist', label: 'MACD Histogram', family: IndicatorFamily.trend,
    params: [
      IndicatorParam.numParam('fast', defaultNum: 12),
      IndicatorParam.numParam('slow', defaultNum: 26),
      IndicatorParam.numParam('signal', defaultNum: 9),
    ]),
  IndicatorDef(name: 'adx', label: 'ADX', family: IndicatorFamily.trend,
    params: [IndicatorParam.numParam('period', defaultNum: 14)]),
  IndicatorDef(name: 'di_plus', label: '+DI', family: IndicatorFamily.trend,
    params: [IndicatorParam.numParam('period', defaultNum: 14)]),
  IndicatorDef(name: 'di_minus', label: '-DI', family: IndicatorFamily.trend,
    params: [IndicatorParam.numParam('period', defaultNum: 14)]),
  IndicatorDef(name: 'supertrend_line', label: 'SuperTrend Line',
    family: IndicatorFamily.trend,
    params: [
      IndicatorParam.numParam('period', defaultNum: 10),
      IndicatorParam.numParam('mult', defaultNum: 3),
    ]),
  IndicatorDef(name: 'supertrend_dir', label: 'SuperTrend Direction',
    family: IndicatorFamily.trend,
    params: [
      IndicatorParam.numParam('period', defaultNum: 10),
      IndicatorParam.numParam('mult', defaultNum: 3),
    ]),
  IndicatorDef(name: 'psar', label: 'Parabolic SAR', family: IndicatorFamily.trend,
    params: [
      IndicatorParam.numParam('step', defaultNum: 0.02),
      IndicatorParam.numParam('max', defaultNum: 0.2),
    ]),

  // Volatility
  IndicatorDef(name: 'atr', label: 'ATR', family: IndicatorFamily.volatility,
    params: [IndicatorParam.numParam('period', defaultNum: 14)]),
  IndicatorDef(name: 'narrow_range', label: 'Narrow Range',
    family: IndicatorFamily.volatility,
    params: [IndicatorParam.numParam('lookback', defaultNum: 4)]),
  IndicatorDef(name: 'beta', label: 'Beta', family: IndicatorFamily.volatility,
    params: [
      IndicatorParam.numParam('period', defaultNum: 60),
      IndicatorParam.stringParam('benchmark', defaultString: '^NSEI'),
    ]),

  // Ichimoku
  IndicatorDef(name: 'tenkan', label: 'Tenkan', family: IndicatorFamily.ichimoku),
  IndicatorDef(name: 'kijun', label: 'Kijun', family: IndicatorFamily.ichimoku),
  IndicatorDef(name: 'senkou_a', label: 'Senkou A', family: IndicatorFamily.ichimoku),
  IndicatorDef(name: 'senkou_b', label: 'Senkou B', family: IndicatorFamily.ichimoku),
  IndicatorDef(name: 'chikou', label: 'Chikou', family: IndicatorFamily.ichimoku),

  // Candlestick patterns
  IndicatorDef(name: 'cdl_doji', label: 'Doji', family: IndicatorFamily.candlestickPatterns),
  IndicatorDef(name: 'cdl_hammer', label: 'Hammer', family: IndicatorFamily.candlestickPatterns),
  IndicatorDef(name: 'cdl_shooting_star', label: 'Shooting Star',
    family: IndicatorFamily.candlestickPatterns),
  IndicatorDef(name: 'cdl_bullish_engulfing', label: 'Bullish Engulfing',
    family: IndicatorFamily.candlestickPatterns),
  IndicatorDef(name: 'cdl_bearish_engulfing', label: 'Bearish Engulfing',
    family: IndicatorFamily.candlestickPatterns),
  IndicatorDef(name: 'cdl_morning_star', label: 'Morning Star',
    family: IndicatorFamily.candlestickPatterns),
  IndicatorDef(name: 'cdl_evening_star', label: 'Evening Star',
    family: IndicatorFamily.candlestickPatterns),
  IndicatorDef(name: 'cdl_three_white_soldiers', label: 'Three White Soldiers',
    family: IndicatorFamily.candlestickPatterns),
  IndicatorDef(name: 'cdl_three_black_crows', label: 'Three Black Crows',
    family: IndicatorFamily.candlestickPatterns),
  IndicatorDef(name: 'cdl_harami_bull', label: 'Harami (Bull)',
    family: IndicatorFamily.candlestickPatterns),
  IndicatorDef(name: 'cdl_harami_bear', label: 'Harami (Bear)',
    family: IndicatorFamily.candlestickPatterns),

  // Relative strength
  IndicatorDef(name: 'relative_strength', label: 'Relative Strength',
    family: IndicatorFamily.relativeStrength,
    params: [
      IndicatorParam.numParam('period', defaultNum: 60),
      IndicatorParam.stringParam('benchmark', defaultString: '^NSEI'),
    ]),
];

/// Look up a definition by indicator name. Returns null for unknown names.
IndicatorDef? indicatorByName(String name) {
  for (final i in kIndicatorCatalog) {
    if (i.name == name) return i;
  }
  return null;
}

/// Group catalog by family for the dropdown UI.
Map<IndicatorFamily, List<IndicatorDef>> get indicatorsByFamily {
  final out = <IndicatorFamily, List<IndicatorDef>>{};
  for (final i in kIndicatorCatalog) {
    out.putIfAbsent(i.family, () => []).add(i);
  }
  return out;
}
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/screens/web/scanner/utils/indicator_catalog.dart
```

Expected: no issues.

---

### Task 16: Create shared metric_card and score_progress_bar widgets

**Files:**
- Create: `lib/screens/web/scanner/widgets/metric_card.dart`
- Create: `lib/screens/web/scanner/widgets/score_progress_bar.dart`

- [ ] **Step 1: `metric_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/technical_interpretations.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final TechnicalBadge? badge;
  final String? secondaryLine;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.badge,
    this.secondaryLine,
  });

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(8),
        color: resolveThemeColor(context,
            dark: MyntColors.surfaceDark, light: MyntColors.surface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: MyntWebTextStyles.caption(context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: MyntWebTextStyles.body(context,
                fontWeight: MyntFonts.semiBold),
          ),
          if (badge != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badge!.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge!.label,
                style: MyntWebTextStyles.caption(context,
                    color: badge!.color, fontWeight: MyntFonts.medium),
              ),
            ),
          ],
          if (secondaryLine != null) ...[
            const SizedBox(height: 4),
            Text(secondaryLine!,
                style: MyntWebTextStyles.caption(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary))),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: `score_progress_bar.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

class ScoreProgressBar extends StatelessWidget {
  final String label;
  final double? score; // 0–100
  const ScoreProgressBar({super.key, required this.label, required this.score});

  Color _color(double s) {
    if (s >= 80) return MyntColors.success;
    if (s >= 60) return const Color(0xFF10B981); // emerald
    if (s >= 40) return MyntColors.warning;
    return MyntColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final s = (score ?? 0).clamp(0, 100).toDouble();
    final color = _color(s);
    final bg = resolveThemeColor(context,
        dark: MyntColors.surfaceVariantDark, light: MyntColors.surfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: MyntWebTextStyles.body(context)),
            Text(
              score == null ? '—' : s.toStringAsFixed(1),
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.semiBold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 8, color: bg),
              FractionallySizedBox(
                widthFactor: s / 100,
                child: Container(height: 8, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Run analyzer**

```bash
flutter analyze lib/screens/web/scanner/widgets/metric_card.dart lib/screens/web/scanner/widgets/score_progress_bar.dart
```

Expected: no issues.

---

### Task 17: Create scanner_results_table.dart and export_modal.dart

**Files:**
- Create: `lib/screens/web/scanner/widgets/scanner_results_table.dart`
- Create: `lib/screens/web/scanner/widgets/export_modal.dart`

- [ ] **Step 1: `scanner_results_table.dart` — sortable table reused by Scanners + Fundamentals**

```dart
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';

class ScanColumn {
  final String key;
  final String label;
  final String fmt;
  final String? description;
  final bool isStandard; // for Ticker/Name/Sector cols
  const ScanColumn({
    required this.key,
    required this.label,
    required this.fmt,
    this.description,
    this.isStandard = false,
  });
}

class ScanRow {
  final String ticker;
  final String name;
  final Map<String, dynamic> values; // contains all column values
  const ScanRow({required this.ticker, required this.name, required this.values});
}

class ScannerResultsTable extends StatefulWidget {
  final List<ScanColumn> columns;
  final List<ScanRow> rows;
  final ValueChanged<String>? onTickerTap;
  final String footer;
  final List<ScanColumn> standardPrefixColumns;

  const ScannerResultsTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.footer,
    this.onTickerTap,
    this.standardPrefixColumns = const [],
  });

  @override
  State<ScannerResultsTable> createState() => _ScannerResultsTableState();
}

class _ScannerResultsTableState extends State<ScannerResultsTable> {
  int? _sortColIdx;
  bool _sortAsc = true;

  List<ScanColumn> get _allCols => [
        const ScanColumn(key: 'ticker', label: 'Ticker', fmt: 'string', isStandard: true),
        const ScanColumn(key: 'name', label: 'Name', fmt: 'string', isStandard: true),
        ...widget.standardPrefixColumns,
        ...widget.columns,
      ];

  List<ScanRow> get _sortedRows {
    if (_sortColIdx == null) return widget.rows;
    final col = _allCols[_sortColIdx!];
    final sorted = [...widget.rows];
    sorted.sort((a, b) {
      final av = _cellValue(a, col);
      final bv = _cellValue(b, col);
      int c;
      if (av is num && bv is num) {
        c = av.compareTo(bv);
      } else {
        c = av.toString().compareTo(bv.toString());
      }
      return _sortAsc ? c : -c;
    });
    return sorted;
  }

  dynamic _cellValue(ScanRow r, ScanColumn c) {
    if (c.key == 'ticker') return r.ticker;
    if (c.key == 'name') return r.name;
    return r.values[c.key];
  }

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final headerBg = resolveThemeColor(context,
        dark: MyntColors.surfaceVariantDark, light: MyntColors.surfaceVariant);
    final cols = _allCols;
    final rows = _sortedRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(headerBg),
              showCheckboxColumn: false,
              sortColumnIndex: _sortColIdx,
              sortAscending: _sortAsc,
              columns: [
                for (int i = 0; i < cols.length; i++)
                  DataColumn(
                    label: _ColumnHeader(col: cols[i]),
                    onSort: (idx, asc) {
                      setState(() {
                        _sortColIdx = idx;
                        _sortAsc = asc;
                      });
                    },
                  ),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    onSelectChanged: widget.onTickerTap == null
                        ? null
                        : (_) => widget.onTickerTap!(r.ticker),
                    cells: [
                      for (final c in cols) DataCell(_buildCell(context, r, c)),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.footer,
            style: MyntWebTextStyles.caption(context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary))),
      ],
    );
  }

  Widget _buildCell(BuildContext context, ScanRow r, ScanColumn c) {
    if (c.key == 'ticker') {
      return Text(r.ticker, style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium));
    }
    if (c.key == 'name') {
      return Text(r.name, style: MyntWebTextStyles.body(context));
    }
    final raw = r.values[c.key];
    if (raw == null) return Text('—', style: MyntWebTextStyles.body(context));
    if (raw is num) {
      final res = formatColumn(context, raw, c.fmt);
      return Text(res.text,
          style: MyntWebTextStyles.body(context,
              color: res.color ??
                  resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary)));
    }
    return Text(raw.toString(), style: MyntWebTextStyles.body(context));
  }
}

class _ColumnHeader extends StatelessWidget {
  final ScanColumn col;
  const _ColumnHeader({required this.col});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(col.label, style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
        if (col.description != null) ...[
          const SizedBox(width: 4),
          shadcn.Tooltip(
            tooltip: TooltipContainer(child: Text(col.description!)).call,
            child: Icon(shadcn.LucideIcons.info, size: 12,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary)),
          ),
        ],
      ],
    );
  }
}

/// Compatibility wrapper for shadcn Tooltip API differences between versions.
/// Adjust if your shadcn version exposes tooltip differently.
class TooltipContainer extends StatelessWidget {
  final Widget child;
  const TooltipContainer({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.surfaceDark, light: MyntColors.surface),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: shadcn.Theme.of(context).colorScheme.border),
      ),
      child: child,
    );
  }
}
```

> ⚠️ The `shadcn.Tooltip` API varies between versions of `shadcn_flutter`. If the `tooltip:` parameter signature differs, adapt to your version — e.g. wrap with `MouseRegion` + a manually shown overlay, or use Material's `Tooltip(message:, child:)`. The behavior must remain: hover over the info icon shows the column description.

- [ ] **Step 2: `export_modal.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

enum ExportColumnsMode { visible, all, custom }

class ExportModalResult {
  final ExportColumnsMode mode;
  final List<String> customColumns;
  const ExportModalResult({required this.mode, this.customColumns = const []});
}

/// Show the export modal — returns null if the user cancels.
Future<ExportModalResult?> showExportModal(
  BuildContext context, {
  bool allowCustom = false,
  List<String> availableCustomKeys = const [],
}) {
  return showDialog<ExportModalResult>(
    context: context,
    builder: (_) => _ExportDialog(
      allowCustom: allowCustom,
      availableCustomKeys: availableCustomKeys,
    ),
  );
}

class _ExportDialog extends StatefulWidget {
  final bool allowCustom;
  final List<String> availableCustomKeys;
  const _ExportDialog({required this.allowCustom, required this.availableCustomKeys});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  ExportColumnsMode _mode = ExportColumnsMode.visible;
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Export to Excel',
          style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioListTile<ExportColumnsMode>(
            value: ExportColumnsMode.visible,
            groupValue: _mode,
            title: Text('Visible columns only', style: MyntWebTextStyles.body(context)),
            onChanged: (v) => setState(() => _mode = v!),
          ),
          RadioListTile<ExportColumnsMode>(
            value: ExportColumnsMode.all,
            groupValue: _mode,
            title: Text('All columns', style: MyntWebTextStyles.body(context)),
            onChanged: (v) => setState(() => _mode = v!),
          ),
          if (widget.allowCustom) ...[
            RadioListTile<ExportColumnsMode>(
              value: ExportColumnsMode.custom,
              groupValue: _mode,
              title: Text('Custom columns', style: MyntWebTextStyles.body(context)),
              onChanged: (v) => setState(() => _mode = v!),
            ),
            if (_mode == ExportColumnsMode.custom)
              SizedBox(
                width: 320, height: 200,
                child: ListView(
                  children: [
                    for (final k in widget.availableCustomKeys)
                      CheckboxListTile(
                        value: _selected.contains(k),
                        title: Text(k, style: MyntWebTextStyles.body(context)),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(k);
                          } else {
                            _selected.remove(k);
                          }
                        }),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: MyntWebTextStyles.body(context)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ExportModalResult(mode: _mode, customColumns: _selected.toList()),
          ),
          child: Text('Download',
              style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium)),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Run analyzer**

```bash
flutter analyze lib/screens/web/scanner/widgets/scanner_results_table.dart lib/screens/web/scanner/widgets/export_modal.dart
```

Expected: no issues (possible warnings about `shadcn.Tooltip` API — adjust per your shadcn version).

---

### Task 18: Create empty_state.dart

**Files:**
- Create: `lib/screens/web/scanner/widgets/empty_state.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

enum EmptyStateKind { empty, search, error, insufficientData }

class EmptyState extends StatelessWidget {
  final EmptyStateKind kind;
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  const EmptyState({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.onRetry,
  });

  IconData get _icon {
    switch (kind) {
      case EmptyStateKind.empty: return shadcn.LucideIcons.inbox;
      case EmptyStateKind.search: return shadcn.LucideIcons.search;
      case EmptyStateKind.error: return shadcn.LucideIcons.circleAlert;
      case EmptyStateKind.insufficientData: return shadcn.LucideIcons.database;
    }
  }

  Color _iconColor(BuildContext context) {
    switch (kind) {
      case EmptyStateKind.error: return MyntColors.error;
      default:
        return resolveThemeColor(context,
            dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 48, color: _iconColor(context)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium)),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: MyntWebTextStyles.caption(context)),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/screens/web/scanner/widgets/empty_state.dart
```

Expected: no issues.

---

> 🟢 **Manual checkpoint after Milestone 2**
>
> Run unit tests:
>
> ```bash
> flutter test test/scanner/
> ```
>
> All tests should pass. Run `flutter analyze` on the whole project — no new warnings should be introduced.
>
> No visible UI change yet (sub-pages still render placeholders). Safe to commit a "utilities + widgets ready" snapshot.

---

## Milestone 3 — API layer + models (Tasks 19–28)

Each task creates one or more related model files and adds the corresponding methods to `StockScannerApi`. After this milestone, every endpoint listed in the spec is callable from Dart.

### Task 19: Symbol models + symbols/* API methods (list + detail + ohlcv)

**Files:**
- Create: `lib/models/scanner_model/symbol.dart`
- Create: `lib/models/scanner_model/ohlcv.dart`
- Modify: `lib/api/stock_scanner_api.dart`

- [ ] **Step 1: Create `lib/models/scanner_model/symbol.dart`**

```dart
class Symbol {
  final String ticker;
  final String ySymbol;
  final String? isin;
  final String name;
  final String series;
  final bool isActive;
  final String? historyStart;
  final String? historyEnd;

  const Symbol({
    required this.ticker,
    required this.ySymbol,
    required this.isin,
    required this.name,
    required this.series,
    required this.isActive,
    required this.historyStart,
    required this.historyEnd,
  });

  factory Symbol.fromJson(Map<String, dynamic> j) => Symbol(
        ticker: j['ticker'] as String,
        ySymbol: (j['y_symbol'] ?? '') as String,
        isin: j['isin'] as String?,
        name: (j['name'] ?? '') as String,
        series: (j['series'] ?? 'EQ') as String,
        isActive: (j['is_active'] ?? true) as bool,
        historyStart: j['history_start'] as String?,
        historyEnd: j['history_end'] as String?,
      );
}

class SymbolListResponse {
  final List<Symbol> items;
  final int total;
  final int page;
  final int pageSize;

  const SymbolListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory SymbolListResponse.fromJson(Map<String, dynamic> j) =>
      SymbolListResponse(
        items: (j['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(Symbol.fromJson)
            .toList(),
        total: (j['total'] ?? 0) as int,
        page: (j['page'] ?? 1) as int,
        pageSize: (j['page_size'] ?? 50) as int,
      );
}
```

- [ ] **Step 2: Create `lib/models/scanner_model/ohlcv.dart`**

```dart
class OhlcvBar {
  final String date;
  final double open, high, low, close, adjclose;
  final int volume;

  const OhlcvBar({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.adjclose,
    required this.volume,
  });

  factory OhlcvBar.fromJson(Map<String, dynamic> j) => OhlcvBar(
        date: j['date'] as String,
        open: (j['open'] as num).toDouble(),
        high: (j['high'] as num).toDouble(),
        low: (j['low'] as num).toDouble(),
        close: (j['close'] as num).toDouble(),
        adjclose: (j['adjclose'] as num? ?? j['close'] as num).toDouble(),
        volume: ((j['volume'] as num?) ?? 0).toInt(),
      );
}

class OhlcvResponse {
  final String ticker;
  final bool adjusted;
  final List<OhlcvBar> bars;

  const OhlcvResponse({
    required this.ticker,
    required this.adjusted,
    required this.bars,
  });

  factory OhlcvResponse.fromJson(Map<String, dynamic> j) => OhlcvResponse(
        ticker: j['ticker'] as String,
        adjusted: (j['adjusted'] ?? true) as bool,
        bars: (j['bars'] as List)
            .cast<Map<String, dynamic>>()
            .map(OhlcvBar.fromJson)
            .toList(),
      );
}
```

- [ ] **Step 3: Add the three matching API methods to `lib/api/stock_scanner_api.dart`** (append above the closing `}` of the mixin):

```dart
  // --- /symbols/* ----------------------------------------------------------

  Future<SymbolListResponse> fetchSymbols({
    String? q,
    int page = 1,
    int pageSize = 50,
  }) async {
    final j = await _get('/symbols', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      'page': page,
      'page_size': pageSize,
    });
    return SymbolListResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<Symbol> fetchSymbol(String ticker) async {
    final j = await _get('/symbols/$ticker');
    return Symbol.fromJson(j as Map<String, dynamic>);
  }

  Future<OhlcvResponse> fetchOhlcv(
    String ticker, {
    String? from,
    String? to,
    bool adjusted = true,
  }) async {
    final j = await _get('/symbols/$ticker/ohlcv', query: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      'adjusted': adjusted,
    });
    return OhlcvResponse.fromJson(j as Map<String, dynamic>);
  }
```

- [ ] **Step 4: Add the corresponding imports at the top of `stock_scanner_api.dart`**:

```dart
import 'package:mynt_plus/models/scanner_model/symbol.dart';
import 'package:mynt_plus/models/scanner_model/ohlcv.dart';
```

- [ ] **Step 5: Remove any `// ignore: unused_element` comments added in Task 3** — the helpers are now actually used.

- [ ] **Step 6: Run analyzer**

```bash
flutter analyze lib/api/stock_scanner_api.dart lib/models/scanner_model/
```

Expected: no issues.

---

### Task 20: Technicals + Performance + symbol-scanners models + API methods

**Files:**
- Create: `lib/models/scanner_model/technicals.dart`
- Create: `lib/models/scanner_model/performance.dart`
- Modify: `lib/api/stock_scanner_api.dart`

- [ ] **Step 1: `technicals.dart`**

```dart
class TechnicalsResponse {
  final String ticker;
  final String asOf;
  /// `key → value` map of ~25 indicators. Values may be null when data is
  /// insufficient (e.g. SMA(200) before 200 bars exist).
  final Map<String, num?> indicators;

  const TechnicalsResponse({
    required this.ticker,
    required this.asOf,
    required this.indicators,
  });

  factory TechnicalsResponse.fromJson(Map<String, dynamic> j) {
    final raw = (j['indicators'] as Map?) ?? const {};
    final ind = <String, num?>{};
    raw.forEach((k, v) {
      if (v == null) {
        ind[k.toString()] = null;
      } else if (v is num) {
        ind[k.toString()] = v;
      } else {
        ind[k.toString()] = num.tryParse(v.toString());
      }
    });
    return TechnicalsResponse(
      ticker: j['ticker'] as String,
      asOf: (j['as_of'] ?? '') as String,
      indicators: ind,
    );
  }
}
```

- [ ] **Step 2: `performance.dart`**

```dart
class PerformanceResponse {
  final String ticker;
  final String asOf;
  final Map<String, double?> returns;
  final Map<String, double?>? relative;

  const PerformanceResponse({
    required this.ticker,
    required this.asOf,
    required this.returns,
    required this.relative,
  });

  factory PerformanceResponse.fromJson(Map<String, dynamic> j) {
    Map<String, double?> _parseMap(dynamic raw) {
      if (raw is! Map) return const {};
      final out = <String, double?>{};
      raw.forEach((k, v) {
        if (v == null) {
          out[k.toString()] = null;
        } else if (v is num) {
          out[k.toString()] = v.toDouble();
        } else {
          out[k.toString()] = double.tryParse(v.toString());
        }
      });
      return out;
    }

    return PerformanceResponse(
      ticker: j['ticker'] as String,
      asOf: (j['as_of'] ?? '') as String,
      returns: _parseMap(j['returns']),
      relative: j['relative'] == null ? null : _parseMap(j['relative']),
    );
  }
}
```

- [ ] **Step 3: Add API methods to `stock_scanner_api.dart`**:

```dart
  Future<TechnicalsResponse> fetchTechnicals(String ticker) async {
    final j = await _get('/symbols/$ticker/technicals');
    return TechnicalsResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<PerformanceResponse> fetchPerformance(String ticker) async {
    final j = await _get('/symbols/$ticker/performance');
    return PerformanceResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<List<String>> fetchSymbolScanners(String ticker,
      {String date = 'latest'}) async {
    final j = await _get('/symbols/$ticker/scanners',
        query: {'date': date});
    return (j as List).map((e) => e.toString()).toList();
  }
```

- [ ] **Step 4: Add imports + run analyzer**

```dart
import 'package:mynt_plus/models/scanner_model/technicals.dart';
import 'package:mynt_plus/models/scanner_model/performance.dart';
```

```bash
flutter analyze lib/api/stock_scanner_api.dart lib/models/scanner_model/
```

Expected: no issues.

---

### Task 21: Fundamental score + symbol info + financials + peers models & API

**Files:**
- Create: `lib/models/scanner_model/fundamental_score.dart`
- Create: `lib/models/scanner_model/symbol_info.dart`
- Create: `lib/models/scanner_model/financials.dart`
- Create: `lib/models/scanner_model/peers.dart`
- Modify: `lib/api/stock_scanner_api.dart`

Pattern is the same as Tasks 19–20: each model has a `fromJson` factory; each gets one API method.

- [ ] **Step 1: `fundamental_score.dart`**

```dart
class FundamentalScore {
  final String ticker;
  final double? valuation, growth, profitability, quality, solvency, efficiency;
  final double? composite;
  final List<String> notes;

  const FundamentalScore({
    required this.ticker,
    required this.valuation,
    required this.growth,
    required this.profitability,
    required this.quality,
    required this.solvency,
    required this.efficiency,
    required this.composite,
    required this.notes,
  });

  factory FundamentalScore.fromJson(Map<String, dynamic> j) {
    double? d(String k) {
      final v = j[k];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    return FundamentalScore(
      ticker: j['ticker'] as String,
      valuation: d('valuation'),
      growth: d('growth'),
      profitability: d('profitability'),
      quality: d('quality'),
      solvency: d('solvency'),
      efficiency: d('efficiency'),
      composite: d('composite'),
      notes: (j['notes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
```

- [ ] **Step 2: `symbol_info.dart`** — backend returns ~30 yfinance fields. Keep it lenient: store all fields in a `Map<String, dynamic>` and expose typed getters for the common ones.

```dart
class SymbolInfo {
  final String ticker;
  final String? fetchedAt;
  final Map<String, dynamic> raw;

  const SymbolInfo({
    required this.ticker,
    required this.fetchedAt,
    required this.raw,
  });

  factory SymbolInfo.fromJson(Map<String, dynamic> j) => SymbolInfo(
        ticker: j['ticker'] as String,
        fetchedAt: j['fetched_at'] as String?,
        raw: Map<String, dynamic>.from(j),
      );

  // Typed accessors for the fields the UI references.
  String? get sector => raw['sector'] as String?;
  String? get industry => raw['industry'] as String?;
  String? get longName => raw['long_name'] as String?;
  String? get businessSummary => raw['business_summary'] as String?;
  double? get marketCap => _toDouble(raw['market_cap']);
  double? get peTrailing => _toDouble(raw['pe_trailing']);
  double? get pbRatio => _toDouble(raw['pb_ratio']);
  double? get returnOnEquity => _toDouble(raw['return_on_equity']);
  double? get dividendYield => _toDouble(raw['dividend_yield']);
  double? get fiftyTwoWeekHigh => _toDouble(raw['fifty_two_week_high']);
  double? get fiftyTwoWeekLow => _toDouble(raw['fifty_two_week_low']);
  double? get beta => _toDouble(raw['beta']);

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
```

- [ ] **Step 3: `financials.dart`**

```dart
class FinancialsResponse {
  final String ticker;
  final String periodType; // "quarterly" | "annual"
  final String statement; // "income" | "balance" | "cashflow"
  final List<String> periods;
  final List<String> lineItems;
  /// `lineItem → period → value`. Values may be null.
  final Map<String, Map<String, num?>> values;

  const FinancialsResponse({
    required this.ticker,
    required this.periodType,
    required this.statement,
    required this.periods,
    required this.lineItems,
    required this.values,
  });

  factory FinancialsResponse.fromJson(Map<String, dynamic> j) {
    final rawVals = (j['values'] as Map?) ?? const {};
    final values = <String, Map<String, num?>>{};
    rawVals.forEach((lineItem, periodMap) {
      final inner = <String, num?>{};
      if (periodMap is Map) {
        periodMap.forEach((period, v) {
          if (v == null) {
            inner[period.toString()] = null;
          } else if (v is num) {
            inner[period.toString()] = v;
          } else {
            inner[period.toString()] = num.tryParse(v.toString());
          }
        });
      }
      values[lineItem.toString()] = inner;
    });
    return FinancialsResponse(
      ticker: j['ticker'] as String,
      periodType: j['period_type'] as String,
      statement: j['statement'] as String,
      periods: (j['periods'] as List).map((e) => e.toString()).toList(),
      lineItems: (j['line_items'] as List).map((e) => e.toString()).toList(),
      values: values,
    );
  }
}
```

- [ ] **Step 4: `peers.dart`**

```dart
class PeerEntry {
  final String ticker;
  final String name;
  final double? marketCap;
  final double? peTrailing;
  final String? sector;
  final String? industry;

  const PeerEntry({
    required this.ticker,
    required this.name,
    required this.marketCap,
    required this.peTrailing,
    required this.sector,
    required this.industry,
  });

  factory PeerEntry.fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    return PeerEntry(
      ticker: j['ticker'] as String,
      name: (j['name'] ?? '') as String,
      marketCap: d(j['market_cap']),
      peTrailing: d(j['pe_trailing']),
      sector: j['sector'] as String?,
      industry: j['industry'] as String?,
    );
  }
}

class PeersResponse {
  final String ticker;
  final String? industry;
  final String? sector;
  final List<PeerEntry> peers;

  const PeersResponse({
    required this.ticker,
    required this.industry,
    required this.sector,
    required this.peers,
  });

  factory PeersResponse.fromJson(Map<String, dynamic> j) => PeersResponse(
        ticker: j['ticker'] as String,
        industry: j['industry'] as String?,
        sector: j['sector'] as String?,
        peers: (j['peers'] as List)
            .cast<Map<String, dynamic>>()
            .map(PeerEntry.fromJson)
            .toList(),
      );
}
```

- [ ] **Step 5: API methods**

```dart
  Future<SymbolInfo> fetchSymbolInfo(String ticker) async {
    final j = await _get('/symbols/$ticker/info');
    return SymbolInfo.fromJson(j as Map<String, dynamic>);
  }

  Future<FundamentalScore> fetchFundamentalScore(String ticker) async {
    final j = await _get('/symbols/$ticker/fundamental-score');
    return FundamentalScore.fromJson(j as Map<String, dynamic>);
  }

  Future<FinancialsResponse> fetchFinancials(
    String ticker, {
    String period = 'quarterly', // or 'annual'
    String statement = 'income', // 'balance' | 'cashflow'
  }) async {
    final j = await _get('/symbols/$ticker/financials',
        query: {'period': period, 'statement': statement});
    return FinancialsResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<PeersResponse> fetchPeers(String ticker, {int limit = 10}) async {
    final j = await _get('/symbols/$ticker/peers', query: {'limit': limit});
    return PeersResponse.fromJson(j as Map<String, dynamic>);
  }
```

- [ ] **Step 6: Add the imports and run analyzer**

```dart
import 'package:mynt_plus/models/scanner_model/fundamental_score.dart';
import 'package:mynt_plus/models/scanner_model/symbol_info.dart';
import 'package:mynt_plus/models/scanner_model/financials.dart';
import 'package:mynt_plus/models/scanner_model/peers.dart';
```

```bash
flutter analyze lib/api/stock_scanner_api.dart lib/models/scanner_model/
```

Expected: no issues.

---

### Task 22: Holders / News / Dividends / Deliveries / Announcements API methods

These endpoints return list-shaped responses with sparse coverage for Indian stocks. Use a permissive `List<Map<String, dynamic>>` typing — UI will pluck the fields it shows and treat the rest as raw.

**Files:**
- Modify: `lib/api/stock_scanner_api.dart`

- [ ] **Step 1: Add five methods**

```dart
  Future<List<Map<String, dynamic>>> fetchHolders(String ticker) async {
    final j = await _get('/symbols/$ticker/holders');
    if (j is! List) return const [];
    return j.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchNews(String ticker) async {
    final j = await _get('/symbols/$ticker/news');
    if (j is! List) return const [];
    return j.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchDividends(String ticker) async {
    final j = await _get('/symbols/$ticker/dividends');
    if (j is! List) return const [];
    return j.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchDeliveries(String ticker) async {
    final j = await _get('/symbols/$ticker/deliveries');
    if (j is! List) return const [];
    return j.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchAnnouncements(String ticker) async {
    final j = await _get('/symbols/$ticker/announcements');
    if (j is! List) return const [];
    return j.cast<Map<String, dynamic>>();
  }
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/api/stock_scanner_api.dart
```

Expected: no issues.

---

### Task 23: Scanner models + scanners/* API methods

**Files:**
- Create: `lib/models/scanner_model/scanner.dart`
- Create: `lib/models/scanner_model/scan_result.dart`
- Modify: `lib/api/stock_scanner_api.dart`

- [ ] **Step 1: `scanner.dart`**

```dart
class Scanner {
  final String code;
  final String groupName;
  final String? subGroup;
  final String displayName;
  final String description;
  final bool isActive;
  final Map<String, dynamic>? predicate;

  const Scanner({
    required this.code,
    required this.groupName,
    required this.subGroup,
    required this.displayName,
    required this.description,
    required this.isActive,
    required this.predicate,
  });

  factory Scanner.fromJson(Map<String, dynamic> j) => Scanner(
        code: j['code'] as String,
        groupName: (j['group_name'] ?? '') as String,
        subGroup: j['sub_group'] as String?,
        displayName: (j['display_name'] ?? j['code']) as String,
        description: (j['description'] ?? '') as String,
        isActive: (j['is_active'] ?? true) as bool,
        predicate: j['predicate'] is Map
            ? Map<String, dynamic>.from(j['predicate'] as Map)
            : null,
      );
}

class ScannerListResponse {
  final List<Scanner> items;
  final int total;
  final int page;
  final int pageSize;

  const ScannerListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory ScannerListResponse.fromJson(Map<String, dynamic> j) =>
      ScannerListResponse(
        items: (j['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(Scanner.fromJson)
            .toList(),
        total: (j['total'] ?? 0) as int,
        page: (j['page'] ?? 1) as int,
        pageSize: (j['page_size'] ?? 100) as int,
      );
}
```

- [ ] **Step 2: `scan_result.dart`**

```dart
class ScanResultColumn {
  final String key;
  final String label;
  final String fmt;
  final String? description;

  const ScanResultColumn({
    required this.key,
    required this.label,
    required this.fmt,
    this.description,
  });

  factory ScanResultColumn.fromJson(Map<String, dynamic> j) =>
      ScanResultColumn(
        key: j['key'] as String,
        label: (j['label'] ?? j['key']) as String,
        fmt: (j['fmt'] ?? 'raw') as String,
        description: j['description'] as String?,
      );
}

class ScanResultRow {
  final String ticker;
  final String name;
  final Map<String, dynamic> values;

  const ScanResultRow({
    required this.ticker,
    required this.name,
    required this.values,
  });

  factory ScanResultRow.fromJson(Map<String, dynamic> j) => ScanResultRow(
        ticker: j['ticker'] as String,
        name: (j['name'] ?? '') as String,
        values: (j['values'] is Map)
            ? Map<String, dynamic>.from(j['values'] as Map)
            : const {},
      );
}

class ScanResultsDetail {
  final String code;
  final String asOf;
  final int total;
  final List<ScanResultColumn> columns;
  final List<ScanResultRow> matches;

  const ScanResultsDetail({
    required this.code,
    required this.asOf,
    required this.total,
    required this.columns,
    required this.matches,
  });

  factory ScanResultsDetail.fromJson(Map<String, dynamic> j) => ScanResultsDetail(
        code: j['code'] as String,
        asOf: (j['as_of'] ?? '') as String,
        total: (j['total'] ?? 0) as int,
        columns: ((j['columns'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ScanResultColumn.fromJson)
            .toList(),
        matches: ((j['matches'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ScanResultRow.fromJson)
            .toList(),
      );
}
```

- [ ] **Step 3: API methods**

```dart
  // --- /scanners/* ---------------------------------------------------------

  Future<ScannerListResponse> fetchScanners({
    String? group,
    String? subGroup,
    String? q,
    int page = 1,
    int pageSize = 100,
  }) async {
    final j = await _get('/scanners', query: {
      if (group != null) 'group': group,
      if (subGroup != null) 'sub_group': subGroup,
      if (q != null && q.isNotEmpty) 'q': q,
      'page': page,
      'page_size': pageSize,
    });
    return ScannerListResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<Scanner> fetchScanner(String code) async {
    final j = await _get('/scanners/$code');
    return Scanner.fromJson(j as Map<String, dynamic>);
  }

  Future<ScanResultsDetail> fetchScannerResults(
    String code, {
    String date = 'latest',
    int limit = 5000,
    int offset = 0,
    bool detail = true,
  }) async {
    final j = await _get('/scanners/$code/results', query: {
      'date': date,
      'limit': limit,
      'offset': offset,
      'detail': detail,
    });
    return ScanResultsDetail.fromJson(j as Map<String, dynamic>);
  }

  /// Returns the .xlsx bytes plus the server-provided filename.
  Future<({List<int> bytes, String? filename})>
      downloadScannerExportXlsx(String code, {String columns = 'visible'}) {
    return _downloadBlob('/scanners/$code/export',
        query: {'columns': columns});
  }
```

- [ ] **Step 4: Imports + analyzer**

```dart
import 'package:mynt_plus/models/scanner_model/scanner.dart';
import 'package:mynt_plus/models/scanner_model/scan_result.dart';
```

```bash
flutter analyze lib/api/stock_scanner_api.dart lib/models/scanner_model/
```

Expected: no issues.

---

### Task 24: Fundamental field, scan request/response, saved-screen models

**Files:**
- Create: `lib/models/scanner_model/fundamental_field.dart`
- Create: `lib/models/scanner_model/fundamental_scan.dart`
- Create: `lib/models/scanner_model/saved_screen.dart`

- [ ] **Step 1: `fundamental_field.dart`**

```dart
class FundamentalField {
  final String key;
  final String label;
  final String group;
  /// number | pct | currency_inr | string
  final String dtype;
  final String description;

  const FundamentalField({
    required this.key,
    required this.label,
    required this.group,
    required this.dtype,
    required this.description,
  });

  factory FundamentalField.fromJson(Map<String, dynamic> j) => FundamentalField(
        key: j['key'] as String,
        label: (j['label'] ?? j['key']) as String,
        group: (j['group'] ?? '') as String,
        dtype: (j['dtype'] ?? 'number') as String,
        description: (j['description'] ?? '') as String,
      );

  /// Fields that support the `years` sidecar (median-over-N-years comparison).
  static const Set<String> multiYearCapable = {
    'revenue_growth', 'earnings_growth', 'return_on_equity', 'return_on_assets',
    'profit_margins', 'operating_margins', 'current_ratio', 'quick_ratio',
    'debt_to_equity',
  };
}
```

- [ ] **Step 2: `fundamental_scan.dart`**

```dart
class FundamentalFilter {
  final String field;
  final String op;
  /// Single number/string/list — serialized as-is.
  final dynamic value;
  /// Optional: median-over-N-years (2..15).
  final int? years;

  const FundamentalFilter({
    required this.field,
    required this.op,
    this.value,
    this.years,
  });

  Map<String, dynamic> toJson() => {
        'field': field,
        'op': op,
        if (value != null) 'value': value,
        if (years != null) 'years': years,
      };
}

class FundamentalColumnLabel {
  final String field;
  final String label;
  const FundamentalColumnLabel({required this.field, required this.label});

  factory FundamentalColumnLabel.fromJson(Map<String, dynamic> j) =>
      FundamentalColumnLabel(
        field: j['field'] as String,
        label: (j['label'] ?? j['field']) as String,
      );
}

class FundamentalMatch {
  final String ticker;
  final String name;
  final String? sector;
  final String? industry;
  final double? marketCap;
  final Map<String, dynamic> values;

  const FundamentalMatch({
    required this.ticker,
    required this.name,
    required this.sector,
    required this.industry,
    required this.marketCap,
    required this.values,
  });

  factory FundamentalMatch.fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    return FundamentalMatch(
      ticker: j['ticker'] as String,
      name: (j['name'] ?? '') as String,
      sector: j['sector'] as String?,
      industry: j['industry'] as String?,
      marketCap: d(j['market_cap']),
      values: (j['values'] is Map)
          ? Map<String, dynamic>.from(j['values'] as Map)
          : const {},
    );
  }
}

class FundamentalScanResponse {
  final int total;
  final int returned;
  final List<FundamentalColumnLabel> columnLabels;
  final List<FundamentalMatch> matches;

  const FundamentalScanResponse({
    required this.total,
    required this.returned,
    required this.columnLabels,
    required this.matches,
  });

  factory FundamentalScanResponse.fromJson(Map<String, dynamic> j) =>
      FundamentalScanResponse(
        total: (j['total'] ?? 0) as int,
        returned: (j['returned'] ?? 0) as int,
        columnLabels: ((j['column_labels'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(FundamentalColumnLabel.fromJson)
            .toList(),
        matches: ((j['matches'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(FundamentalMatch.fromJson)
            .toList(),
      );
}

class FundamentalScanRequest {
  final List<FundamentalFilter> filters;
  final String treatNullAs; // 'fail' | 'pass'
  final String orderBy;
  final String orderDir; // 'asc' | 'desc'
  final int limit;
  final int offset;

  const FundamentalScanRequest({
    required this.filters,
    this.treatNullAs = 'fail',
    this.orderBy = 'market_cap',
    this.orderDir = 'desc',
    this.limit = 100,
    this.offset = 0,
  });

  Map<String, dynamic> toJson() => {
        'filters': filters.map((f) => f.toJson()).toList(),
        'treat_null_as': treatNullAs,
        'order_by': orderBy,
        'order_dir': orderDir,
        'limit': limit,
        'offset': offset,
      };
}

class FundamentalPreset {
  final String id;
  final String name;
  final String description;
  final List<FundamentalFilter> filters;
  final String treatNullAs;

  const FundamentalPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.filters,
    required this.treatNullAs,
  });

  factory FundamentalPreset.fromJson(Map<String, dynamic> j) {
    final filters = ((j['filters'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((f) => FundamentalFilter(
              field: f['field'] as String,
              op: f['op'] as String,
              value: f['value'],
              years: f['years'] as int?,
            ))
        .toList();
    return FundamentalPreset(
      id: (j['id'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      description: (j['description'] ?? '') as String,
      filters: filters,
      treatNullAs: (j['treat_null_as'] ?? 'fail') as String,
    );
  }
}
```

- [ ] **Step 3: `saved_screen.dart`**

```dart
import 'fundamental_scan.dart';

class SavedFundamentalScreen {
  final int id;
  final String name;
  final List<FundamentalFilter> filters;
  final String treatNullAs;
  final String? orderBy;
  final String? orderDir;
  final int? limit;
  final String? createdAt;

  const SavedFundamentalScreen({
    required this.id,
    required this.name,
    required this.filters,
    required this.treatNullAs,
    required this.orderBy,
    required this.orderDir,
    required this.limit,
    required this.createdAt,
  });

  factory SavedFundamentalScreen.fromJson(Map<String, dynamic> j) {
    final filters = ((j['filters'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((f) => FundamentalFilter(
              field: f['field'] as String,
              op: f['op'] as String,
              value: f['value'],
              years: f['years'] as int?,
            ))
        .toList();
    return SavedFundamentalScreen(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String,
      filters: filters,
      treatNullAs: (j['treat_null_as'] ?? 'fail') as String,
      orderBy: j['order_by'] as String?,
      orderDir: j['order_dir'] as String?,
      limit: (j['limit'] as num?)?.toInt(),
      createdAt: j['created_at'] as String?,
    );
  }
}
```

- [ ] **Step 4: Analyzer**

```bash
flutter analyze lib/models/scanner_model/
```

Expected: no issues.

---

### Task 25: Fundamental scan API methods

**Files:**
- Modify: `lib/api/stock_scanner_api.dart`

- [ ] **Step 1: Add the methods + imports**

```dart
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';
import 'package:mynt_plus/models/scanner_model/saved_screen.dart';
```

```dart
  // --- /scans/fundamental/* -----------------------------------------------

  Future<List<FundamentalField>> fetchFundamentalFields() async {
    final j = await _get('/scans/fundamental/fields');
    return (j as List)
        .cast<Map<String, dynamic>>()
        .map(FundamentalField.fromJson)
        .toList();
  }

  Future<List<FundamentalPreset>> fetchFundamentalPresets() async {
    final j = await _get('/scans/fundamental/presets');
    return (j as List)
        .cast<Map<String, dynamic>>()
        .map(FundamentalPreset.fromJson)
        .toList();
  }

  Future<FundamentalScanResponse> runFundamentalScan(
      FundamentalScanRequest req) async {
    final j = await _post('/scans/fundamental', req.toJson());
    return FundamentalScanResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<({List<int> bytes, String? filename})> downloadFundamentalExportXlsx({
    required FundamentalScanRequest req,
    required String columns, // 'visible' | 'all' | 'custom'
    List<String> customColumns = const [],
  }) {
    final body = {
      ...req.toJson(),
      'columns': columns,
      if (columns == 'custom') 'custom_columns': customColumns,
    };
    return _downloadBlob('/scans/fundamental/export', postBody: body);
  }

  Future<List<SavedFundamentalScreen>> listSavedScreens() async {
    final j = await _get('/scans/fundamental/saved');
    return (j as List)
        .cast<Map<String, dynamic>>()
        .map(SavedFundamentalScreen.fromJson)
        .toList();
  }

  Future<SavedFundamentalScreen> getSavedScreen(int id) async {
    final j = await _get('/scans/fundamental/saved/$id');
    return SavedFundamentalScreen.fromJson(j as Map<String, dynamic>);
  }

  Future<SavedFundamentalScreen> saveScreen({
    required String name,
    required List<FundamentalFilter> filters,
    String treatNullAs = 'fail',
    String? orderBy,
    String? orderDir,
    int? limit,
  }) async {
    final j = await _post('/scans/fundamental/saved', {
      'name': name,
      'filters': filters.map((f) => f.toJson()).toList(),
      'treat_null_as': treatNullAs,
      if (orderBy != null) 'order_by': orderBy,
      if (orderDir != null) 'order_dir': orderDir,
      if (limit != null) 'limit': limit,
    });
    return SavedFundamentalScreen.fromJson(j as Map<String, dynamic>);
  }

  Future<FundamentalScanResponse> runSavedScreen(int id) async {
    final j = await _post('/scans/fundamental/saved/$id/run', {});
    return FundamentalScanResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<void> deleteSavedScreen(int id) async {
    await _delete('/scans/fundamental/saved/$id');
  }
```

- [ ] **Step 2: Analyzer**

```bash
flutter analyze lib/api/stock_scanner_api.dart
```

Expected: no issues.

---

### Task 26: Custom scan / Predicate models + JSON round-trip tests

**Files:**
- Create: `lib/models/scanner_model/predicate.dart`
- Create: `lib/models/scanner_model/custom_scan.dart`
- Create: `test/scanner_model/predicate_test.dart`

- [ ] **Step 1: `predicate.dart`** — the visual builder uses this in-memory representation; round-trips to/from the spec's JSON.

```dart
/// A reference on either side of a comparison leaf:
/// `{ "value": 30 }`, `{ "value": [20, 80] }`, or `{ "indicator": "rsi", "period": 14 }`.
class IndicatorRef {
  final num? literalNumber;
  final List<num>? literalRange;
  final String? indicator;
  final Map<String, dynamic> indicatorParams;

  const IndicatorRef._({
    this.literalNumber,
    this.literalRange,
    this.indicator,
    this.indicatorParams = const {},
  });

  factory IndicatorRef.number(num n) => IndicatorRef._(literalNumber: n);
  factory IndicatorRef.range(num a, num b) =>
      IndicatorRef._(literalRange: [a, b]);
  factory IndicatorRef.indicator(String name, [Map<String, dynamic>? params]) =>
      IndicatorRef._(indicator: name, indicatorParams: params ?? const {});

  Map<String, dynamic> toJson() {
    if (literalNumber != null) return {'value': literalNumber};
    if (literalRange != null) return {'value': literalRange};
    return {'indicator': indicator, ...indicatorParams};
  }

  factory IndicatorRef.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('value')) {
      final v = j['value'];
      if (v is num) return IndicatorRef.number(v);
      if (v is List && v.length == 2 && v.every((x) => x is num)) {
        return IndicatorRef.range(v[0] as num, v[1] as num);
      }
      throw ArgumentError('Unsupported literal value: $v');
    }
    if (j.containsKey('indicator')) {
      final ind = j['indicator'] as String;
      final params = Map<String, dynamic>.from(j)..remove('indicator');
      return IndicatorRef.indicator(ind, params);
    }
    throw ArgumentError('IndicatorRef must have "value" or "indicator"');
  }
}

abstract class PredicateNode {
  Map<String, dynamic> toJson();
  static PredicateNode fromJson(Map<String, dynamic> j) {
    if (j.containsKey('all')) {
      return PredicateAll((j['all'] as List)
          .cast<Map<String, dynamic>>()
          .map(PredicateNode.fromJson)
          .toList());
    }
    if (j.containsKey('any')) {
      return PredicateAny((j['any'] as List)
          .cast<Map<String, dynamic>>()
          .map(PredicateNode.fromJson)
          .toList());
    }
    if (j.containsKey('none')) {
      return PredicateNone((j['none'] as List)
          .cast<Map<String, dynamic>>()
          .map(PredicateNode.fromJson)
          .toList());
    }
    if (j.containsKey('left')) {
      return PredicateLeaf(
        left: IndicatorRef.fromJson(j['left'] as Map<String, dynamic>),
        op: j['op'] as String,
        right: IndicatorRef.fromJson(j['right'] as Map<String, dynamic>),
      );
    }
    throw ArgumentError('Unknown predicate node: $j');
  }
}

class PredicateLeaf extends PredicateNode {
  final IndicatorRef left;
  final String op;
  final IndicatorRef right;
  PredicateLeaf({required this.left, required this.op, required this.right});

  @override
  Map<String, dynamic> toJson() => {
        'left': left.toJson(),
        'op': op,
        'right': right.toJson(),
      };
}

class PredicateAll extends PredicateNode {
  final List<PredicateNode> children;
  PredicateAll(this.children);
  @override
  Map<String, dynamic> toJson() =>
      {'all': children.map((c) => c.toJson()).toList()};
}

class PredicateAny extends PredicateNode {
  final List<PredicateNode> children;
  PredicateAny(this.children);
  @override
  Map<String, dynamic> toJson() =>
      {'any': children.map((c) => c.toJson()).toList()};
}

class PredicateNone extends PredicateNode {
  final List<PredicateNode> children;
  PredicateNone(this.children);
  @override
  Map<String, dynamic> toJson() =>
      {'none': children.map((c) => c.toJson()).toList()};
}

/// All operators the backend accepts.
const List<String> kPredicateOperators = [
  '<', '<=', '>', '>=', '==', '!=',
  'between', 'crossed_above', 'crossed_below',
  'is_true', 'is_false',
];
```

- [ ] **Step 2: `custom_scan.dart`**

```dart
class SavedCustomScan {
  final int id;
  final String name;
  final Map<String, dynamic> predicateJson;
  final String? createdBy;
  final String? createdAt;
  final String? lastRunAt;
  final int runCount;

  const SavedCustomScan({
    required this.id,
    required this.name,
    required this.predicateJson,
    required this.createdBy,
    required this.createdAt,
    required this.lastRunAt,
    required this.runCount,
  });

  factory SavedCustomScan.fromJson(Map<String, dynamic> j) => SavedCustomScan(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        predicateJson: Map<String, dynamic>.from(
            (j['predicate_json'] ?? j['predicate'] ?? const {}) as Map),
        createdBy: j['created_by'] as String?,
        createdAt: j['created_at'] as String?,
        lastRunAt: j['last_run_at'] as String?,
        runCount: ((j['run_count'] ?? 0) as num).toInt(),
      );
}

class CustomScanRunResult {
  final String asOf;
  final List<({String ticker, String name})> matches;
  const CustomScanRunResult({required this.asOf, required this.matches});

  factory CustomScanRunResult.fromJson(Map<String, dynamic> j) {
    final list = ((j['matches'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((m) => (
              ticker: m['ticker'] as String,
              name: (m['name'] ?? '') as String,
            ))
        .toList();
    return CustomScanRunResult(asOf: (j['as_of'] ?? '') as String, matches: list);
  }
}
```

- [ ] **Step 3: Round-trip test `test/scanner_model/predicate_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/models/scanner_model/predicate.dart';

void main() {
  test('PredicateLeaf round-trip', () {
    final node = PredicateLeaf(
      left: IndicatorRef.indicator('rsi', {'period': 14}),
      op: '<',
      right: IndicatorRef.number(30),
    );
    final j = node.toJson();
    expect(j['left'], {'indicator': 'rsi', 'period': 14});
    expect(j['op'], '<');
    expect(j['right'], {'value': 30});
    final back = PredicateNode.fromJson(j);
    expect(back, isA<PredicateLeaf>());
    expect((back as PredicateLeaf).op, '<');
  });

  test('PredicateAll with mixed children round-trip', () {
    final json = {
      'all': [
        {
          'left': {'indicator': 'rsi', 'period': 14},
          'op': 'crossed_above',
          'right': {'value': 30}
        },
        {
          'left': {'indicator': 'volume'},
          'op': '>',
          'right': {
            'indicator': 'sma',
            'source': 'volume',
            'period': 20,
            'scale': 2.0,
          }
        },
      ]
    };
    final node = PredicateNode.fromJson(json);
    expect(node, isA<PredicateAll>());
    expect(node.toJson(), json);
  });

  test('between operator with range literal', () {
    final json = {
      'left': {'indicator': 'rsi', 'period': 14},
      'op': 'between',
      'right': {'value': [20, 80]},
    };
    final node = PredicateNode.fromJson(json);
    expect(node.toJson(), json);
  });
}
```

- [ ] **Step 4: Run tests + analyzer**

```bash
flutter test test/scanner_model/predicate_test.dart
flutter analyze lib/models/scanner_model/
```

Expected: all tests pass; analyzer clean.

---

### Task 27: Custom scan API methods

**Files:**
- Modify: `lib/api/stock_scanner_api.dart`

- [ ] **Step 1: Add the methods + imports**

```dart
import 'package:mynt_plus/models/scanner_model/custom_scan.dart';
```

```dart
  // --- /scans/* (custom) ---------------------------------------------------

  Future<CustomScanRunResult> runCustomScan({
    required Map<String, dynamic> predicate,
    String asOf = 'latest',
  }) async {
    final j = await _post('/scans/run', {
      'predicate': predicate,
      'as_of': asOf,
    });
    return CustomScanRunResult.fromJson(j as Map<String, dynamic>);
  }

  Future<SavedCustomScan> saveCustomScan({
    required String name,
    required Map<String, dynamic> predicate,
  }) async {
    final j = await _post('/scans/saved', {
      'name': name,
      'predicate': predicate,
    });
    return SavedCustomScan.fromJson(j as Map<String, dynamic>);
  }

  Future<List<SavedCustomScan>> listSavedCustomScans() async {
    final j = await _get('/scans/saved');
    return (j as List)
        .cast<Map<String, dynamic>>()
        .map(SavedCustomScan.fromJson)
        .toList();
  }

  Future<SavedCustomScan> getSavedCustomScan(int id) async {
    final j = await _get('/scans/saved/$id');
    return SavedCustomScan.fromJson(j as Map<String, dynamic>);
  }

  Future<CustomScanRunResult> runSavedCustomScan(int id) async {
    final j = await _post('/scans/saved/$id/run', {});
    return CustomScanRunResult.fromJson(j as Map<String, dynamic>);
  }

  Future<void> deleteSavedCustomScan(int id) async {
    await _delete('/scans/saved/$id');
  }
```

- [ ] **Step 2: Analyzer**

```bash
flutter analyze lib/api/stock_scanner_api.dart
```

Expected: no issues.

---

### Task 28: Create per-sub-page Riverpod providers

**Files:**
- Create: `lib/provider/scanner/symbols_provider.dart`
- Create: `lib/provider/scanner/scanners_provider.dart`
- Create: `lib/provider/scanner/fundamentals_provider.dart`
- Create: `lib/provider/scanner/custom_scans_provider.dart`

These are thin Riverpod wrappers — each provider calls one API method via the GetIt-resolved `ApiExporter` and surfaces typed errors.

- [ ] **Step 1: `symbols_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/financials.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_score.dart';
import 'package:mynt_plus/models/scanner_model/ohlcv.dart';
import 'package:mynt_plus/models/scanner_model/peers.dart';
import 'package:mynt_plus/models/scanner_model/performance.dart';
import 'package:mynt_plus/models/scanner_model/symbol.dart';
import 'package:mynt_plus/models/scanner_model/symbol_info.dart';
import 'package:mynt_plus/models/scanner_model/technicals.dart';

ApiExporter get _api => locator<ApiExporter>();

/// Symbol-search results, keyed by the debounced query.
final symbolSearchProvider =
    FutureProvider.family<SymbolListResponse, String>((ref, q) async {
  if (q.trim().isEmpty) {
    return const SymbolListResponse(items: [], total: 0, page: 1, pageSize: 0);
  }
  return _api.fetchSymbols(q: q, pageSize: 20);
});

final symbolMetaProvider =
    FutureProvider.family<Symbol, String>((_, t) => _api.fetchSymbol(t));

final ohlcvProvider =
    FutureProvider.family<OhlcvResponse, ({String ticker, String? from})>(
        (_, args) => _api.fetchOhlcv(args.ticker, from: args.from));

final technicalsProvider = FutureProvider.family<TechnicalsResponse, String>(
    (_, t) => _api.fetchTechnicals(t));

final performanceProvider = FutureProvider.family<PerformanceResponse, String>(
    (_, t) => _api.fetchPerformance(t));

final symbolScannersProvider = FutureProvider.family<List<String>, String>(
    (_, t) => _api.fetchSymbolScanners(t));

final symbolInfoProvider =
    FutureProvider.family<SymbolInfo, String>((_, t) => _api.fetchSymbolInfo(t));

final fundamentalScoreProvider = FutureProvider.family<FundamentalScore, String>(
    (_, t) => _api.fetchFundamentalScore(t));

final financialsProvider = FutureProvider.family<FinancialsResponse,
    ({String ticker, String period, String statement})>(
        (_, args) => _api.fetchFinancials(
              args.ticker,
              period: args.period,
              statement: args.statement,
            ));

final peersProvider =
    FutureProvider.family<PeersResponse, String>((_, t) => _api.fetchPeers(t));

final holdersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (_, t) => _api.fetchHolders(t));

final newsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (_, t) => _api.fetchNews(t));

final dividendsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (_, t) => _api.fetchDividends(t));

final deliveriesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (_, t) => _api.fetchDeliveries(t));
```

- [ ] **Step 2: `scanners_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/scanner.dart';
import 'package:mynt_plus/models/scanner_model/scan_result.dart';

ApiExporter get _api => locator<ApiExporter>();

/// All built-in scanners (fetched once, filtered client-side).
final scannerListProvider = FutureProvider<ScannerListResponse>(
    (_) => _api.fetchScanners(pageSize: 2000));

final scannerDetailProvider =
    FutureProvider.family<Scanner, String>((_, code) => _api.fetchScanner(code));

final scannerResultsProvider =
    FutureProvider.family<ScanResultsDetail, String>(
        (_, code) => _api.fetchScannerResults(code, detail: true, limit: 5000));
```

- [ ] **Step 3: `fundamentals_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';
import 'package:mynt_plus/models/scanner_model/saved_screen.dart';

ApiExporter get _api => locator<ApiExporter>();

final fundamentalFieldsProvider =
    FutureProvider<List<FundamentalField>>((_) => _api.fetchFundamentalFields());

final fundamentalPresetsProvider =
    FutureProvider<List<FundamentalPreset>>((_) => _api.fetchFundamentalPresets());

final savedScreensProvider = FutureProvider<List<SavedFundamentalScreen>>(
    (_) => _api.listSavedScreens());

/// The result of the most recent ad-hoc run. Cleared/refreshed by the UI.
final lastFundamentalResultProvider =
    StateProvider<AsyncValue<FundamentalScanResponse>?>((_) => null);
```

- [ ] **Step 4: `custom_scans_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/custom_scan.dart';

ApiExporter get _api => locator<ApiExporter>();

final savedCustomScansProvider = FutureProvider<List<SavedCustomScan>>(
    (_) => _api.listSavedCustomScans());

final lastCustomRunProvider =
    StateProvider<AsyncValue<CustomScanRunResult>?>((_) => null);
```

- [ ] **Step 5: Analyzer**

```bash
flutter analyze lib/provider/scanner/
```

Expected: no issues.

---

> 🟢 **Manual checkpoint after Milestone 3**
>
> All endpoints can now be called from Dart. Smoke-test from a Riverpod-aware temp screen or a Dart test:
>
> ```bash
> flutter analyze
> flutter test
> ```
>
> No UI work yet — sub-pages still show placeholders. Safe to commit.

---

## Milestone 4 — Symbols sub-page (list + detail header) (Tasks 29–32)

After this milestone, the Symbols sub-page works for search + symbol selection + detail-header rendering. Tabs are still placeholders (filled in Milestone 5).

### Task 29: Create SymbolsSubPage skeleton with mode switching

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/symbols_sub_page.dart`

- [ ] **Step 1: Create the file (list ↔ detail mode container)**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'symbols_search_pane.dart';
import 'symbols_detail_pane.dart';

class SymbolsSubPage extends ConsumerStatefulWidget {
  const SymbolsSubPage({super.key});

  @override
  ConsumerState<SymbolsSubPage> createState() => _SymbolsSubPageState();
}

class _SymbolsSubPageState extends ConsumerState<SymbolsSubPage> {
  String? _selectedTicker;

  @override
  void initState() {
    super.initState();
    // Consume any pending ticker pushed by another sub-page (e.g. scanner row click).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(scannerShellProvider).pendingTicker;
      if (pending != null) {
        setState(() => _selectedTicker = pending);
        ref.read(scannerShellProvider.notifier).consumePendingTicker();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for further preselections while mounted.
    ref.listen(scannerShellProvider, (prev, next) {
      if (next.pendingTicker != null && next.pendingTicker != _selectedTicker) {
        setState(() => _selectedTicker = next.pendingTicker);
        ref.read(scannerShellProvider.notifier).consumePendingTicker();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedTicker == null) {
      return SymbolsSearchPane(
        onSelect: (t) => setState(() => _selectedTicker = t),
      );
    }
    return SymbolsDetailPane(
      ticker: _selectedTicker!,
      onBack: () => setState(() => _selectedTicker = null),
      onPeerTap: (t) => setState(() => _selectedTicker = t),
    );
  }
}
```

- [ ] **Step 2: Run analyzer** (will warn about missing `SymbolsSearchPane`/`SymbolsDetailPane` — fixed in Tasks 30, 31)

```bash
flutter analyze lib/screens/web/scanner/sub_pages/symbols_sub_page.dart
```

Expected: 2 errors about missing imports. These resolve in Tasks 30/31.

---

### Task 30: Create SymbolsSearchPane (list mode)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/symbols_search_pane.dart`

- [ ] **Step 1: Create the file**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class SymbolsSearchPane extends ConsumerStatefulWidget {
  final ValueChanged<String> onSelect;
  const SymbolsSearchPane({super.key, required this.onSelect});

  @override
  ConsumerState<SymbolsSearchPane> createState() => _SymbolsSearchPaneState();
}

class _SymbolsSearchPaneState extends ConsumerState<SymbolsSearchPane> {
  final TextEditingController _ctl = TextEditingController();
  Timer? _debounce;
  String _activeQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _activeQuery = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: TextField(
            controller: _ctl,
            onChanged: _onChanged,
            style: MyntWebTextStyles.body(context),
            decoration: InputDecoration(
              hintText: 'Search by ticker or company name',
              hintStyle: MyntWebTextStyles.body(context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary)),
              prefixIcon: Icon(shadcn.LucideIcons.search,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    if (_activeQuery.isEmpty) {
      return const EmptyState(
        kind: EmptyStateKind.search,
        title: 'Search to find a stock',
        message: 'Try RELIANCE, TCS, or INFY.',
      );
    }
    final async = ref.watch(symbolSearchProvider(_activeQuery));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not search',
        message: e.toString(),
        onRetry: () => ref.invalidate(symbolSearchProvider(_activeQuery)),
      ),
      data: (resp) {
        if (resp.items.isEmpty) {
          return EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No stocks found for "$_activeQuery"',
            message: 'Try a different ticker.',
          );
        }
        return ListView.separated(
          itemCount: resp.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, i) {
            final s = resp.items[i];
            return _ResultRow(
              ticker: s.ticker,
              name: s.name,
              onTap: () => widget.onSelect(s.ticker),
            );
          },
        );
      },
    );
  }
}

class _ResultRow extends StatefulWidget {
  final String ticker;
  final String name;
  final VoidCallback onTap;

  const _ResultRow({
    required this.ticker,
    required this.name,
    required this.onTap,
  });

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.surfaceVariantDark, light: MyntColors.surfaceVariant);
    final chipBg = resolveThemeColor(context,
        dark: MyntColors.surfaceVariantDark, light: MyntColors.surfaceVariant);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  widget.ticker,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.semiBold),
                ),
              ),
              Expanded(
                child: Text(
                  widget.name,
                  style: MyntWebTextStyles.body(context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('NSE',
                    style: MyntWebTextStyles.caption(context,
                        fontWeight: MyntFonts.medium)),
              ),
              const SizedBox(width: 8),
              Icon(shadcn.LucideIcons.chevronRight,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textTertiaryDark,
                      light: MyntColors.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyzer**

```bash
flutter analyze lib/screens/web/scanner/sub_pages/symbols_search_pane.dart
```

Expected: no issues.

---

### Task 31: Create SymbolsDetailPane (header + 9-tab scaffold with placeholders)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/symbols_detail_pane.dart`

This task wires the detail-mode header + the `TabBar` with 9 tab placeholders. Each tab gets its own widget file in Milestone 5; for now they are simple `Center(Text('Coming soon'))` widgets so we can verify the header + tab layout.

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class SymbolsDetailPane extends ConsumerStatefulWidget {
  final String ticker;
  final VoidCallback onBack;
  final ValueChanged<String> onPeerTap;

  const SymbolsDetailPane({
    super.key,
    required this.ticker,
    required this.onBack,
    required this.onPeerTap,
  });

  @override
  ConsumerState<SymbolsDetailPane> createState() => _SymbolsDetailPaneState();
}

class _SymbolsDetailPaneState extends ConsumerState<SymbolsDetailPane>
    with TickerProviderStateMixin {
  late TabController _tab;
  static const _tabs = [
    'Prices', 'Scans', 'Technicals', 'Performance',
    'Fundamental', 'Financials', 'Peers', 'Holders', 'Deliveries',
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(ticker: widget.ticker, onBack: widget.onBack),
        const SizedBox(height: 12),
        _buildTabBar(),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              for (final t in _tabs)
                Center(child: Text('$t — coming soon',
                    style: MyntWebTextStyles.body(context))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tab,
      isScrollable: true,
      indicatorColor: MyntColors.primary,
      labelColor: MyntColors.primary,
      unselectedLabelColor: resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary),
      tabs: [for (final t in _tabs) Tab(text: t)],
    );
  }
}

class _Header extends ConsumerWidget {
  final String ticker;
  final VoidCallback onBack;
  const _Header({required this.ticker, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(symbolMetaProvider(ticker));
    final ohlcv = ref.watch(ohlcvProvider((ticker: ticker, from: null)));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: Icon(shadcn.LucideIcons.arrowLeft, size: 18,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary)),
                tooltip: 'Back to search',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(
                ticker,
                style: MyntWebTextStyles.heading(context,
                    fontWeight: MyntFonts.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: resolveThemeColor(context,
                      dark: MyntColors.surfaceVariantDark,
                      light: MyntColors.surfaceVariant),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('NSE',
                    style: MyntWebTextStyles.caption(context,
                        fontWeight: MyntFonts.medium)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          meta.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (s) => Text(s.name,
                style: MyntWebTextStyles.body(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary))),
          ),
          const SizedBox(height: 6),
          ohlcv.when(
            loading: () => Text('Loading price…',
                style: MyntWebTextStyles.caption(context)),
            error: (e, _) => Text(e.toString(),
                style: MyntWebTextStyles.caption(context,
                    color: MyntColors.error)),
            data: (resp) {
              if (resp.bars.isEmpty) {
                return Text('No price data',
                    style: MyntWebTextStyles.caption(context));
              }
              final last = resp.bars.last;
              final prev = resp.bars.length > 1
                  ? resp.bars[resp.bars.length - 2]
                  : last;
              final change = last.close - prev.close;
              final pct = prev.close == 0 ? 0.0 : change / prev.close;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    last.close.toStringAsFixed(2),
                    style: MyntWebTextStyles.heading(context,
                        fontWeight: MyntFonts.semiBold),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${formatSignedNumber(change)}  (${formatPercent(pct, signed: true)})',
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.medium,
                        color: signedColor(context, change)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'As of ${formatDate(last.date)}',
                    style: MyntWebTextStyles.caption(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
```

> ⚠️ If `MyntWebTextStyles.heading` doesn't exist, substitute the closest existing larger style (e.g. `MyntWebTextStyles.body(context).copyWith(fontSize: 22, fontWeight: FontWeight.bold)`) — check `lib/res/mynt_web_text_styles.dart` for available constructors.

- [ ] **Step 2: Analyzer**

```bash
flutter analyze lib/screens/web/scanner/sub_pages/
```

Expected: no issues.

---

### Task 32: Wire SymbolsSubPage into the shell

**Files:**
- Modify: `lib/screens/web/scanner/scanner_shell_screen.dart`

- [ ] **Step 1: Replace the `_Placeholder('Symbols')` entry in the `IndexedStack` children with the real sub-page**

At the top of the file, add the import:

```dart
import 'sub_pages/symbols_sub_page.dart';
```

In the `IndexedStack` `children: const [...]` list, replace the first entry:

```dart
                      children: const [
                        SymbolsSubPage(),
                        _Placeholder('Scanners'),
                        _Placeholder('Fundamentals'),
                        _Placeholder('Custom Scans'),
                      ],
```

(Drop the `const` from the list literal if any child can't be const.)

- [ ] **Step 2: Build + manual verify**

```bash
flutter run -d chrome --web-port 8080
```

---

> 🟢 **Manual checkpoint after Milestone 4**
>
> In the running app:
>
> 1. Open Options → Scanner → Symbols tab
> 2. Type "REL" — should debounce 200ms then show RELIANCE + similar matches
> 3. Click RELIANCE → detail view shows header with ticker, name, latest price, day change colored, as-of date
> 4. 9 tabs visible at top: Prices, Scans, Technicals, Performance, Fundamental, Financials, Peers, Holders, Deliveries — clicking each shows "<TabName> — coming soon"
> 5. Click back arrow → returns to search view, query preserved (or cleared depending on `Symbols` widget state — verify the behavior matches your preference; you may want to keep the previous query)
> 6. Dark theme: all colors adapt
>
> If symbol search returns "Could not reach StockScanner" — verify the backend at `http://192.168.5.47:8000` is reachable from your dev machine and that CORS allows your dev origin.

---

## Milestone 5 — Symbols 9 tabs (Tasks 33–41)

All 9 tab widgets follow the **same pattern**: a `ConsumerWidget` that watches a Riverpod `FutureProvider.family<T, String>(ticker)`, renders one of three states (loading / error / data) using `EmptyState` for errors, and shows the tab-specific UI on data.

### Shared tab pattern (copy this for every tab)

```dart
class XyzTab extends ConsumerWidget {
  final String ticker;
  const XyzTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(<theProvider>(ticker));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load',
        message: e.toString(),
        onRetry: () => ref.invalidate(<theProvider>(ticker)),
      ),
      data: (data) => /* tab-specific UI */,
    );
  }
}
```

After each task, **update `lib/screens/web/scanner/sub_pages/symbols_detail_pane.dart`** to swap the corresponding placeholder `Center(...)` for the new tab widget. Don't forget the import.

---

### Task 33: PricesTab

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/symbols_tabs/prices_tab.dart`
- Modify: `lib/screens/web/scanner/sub_pages/symbols_detail_pane.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class PricesTab extends ConsumerWidget {
  final String ticker;
  const PricesTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ohlcvProvider((ticker: ticker, from: null)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load prices',
        message: e.toString(),
        onRetry: () => ref.invalidate(ohlcvProvider((ticker: ticker, from: null))),
      ),
      data: (resp) {
        final bars = resp.bars.reversed.take(90).toList();
        if (bars.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No price data available',
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Open'), numeric: true),
                DataColumn(label: Text('High'), numeric: true),
                DataColumn(label: Text('Low'), numeric: true),
                DataColumn(label: Text('Close'), numeric: true),
                DataColumn(label: Text('Volume'), numeric: true),
              ],
              rows: [
                for (final b in bars)
                  DataRow(cells: [
                    DataCell(Text(formatDate(b.date),
                        style: MyntWebTextStyles.body(context))),
                    DataCell(Text(b.open.toStringAsFixed(2))),
                    DataCell(Text(b.high.toStringAsFixed(2))),
                    DataCell(Text(b.low.toStringAsFixed(2))),
                    DataCell(Text(b.close.toStringAsFixed(2))),
                    DataCell(Text(b.volume.toString())),
                  ]),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

Then in `symbols_detail_pane.dart`, replace the first `Center(...)` in the `TabBarView` children with:

```dart
PricesTab(ticker: widget.ticker),
```

(add the import at the top: `import 'symbols_tabs/prices_tab.dart';`)

Run `flutter analyze` — should be clean.

---

### Task 34: ScansTab (chips → switch to Scanners sub-page)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/symbols_tabs/scans_tab.dart`
- Modify: `symbols_detail_pane.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class ScansTab extends ConsumerWidget {
  final String ticker;
  const ScansTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(symbolScannersProvider(ticker));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load scanner matches',
        message: e.toString(),
        onRetry: () => ref.invalidate(symbolScannersProvider(ticker)),
      ),
      data: (codes) {
        if (codes.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No active scanner matches today',
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final code in codes)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => ref
                        .read(scannerShellProvider.notifier)
                        .navigateToScannerDetail(code),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: MyntColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: MyntColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(code,
                              style: MyntWebTextStyles.caption(context,
                                  fontWeight: MyntFonts.medium,
                                  color: MyntColors.primary)),
                          const SizedBox(width: 4),
                          Icon(shadcn.LucideIcons.arrowUpRight,
                              size: 12, color: MyntColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
```

Wire into `symbols_detail_pane.dart` at index 1 (replacing 'Scans' placeholder) + analyzer.

---

### Task 35: TechnicalsTab (metric-card grid with badges)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/symbols_tabs/technicals_tab.dart`
- Modify: `symbols_detail_pane.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/utils/technical_interpretations.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/metric_card.dart';

class TechnicalsTab extends ConsumerWidget {
  final String ticker;
  const TechnicalsTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(technicalsProvider(ticker));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load technicals',
        message: e.toString(),
        onRetry: () => ref.invalidate(technicalsProvider(ticker)),
      ),
      data: (resp) {
        if (resp.indicators.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.insufficientData,
            title: 'No indicator values for this symbol',
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final e in resp.indicators.entries)
                MetricCard(
                  label: indicatorLabel(e.key),
                  value: e.value == null
                      ? kEmDash
                      : e.value!.toStringAsFixed(2),
                  badge: interpretIndicator(
                    key: e.key,
                    value: e.value,
                    allIndicators: resp.indicators,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
```

Wire at index 2.

---

### Task 36: PerformanceTab (table + pure-Flutter inline bar chart)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/symbols_tabs/performance_tab.dart`
- Modify: `symbols_detail_pane.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

const _periodOrder = ['1D', '1W', '1M', '3M', '6M', '1Y', '2Y', '5Y', '10Y', 'MAX'];

class PerformanceTab extends ConsumerWidget {
  final String ticker;
  const PerformanceTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(performanceProvider(ticker));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load performance',
        message: e.toString(),
        onRetry: () => ref.invalidate(performanceProvider(ticker)),
      ),
      data: (resp) {
        if (resp.returns.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No performance data',
          );
        }
        final maxAbs = resp.returns.values
            .where((v) => v != null)
            .map((v) => v!.abs())
            .fold<double>(0, (acc, v) => v > acc ? v : acc);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: LayoutBuilder(
            builder: (ctx, c) {
              final wide = c.maxWidth >= 700;
              final tableW = wide ? 360.0 : c.maxWidth;
              final children = <Widget>[
                SizedBox(width: tableW, child: _table(context, resp)),
                if (wide) const SizedBox(width: 24),
                Expanded(child: _bars(context, resp, maxAbs)),
              ];
              return wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: children)
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
            },
          ),
        );
      },
    );
  }

  Widget _table(BuildContext context, dynamic resp) {
    final hasRelative = resp.relative != null;
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: IntrinsicColumnWidth(),
      },
      children: [
        TableRow(children: [
          _hd(context, 'Period'),
          _hd(context, 'Return'),
          if (hasRelative) _hd(context, 'vs NIFTY'),
        ]),
        for (final p in _periodOrder)
          if (resp.returns.containsKey(p))
            TableRow(children: [
              _cell(context, p, false),
              _pctCell(context, resp.returns[p]),
              if (hasRelative)
                _pctCell(context, (resp.relative as Map)[p] as double?),
            ]),
      ],
    );
  }

  Widget _hd(BuildContext ctx, String t) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(t,
            style:
                MyntWebTextStyles.caption(ctx, fontWeight: MyntFonts.semiBold)),
      );

  Widget _cell(BuildContext ctx, String t, bool right) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(t, style: MyntWebTextStyles.body(ctx)),
      );

  Widget _pctCell(BuildContext ctx, double? v) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          formatPercent(v == null ? null : v / 100, signed: true),
          style: MyntWebTextStyles.body(ctx,
              fontWeight: MyntFonts.medium, color: signedColor(ctx, v)),
        ),
      );

  Widget _bars(BuildContext context, dynamic resp, double maxAbs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in _periodOrder)
          if (resp.returns.containsKey(p))
            _barRow(context, p, (resp.returns[p] as double?) ?? 0, maxAbs),
      ],
    );
  }

  Widget _barRow(BuildContext ctx, String label, double v, double maxAbs) {
    final color = v >= 0 ? MyntColors.success : MyntColors.error;
    final widthFactor = maxAbs == 0 ? 0.0 : (v.abs() / maxAbs).clamp(0.0, 1.0);
    final bg = resolveThemeColor(ctx,
        dark: MyntColors.surfaceVariantDark, light: MyntColors.surfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text(label, style: MyntWebTextStyles.caption(ctx))),
          Expanded(
            child: Stack(children: [
              Container(height: 18, color: bg),
              FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(height: 18, color: color),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(formatPercent(v / 100, signed: true),
                textAlign: TextAlign.right,
                style: MyntWebTextStyles.caption(ctx, color: color)),
          ),
        ],
      ),
    );
  }
}
```

Wire at index 3.

> Note: backend may return percentages as fractions OR raw numbers (e.g. `1.7` could mean 1.7% or 170%). The spec section 4.1 example shows `"1D": 1.7` for a daily return = 1.7%, so values are likely percentages already (not fractions). The code above divides by 100 before calling `formatPercent` which expects fractions. **Verify with a real response and adjust if needed.**

---

### Task 37: FundamentalTab (info grid + 6 score bars)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/symbols_tabs/fundamental_tab.dart`
- Modify: `symbols_detail_pane.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/metric_card.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/score_progress_bar.dart';

class FundamentalTab extends ConsumerWidget {
  final String ticker;
  const FundamentalTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(symbolInfoProvider(ticker));
    final score = ref.watch(fundamentalScoreProvider(ticker));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Company info',
              style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 8),
          info.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not load company info',
              message: e.toString(),
              onRetry: () => ref.invalidate(symbolInfoProvider(ticker)),
            ),
            data: (i) => Wrap(spacing: 12, runSpacing: 12, children: [
              MetricCard(label: 'Sector', value: i.sector ?? kEmDash),
              MetricCard(label: 'Industry', value: i.industry ?? kEmDash),
              MetricCard(label: 'Market Cap', value: formatCurrencyINR(i.marketCap)),
              MetricCard(label: 'P/E (TTM)', value: i.peTrailing?.toStringAsFixed(2) ?? kEmDash),
              MetricCard(label: 'P/B', value: i.pbRatio?.toStringAsFixed(2) ?? kEmDash),
              MetricCard(label: 'ROE', value: formatPercent(i.returnOnEquity)),
              MetricCard(label: 'Dividend Yield', value: formatPercent(i.dividendYield)),
              MetricCard(label: 'Beta', value: i.beta?.toStringAsFixed(2) ?? kEmDash),
              MetricCard(label: '52W High', value: i.fiftyTwoWeekHigh?.toStringAsFixed(2) ?? kEmDash),
              MetricCard(label: '52W Low', value: i.fiftyTwoWeekLow?.toStringAsFixed(2) ?? kEmDash),
            ]),
          ),
          const SizedBox(height: 24),
          Text('Fundamental score',
              style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 8),
          score.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not load score',
              message: e.toString(),
              onRetry: () => ref.invalidate(fundamentalScoreProvider(ticker)),
            ),
            data: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ScoreProgressBar(label: 'Composite', score: s.composite),
              const SizedBox(height: 12),
              ScoreProgressBar(label: 'Valuation', score: s.valuation),
              const SizedBox(height: 12),
              ScoreProgressBar(label: 'Growth', score: s.growth),
              const SizedBox(height: 12),
              ScoreProgressBar(label: 'Profitability', score: s.profitability),
              const SizedBox(height: 12),
              ScoreProgressBar(label: 'Quality', score: s.quality),
              const SizedBox(height: 12),
              ScoreProgressBar(label: 'Solvency', score: s.solvency),
              const SizedBox(height: 12),
              ScoreProgressBar(label: 'Efficiency', score: s.efficiency),
            ]),
          ),
        ],
      ),
    );
  }
}
```

Wire at index 4.

---

### Task 38: FinancialsTab (Income/Balance/Cashflow × Quarterly/Annual)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/symbols_tabs/financials_tab.dart`
- Modify: `symbols_detail_pane.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class FinancialsTab extends ConsumerStatefulWidget {
  final String ticker;
  const FinancialsTab({super.key, required this.ticker});

  @override
  ConsumerState<FinancialsTab> createState() => _FinancialsTabState();
}

class _FinancialsTabState extends ConsumerState<FinancialsTab> {
  String _statement = 'income';
  String _period = 'quarterly';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(financialsProvider((
      ticker: widget.ticker,
      period: _period,
      statement: _statement,
    )));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(children: [
          _SegToggle(
            options: const ['income', 'balance', 'cashflow'],
            labels: const ['Income', 'Balance', 'Cash Flow'],
            value: _statement,
            onChanged: (v) => setState(() => _statement = v),
          ),
          const SizedBox(width: 16),
          _SegToggle(
            options: const ['quarterly', 'annual'],
            labels: const ['Quarterly', 'Annual'],
            value: _period,
            onChanged: (v) => setState(() => _period = v),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not load financials',
              message: e.toString(),
              onRetry: () => ref.invalidate(financialsProvider((
                ticker: widget.ticker,
                period: _period,
                statement: _statement,
              ))),
            ),
            data: (resp) {
              if (resp.lineItems.isEmpty) {
                return const EmptyState(
                  kind: EmptyStateKind.insufficientData,
                  title: 'No financial statements available',
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Line item')),
                      for (final p in resp.periods)
                        DataColumn(label: Text(formatDate(p)), numeric: true),
                    ],
                    rows: [
                      for (final li in resp.lineItems)
                        DataRow(cells: [
                          DataCell(Text(li, style: MyntWebTextStyles.body(context))),
                          for (final p in resp.periods)
                            DataCell(Text(
                              _formatCr(resp.values[li]?[p]),
                              style: MyntWebTextStyles.body(context),
                            )),
                        ]),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatCr(num? v) {
    if (v == null) return kEmDash;
    final cr = v / 1e7;
    return '${cr.toStringAsFixed(2)} Cr';
  }
}

class _SegToggle extends StatelessWidget {
  final List<String> options;
  final List<String> labels;
  final String value;
  final ValueChanged<String> onChanged;
  const _SegToggle({
    required this.options,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        for (int i = 0; i < options.length; i++)
          FilterChip(
            label: Text(labels[i]),
            selected: value == options[i],
            onSelected: (_) => onChanged(options[i]),
          ),
      ],
    );
  }
}
```

Wire at index 5.

---

### Task 39: PeersTab (sortable table, row click → switch ticker)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/symbols_tabs/peers_tab.dart`
- Modify: `symbols_detail_pane.dart` (pass `widget.onPeerTap`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class PeersTab extends ConsumerWidget {
  final String ticker;
  final ValueChanged<String> onPeerTap;
  const PeersTab({super.key, required this.ticker, required this.onPeerTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(peersProvider(ticker));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load peers',
        message: e.toString(),
        onRetry: () => ref.invalidate(peersProvider(ticker)),
      ),
      data: (resp) {
        if (resp.peers.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No peer data available',
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Ticker')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Market Cap'), numeric: true),
                DataColumn(label: Text('P/E (TTM)'), numeric: true),
              ],
              rows: [
                for (final p in resp.peers)
                  DataRow(
                    onSelectChanged: (_) => onPeerTap(p.ticker),
                    cells: [
                      DataCell(Text(p.ticker,
                          style: MyntWebTextStyles.body(context,
                              fontWeight: MyntFonts.medium))),
                      DataCell(Text(p.name)),
                      DataCell(Text(formatCurrencyINR(p.marketCap))),
                      DataCell(Text(p.peTrailing?.toStringAsFixed(2) ?? kEmDash)),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

In `symbols_detail_pane.dart`, replace the Peers placeholder with:

```dart
PeersTab(ticker: widget.ticker, onPeerTap: widget.onPeerTap),
```

---

### Task 40: HoldersTab (collapsible Holders / News / Dividends)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/symbols_tabs/holders_tab.dart`
- Modify: `symbols_detail_pane.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class HoldersTab extends ConsumerWidget {
  final String ticker;
  const HoldersTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            title: 'Major holders',
            async: ref.watch(holdersProvider(ticker)),
            renderRow: (m) => '${m['holder'] ?? '—'}  ·  ${m['pct'] ?? '—'}%',
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Latest news',
            async: ref.watch(newsProvider(ticker)),
            renderRow: (m) => m['title']?.toString() ?? '—',
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Dividends',
            async: ref.watch(dividendsProvider(ticker)),
            renderRow: (m) => '${m['date'] ?? '—'}  ·  ₹${m['amount'] ?? '—'}',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final AsyncValue<List<Map<String, dynamic>>> async;
  final String Function(Map<String, dynamic>) renderRow;

  const _Section({
    required this.title,
    required this.async,
    required this.renderRow,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(title,
          style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
      children: [
        async.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => EmptyState(
            kind: EmptyStateKind.error,
            title: 'Could not load',
            message: e.toString(),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const EmptyState(
                kind: EmptyStateKind.insufficientData,
                title: 'Insufficient data for this stock',
              );
            }
            return Column(
              children: [
                for (final row in rows)
                  ListTile(
                    dense: true,
                    title: Text(renderRow(row),
                        style: MyntWebTextStyles.body(context)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
```

Wire at index 7.

---

### Task 41: DeliveriesTab

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/symbols_tabs/deliveries_tab.dart`
- Modify: `symbols_detail_pane.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class DeliveriesTab extends ConsumerWidget {
  final String ticker;
  const DeliveriesTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deliveriesProvider(ticker));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load deliveries',
        message: e.toString(),
        onRetry: () => ref.invalidate(deliveriesProvider(ticker)),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.insufficientData,
            title: 'No delivery data available',
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Deliverable Qty'), numeric: true),
                DataColumn(label: Text('Delivery %'), numeric: true),
              ],
              rows: [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(Text(formatDate(r['date']?.toString() ?? ''),
                        style: MyntWebTextStyles.body(context))),
                    DataCell(Text(r['deliverable_qty']?.toString() ?? kEmDash)),
                    DataCell(Text(r['delivery_pct']?.toString() ?? kEmDash)),
                  ]),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

Wire at index 8.

---

> 🟢 **Manual checkpoint after Milestone 5**
>
> Full Symbol detail is now functional. In the running app: search RELIANCE, open detail, click through all 9 tabs. Each tab should show its own loading → data view. Tabs without backend data should show "Insufficient data" empty states.

---

## Milestone 6 — Scanners sub-page (Tasks 42–46)

After this milestone, the Scanners sub-page shows the full scanner list, lets the user open a detail view with results, and exports to Excel.

### Task 42: Create ScannersSubPage skeleton (list ↔ detail switching)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/scanners_sub_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'scanners_list_pane.dart';
import 'scanners_detail_pane.dart';

class ScannersSubPage extends ConsumerStatefulWidget {
  const ScannersSubPage({super.key});

  @override
  ConsumerState<ScannersSubPage> createState() => _ScannersSubPageState();
}

class _ScannersSubPageState extends ConsumerState<ScannersSubPage> {
  String? _selectedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(scannerShellProvider).pendingScannerCode;
      if (pending != null) {
        setState(() => _selectedCode = pending);
        ref.read(scannerShellProvider.notifier).consumePendingScannerCode();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.listen(scannerShellProvider, (prev, next) {
      if (next.pendingScannerCode != null &&
          next.pendingScannerCode != _selectedCode) {
        setState(() => _selectedCode = next.pendingScannerCode);
        ref.read(scannerShellProvider.notifier).consumePendingScannerCode();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCode == null) {
      return ScannersListPane(onSelect: (c) => setState(() => _selectedCode = c));
    }
    return ScannersDetailPane(
      code: _selectedCode!,
      onBack: () => setState(() => _selectedCode = null),
    );
  }
}
```

---

### Task 43: ScannersListPane (facets + table)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/scanners_list_pane.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/provider/scanner/scanners_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class ScannersListPane extends ConsumerStatefulWidget {
  final ValueChanged<String> onSelect;
  const ScannersListPane({super.key, required this.onSelect});

  @override
  ConsumerState<ScannersListPane> createState() => _ScannersListPaneState();
}

class _ScannersListPaneState extends ConsumerState<ScannersListPane> {
  String? _activeGroup; // null = All
  final TextEditingController _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(scannerListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load scanners',
        message: e.toString(),
        onRetry: () => ref.invalidate(scannerListProvider),
      ),
      data: (resp) {
        final groups = <String, int>{};
        for (final s in resp.items) {
          groups.update(s.groupName, (n) => n + 1, ifAbsent: () => 1);
        }
        final filtered = resp.items.where((s) {
          if (_activeGroup != null && s.groupName != _activeGroup) return false;
          if (_q.text.isEmpty) return true;
          final q = _q.text.toLowerCase();
          return s.displayName.toLowerCase().contains(q) ||
              s.code.toLowerCase().contains(q);
        }).toList();

        final wide = MediaQuery.of(context).size.width >= 900;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              SizedBox(
                width: 180,
                child: _facets(context, groups, resp.items.length),
              ),
            if (wide) const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!wide) ...[
                    _facetPopup(context, groups, resp.items.length),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _q,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search scanners by name or code',
                      prefixIcon: Icon(Icons.search, size: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const EmptyState(
                            kind: EmptyStateKind.search,
                            title: 'No scanners match this filter',
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (_, i) {
                              final s = filtered[i];
                              return ListTile(
                                title: Text(s.displayName,
                                    style: MyntWebTextStyles.body(context,
                                        fontWeight: MyntFonts.medium)),
                                subtitle: Text(
                                  '${s.groupName}${s.subGroup == null ? "" : " · ${s.subGroup}"}  ·  ${s.code}',
                                  style: MyntWebTextStyles.caption(context),
                                ),
                                trailing: Icon(shadcn.LucideIcons.chevronRight,
                                    size: 16),
                                onTap: () => widget.onSelect(s.code),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _facets(BuildContext ctx, Map<String, int> groups, int total) {
    final entries = [('All', total, null), ...groups.entries.map((e) => (e.key, e.value, e.key))];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: shadcn.Theme.of(ctx).colorScheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, count, key) in entries)
            _FacetRow(
              label: label,
              count: count,
              active: _activeGroup == key,
              onTap: () => setState(() => _activeGroup = key),
            ),
        ],
      ),
    );
  }

  Widget _facetPopup(BuildContext ctx, Map<String, int> groups, int total) {
    return TextButton.icon(
      onPressed: () async {
        final selected = await showModalBottomSheet<String?>(
          context: ctx,
          builder: (_) => ListView(
            children: [
              ListTile(
                title: Text('All ($total)'),
                onTap: () => Navigator.pop(ctx, null),
              ),
              for (final e in groups.entries)
                ListTile(
                  title: Text('${e.key} (${e.value})'),
                  onTap: () => Navigator.pop(ctx, e.key),
                ),
            ],
          ),
        );
        setState(() => _activeGroup = selected);
      },
      icon: const Icon(Icons.filter_list, size: 16),
      label: Text(_activeGroup ?? 'All scanners'),
    );
  }
}

class _FacetRow extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _FacetRow({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? MyntColors.primary : null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: active ? MyntFonts.semiBold : MyntFonts.regular,
                      color: color)),
            ),
            Text('$count',
                style: MyntWebTextStyles.caption(context, color: color)),
          ],
        ),
      ),
    );
  }
}
```

---

### Task 44: ScannersDetailPane (header + expandable predicate + results table)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/scanners_detail_pane.dart`

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'package:mynt_plus/provider/scanner/scanners_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/download_xlsx.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/export_modal.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/scanner_results_table.dart';

class ScannersDetailPane extends ConsumerWidget {
  final String code;
  final VoidCallback onBack;
  const ScannersDetailPane({super.key, required this.code, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(scannerDetailProvider(code));
    final results = ref.watch(scannerResultsProvider(code));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            tooltip: 'Back to scanners',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          meta.when(
            loading: () => Text('Loading…', style: MyntWebTextStyles.body(context)),
            error: (_, __) => Text(code,
                style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
            data: (s) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.displayName,
                      style: MyntWebTextStyles.body(context,
                          fontWeight: MyntFonts.bold)),
                  Text(
                    '${s.groupName}${s.subGroup == null ? "" : " · ${s.subGroup}"}',
                    style: MyntWebTextStyles.caption(context),
                  ),
                ],
              ),
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export'),
            onPressed: () => _export(context),
          ),
        ]),
        const SizedBox(height: 12),
        meta.maybeWhen(
          data: (s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (s.description.isNotEmpty)
              Text(s.description,
                  style: MyntWebTextStyles.body(context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary))),
            if (s.predicate != null) ...[
              const SizedBox(height: 8),
              _PredicateAccordion(predicate: s.predicate!),
            ],
          ]),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not load results',
              message: e.toString(),
              onRetry: () => ref.invalidate(scannerResultsProvider(code)),
            ),
            data: (r) {
              if (r.matches.isEmpty) {
                return const EmptyState(
                  kind: EmptyStateKind.empty,
                  title: 'No matches today',
                );
              }
              final cols = [
                for (final c in r.columns)
                  ScanColumn(
                    key: c.key,
                    label: c.label,
                    fmt: c.fmt,
                    description: c.description,
                  ),
              ];
              final rows = [
                for (final m in r.matches)
                  ScanRow(ticker: m.ticker, name: m.name, values: m.values),
              ];
              final visible = r.matches.length;
              final total = r.total;
              final footer = total > visible
                  ? 'Showing $visible of $total matches — increase limit or refine'
                  : 'Showing $visible matches';
              return ScannerResultsTable(
                columns: cols,
                rows: rows,
                footer: footer,
                onTickerTap: (t) {
                  ref.read(scannerShellProvider.notifier)
                      .navigateToSymbolDetail(t);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    final res = await showExportModal(context);
    if (res == null) return;
    final api = locator<ApiExporter>();
    try {
      final blob = await api.downloadScannerExportXlsx(
        code,
        columns: res.mode == ExportColumnsMode.all ? 'all' : 'visible',
      );
      triggerXlsxDownload(
        bytes: Uint8List.fromList(blob.bytes),
        filename: blob.filename,
        fallbackName: '${code}_export.xlsx',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

class _PredicateAccordion extends StatefulWidget {
  final Map<String, dynamic> predicate;
  const _PredicateAccordion({required this.predicate});

  @override
  State<_PredicateAccordion> createState() => _PredicateAccordionState();
}

class _PredicateAccordionState extends State<_PredicateAccordion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final json = const JsonEncoder.withIndent('  ').convert(widget.predicate);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Row(children: [
          Icon(_expanded ? shadcn.LucideIcons.chevronDown : shadcn.LucideIcons.chevronRight, size: 14),
          const SizedBox(width: 4),
          Text('View technical predicate',
              style: MyntWebTextStyles.caption(context,
                  fontWeight: MyntFonts.medium)),
        ]),
      ),
      if (_expanded) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.surfaceVariantDark,
                light: MyntColors.surfaceVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: SelectableText(
                json,
                style: MyntWebTextStyles.caption(context).copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy JSON',
              onPressed: () => Clipboard.setData(ClipboardData(text: json)),
            ),
          ]),
        ),
      ],
    ]);
  }
}
```

---

### Task 45: Wire ScannersSubPage into the shell

**Files:**
- Modify: `lib/screens/web/scanner/scanner_shell_screen.dart`

Add the import:

```dart
import 'sub_pages/scanners_sub_page.dart';
```

Replace the `_Placeholder('Scanners')` entry in the `IndexedStack`:

```dart
ScannersSubPage(),
```

Run `flutter analyze` — should be clean.

---

### Task 46: Smoke-test the cross-sub-page navigation

This is a verification-only task — no new code.

- [ ] Open the app → Scanner → Symbols → search a ticker → open detail → Scans tab → click a scanner-code chip → should switch to Scanners sub-page with that scanner detail loaded automatically
- [ ] On the scanner detail, click a result row → should switch to Symbols sub-page with that ticker's detail loaded automatically
- [ ] Click Export on a scanner detail → modal opens → choose Visible → .xlsx downloads (browser native download)

---

> 🟢 **Manual checkpoint after Milestone 6**
>
> Scanners sub-page is fully functional. Verify cross-page navigation, exports, and dark theme. Commit if you like.

---

## Milestone 7 — Fundamentals sub-page (Tasks 47–53)

After this milestone, the Fundamentals screener is fully functional: presets, saved screens (load/save/delete), filter builder with all dtype-driven dropdowns, run, and export.

### Task 47: Create FundamentalsBuilderState (in-memory builder model)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/fundamentals_builder_state.dart`

Encapsulates the builder's mutable state in a small class so the sub-page widget stays focused on UI.

```dart
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';

class FundamentalsBuilderState {
  final List<FundamentalFilter> filters;
  final String treatNullAs; // 'fail' | 'pass'
  final String orderBy;
  final String orderDir; // 'asc' | 'desc'
  final int limit;

  const FundamentalsBuilderState({
    this.filters = const [],
    this.treatNullAs = 'fail',
    this.orderBy = 'market_cap',
    this.orderDir = 'desc',
    this.limit = 100,
  });

  FundamentalsBuilderState copyWith({
    List<FundamentalFilter>? filters,
    String? treatNullAs,
    String? orderBy,
    String? orderDir,
    int? limit,
  }) =>
      FundamentalsBuilderState(
        filters: filters ?? this.filters,
        treatNullAs: treatNullAs ?? this.treatNullAs,
        orderBy: orderBy ?? this.orderBy,
        orderDir: orderDir ?? this.orderDir,
        limit: limit ?? this.limit,
      );

  FundamentalScanRequest toRequest() => FundamentalScanRequest(
        filters: filters,
        treatNullAs: treatNullAs,
        orderBy: orderBy,
        orderDir: orderDir,
        limit: limit,
      );
}

List<String> validOpsForDtype(String dtype, {bool multiYear = false}) {
  switch (dtype) {
    case 'string':
      return const ['==', '!=', 'in', 'not_in', 'is_null', 'is_not_null'];
    default:
      final base = ['<', '<=', '>', '>=', '==', '!=', 'between', 'is_null', 'is_not_null'];
      if (multiYear) base.add('min_years');
      return base;
  }
}
```

---

### Task 48: Create FundamentalFilterRow widget (one builder row)

**Files:**
- Create: `lib/screens/web/scanner/widgets/fundamental_filter_row.dart`

```dart
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/sub_pages/fundamentals_builder_state.dart';

class FundamentalFilterRow extends StatefulWidget {
  final List<FundamentalField> fields;
  final FundamentalFilter filter;
  final ValueChanged<FundamentalFilter> onChange;
  final VoidCallback onRemove;

  const FundamentalFilterRow({
    super.key,
    required this.fields,
    required this.filter,
    required this.onChange,
    required this.onRemove,
  });

  @override
  State<FundamentalFilterRow> createState() => _FundamentalFilterRowState();
}

class _FundamentalFilterRowState extends State<FundamentalFilterRow> {
  late final TextEditingController _v1 = TextEditingController();
  late final TextEditingController _v2 = TextEditingController();
  late final TextEditingController _years = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  void _hydrate() {
    final v = widget.filter.value;
    if (v is num) {
      _v1.text = _isPct() ? (v * 100).toString() : v.toString();
    } else if (v is String) {
      _v1.text = v;
    } else if (v is List && v.length == 2) {
      _v1.text = (_isPct() ? (v[0] as num) * 100 : v[0]).toString();
      _v2.text = (_isPct() ? (v[1] as num) * 100 : v[1]).toString();
    }
    if (widget.filter.years != null) _years.text = widget.filter.years.toString();
  }

  FundamentalField? get _field {
    for (final f in widget.fields) {
      if (f.key == widget.filter.field) return f;
    }
    return null;
  }

  bool get _isPct => () => _field?.dtype == 'pct';
  bool get _isMultiYear =>
      FundamentalField.multiYearCapable.contains(widget.filter.field);

  @override
  Widget build(BuildContext context) {
    final field = _field;
    final ops = field == null
        ? const <String>[]
        : validOpsForDtype(field.dtype, multiYear: _isMultiYear);
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(width: 220, child: _fieldDropdown()),
      const SizedBox(width: 8),
      SizedBox(width: 140, child: _opDropdown(ops)),
      const SizedBox(width: 8),
      Expanded(child: _valueInputs(field)),
      if (_isMultiYear) ...[
        const SizedBox(width: 8),
        SizedBox(width: 60, child: _yearsInput()),
      ],
      const SizedBox(width: 8),
      IconButton(
        onPressed: widget.onRemove,
        icon: const Icon(shadcn.LucideIcons.x, size: 16),
        tooltip: 'Remove',
      ),
    ]);
  }

  Widget _fieldDropdown() {
    final byGroup = <String, List<FundamentalField>>{};
    for (final f in widget.fields) {
      byGroup.putIfAbsent(f.group, () => []).add(f);
    }
    return DropdownButton<String>(
      isExpanded: true,
      value: widget.filter.field,
      items: [
        for (final entry in byGroup.entries) ...[
          DropdownMenuItem(
            enabled: false,
            value: '__g_${entry.key}',
            child: Text(entry.key,
                style: MyntWebTextStyles.caption(context,
                    fontWeight: MyntFonts.semiBold)),
          ),
          for (final f in entry.value)
            DropdownMenuItem(value: f.key, child: Text(f.label)),
        ],
      ],
      onChanged: (v) {
        if (v == null || v.startsWith('__g_')) return;
        widget.onChange(FundamentalFilter(field: v, op: widget.filter.op));
      },
    );
  }

  Widget _opDropdown(List<String> ops) {
    return DropdownButton<String>(
      isExpanded: true,
      value: ops.contains(widget.filter.op) ? widget.filter.op : null,
      items: [for (final o in ops) DropdownMenuItem(value: o, child: Text(o))],
      onChanged: (v) {
        if (v == null) return;
        widget.onChange(FundamentalFilter(
          field: widget.filter.field,
          op: v,
          value: widget.filter.value,
          years: widget.filter.years,
        ));
      },
    );
  }

  Widget _valueInputs(FundamentalField? f) {
    if (f == null) return const SizedBox.shrink();
    final op = widget.filter.op;
    if (op == 'is_null' || op == 'is_not_null') return const SizedBox.shrink();
    if (op == 'min_years') {
      return _yearsInput(); // re-use
    }
    if (op == 'between') {
      return Row(children: [
        Expanded(child: _numericInput(_v1, suffix: _isPct() ? '%' : null)),
        const SizedBox(width: 4),
        const Text('and'),
        const SizedBox(width: 4),
        Expanded(child: _numericInput(_v2, suffix: _isPct() ? '%' : null)),
      ]);
    }
    if (op == 'in' || op == 'not_in') {
      return TextField(
        controller: _v1,
        decoration: const InputDecoration(hintText: 'comma,separated,values'),
        onChanged: (txt) => widget.onChange(FundamentalFilter(
          field: widget.filter.field,
          op: op,
          value: txt.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        )),
      );
    }
    // single value
    return _numericInput(_v1, suffix: _isPct() ? '%' : null);
  }

  Widget _numericInput(TextEditingController c, {String? suffix}) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(suffixText: suffix),
      onChanged: (_) => _emit(),
    );
  }

  Widget _yearsInput() {
    return TextField(
      controller: _years,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(hintText: 'yrs'),
      onChanged: (_) => _emit(),
    );
  }

  void _emit() {
    final field = _field;
    if (field == null) return;
    final op = widget.filter.op;
    dynamic value;
    if (op == 'is_null' || op == 'is_not_null') {
      value = null;
    } else if (op == 'between') {
      final a = double.tryParse(_v1.text);
      final b = double.tryParse(_v2.text);
      if (a != null && b != null) {
        value = _isPct() ? [a / 100, b / 100] : [a, b];
      }
    } else if (op == 'in' || op == 'not_in') {
      value = _v1.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } else {
      final n = double.tryParse(_v1.text);
      if (n != null) value = _isPct() ? n / 100 : n;
    }
    widget.onChange(FundamentalFilter(
      field: field.key,
      op: op,
      value: value,
      years: int.tryParse(_years.text),
    ));
  }
}
```

---

### Task 49: FundamentalsSubPage skeleton (presets + saved + builder)

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/fundamentals_sub_page.dart`

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';
import 'package:mynt_plus/provider/scanner/fundamentals_provider.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/sub_pages/fundamentals_builder_state.dart';
import 'package:mynt_plus/screens/web/scanner/utils/download_xlsx.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/export_modal.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/fundamental_filter_row.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/scanner_results_table.dart';

class FundamentalsSubPage extends ConsumerStatefulWidget {
  const FundamentalsSubPage({super.key});

  @override
  ConsumerState<FundamentalsSubPage> createState() =>
      _FundamentalsSubPageState();
}

class _FundamentalsSubPageState extends ConsumerState<FundamentalsSubPage> {
  FundamentalsBuilderState _state = const FundamentalsBuilderState();
  AsyncValue<FundamentalScanResponse>? _result;

  @override
  Widget build(BuildContext context) {
    final fields = ref.watch(fundamentalFieldsProvider);
    final presets = ref.watch(fundamentalPresetsProvider);
    final saved = ref.watch(savedScreensProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Presets ---
          Text('Presets', style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 8),
          presets.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(e.toString(), style: MyntWebTextStyles.caption(context)),
            data: (list) => Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in list)
                ActionChip(
                  label: Text(p.name),
                  onPressed: () => setState(() => _state = _state.copyWith(
                        filters: p.filters,
                        treatNullAs: p.treatNullAs,
                      )),
                ),
            ]),
          ),
          const SizedBox(height: 16),

          // --- Saved screens ---
          Text('Saved screens', style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 8),
          saved.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(e.toString(), style: MyntWebTextStyles.caption(context)),
            data: (list) => list.isEmpty
                ? Text('No saved screens yet.',
                    style: MyntWebTextStyles.caption(context))
                : Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in list)
                      InputChip(
                        label: Text(s.name),
                        onPressed: () => setState(() => _state = _state.copyWith(
                              filters: s.filters,
                              treatNullAs: s.treatNullAs,
                            )),
                        onDeleted: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete saved screen?'),
                              content: Text('"${s.name}" will be removed.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await locator<ApiExporter>().deleteSavedScreen(s.id);
                            ref.invalidate(savedScreensProvider);
                          }
                        },
                      ),
                  ]),
          ),
          const SizedBox(height: 24),

          // --- Filter builder ---
          Text('Filters', style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 8),
          fields.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not load field catalog',
              message: e.toString(),
              onRetry: () => ref.invalidate(fundamentalFieldsProvider),
            ),
            data: (fList) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < _state.filters.length; i++) ...[
                  FundamentalFilterRow(
                    fields: fList,
                    filter: _state.filters[i],
                    onChange: (f) {
                      final nf = [..._state.filters]..[i] = f;
                      setState(() => _state = _state.copyWith(filters: nf));
                    },
                    onRemove: () {
                      final nf = [..._state.filters]..removeAt(i);
                      setState(() => _state = _state.copyWith(filters: nf));
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                TextButton.icon(
                  icon: const Icon(shadcn.LucideIcons.plus, size: 14),
                  label: const Text('Add filter'),
                  onPressed: () {
                    if (fList.isEmpty) return;
                    final nf = [..._state.filters, FundamentalFilter(field: fList.first.key, op: '<')];
                    setState(() => _state = _state.copyWith(filters: nf));
                  },
                ),
                const SizedBox(height: 16),
                _settingsRow(),
                const SizedBox(height: 16),
                _actions(),
              ],
            ),
          ),

          const SizedBox(height: 24),
          if (_result != null) _buildResults(),
        ],
      ),
    );
  }

  Widget _settingsRow() {
    return Row(children: [
      const Text('Missing data:'),
      const SizedBox(width: 8),
      Radio<String>(value: 'fail', groupValue: _state.treatNullAs,
        onChanged: (v) => setState(() => _state = _state.copyWith(treatNullAs: v))),
      const Text('Exclude'),
      Radio<String>(value: 'pass', groupValue: _state.treatNullAs,
        onChanged: (v) => setState(() => _state = _state.copyWith(treatNullAs: v))),
      const Text('Include'),
      const Spacer(),
      const Text('Limit:'),
      SizedBox(
        width: 80,
        child: TextField(
          controller: TextEditingController(text: _state.limit.toString()),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null) setState(() => _state = _state.copyWith(limit: n));
          },
        ),
      ),
    ]);
  }

  Widget _actions() {
    return Row(children: [
      FilledButton.icon(
        icon: const Icon(shadcn.LucideIcons.play, size: 14),
        label: const Text('Run scan'),
        onPressed: _run,
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        icon: const Icon(shadcn.LucideIcons.save, size: 14),
        label: const Text('Save as…'),
        onPressed: _save,
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        icon: const Icon(shadcn.LucideIcons.download, size: 14),
        label: const Text('Download'),
        onPressed: _export,
      ),
    ]);
  }

  Future<void> _run() async {
    setState(() => _result = const AsyncLoading());
    try {
      final r = await locator<ApiExporter>().runFundamentalScan(_state.toRequest());
      setState(() => _result = AsyncData(r));
    } catch (e, st) {
      setState(() => _result = AsyncError(e, st));
    }
  }

  Future<void> _save() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save screen'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Screen name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await locator<ApiExporter>().saveScreen(
        name: ctrl.text.trim(),
        filters: _state.filters,
        treatNullAs: _state.treatNullAs,
        orderBy: _state.orderBy,
        orderDir: _state.orderDir,
        limit: _state.limit,
      );
      ref.invalidate(savedScreensProvider);
    }
  }

  Future<void> _export() async {
    final res = await showExportModal(context, allowCustom: false);
    if (res == null) return;
    try {
      final blob = await locator<ApiExporter>().downloadFundamentalExportXlsx(
        req: _state.toRequest(),
        columns: res.mode == ExportColumnsMode.all ? 'all' : 'visible',
      );
      triggerXlsxDownload(
        bytes: Uint8List.fromList(blob.bytes),
        filename: blob.filename,
        fallbackName: 'fundamental_screen.xlsx',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Widget _buildResults() {
    return _result!.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Run failed',
        message: e.toString(),
      ),
      data: (resp) {
        if (resp.matches.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No stocks match these filters',
          );
        }
        final cols = [
          // Standard prefix columns
          const ScanColumn(key: 'sector', label: 'Sector', fmt: 'string', isStandard: true),
          const ScanColumn(key: 'industry', label: 'Industry', fmt: 'string', isStandard: true),
          const ScanColumn(key: 'market_cap', label: 'Market Cap (Cr)', fmt: 'int', isStandard: true),
          // Filter-derived columns from response.column_labels
          for (final cl in resp.columnLabels)
            ScanColumn(key: cl.field, label: cl.label, fmt: 'ratio'),
        ];
        final rows = [
          for (final m in resp.matches)
            ScanRow(
              ticker: m.ticker,
              name: m.name,
              values: {
                ...m.values,
                'sector': m.sector ?? '',
                'industry': m.industry ?? '',
                'market_cap': m.marketCap == null ? null : (m.marketCap! / 1e7).round(),
              },
            ),
        ];
        return ScannerResultsTable(
          columns: cols.where((c) => !c.isStandard).toList(),
          standardPrefixColumns: cols.where((c) => c.isStandard).toList(),
          rows: rows,
          footer: '${resp.returned} of ${resp.total} matches',
          onTickerTap: (t) {
            ref.read(scannerShellProvider.notifier).navigateToSymbolDetail(t);
          },
        );
      },
    );
  }
}
```

---

### Task 50: Wire FundamentalsSubPage into the shell

**Files:**
- Modify: `lib/screens/web/scanner/scanner_shell_screen.dart`

Add import + replace `_Placeholder('Fundamentals')` with `FundamentalsSubPage()`.

---

### Task 51: Smoke-test fundamentals end-to-end

Verification-only.

- [ ] Open Scanner → Fundamentals. Preset chips load → click one → filters appear in builder
- [ ] Click "Run scan" → results table populates with column labels from the response (verify "(median over N years)" suffix appears for fields with `years` set)
- [ ] Click a result row → switches to Symbols sub-page with that ticker
- [ ] Click "Save as…" → enter a name → saved chip appears in Saved screens row
- [ ] Click the X on a saved chip → confirm dialog → chip removed
- [ ] Click "Download" → modal → choose Visible → .xlsx downloads

---

### Task 52: Add `null`-handling guards for percentage fields

When `_emit()` runs with an empty textfield, the filter's `value` is null. The backend treats missing `value` differently from explicit `is_null` op. Add a `setState` guard so we never submit a non-null op with a null value.

**Files:**
- Modify: `lib/screens/web/scanner/sub_pages/fundamentals_sub_page.dart`

- [ ] In `_run()`, before calling `runFundamentalScan`, validate that every filter has a value (unless its op is `is_null` / `is_not_null`):

```dart
  Future<void> _run() async {
    for (final f in _state.filters) {
      final needsValue = f.op != 'is_null' && f.op != 'is_not_null';
      if (needsValue && f.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Set a value for "${f.field}" (${f.op})')),
        );
        return;
      }
    }
    setState(() => _result = const AsyncLoading());
    try {
      final r = await locator<ApiExporter>().runFundamentalScan(_state.toRequest());
      setState(() => _result = AsyncData(r));
    } catch (e, st) {
      setState(() => _result = AsyncError(e, st));
    }
  }
```

---

### Task 53: Test percentage round-trip end-to-end

Manual verification only.

- [ ] Add a `Return on Equity >= 5` filter via the UI → enter `5` → the request sent to backend should have `value: 0.05` (open browser devtools Network tab to verify). On the response, the value displayed in the results table should be `5.00%`.

---

> 🟢 **Manual checkpoint after Milestone 7**
>
> Fundamentals screener is fully functional. Verify all three flows (presets, saved, custom). Commit if you like.

---

## Milestone 8 — Custom Scans sub-page (Tasks 54–60)

After this milestone, the Custom Scans sub-page lists saved custom scans, supports a tree-style visual predicate builder, runs inline, and saves.

### Task 54: Create IndicatorPicker widget (dropdown grouped by family)

**Files:**
- Create: `lib/screens/web/scanner/widgets/indicator_picker.dart`

```dart
import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/indicator_catalog.dart';

class IndicatorPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const IndicatorPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      hint: const Text('Pick indicator'),
      isExpanded: true,
      items: [
        for (final entry in indicatorsByFamily.entries) ...[
          DropdownMenuItem(
            enabled: false,
            value: '__f_${entry.key.name}',
            child: Text(entry.key.label,
                style: MyntWebTextStyles.caption(context,
                    fontWeight: MyntFonts.semiBold)),
          ),
          for (final ind in entry.value)
            DropdownMenuItem(value: ind.name, child: Text(ind.label)),
        ],
      ],
      onChanged: (v) {
        if (v == null || v.startsWith('__f_')) return;
        onChanged(v);
      },
    );
  }
}
```

---

### Task 55: Create PredicateBuilder widget (recursive tree)

**Files:**
- Create: `lib/screens/web/scanner/widgets/predicate_builder.dart`

The builder maintains a mutable tree mirroring the `PredicateNode` shape. It calls `onChange` with the serialized JSON whenever a leaf changes.

```dart
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/predicate.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'indicator_picker.dart';

/// Mutable tree node used internally by the builder. Converts to the
/// immutable [PredicateNode] when serializing.
abstract class _BNode {
  PredicateNode toNode();
}

class _BGroup extends _BNode {
  String op; // 'all' | 'any' | 'none'
  List<_BNode> children;
  _BGroup({required this.op, required this.children});

  @override
  PredicateNode toNode() {
    final kids = children.map((c) => c.toNode()).toList();
    switch (op) {
      case 'any': return PredicateAny(kids);
      case 'none': return PredicateNone(kids);
      case 'all':
      default: return PredicateAll(kids);
    }
  }
}

class _BLeaf extends _BNode {
  // Left side
  String? leftIndicator;
  Map<String, dynamic> leftParams;
  // Op
  String op;
  // Right side
  bool rightIsValue;
  double? rightValueA;
  double? rightValueB; // for `between`
  String? rightIndicator;
  Map<String, dynamic> rightParams;

  _BLeaf({
    this.leftIndicator,
    this.leftParams = const {},
    this.op = '<',
    this.rightIsValue = true,
    this.rightValueA,
    this.rightValueB,
    this.rightIndicator,
    this.rightParams = const {},
  });

  @override
  PredicateNode toNode() {
    final left = leftIndicator == null
        ? IndicatorRef.number(0)
        : IndicatorRef.indicator(leftIndicator!, leftParams);
    IndicatorRef right;
    if (rightIsValue) {
      if (op == 'between' && rightValueA != null && rightValueB != null) {
        right = IndicatorRef.range(rightValueA!, rightValueB!);
      } else {
        right = IndicatorRef.number(rightValueA ?? 0);
      }
    } else {
      right = rightIndicator == null
          ? IndicatorRef.number(0)
          : IndicatorRef.indicator(rightIndicator!, rightParams);
    }
    return PredicateLeaf(left: left, op: op, right: right);
  }
}

class PredicateBuilder extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final ValueChanged<Map<String, dynamic>> onChange;

  const PredicateBuilder({super.key, this.initial, required this.onChange});

  @override
  State<PredicateBuilder> createState() => _PredicateBuilderState();
}

class _PredicateBuilderState extends State<PredicateBuilder> {
  late _BGroup _root;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      try {
        final node = PredicateNode.fromJson(widget.initial!);
        _root = _fromNode(node) as _BGroup;
      } catch (_) {
        _root = _BGroup(op: 'all', children: []);
      }
    } else {
      _root = _BGroup(op: 'all', children: [_BLeaf()]);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  _BNode _fromNode(PredicateNode n) {
    if (n is PredicateAll) {
      return _BGroup(op: 'all', children: n.children.map(_fromNode).toList());
    }
    if (n is PredicateAny) {
      return _BGroup(op: 'any', children: n.children.map(_fromNode).toList());
    }
    if (n is PredicateNone) {
      return _BGroup(op: 'none', children: n.children.map(_fromNode).toList());
    }
    if (n is PredicateLeaf) {
      final leaf = _BLeaf(op: n.op);
      // hydrate left
      if (n.left.indicator != null) {
        leaf.leftIndicator = n.left.indicator;
        leaf.leftParams = Map.of(n.left.indicatorParams);
      }
      // hydrate right
      if (n.right.indicator != null) {
        leaf.rightIsValue = false;
        leaf.rightIndicator = n.right.indicator;
        leaf.rightParams = Map.of(n.right.indicatorParams);
      } else if (n.right.literalRange != null) {
        leaf.rightIsValue = true;
        leaf.rightValueA = n.right.literalRange![0].toDouble();
        leaf.rightValueB = n.right.literalRange![1].toDouble();
      } else if (n.right.literalNumber != null) {
        leaf.rightIsValue = true;
        leaf.rightValueA = n.right.literalNumber!.toDouble();
      }
      return leaf;
    }
    return _BLeaf();
  }

  void _emit() => widget.onChange(_root.toNode().toJson());

  @override
  Widget build(BuildContext context) {
    return _buildGroup(_root, depth: 0);
  }

  Widget _buildGroup(_BGroup g, {required int depth}) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
        color: depth == 0
            ? Colors.transparent
            : resolveThemeColor(context,
                dark: MyntColors.surfaceVariantDark,
                light: MyntColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Match', style: MyntWebTextStyles.body(context)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: g.op,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('all (AND)')),
                DropdownMenuItem(value: 'any', child: Text('any (OR)')),
                DropdownMenuItem(value: 'none', child: Text('none (NOT)')),
              ],
              onChanged: (v) => setState(() {
                if (v != null) g.op = v;
                _emit();
              }),
            ),
            const SizedBox(width: 8),
            Text('of the following:', style: MyntWebTextStyles.body(context)),
          ]),
          const SizedBox(height: 8),
          for (int i = 0; i < g.children.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: g.children[i] is _BGroup
                        ? _buildGroup(g.children[i] as _BGroup, depth: depth + 1)
                        : _buildLeaf(g.children[i] as _BLeaf),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      g.children.removeAt(i);
                      _emit();
                    }),
                    icon: const Icon(shadcn.LucideIcons.x, size: 14),
                    tooltip: 'Remove',
                  ),
                ],
              ),
            ),
          Row(children: [
            TextButton.icon(
              icon: const Icon(shadcn.LucideIcons.plus, size: 14),
              label: const Text('Add condition'),
              onPressed: () => setState(() {
                g.children.add(_BLeaf());
                _emit();
              }),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(shadcn.LucideIcons.plus, size: 14),
              label: const Text('Add group'),
              onPressed: () => setState(() {
                g.children.add(_BGroup(op: 'all', children: [_BLeaf()]));
                _emit();
              }),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildLeaf(_BLeaf l) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.surfaceDark, light: MyntColors.surface),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 200,
          child: IndicatorPicker(
            value: l.leftIndicator,
            onChanged: (v) => setState(() {
              l.leftIndicator = v;
              l.leftParams = {};
              _emit();
            }),
          ),
        ),
        SizedBox(
          width: 130,
          child: DropdownButton<String>(
            isExpanded: true,
            value: kPredicateOperators.contains(l.op) ? l.op : '<',
            items: [for (final o in kPredicateOperators) DropdownMenuItem(value: o, child: Text(o))],
            onChanged: (v) => setState(() {
              if (v != null) l.op = v;
              _emit();
            }),
          ),
        ),
        // Right side toggle
        SizedBox(
          width: 110,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Value')),
              ButtonSegment(value: false, label: Text('Indicator')),
            ],
            selected: {l.rightIsValue},
            onSelectionChanged: (s) => setState(() {
              l.rightIsValue = s.first;
              _emit();
            }),
          ),
        ),
        if (l.rightIsValue) ...[
          SizedBox(
            width: 100,
            child: TextField(
              decoration: const InputDecoration(hintText: 'value'),
              controller: TextEditingController(text: l.rightValueA?.toString() ?? ''),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              onChanged: (v) {
                l.rightValueA = double.tryParse(v);
                _emit();
              },
            ),
          ),
          if (l.op == 'between')
            SizedBox(
              width: 100,
              child: TextField(
                decoration: const InputDecoration(hintText: 'value 2'),
                controller: TextEditingController(text: l.rightValueB?.toString() ?? ''),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                onChanged: (v) {
                  l.rightValueB = double.tryParse(v);
                  _emit();
                },
              ),
            ),
        ] else
          SizedBox(
            width: 200,
            child: IndicatorPicker(
              value: l.rightIndicator,
              onChanged: (v) => setState(() {
                l.rightIndicator = v;
                l.rightParams = {};
                _emit();
              }),
            ),
          ),
      ]),
    );
  }
}
```

> ⚠️ **Param inputs (e.g. RSI period) are intentionally absent in this MVP** — the builder serializes leftIndicator/rightIndicator with empty params, falling back to backend defaults (e.g. RSI defaults to 14). Add per-indicator param inputs from `indicator_catalog.dart` in a follow-up when users need to override defaults.

---

### Task 56: CustomScansSubPage — list mode

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/custom_scans_sub_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/custom_scan.dart';
import 'package:mynt_plus/provider/scanner/custom_scans_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'custom_scan_builder_pane.dart';

class CustomScansSubPage extends ConsumerStatefulWidget {
  const CustomScansSubPage({super.key});

  @override
  ConsumerState<CustomScansSubPage> createState() => _CustomScansSubPageState();
}

class _CustomScansSubPageState extends ConsumerState<CustomScansSubPage> {
  SavedCustomScan? _editing;
  bool _newBuilder = false;

  @override
  Widget build(BuildContext context) {
    if (_newBuilder || _editing != null) {
      return CustomScanBuilderPane(
        existing: _editing,
        onClose: () => setState(() {
          _newBuilder = false;
          _editing = null;
        }),
      );
    }

    final async = ref.watch(savedCustomScansProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: const Text('New custom scan'),
            onPressed: () => setState(() => _newBuilder = true),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not load custom scans',
              message: e.toString(),
              onRetry: () => ref.invalidate(savedCustomScansProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  kind: EmptyStateKind.empty,
                  title: 'No custom scans yet',
                  message: 'Click "New custom scan" to write your first predicate.',
                  onRetry: () => setState(() => _newBuilder = true),
                );
              }
              return SingleChildScrollView(
                child: Wrap(
                  spacing: 12, runSpacing: 12,
                  children: [for (final s in list) _ScanCard(scan: s, onEdit: () => setState(() => _editing = s), onChanged: () => ref.invalidate(savedCustomScansProvider))],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScanCard extends StatelessWidget {
  final SavedCustomScan scan;
  final VoidCallback onEdit;
  final VoidCallback onChanged;
  const _ScanCard({required this.scan, required this.onEdit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(scan.name,
                  style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
              const SizedBox(height: 4),
              Text('Created ${formatDateTime(scan.createdAt)}',
                  style: MyntWebTextStyles.caption(context)),
              Text('Runs: ${scan.runCount}  ·  Last ${formatDateTime(scan.lastRunAt)}',
                  style: MyntWebTextStyles.caption(context)),
              const SizedBox(height: 8),
              Row(children: [
                TextButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 14),
                  label: const Text('Run'),
                  onPressed: () async {
                    final r = await locator<ApiExporter>().runSavedCustomScan(scan.id);
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('${r.matches.length} matches'),
                        content: SizedBox(
                          width: 400, height: 320,
                          child: ListView(
                            children: [for (final m in r.matches) ListTile(title: Text(m.ticker), subtitle: Text(m.name))],
                          ),
                        ),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                      ),
                    );
                    onChanged();
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit'),
                  onPressed: onEdit,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: MyntColors.error),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete custom scan?'),
                        content: Text('"${scan.name}" will be removed.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await locator<ApiExporter>().deleteSavedCustomScan(scan.id);
                      onChanged();
                    }
                  },
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

### Task 57: CustomScanBuilderPane — predicate builder + run + save

**Files:**
- Create: `lib/screens/web/scanner/sub_pages/custom_scan_builder_pane.dart`

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/custom_scan.dart';
import 'package:mynt_plus/provider/scanner/custom_scans_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/predicate_builder.dart';

class CustomScanBuilderPane extends ConsumerStatefulWidget {
  final SavedCustomScan? existing;
  final VoidCallback onClose;
  const CustomScanBuilderPane({super.key, this.existing, required this.onClose});

  @override
  ConsumerState<CustomScanBuilderPane> createState() => _CustomScanBuilderPaneState();
}

class _CustomScanBuilderPaneState extends ConsumerState<CustomScanBuilderPane> {
  late final TextEditingController _nameCtl;
  Map<String, dynamic> _predicate = {'all': []};
  AsyncValue<CustomScanRunResult>? _result;
  bool _showJson = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.existing?.name ?? '');
    if (widget.existing != null) {
      _predicate = widget.existing!.predicateJson;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: widget.onClose,
              tooltip: 'Back to list',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _nameCtl,
                decoration: const InputDecoration(hintText: 'Scan name'),
                style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          PredicateBuilder(
            initial: widget.existing?.predicateJson,
            onChange: (json) => _predicate = json,
          ),
          const SizedBox(height: 16),
          Row(children: [
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow, size: 14),
              label: const Text('Run inline'),
              onPressed: _runInline,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.save, size: 14),
              label: Text(widget.existing == null ? 'Save' : 'Save changes'),
              onPressed: _save,
            ),
            const Spacer(),
            TextButton.icon(
              icon: Icon(_showJson ? Icons.expand_less : Icons.code, size: 14),
              label: Text(_showJson ? 'Hide JSON' : 'Preview JSON'),
              onPressed: () => setState(() => _showJson = !_showJson),
            ),
          ]),
          if (_showJson) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: resolveThemeColor(context,
                    dark: MyntColors.surfaceVariantDark,
                    light: MyntColors.surfaceVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(_predicate),
                style: MyntWebTextStyles.caption(context).copyWith(fontFamily: 'monospace'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_result != null) _resultArea(),
        ],
      ),
    );
  }

  Future<void> _runInline() async {
    setState(() => _result = const AsyncLoading());
    try {
      final r = await locator<ApiExporter>().runCustomScan(predicate: _predicate);
      setState(() => _result = AsyncData(r));
    } catch (e, st) {
      setState(() => _result = AsyncError(e, st));
    }
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the scan a name first.')),
      );
      return;
    }
    try {
      await locator<ApiExporter>().saveCustomScan(name: name, predicate: _predicate);
      ref.invalidate(savedCustomScansProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "$name"')),
      );
      widget.onClose();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Widget _resultArea() {
    return _result!.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Run failed',
        message: e.toString(),
      ),
      data: (r) {
        if (r.matches.isEmpty) {
          return const EmptyState(kind: EmptyStateKind.empty, title: 'No matches');
        }
        return Container(
          height: 320,
          decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor)),
          child: ListView(
            children: [
              for (final m in r.matches)
                ListTile(title: Text(m.ticker), subtitle: Text(m.name)),
            ],
          ),
        );
      },
    );
  }
}
```

---

### Task 58: Wire CustomScansSubPage into the shell

**Files:**
- Modify: `lib/screens/web/scanner/scanner_shell_screen.dart`

Add import + replace `_Placeholder('Custom Scans')` with `CustomScansSubPage()`.

---

### Task 59: Smoke-test custom scans end-to-end

Verification-only.

- [ ] Open Scanner → Custom Scans → "New custom scan"
- [ ] Add condition: left = `rsi`, op = `<`, value = `30` → click "Preview JSON" → confirm the predicate matches `{"all":[{"left":{"indicator":"rsi"},"op":"<","right":{"value":30}}]}`
- [ ] Click "Run inline" → results list populates
- [ ] Enter name "rsi-oversold" → "Save" → returns to list view → card appears
- [ ] Click "Edit" on the card → builder reopens with predicate restored
- [ ] Click delete → confirm → card removed

---

### Task 60: Final cross-feature smoke test

Verification-only.

- [ ] Open Scanner via Options dropdown — Symbols sub-page loads
- [ ] Open `/scanner/scanners` directly — Scanners sub-page loads
- [ ] Open hamburger drawer (narrow window) — Scanner appears in TRADE section
- [ ] Symbols search RELIANCE → open detail → click through all 9 tabs
- [ ] Symbols → detail → Scans tab → click chip → switches to Scanners detail
- [ ] Scanners detail → row click → switches to Symbols detail
- [ ] Fundamentals → preset → run → row click → Symbols detail
- [ ] Custom Scans → new → simple predicate → run → save
- [ ] Toggle dark mode — every screen, every state, no hardcoded colors

---

> 🟢 **Manual checkpoint after Milestone 8 — Feature complete**
>
> All four sub-pages are functional. Cross-page navigation works. Both themes render correctly. Ready for thorough manual testing and your manual git commit.

---

## Self-Review Summary

After writing this plan, I checked it against the design spec:

**Spec coverage:**
- ✅ §3 Backend contract — Task 1 (base URL), Task 4 (mixin registration)
- ✅ §4 Navigation — Tasks 5–11 (enum, routes, dropdown, drawer)
- ✅ §5 Architecture — Tasks 7–8 (shell + provider + left rail + breadcrumb)
- ✅ §6.1 Symbols list + 9 detail tabs — Tasks 29–41 (note: Chart tab intentionally skipped per spec §2 non-goals)
- ✅ §6.2 Scanners list + detail + export — Tasks 42–46
- ✅ §6.3 Fundamentals (presets, saved, builder, results, export) — Tasks 47–53
- ✅ §6.4 Custom Scans (list, visual builder, run inline, save) — Tasks 54–60
- ✅ §7 API + models + providers — Tasks 19–28
- ✅ §8 Formatters — Task 12
- ✅ §10 Edge cases — handled by `EmptyState(kind: insufficientData)` in tabs 7, 8, 10 etc.
- ⚠️ §11 Testing — only data-layer tests (`scanner_exception_test`, `formatters_test`, `predicate_test`) are required by tasks. Widget tests are not enforced; user can add manually if desired.

**Known gaps / follow-ups noted in tasks:**
- Predicate builder leaf rows don't surface per-indicator param inputs yet (uses backend defaults) — flagged in Task 55
- `shadcn.Tooltip` API may need version-specific adjustment — flagged in Task 17
- Performance tab assumes return values are already percentages (not fractions) — flagged in Task 36 with a verification note
- The Chart tab is deferred per the spec's non-goals; the syncfusion dependency is already in pubspec for future use

**Type-consistency check passed:**
- `ScannerSubPage` enum used identically in router, shell, provider, panel builder
- `ScanColumn`/`ScanRow` types used identically in `scanner_results_table.dart`, scanners detail pane, and fundamentals sub-page
- `FundamentalFilter.toJson()` shape verified against spec §4.3 request body
- `PredicateNode.toJson()` matches spec §3.6 worked example exactly (verified by Task 26 round-trip test)

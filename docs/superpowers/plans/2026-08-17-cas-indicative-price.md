# CAS Indicative-Price Row Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an always-present row to the WEB market-depth panel that shows the exchange's live Closing-Auction-Session indicative price (feed field `ic`), badged `CAS`, and shows `—` when no auction is running.

**Architecture:** The depth panel reads a `GetQuotes` object (`depthData`) that is updated from the websocket `socketData` map. Add `ic` to that model, latch it from `socketData['ic']` in the existing `_processDepthData`, and render a new row (via a pure display helper) below the Total Buy/Sell Qty row in both depth layouts. First remove the throwaway debug logger that was used to discover `ic`.

**Tech Stack:** Flutter (web), Riverpod, existing `MyntColors` / `MyntWebTextStyles` / `resolveThemeColor` theming.

## Global Constraints

- **Web only** for v1 (`lib/screens/web/market_watch/scrip_depth_info_web.dart`). Do NOT touch the mobile depth screen.
- **Source of truth is the feed `ic` field.** Never compute the equilibrium price from the depth ladder (verified unreliable — yields circuit edges).
- **Display rule:** show `₹<ic>` only when `ic` is non-null and `> 0`; otherwise `—`.
- **`CAS` badge** must be a solid, colored chip with white text (project chip convention — never transparent/grey).
- **Branch:** implement on a fresh branch off `main` (NOT `popout-chart`).
- Existing depth rows (ladder, Total Buy/Sell Qty) must remain visually unchanged.
- Static gate for every task: `flutter analyze lib/screens/web/market_watch/scrip_depth_info_web.dart lib/models/marketwatch_model/get_quotes.dart` (+ any file the task touches) has no NEW errors.

---

### Task 1: Remove the temporary CAS debug instrument

**Files:**
- Delete: `lib/utils/cas_debug_logger.dart`
- Modify: `lib/provider/websocket_provider.dart` (remove import line 26 + the `CasDebugLogger.record(...)` block ~lines 902–909)
- Modify: `lib/screens/web/market_watch/scrip_depth_info_web.dart` (remove import line 41, the `CasDebugLogger.setQuotes(...)` call ~line 820, and the entire debug button row ~lines 884–921)

**Interfaces:**
- Produces: a clean depth screen + provider with zero references to `CasDebugLogger`. Later tasks add the real row into the same file.

- [ ] **Step 1: Delete the logger file**

```bash
git rm lib/utils/cas_debug_logger.dart
```

- [ ] **Step 2: Remove the provider hook** — in `lib/provider/websocket_provider.dart`, delete the `import '../utils/cas_debug_logger.dart';` (line 26) and the guarded record block in `_handleWebSocketMessage` (the comment lines ~902–903 plus `CasDebugLogger.record(res as Map);` ~909). Leave all surrounding routing logic exactly as it was before the instrument.

- [ ] **Step 3: Remove the depth-screen hooks** — in `scrip_depth_info_web.dart`, delete the `import '../../../utils/cas_debug_logger.dart';` (line 41), the `CasDebugLogger.setQuotes(depthData.toJson());` call (~820), and the whole debug button `Row`/widgets that reference `CasDebugLogger` (~884–921, the `CAS log: START/REC/DOWNLOAD` control that was added as the first child of the depth panel column).

- [ ] **Step 4: Verify no references remain**

Run: `grep -rn "CasDebugLogger\|cas_debug" lib/`
Expected: no matches.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/provider/websocket_provider.dart lib/screens/web/market_watch/scrip_depth_info_web.dart`
Expected: no NEW errors (pre-existing warnings elsewhere are fine).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(cas): remove temporary CAS-window debug logger"
```

---

### Task 2: `ic` model field + parse latch + pure display helper (with test)

**Files:**
- Create: `lib/utils/cas_indicative.dart`
- Test: `test/cas_indicative_test.dart`
- Modify: `lib/models/marketwatch_model/get_quotes.dart` (add `ic` field: decl near line 87–88, ctor near 171–172, `fromJson` near 255–256, `toJson` near 341–342)
- Modify: `lib/screens/web/market_watch/scrip_depth_info_web.dart` (latch `socketData['ic']` in `_processDepthData` near line 330)

**Interfaces:**
- Produces: `String casIndicativeDisplay(String? ic)` → `'₹<ic>'` for a valid positive value, else `'—'`; consumed by Task 3's row. `GetQuotes.ic` (`String?`) populated from the feed.

- [ ] **Step 1: Write the failing test**

```dart
// test/cas_indicative_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/utils/cas_indicative.dart';

void main() {
  test('casIndicativeDisplay formats a valid price', () {
    expect(casIndicativeDisplay('1316.00'), '₹1316.00');
  });
  test('casIndicativeDisplay is a dash for null/empty/zero', () {
    expect(casIndicativeDisplay(null), '—');
    expect(casIndicativeDisplay(''), '—');
    expect(casIndicativeDisplay('0'), '—');
    expect(casIndicativeDisplay('0.00'), '—');
    expect(casIndicativeDisplay('null'), '—');
  });
}
```

- [ ] **Step 2: Run it, verify it FAILS**

Run: `flutter test test/cas_indicative_test.dart`
Expected: FAIL (target of URI doesn't exist / `casIndicativeDisplay` undefined).

- [ ] **Step 3: Implement the helper**

```dart
// lib/utils/cas_indicative.dart
/// Display string for the Closing-Auction-Session indicative price (feed `ic`).
/// Returns the rupee-formatted value only when [ic] is a real positive price;
/// otherwise an em dash (no auction / not eligible / not sent).
String casIndicativeDisplay(String? ic) {
  if (ic == null) return '—';
  final s = ic.trim();
  if (s.isEmpty || s == 'null') return '—';
  final v = double.tryParse(s);
  if (v == null || v <= 0) return '—';
  return '₹$s';
}
```

- [ ] **Step 4: Run the test, verify it PASSES**

Run: `flutter test test/cas_indicative_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Add `ic` to the `GetQuotes` model** — in `lib/models/marketwatch_model/get_quotes.dart`:
  - Field declaration, next to `chng`/`pc` (~line 87): `String? ic;`
  - Constructor param, next to `this.pc` (~line 172): `this.ic,`
  - `fromJson`, next to `pc = json['pc'];` (~line 256): `ic = json['ic'];`
  - `toJson`, next to `data['pc'] = pc;` (~line 342): `data['ic'] = ic;`

- [ ] **Step 6: Latch `ic` from the socket** — in `scrip_depth_info_web.dart` `_processDepthData` (after the `tbq`/`tsq` lines ~330), add:

```dart
// CAS indicative equilibrium price. Delta field — only present during an
// auction (pre-open / closing). Latch when valid so idle frames don't clear it.
if (_isValidValue(socketData['ic'])) depthData.ic = "${socketData['ic']}";
```

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/utils/cas_indicative.dart lib/models/marketwatch_model/get_quotes.dart lib/screens/web/market_watch/scrip_depth_info_web.dart`
Expected: no NEW errors.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(cas): parse feed ic field into GetQuotes + display helper"
```

---

### Task 3: Render the CAS indicative-price row in both depth layouts

**Files:**
- Modify: `lib/screens/web/market_watch/scrip_depth_info_web.dart` (add the row below the Total Buy/Sell Qty row in BOTH layouts — the compact panel ~after line 679 and the expanded layout ~after line 2144/2255)

**Interfaces:**
- Consumes: `casIndicativeDisplay(depthData.ic)` from Task 2.

- [ ] **Step 1: Add a private row builder** to the depth widget's State/class (place near the other `_build...` helpers in the file):

```dart
Widget _buildCasIndicativeRow(BuildContext context, ThemeData theme) {
  final value = casIndicativeDisplay(depthData.ic);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        // Solid CAS badge — colored, white text (chip convention).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: resolveThemeColor(context, dark: MyntColors.primary, light: MyntColors.primary),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('CAS',
              style: MyntWebTextStyles.caption(context,
                  fontWeight: MyntFonts.semiBold, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Text('Indicative Close',
            style: MyntWebTextStyles.body(context,
                fontWeight: MyntFonts.medium,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary))),
        const Spacer(),
        Text(value,
            style: MyntWebTextStyles.body(context,
                fontWeight: MyntFonts.semiBold,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary))),
      ],
    ),
  );
}
```
Note: if `MyntWebTextStyles.caption` or the exact color tokens differ in this file, match the tokens already used by the adjacent Total Buy/Sell Qty widgets (they use `MyntWebTextStyles.body` + `MyntColors.textSecondary`/`textSecondaryDark`); keep the badge solid + white text regardless.

- [ ] **Step 2: Insert the row in the compact layout** — after the Total Buy/Sell Qty block (the widget ending around line 679, before the percentage bar `if (...)` at 679), add `_buildCasIndicativeRow(context, theme)` to the same `Column`'s children.

- [ ] **Step 3: Insert the row in the expanded layout** — in the second depth layout (~lines 2050–2255), after its Total Buy/Sell Qty block, add the same `_buildCasIndicativeRow(context, theme)` call to that layout's column.

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/screens/web/market_watch/scrip_depth_info_web.dart`
Expected: no NEW errors.

- [ ] **Step 5: Manual verification (record in report; not a blocking gate)**
  - Idle (any scrip, market closed / non-auction): the row shows `[CAS] Indicative Close  —`.
  - During a live auction on a CAS-eligible equity (3:20–3:35 close or 9:00–9:08 pre-open): the row shows `[CAS] Indicative Close  ₹<price>` and updates as `ic` changes.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(cas): show CAS indicative-price row in depth panel (both layouts)"
```

---

## Self-Review

**Spec coverage:** `ic` source + latch → Task 2; always-present row + `CAS` badge + `—` idle → Task 3; debug-logger removal → Task 1; web-only + branch-off-main → Global Constraints. All covered.

**Placeholder scan:** none — every code step carries real code. The only approximate items are the line numbers (anchors move as the file changes); the surrounding-code snippets identify the true site.

**Type consistency:** `casIndicativeDisplay(String?)` defined in Task 2, consumed in Task 3; `GetQuotes.ic` is `String?` throughout (matches sibling fields `pc`/`chng`); `depthData.ic` read only after Task 2 adds it.

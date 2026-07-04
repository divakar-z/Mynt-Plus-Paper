# Chart Engine — Phase 6 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Single global toggle `Instant orders` in the per-pane Settings popup. When ON: cancel ×, square-off ×, drag-to-modify release, and `+` menu placements (BuyLimit / SellSL-MKT / SellSL-LMT) fire the corresponding API directly with no confirm dialog and no PlaceOrderScreen launch. OFF by default. First OFF→ON flip shows a one-time warning dialog; subsequent toggles don't re-prompt. Top-bar `⚠ INSTANT` badge while ON.

**Architecture:** Two new session-level booleans (`instantOrders`, `instantWarningAck`) persisted alongside `layout` / `panes` in `chartEngineSessionV1`. Five branch points in the shell screen read `session.instantOrders` and either fire the existing dialog/screen path or the API-direct path. The API-direct path for placement uses a new `buildPlaceOrderInput(...)` helper (mirror of `buildOrderScreenArgs`) that produces a typed `PlaceOrderInput`. No iframe / bridge changes.

**Tech Stack:** Flutter (Riverpod 3, pointer_interceptor). No JS.

---

## Project conventions

- **No git commits in plan steps.**
- **Static gates after every code edit:** `flutter analyze lib/screens/web/chart_engine` for Dart. (No JS changes.) Don't move on if errors related to your changes.
- **Spec reference:** `docs/superpowers/specs/2026-05-25-chart-engine-phase6-design.md`.
- **Reuse Phase 3-5 patterns:** `_showIframeSafeDialog` from `overlay_close_dialog.dart` for the first-enable warning; existing `showCloseOrderDialog` / `showSquareOffDialog` / `showModifyOrderDialog` for confirm-mode paths.
- **Chip styling rule still applies** to the new `⚠ INSTANT` badge: solid colour bg + white text, no transparency.

## File map

### Modified (Flutter)
| Path | What changes |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | `ChartEngineSession.instantOrders` + `instantWarningAck` fields (defaults `false`) + `copyWith` + `toJson` + `fromJson`; notifier methods `setInstantOrders(bool)` + `markInstantWarningAck()`. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | `_SettingsButton` popup gets a divider + `Instant orders` toggle row + warning sub-text; OFF→ON flow gated on `showInstantWarningDialog`; new `_InstantBadge` widget appended to the top-bar `Wrap`. |
| `lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart` | New `Future<bool> showInstantWarningDialog(...)` helper using `_showIframeSafeDialog`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | Five branch points read `session.instantOrders`: cancel ×, square-off ×, drag-end, `+` menu pick (non-blank). |
| `lib/screens/web/chart_engine/state/place_order_prefill.dart` | New helper `buildPlaceOrderInput(...)` mirroring `buildOrderScreenArgs` but producing a typed `PlaceOrderInput` ready for the place-order API. |

No JS changes. No new files.

---

## Task ordering

1. **Group A — Session state.** Add the two boolean fields + setters + persistence.
2. **Group B — Toggle UI + warning dialog + badge.** Settings popup row, warning dialog, top-bar badge.
3. **Group C — Instant branches.** Five shell-screen branches that bypass dialogs/screen when instant is ON.
4. **Group D — Static gate + smoke.**

---

# Group A — Session state

End state: `chartEngineSessionProvider` exposes `instantOrders` (bool) + `instantWarningAck` (bool); setters persist; reload preserves.

---

### Task A1: Add fields + setters to `ChartEngineSession`

**Files:**
- Modify: `lib/screens/web/chart_engine/state/chart_engine_store.dart`

- [ ] **Step 1: Add fields + constructor params**

Find the existing `ChartEngineSession` class. Add `instantOrders` + `instantWarningAck` to fields, constructor (with `false` defaults), `copyWith`, `toJson`, `fromJson`:

```dart
class ChartEngineSession {
  final ChartLayout layout;
  final int activePaneIndex;
  final List<PaneState> panes;
  final bool instantOrders;       // NEW
  final bool instantWarningAck;   // NEW

  const ChartEngineSession({
    this.layout = ChartLayout.single,
    this.activePaneIndex = 0,
    this.panes = const [PaneState()],
    this.instantOrders = false,
    this.instantWarningAck = false,
  });

  PaneState get active => panes[activePaneIndex];

  ChartEngineSession copyWith({
    ChartLayout? layout,
    int? activePaneIndex,
    List<PaneState>? panes,
    bool? instantOrders,
    bool? instantWarningAck,
  }) =>
      ChartEngineSession(
        layout: layout ?? this.layout,
        activePaneIndex: activePaneIndex ?? this.activePaneIndex,
        panes: panes ?? this.panes,
        instantOrders: instantOrders ?? this.instantOrders,
        instantWarningAck: instantWarningAck ?? this.instantWarningAck,
      );

  ChartEngineSession copyWithPane(int index, PaneState next) {
    if (index < 0 || index >= panes.length) return this;
    final m = List<PaneState>.from(panes);
    m[index] = next;
    return copyWith(panes: m);
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'layout': layout.id,
        'activePaneIndex': activePaneIndex,
        'panes': [for (final p in panes) p.toJson()],
        'instantOrders': instantOrders,
        'instantWarningAck': instantWarningAck,
      };

  static ChartEngineSession fromJson(Map<String, dynamic> j) {
    final layout = ChartLayout.fromId(j['layout'] as String? ?? 'single') ??
        ChartLayout.single;
    final activePaneIndex = (j['activePaneIndex'] as num?)?.toInt() ?? 0;
    final rawPanes = (j['panes'] as List?) ?? const [];
    final parsedPanes = <PaneState>[
      for (final p in rawPanes) PaneState.fromJson(p as Map<String, dynamic>),
    ];
    final panes = List<PaneState>.generate(
      layout.paneCount,
      (i) => i < parsedPanes.length ? parsedPanes[i] : const PaneState(),
    );
    return ChartEngineSession(
      layout: layout,
      activePaneIndex: activePaneIndex.clamp(0, panes.length - 1),
      panes: panes,
      instantOrders: j['instantOrders'] as bool? ?? false,
      instantWarningAck: j['instantWarningAck'] as bool? ?? false,
    );
  }
}
```

- [ ] **Step 2: Add notifier methods**

Inside `ChartEngineSessionNotifier`, alongside existing setters (next to `setPaneOverlays`):

```dart
void setInstantOrders(bool enabled) {
  if (enabled == state.instantOrders) return;
  state = state.copyWith(instantOrders: enabled);
  _schedulePersist();
}

void markInstantWarningAck() {
  if (state.instantWarningAck) return;
  state = state.copyWith(instantWarningAck: true);
  _schedulePersist();
}
```

- [ ] **Step 3: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/state/chart_engine_store.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

# Group B — Toggle UI + warning dialog + badge

End state: Settings popup has the third toggle row; OFF→ON triggers warning dialog; top bar shows `⚠ INSTANT` badge while ON; tapping badge opens Settings.

---

### Task B1: Add `showInstantWarningDialog` helper

**Files:**
- Modify: `lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart`

- [ ] **Step 1: Append the helper at the bottom of the file**

```dart
/// One-time warning shown when the user first enables Instant orders.
/// Returns true if the user clicks Enable, false otherwise.
Future<bool> showInstantWarningDialog({
  required BuildContext context,
}) async {
  bool result = false;
  await _showIframeSafeDialog<void>(
    context: context,
    child: AlertDialog(
      title: const Text('Enable instant orders?'),
      content: const Text(
          'Mutations (cancel, square-off, drag-modify, quick-place) will '
          'fire immediately on click. There will be no second chance to '
          'back out.'),
      actions: [
        Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        )),
        Builder(builder: (ctx) => FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
          onPressed: () {
            result = true;
            Navigator.of(ctx).pop();
          },
          child: const Text('Enable'),
        )),
      ],
    ),
  );
  return result;
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task B2: Add the toggle row to Settings popup + `_InstantBadge` to top bar

**Files:**
- Modify: `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`

- [ ] **Step 1: Add the import for `showInstantWarningDialog`**

At the top:

```dart
import 'package:mynt_plus/screens/web/chart_engine/widgets/overlay_close_dialog.dart';
```

- [ ] **Step 2: Add the toggle row inside `_SettingsButton`'s popup**

Find the existing rows section in `_SettingsButton`'s popup builder (the part with `_ToggleRow` for Gridlines and Volume). Append AFTER the Volume `_ToggleRow`:

```dart
const SizedBox(height: 6),
const Divider(height: 1),
const SizedBox(height: 6),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
  child: Row(children: [
    Expanded(child: Text('Instant orders',
        style: MyntWebTextStyles.body(context))),
    Switch(
      value: session.instantOrders,
      onChanged: (v) async {
        if (v && !session.instantWarningAck) {
          final ok = await showInstantWarningDialog(context: context);
          if (!ok) return;
          ref
              .read(chartEngineSessionProvider.notifier)
              .markInstantWarningAck();
        }
        ref
            .read(chartEngineSessionProvider.notifier)
            .setInstantOrders(v);
      },
    ),
  ]),
),
if (!session.instantOrders)
  Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
    child: Text(
        '⚠ skips confirm for cancels, square-offs, drags & quick place',
        style: MyntWebTextStyles.caption(context,
            color: resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary))),
  ),
```

The `session` variable referenced here must already be in scope inside the popup builder — if not, add at the top of the popup builder:

```dart
final session = ref.watch(chartEngineSessionProvider);
```

(If the existing builder already reads `session` via a slightly different name, use that.)

- [ ] **Step 3: Add `_InstantBadge` widget at the bottom of the file**

```dart
class _InstantBadge extends ConsumerWidget {
  final VoidCallback onTap;
  const _InstantBadge({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(chartEngineSessionProvider
        .select((s) => s.instantOrders));
    if (!on) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('⚠ INSTANT',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11)),
      ),
    );
  }
}
```

- [ ] **Step 4: Place the badge as the LAST child of the top-bar `Wrap`**

In `ChartEngineTopBar.build`, find the `Wrap` whose children include `LayoutPicker`, Symbol Row, Timeframe Row, `_SettingsButton`. Append:

```dart
_InstantBadge(
  onTap: () {
    // Reuses the Settings button's open mechanism — for now we just
    // surface this hint and let the user click Settings manually.
    // (A direct wire-up would require a GlobalKey on _SettingsButton.)
  },
),
```

If you can easily wire it to programmatically open the Settings popup (e.g., via a `GlobalKey<_SettingsButtonState>`), do so. Otherwise the onTap can be a no-op for Phase 6; the badge's purpose is visual indication, and the Settings button is right next to it.

- [ ] **Step 5: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

# Group C — Instant branches

End state: when `session.instantOrders` is true, all four mutation paths bypass their dialogs/screens and fire the API directly.

---

### Task C1: Add `buildPlaceOrderInput(...)` to `place_order_prefill.dart`

**Files:**
- Modify: `lib/screens/web/chart_engine/state/place_order_prefill.dart`

- [ ] **Step 1: Append the helper at the bottom**

```dart
import 'package:flutter/foundation.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';

/// Builds a typed `PlaceOrderInput` for instant-mode placement from the
/// chart `+` menu. Mirror of `buildOrderScreenArgs` minus the
/// ScripInfoModel — we only need the order side itself.
///
/// `deviceInfo` should come from `ref.read(authProvider).deviceInfo`.
PlaceOrderInput buildPlaceOrderInput({
  required ChartScrip scrip,
  required int qty,
  required OrderPrefillKind kind,
  required double price,
  required Map<String, dynamic> deviceInfo,
}) {
  String prctype = 'LMT';
  bool isBuy = true;
  double? prc = price;
  double? trgprc;
  switch (kind) {
    case OrderPrefillKind.buyLimit:
      prctype = 'LMT'; isBuy = true; prc = price; break;
    case OrderPrefillKind.sellLimit:
      prctype = 'LMT'; isBuy = false; prc = price; break;
    case OrderPrefillKind.buyStopMkt:
      prctype = 'SL-MKT'; isBuy = true; prc = null; trgprc = price; break;
    case OrderPrefillKind.sellStopMkt:
      prctype = 'SL-MKT'; isBuy = false; prc = null; trgprc = price; break;
    case OrderPrefillKind.buyStopLmt:
      prctype = 'SL-LMT'; isBuy = true;
      trgprc = price;
      prc = price + scrip.ti;
      break;
    case OrderPrefillKind.sellStopLmt:
      prctype = 'SL-LMT'; isBuy = false;
      trgprc = price;
      prc = price - scrip.ti;
      break;
    case OrderPrefillKind.blank:
      // Should never be called for instant mode — the caller must filter.
      break;
  }

  final isEquity = scrip.exch == 'NSE' || scrip.exch == 'BSE';
  final prd = isEquity ? 'C' : 'M';
  final channel = defaultTargetPlatform == TargetPlatform.android
      ? '${deviceInfo["brand"]}'
      : '${deviceInfo["model"]}';

  return PlaceOrderInput(
    exch: scrip.exch,
    tsym: scrip.tsym,
    qty: qty.toString(),
    prc: (prc ?? 0).toStringAsFixed(2),
    prctype: prctype,
    trantype: isBuy ? 'B' : 'S',
    prd: prd,
    ret: 'DAY',
    trgprc: trgprc != null ? trgprc.toStringAsFixed(2) : '',
    blprc: '',
    bpprc: '',
    dscqty: '',
    amo: '',
    trailprc: '',
    mktProt: '',
    channel: channel,
    frzqty: 0,
  );
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/state/place_order_prefill.dart 2>&1 | tail -5`
Expected: `No issues found!`

(If `PlaceOrderInput`'s `frzqty` is non-nullable and 0 isn't accepted, set to the scrip's lot size as a safe default. If a different param signature, adjust.)

---

### Task C2: Branch the four shell mutation paths on `session.instantOrders`

**Files:**
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:mynt_plus/provider/auth_provider.dart';
import 'package:mynt_plus/api/core/api_export.dart'; // if not already imported
```

(Check if `auth_provider` and `place_order_model` are already imported — skip duplicates.)

- [ ] **Step 2: Branch cancel-order path**

Find `_handleOverlayCloseRequested` for orders. The existing implementation calls `showCloseOrderDialog`. Wrap it:

```dart
if (overlay.kind == 'limit' || overlay.kind == 'sl' || overlay.kind == 'sl-l') {
  // (existing order resolution)
  final order = /* ... */;
  if (order == null) return;
  final session = ref.read(chartEngineSessionProvider);
  if (session.instantOrders) {
    // Instant: skip dialog, fire cancel directly.
    await ref
        .read(orderProvider)
        .fetchOrderCancel(order.norenordno.toString(), context, false);
    return;
  }
  showCloseOrderDialog(context: context, ref: ref, order: order);
  return;
}
```

(Mirror the existing code path; the only addition is the `if (session.instantOrders)` branch BEFORE the showCloseOrderDialog call.)

- [ ] **Step 3: Branch square-off path**

In the position arm of `_handleOverlayCloseRequested`:

```dart
final session = ref.read(chartEngineSessionProvider);
if (session.instantOrders) {
  // Build the same PlaceOrderInput showSquareOffDialog builds, then fire.
  final ls = int.tryParse(position.ls ?? '1') ?? 1;
  final frz = int.tryParse(position.frzqty ?? '0') ?? 0;
  final frzqty = ls > 0 ? (frz ~/ ls) * ls : frz;
  final deviceInfo = ref.read(authProvider).deviceInfo;
  final channel = defaultTargetPlatform == TargetPlatform.android
      ? '${deviceInfo["brand"]}'
      : '${deviceInfo["model"]}';
  final qtyInt = int.tryParse(position.netqty ?? '0') ?? 0;
  final input = PlaceOrderInput(
    exch: position.exch ?? '',
    tsym: position.tsym ?? '',
    qty: (position.netqty ?? '0').replaceAll('-', ''),
    prc: '0',
    prctype: 'MKT',
    trantype: qtyInt < 0 ? 'B' : 'S',
    prd: position.prd ?? '',
    ret: 'DAY',
    trgprc: '', blprc: '', bpprc: '', dscqty: '', amo: '',
    trailprc: '', mktProt: '',
    channel: channel, frzqty: frzqty,
  );
  await ref
      .read(portfolioProvider)
      .fetchExitPosition(context, input, true, false);
  return;
}
showSquareOffDialog(context: context, ref: ref, position: position);
return;
```

You'll need an import for `defaultTargetPlatform` (`package:flutter/foundation.dart`).

- [ ] **Step 4: Branch drag-end (modify) path**

Find `_handleOverlayDragEnded`. Before calling `showModifyOrderDialog`:

```dart
final session = ref.read(chartEngineSessionProvider);
if (session.instantOrders) {
  // Same ModifyOrderInput construction as showModifyOrderDialog.
  final input = ModifyOrderInput(
    exch: order.exch ?? '',
    token: order.token ?? '',
    tsym: order.tsym ?? '',
    orderNum: order.norenordno ?? '',
    qty: order.qty ?? '0',
    dscqty: order.dscqty ?? '0',
    mktProt: order.mktProtection ?? '',
    prctyp: order.prctyp ?? '',
    prd: order.prd ?? '',
    trantype: order.trantype ?? '',
    ret: order.ret ?? 'DAY',
    blprc: order.blprc ?? '',
    bpprc: order.bpprc ?? '',
    prc: finalNewPrice.toStringAsFixed(2),
    trgprc: (newTrigger ?? finalNewPrice).toStringAsFixed(2),
  );
  await ref.read(orderProvider).fetchModifyOrder(input, context);
  return;
}
showModifyOrderDialog(
  context: context,
  ref: ref,
  order: order,
  newPrice: finalNewPrice,
  newTriggerPrice: newTrigger,
);
```

You'll need imports for `ModifyOrderInput`.

- [ ] **Step 5: Branch `+` menu place path**

Find `_openPlaceOrderScreen`. Add a branch BEFORE the screen launch for non-blank kinds:

```dart
Future<void> _openPlaceOrderScreen({
  required ChartScrip scrip,
  required int qty,
  required OrderPrefillKind kind,
  double? price,
}) async {
  final session = ref.read(chartEngineSessionProvider);

  // INSTANT MODE: skip the screen for non-blank kinds and place directly.
  if (session.instantOrders &&
      kind != OrderPrefillKind.blank &&
      price != null) {
    final deviceInfo = ref.read(authProvider).deviceInfo;
    final input = buildPlaceOrderInput(
      scrip: scrip,
      qty: qty,
      kind: kind,
      price: price,
      deviceInfo: deviceInfo,
    );
    // Fire via the existing place-order entry — match what the
    // PlaceOrderScreenWeb's submit path does. The canonical wrapper is
    // `orderProvider.fetchPlaceOrder` (or equivalent) — verify the exact
    // name; this is the place to wire to a real direct API path.
    await ref.read(orderProvider).fetchPlaceOrder(input, context);
    return;
  }

  // (Existing prefetch + screen launch logic — unchanged for blank or
  // confirm-mode.)
  var realInfo = _cachedScripInfo(scrip);
  /* ... rest of the existing method ... */
}
```

(Keep all the existing prefetch + `ResponsiveNavigation.toPlaceOrderScreen` logic intact in the non-instant path.)

- [ ] **Step 6: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -10`
Expected: `No issues found!`

If the analyzer can't find `orderProvider.fetchPlaceOrder`, grep for the correct method name (might be `placeOrderPopup`, `fetchPlaceOrder`, or similar) and use the canonical one. The existing `fetchExitPosition` in `portfolio_provider.dart` is a sibling — find what it actually calls underneath (`api.getPlaceOrder`) and use the matching `orderProvider` wrapper if one exists, or call the API directly if needed (with the ip / channel pattern).

---

# Group D — Static gate + smoke

---

### Task D1: Final static gates

- [ ] **Step 1: Flutter analyze**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -10`
Expected: `No issues found!`

- [ ] **Step 2: JS unchanged — quick syntax check just to be safe**

Run: `node --check web/chart-engine/chart-engine.js web/chart-engine/chart.js web/chart-engine/aggregator.js web/chart-engine/theme.js 2>&1`
Expected: no output.

---

### Task D2: Manual smoke (from spec §7)

Hard-reload and execute the 12-step smoke list in `docs/superpowers/specs/2026-05-25-chart-engine-phase6-design.md`. If everything passes, Phase 6 is done.

---

## Notes for the executing engineer

- **Do not commit.** User commits manually.
- **Settings popup builder reads `session`** — if it currently uses `ref.read` per access, add `final session = ref.watch(chartEngineSessionProvider);` at the top so the Switch reflects state changes (toggle ON then OFF must update the row immediately).
- **`fetchPlaceOrder` exact name** is the main "Pause and ask" item — grep `lib/provider/order_provider.dart` for the canonical direct-place-order method. If only the popup wrapper exists, you may need to wire to the lower-level `api.getPlaceOrder(input, ip)` directly (with `ref.read(orderProvider).ip` for the IP and the channel from `authProvider`).
- **`_InstantBadge` onTap** is allowed to be a no-op in Phase 6 if wiring it to programmatically open the Settings popup is fiddly — the badge's primary job is visibility, not opening anything. Phase 7+ can refine.
- The first-enable warning dialog flow must work both directions: clicking the Switch OFF→ON must show the dialog; clicking ON→OFF must NOT show it. The Switch's `onChanged` handler in B2 step 2 already covers this.

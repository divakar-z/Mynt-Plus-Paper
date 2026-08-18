# Popout Chart (Detached Chart Window) — Design

**Date:** 2026-06-24
**Status:** Approved design (pre-implementation)
**Scope:** v1 — view-only detached chart window fed by the alternate `ws.zebull.in` feed.

## Goal

Let a user "pop out" the in-house chart into a **separate, independent browser
window** — a full standalone chart (own symbol search, timeframe, chart type,
drawings, indicators) that is **view-only** (no trading), fed by a **different
websocket** than the main app so it never collides with the app's primary
broker socket.

## Key constraints (from the product owner)

1. **Do not reuse the app's current websocket** (`wss://go.mynt.in/NorenWSWeb/`,
   `websocket_provider.dart`). The Noren broker socket is effectively one active
   connection per session; a popout must not fight it.
2. **Use the alternate feed** `wss://ws.zebull.in/NorenWS/` (as used by the
   separate "Indicate" project's Python sidecar), which has a **different login
   mechanism** (a per-uid socket-session token, not the REST `jKey`).
3. **Per-popout identity:** the feed `uid` gets a numeric suffix — `_1` for the
   first popout, `_2` for the second, etc. — so each popout is a distinct feed
   connection that collides with neither the main app nor other popouts.
4. **History (TPSeries) and symbol search (SearchScrip)** use the **current
   login's `jKey` + `uid`** (the normal app session), not the feed token.
5. **Session-expiry:** if any API returns the session-expired error, do NOT
   allow access — show a "Session expired" popup and block the popout.

## Reference: the alternate feed (from `d:/Vijay/Indicate/sidecar`)

- **Feed URL:** `wss://ws.zebull.in/NorenWS/`
- **Mint socket token:** `POST https://sess.mynt.in/generateSocketSession`
  body `{ "uid": "<uid>_TA", "src": "TV", "source": "TV" }` → `{ "session": "<token>" }`.
  No password / api-key / jKey required — just the (suffixed) uid. Returns `''`
  on failure (Indicate falls back to the REST token).
- **Connect handshake:** `{ "t":"c", "uid":"<uid>_TA_TV", "actid":"<uid>_TA_TV",
  "source":"TV", "susertoken":"<token>" }` (ack frame `t:"ck"`).
- **Subscribe touchline:** `{ "t":"t", "k":"<exch>|<token>#<exch>|<token>…" }`.
- **Unsubscribe touchline:** `{ "t":"u", "k":"<exch>|<token>…" }`.
- **Tick frames:** `t` in `{tf,tk,df,dk}`, `tk` = token, `lp` = last price,
  `bp1`/`sp1` = best bid/ask (level-1 depth on the touchline; no separate depth
  sub). Delta frames omit unchanged fields.
- This is the **same Noren touchline shape** the chart engine already ingests,
  so no adapter rewrite — lp-only frames get synthesized `v=0`/`ft=now` exactly
  like the app already treats indices.

Indicate's own identity is `<uid>_TA` (mint) / `<uid>_TA_TV` (connect); our
popout generalizes this with a per-window index `n` (see §7).

## Architecture

A **standalone, same-origin popout page** at `web/chart-popout/` — **no Flutter
in the popout**. It embeds the existing chart-engine **iframe verbatim** and
drives it with a small JS "shell" that performs the same duties the Flutter
shell performs today (forward ticks, fulfill history requests, set symbol), but
sourced from the alternate feed. **No changes to the chart engine.**

```
Main window (Flutter app)
   │  "Pop out" button → window.open('/chart-popout/?exch=..&token=..&tsym=..&tf=5&n=1')
   ▼
Popout window (standalone page, same origin)
   ├─ reads localStorage: flutter.clientSession (jKey), flutter.clientId (uid), flutter.userAppTheme
   ├─ chart-engine iframe (unchanged: chart.js, chart-engine.js, aggregator.js, …)
   └─ popout-shell.js (the parent-bridge driver):
        • mint socket token (generateSocketSession, uid = <uid>_<n>_TA)
        • connect ws.zebull.in → subscribe → forward ticks via encodeTick bridge msg
        • fulfill engine requestHistory via TPSeries (jKey/uid)
        • symbol search via SearchScrip (jKey/uid) → setPaneSymbol
        • session-expiry overlay; reconnect + resubscribe discipline
```

**Chosen approach (A/C):** standalone page + reused engine iframe + JS shell
speaking the existing `postMessage` bridge. Rejected: (B) reloading the whole
Flutter app per popout — heavy startup/memory, more new Dart code, no benefit
here.

## Files

All new; the chart engine is untouched.

- `web/chart-popout/index.html` — hosts the chart-engine iframe + a slim symbol
  search box; theme bootstrap reading `flutter.userAppTheme` (mirrors
  `web/lite/index.html`). Includes `popout-shell.js`.
- `web/chart-popout/popout-shell.js` — the shell: session bootstrap,
  socket-session mint, `ws.zebull.in` client (connect/reconnect/subscribe),
  tick→bridge forwarding, TPSeries + SearchScrip, session-expiry overlay,
  `_N` slot handling.
- Flutter side: a **"Pop out" control** on the chart toolbar that allocates the
  next free popout index `n` and calls `window.open('/chart-popout/?…')` with
  the current pane's `exch/token/tsym/timeframe`.
- Hosting: a firebase rewrite so `/chart-popout/**` serves the popout page
  (parallel to the existing `/OAuthlogin/**` → `/lite/index.html` rewrite), and
  the existing `chart-engine/**` no-cache header already covers the reused JS.

## §3 Session & config (hybrid: config in URL, secret from localStorage)

- **URL params (non-sensitive):** `exch`, `token`, `tsym`, `tf` (timeframe
  minutes), `n` (popout index).
- **Secret from `localStorage` (same-origin):** `jKey` from `flutter.clientSession`,
  `uid` from `flutter.clientId` — read + `JSON.parse` (shared_preferences_web
  stores JSON-encoded strings, as the lite page does for `userAppTheme`). The
  jKey is **never** placed in the URL (avoids history/address-bar/access-log/
  Referer exposure of a live trading session key).
- If `jKey` or `uid` is missing/empty → show the "Session expired / sign in"
  overlay and do not render the chart.

## §4 Live feed — connection, reconnection & subscription state

- **Mint per-popout token:** `POST generateSocketSession` with
  `{uid:"<uid>_<n>_TA", src:"TV", source:"TV"}` → `session`.
- **Connect:** `wss://ws.zebull.in/NorenWS/`, send
  `{t:"c", uid:"<uid>_<n>_TA_TV", actid:"<uid>_<n>_TA_TV", source:"TV",
  susertoken:<session>}`.
- **On `ck` ack:** subscribe the currently-tracked token(s) via `{t:"t", k:…}`.
- **Ticks:** normalize `tf/tk/df/dk` (`tk/lp/bp1/sp1`) to the engine's tick shape
  (lp-only → synth `v=0`, `ft=now`, like indices), forward via the existing
  `encodeTick` bridge message to the iframe.

**Single active socket; close-before-connect.** Exactly one live socket
reference at a time. Any reconnect first fully tears down the old socket (detach
handlers, clear reference, `close()`) before opening a new one — never an
overlapping/zombie socket double-feeding or double-subscribing.

**Reconnect path** (on close / error / stall-watchdog force-close):
1. Mark current socket dead, detach handlers, close it.
2. Backoff (1s, capped), then **re-mint** the socket token (it may have expired)
   and open a fresh socket.
3. On `ck` → **re-subscribe the tracked token set** (`{t:"t", k:…}`).
4. **Ignore frames from any socket that is not the current one** — a slow-dying
   old socket must never mutate state.

**Stall watchdog** (mirrors Indicate's ~10s rule): socket open but ticks stopped
→ force-close → clean reconnect above.

**Subscription = one source of truth.** The shell keeps the current subscribed
token set (v1: a single symbol). All (un)subscribe goes through one helper that
updates the set and guards duplicates:
- **Symbol change:** unsubscribe old (`{t:"u", k:"exch|token"}`) → subscribe new
  (`{t:"t", k:"exch|token"}`) → update set.
- **Reconnect:** re-subscribe exactly the tracked set (no duplicates).
So the tracked set and the wire never drift; no leaks, no dup subs, no
stale-socket writes.

## §5 History & symbol search (current session)

- **History:** the engine requests candles over the bridge
  (`requestHistory` → `onHistoryResult`), unchanged. The shell fulfills it with
  `POST https://go.mynt.in/NorenWClientWeb/TPSeries`, body
  `{uid, exch, token, st, et, intrv}` + `&jKey=<jKey>`, parsing
  `ssboe/into/inth/intl/intc/intv`, and posts candles back. Same endpoint/shape
  the app uses today, so aggregation/bucketing is unchanged.
- **Search:** the popout page's search box calls
  `https://ws.mynt.in/search/SearchScrip` (current session). Picking a result
  sets the pane symbol via the bridge (`setPaneSymbol`/`applyActiveSymbol`) and
  re-subscribes the feed to the new token — the popout's independent symbol
  control.

## §6 Session-expiry handling

- One shared detector: any REST reply that is `stat:"Not_Ok"` with `emsg`
  containing "session" (TPSeries / SearchScrip / generateSocketSession) → show a
  **blocking "Session expired — sign in again in the main window"** overlay,
  stop the feed, freeze the chart. No auto re-login (the popout can't re-auth).
- The same overlay covers: missing session in localStorage, and the feed WS
  being rejected/closed on auth.

## §7 Popout lifecycle & `_N` allocation

- The opener keeps a small **active-index registry** in `localStorage` (e.g.
  `popoutSlots = [1,2]`). On "pop out": pick the lowest free integer `n`, add it,
  open `/chart-popout/?…&n=<n>`.
- On popout `beforeunload`: it removes its own `n` from the registry (closing
  popout 1 frees slot 1 for reuse). Monotonic fallback if the registry is
  unreadable.
- Each popout is a fully independent window (own symbol, timeframe, chart type,
  drawings, indicators). Drawings/indicators live in the engine's in-memory
  state; **v1 does not persist them back to the main app** (a popout is a
  throwaway view — persistence can be added later).
- **v1 = single pane per popout.** Open multiple popouts for multiple charts;
  multi-pane-in-popout is a later add.

## §8 Out of scope (v1)

- No trading (no Buy/Sell, orders, OCO, instant mode).
- No order / position / alert lines (the popout has no order-management feed —
  `ws.zebull.in` is market data only).
- No multi-pane in a popout; no drawing persistence back to the app; no Lab
  features that need extra feeds.
- The popout is **view + draw + indicators** only.

## §9 Testing

- **Unit (pure JS):** tick normalization (`tf/tk/df/dk` → engine shape, lp-only
  synth); `_N` uid builder; session-expiry detector; `_N` slot allocate/free.
- **Manual / integration:**
  - Open popout → candles load (TPSeries) + live ticks flow (ws.zebull.in).
  - Open a 2nd popout → both stream independently AND the main app keeps
    streaming (no collision; distinct `_N` identities).
  - Change symbol/timeframe in the popout → unsubscribe old + subscribe new;
    history reloads.
  - Kill the feed socket (or simulate a stall) → clean close + reconnect +
    re-subscribe the current symbol.
  - Force a bad/blank jKey → session-expired overlay; chart blocked.
  - Close popout → its slot is freed for reuse.

## Open risks / to verify at implementation

1. **Suffixed-uid acceptance:** confirm `generateSocketSession` mints for
   `<uid>_<n>_TA` and that `ws.zebull.in` accepts `<uid>_<n>_TA_TV` as a distinct
   identity (Indicate's docstring says each uid gets its own session, so this is
   expected — but verify with a real 2-popout test).
2. **CORS:** confirm `sess.mynt.in/generateSocketSession`, `go.mynt.in/TPSeries`,
   and `ws.mynt.in/SearchScrip` allow browser (XHR/fetch) calls from the app
   origin. The main app already calls TPSeries/SearchScrip, so those are fine;
   `generateSocketSession` is the new one to confirm from the browser (Indicate
   calls it server-side).
3. **localStorage key encoding:** verify the exact JSON encoding of
   `flutter.clientSession` / `flutter.clientId` (plain JSON string vs. a typed
   prefix in newer shared_preferences_web) and parse accordingly.

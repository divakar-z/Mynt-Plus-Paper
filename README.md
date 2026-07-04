# Mynt Plus Web application

A Flutter Web trading application. This README focuses on the **web fast-login
architecture** and the **build/deployment process**. For the broader app overview
see [CLAUDE.md](CLAUDE.md).

---

## Web Fast-Login Architecture

### Why this exists

The login page doubles as an **OAuth/auth gateway** for partner apps: users are
redirected here only to authenticate and bounce back. Booting the full Flutter app
just to show a login form cost **~2.9 s on a cold load** (CanvasKit + ~2 MB JS +
fonts all gate the first frame), which frustrated users who only wanted to log in.

The fix is a **standalone HTML/CSS/JS lite login page** that renders in **~0.7 s
cold / ~0.1 s warm**, while the full Flutter app is prefetched in the background so
the post-login handoff is near-instant.

> **Current testing scope:** the lite page is wired up for the **OAuth gateway
> only**. Normal users (bare root `/` and `/login`) go through the standard Flutter
> login. To roll the lite page out to **all** users, see
> [Enabling the lite page for all users](#enabling-the-lite-page-for-all-users).

### Entry flow

_The diagram below shows the **full-rollout** design. In the current OAuth-only
scope, only the `/OAuthlogin/**` branch is active — `/login` and bare-root requests
go straight to Flutter._

```
                         ┌─────────────────────────────────────────────┐
  User hits  ──────────► │  Firebase Hosting (serves build/web)         │
                         └─────────────────────────────────────────────┘
                                     │
        ┌────────────────────────────┼─────────────────────────────┐
        │                            │                              │
   GET /login                  GET /OAuthlogin/**              GET /  (bare root)
   GET (rewrite)               (rewrite)                       served static index.html
        │                            │                              │
        ▼                            ▼                              ▼
  /lite/index.html            /lite/index.html            web/index.html PRE-BOOT GATE:
  (lite login)                (lite login, OAuth          • ?uid=&token=  → boot Flutter (handoff)
        │                      consent mode)              • clientSession → boot Flutter (logged in)
        │                            │                    • otherwise     → redirect to /login (lite)
        │                            │
        │  user logs in              │  user authorizes
        ▼                            ▼
  location.replace(             form POST to partner
   /?uid=&token= )              redirect_uri
        │
        ▼
  Flutter boots WARM (main.dart.js + canvaskit + fonts already prefetched) → dashboard
```

### What was implemented

| # | Change | File(s) |
|---|--------|---------|
| 1 | **Lite login page** — self-contained HTML/CSS/JS with full parity: login (+ saved-account), OTP/TOTP (incl. TOTP setup), forgot-password, change-password (SHA-256), QR polling, OAuth consent. Theme parity by reading `localStorage['flutter.userAppTheme']` (defaults Light, matching the app; does **not** follow OS). | [web/lite/index.html](web/lite/index.html) |
| 2 | **Pre-boot auth gate** *(not active in OAuth-only scope)* — a tiny synchronous script for the Flutter `index.html` that redirects logged-out bare-root visitors to the lite login *before* the engine boots (handoff/authenticated sessions fall through). Removed for now so normal users use the Flutter login; re-add to roll out to all users (commit `fb04e423`). | [web/index.html](web/index.html) |
| 3 | **Hosting rewrites** — `/OAuthlogin/**` → `/lite/index.html`; everything else (incl. `/login` and bare root) → the Flutter `/index.html`. *(Full rollout also rewrites `/login` → lite.)* | [firebase.json](firebase.json) |
| 4 | **Background Flutter prefetch** — during the login interaction the lite page warms the entire first-frame critical path: `main.dart.js`, the correct CanvasKit variant (`chromium/` on Chromium browsers, base otherwise), `AssetManifest.bin`, and every font in `FontManifest.json` (read dynamically). Same-origin, `rel=prefetch`/`fetch()` at lowest priority. | [web/lite/index.html](web/lite/index.html) |
| 5 | **Web font pruning** — post-build script removes fonts CanvasKit would otherwise download before the first frame: shadcn Geist/GeistMono italics + off weights, plus families verified unused on web (`InterVariable`, `GeistMono`, `syncfusion_flutter_datagrid` icons). **Web build only** — pubspec/dependencies are untouched, so mobile is unaffected. | [tool/prune_web_fonts.py](tool/prune_web_fonts.py) |
| 6 | **CanvasKit self-hosting** — `canvasKitBaseUrl: "canvaskit/"` so the renderer loads from our origin (HTTP/2-multiplexed) instead of `gstatic.com`. Service-worker registration kept. Render-blocking third-party scripts (digio) removed from the critical path. | [web/flutter_bootstrap.js](web/flutter_bootstrap.js), [web/index.html](web/index.html) |

### Measured impact (live A/B: full Flutter vs lite)

| Metric | Full Flutter login | Lite login |
|---|---|---|
| Time to interactive form (cold) | ~2,882 ms | **~680 ms** |
| Time to interactive form (warm) | ~980 ms | **~92 ms** |
| Critical-path bytes to show login | ~4.7 MB | **~0.2 MB** |

After login the engine boots from the prefetch cache (main.dart.js / canvaskit /
fonts served at 0 bytes when the prefetch completed). Font pruning further trimmed
the prefetch from ~5.5 MB to ~4.36 MB and lightens every cold Flutter load.

> **Note:** the prefetch is best-effort — it races the user's login. On a slow
> connection a very fast login can finish before the ~4.36 MB completes, in which
> case the remainder downloads after login (no worse than before).

### Enabling the lite page for all users

The lite page is currently **OAuth-only**. To make it the default for **every**
login (the full-rollout design above):

1. **`firebase.json`** — add the `/login` rewrite *above* the `**` catch-all:
   ```json
   { "source": "/login", "destination": "/lite/index.html" },
   ```
2. **`web/index.html`** — re-add the pre-boot auth gate as the first `<script>` in
   `<head>`: redirect logged-out bare-root visitors to `/login` before the engine
   boots, while letting `?uid=&token=` handoffs and an existing
   `flutter.clientSession` fall through to Flutter. Exact snippet is in commit
   `fb04e423`.
3. Rebuild and deploy.

---

## Build & Deployment

Firebase Hosting serves the `build/web` directory (`"public": "build/web"`).
Everything below is produced by the **standard Flutter build** — there is no manual
copy step. The lite page lives in `web/lite/`, so `flutter build web` copies it to
`build/web/lite/` automatically (same mechanism as `web/icons`, `web/tv`, etc.).

### Process flow

```
  flutter pub get
        │
        ▼
  flutter build web --release
        │   produces build/web/ :
        │     • index.html            (templated, includes the pre-boot auth gate)
        │     • lite/index.html       (copied verbatim from web/lite/)
        │     • flutter_bootstrap.js  (CanvasKit self-hosted)
        │     • main.dart.js, canvaskit/, assets/ (incl. full FontManifest)
        ▼
  firebase deploy --only hosting --project <project>
        │   runs the predeploy hook first:
        │     python3 tool/prune_web_fonts.py build/web
        │       → strips unused fonts from build/web/assets/FontManifest.json + deletes files
        │   then uploads build/web with the rewrites + cache headers from firebase.json
        ▼
  Live
```

### Commands

```bash
# 1. Dependencies
flutter pub get

# 2. Production web build
flutter build web --release

# 3a. Deploy to the TEST project
firebase deploy --only hosting --project ekyc-web-test   # → https://ekyc-web-test.web.app

# 3b. Deploy to PRODUCTION (app.mynt.in) — use the production Firebase project
firebase deploy --only hosting --project <prod-project>
```

The predeploy font-prune runs automatically as part of `firebase deploy` (it is
idempotent and safe to re-run). To run it manually against a build:

```bash
python3 tool/prune_web_fonts.py build/web
```

### Notes & gotchas

- **Keep the lite page in `web/lite/`.** If it is moved back outside `web/`, the
  build will no longer include it and `/login` will 404 → fall through to the full
  Flutter app (slow), with no error.
- **Rewrite order matters** in `firebase.json`: the specific `/login` and
  `/OAuthlogin/**` rules must come *before* the `**` catch-all.
- **The bare root `/` cannot be rewritten to the lite page** — Firebase serves the
  static `index.html` before applying rewrites. That is why root entry is handled by
  the JS pre-boot gate inside `index.html`, not by a rewrite.
- **Font pruning is web-only.** `InterVariable` (and others) are still used on
  mobile; the prune edits only the built web `FontManifest.json`, never `pubspec.yaml`.
- The lite page must be served at the **site root origin** (its asset paths are
  absolute, e.g. `/main.dart.js`, `/assets/...`).

---

## Other developer docs

- [CLAUDE.md](CLAUDE.md) — full app/architecture overview
- [WEB_PERFORMANCE_ANALYSIS_REPORT.md](WEB_PERFORMANCE_ANALYSIS_REPORT.md) — first-load analysis
- [PERFORMANCE_OPTIMIZATION_SUMMARY.md](PERFORMANCE_OPTIMIZATION_SUMMARY.md)
- [WEB_BUILD_OPTIMIZATION.md](WEB_BUILD_OPTIMIZATION.md)

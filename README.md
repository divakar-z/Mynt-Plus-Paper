# Mynt Plus Web application

A Flutter Web project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Running the Web App

### Local (this machine only)

```bash
flutter run -d chrome --web-port 8080
```

### Intranet (other devices on the same network)

Bind the dev server to all network interfaces so other devices on your LAN can
reach it:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Find this machine's LAN IP and share `http://<lan-ip>:8080`:

```bash
ipconfig getifaddr en0    # Wi-Fi on macOS (try en1 if empty)
```

> macOS may prompt to allow incoming connections for `dart`/`flutter` — allow it
> (System Settings → Network → Firewall).

### Internet

`flutter run` is a debug dev server and is **not** meant for public exposure.

**A. Temporary public link (tunnel a running dev server):**

```bash
# Terminal 1
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
# Terminal 2 (pick one)
ngrok http 8080
cloudflared tunnel --url http://localhost:8080
```

**B. Production hosting (release build):**

```bash
flutter build web --release
firebase deploy           # deploys build/web/ via Firebase Hosting
```

> **Note:** When serving on a LAN IP or tunnel domain, the API/WebSocket URLs in
> `lib/api/core/api_link.dart` must be reachable from the browser and CORS must
> allow the new origin. Serving the app over plain HTTP against HTTPS APIs will
> trigger browser mixed-content blocking — the HTTPS tunnel option (A) avoids
> this.

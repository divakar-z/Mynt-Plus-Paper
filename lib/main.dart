import 'dart:developer';
// Conditional import for HttpOverrides only on non-web platforms
import 'package:flutter/foundation.dart'
    show PlatformDispatcher, TargetPlatform, defaultTargetPlatform, kIsWeb;
// ignore: uri_does_not_exist
import 'utils/http_overrides_stub.dart'
    if (dart.library.io) 'utils/http_overrides.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:mynt_plus/firebase_options.dart';
import 'package:mynt_plus/locator/constant.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart'
    show kChartPopoutMode;
import 'package:mynt_plus/sharedWidget/accessibility/accessibility_panel.dart';
import 'package:mynt_plus/sharedWidget/accessibility/chart_a11y_filter.dart';
import 'package:mynt_plus/sharedWidget/accessibility/focus_indicator_overlay.dart';
import 'package:mynt_plus/sharedWidget/accessibility/highlight_links_overlay.dart';
import 'package:mynt_plus/sharedWidget/chart_overlay_widget.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import 'package:mynt_plus/notification/notification_service.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
// Web URL strategy - enables path-based URLs instead of hash-based
import 'package:flutter_web_plugins/url_strategy.dart';
import 'locator/locator.dart';
import 'locator/preference.dart';
import 'provider/accessibility_provider.dart';
import 'utils/auto_login_handoff.dart';
import 'provider/thems.dart';
import 'res/web_resources.dart';
import 'routes/app_routes.dart';
import 'routes/route_names.dart';
import 'routes/web_router.dart';
import 'themes/theme.dart';

// Global route observer to allow screens to react to navigation events
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Get the appropriate navigator key based on platform
/// - Web: uses webNavigatorKey from GoRouter
/// - Mobile: uses rootNavigatorKey from MaterialApp
GlobalKey<NavigatorState> getNavigatorKey() {
  if (kIsWeb) {
    // Import webNavigatorKey dynamically to avoid circular imports
    // The actual key is defined in web_router.dart
    return _webNavigatorKeyGetter();
  }
  return rootNavigatorKey;
}

/// Get the appropriate navigator context based on platform
/// Returns null if no context is available
BuildContext? getNavigatorContext() {
  return getNavigatorKey().currentContext;
}

/// Get the appropriate navigator state based on platform
/// Returns null if no state is available
NavigatorState? getNavigatorState() {
  return getNavigatorKey().currentState;
}

// Getter for web navigator key - set during web router initialization
GlobalKey<NavigatorState> Function() _webNavigatorKeyGetter = () => rootNavigatorKey;

/// Register the web navigator key getter (called from web_router.dart)
void registerWebNavigatorKey(GlobalKey<NavigatorState> Function() getter) {
  _webNavigatorKeyGetter = getter;
}

// Global provider to track Firebase initialization status
final firebaseInitializedProvider = StateProvider<bool>((ref) => false);

// Helper class for Firebase operations
class FirebaseHelper {
  // Static variable to track initialization status
  static bool _isInitialized = false;

  // Check if Firebase is initialized
  static bool isInitialized() {
    return _isInitialized;
  }

  // Mark Firebase as initialized
  static void setInitialized(bool value) {
    _isInitialized = value;

    // Also update the provider if possible
    try {
      final container = ProviderContainer();
      container.read(firebaseInitializedProvider.notifier).state = value;
    } catch (e) {
      // Silently handle provider update errors
    }
  }
}

// used to pass messages from event handler to the UI
final _messageStreamController = BehaviorSubject<RemoteMessage>();

// Create a dedicated function for handling notification messages
void handleNotificationMessage(RemoteMessage message) {
  // Consistent notification display logic
  if (message.data["imageUrl"] != null && message.data["imageUrl"] != "") {
    NotificationService.showNotification(
      title: message.notification?.title,
      body: message.notification?.body?.replaceAll("  ", "\n"),
      notificationLayout: NotificationLayout.BigPicture,
      bigPicture: message.data["imageUrl"],
      payload: {"navigate": "true", "url": message.data["url"]},
    );
  } else {
    NotificationService.showNotification(
      title: message.notification?.title,
      body: message.notification?.body?.replaceAll("  ", "\n"),
      notificationLayout: NotificationLayout.BigText,
    );
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); 
}

// Separated Firebase initialization function for better control and performance
Future<void> initializeFirebaseAsync() async {
  final firebaseStartTime = DateTime.now();

  try {
    // Initialize Firebase with appropriate platform options
    if (TargetPlatform.android == defaultTargetPlatform) {
      await Firebase.initializeApp(
          name: "dev project", options: DefaultFirebaseOptions.currentPlatform);
    } else {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }

    final coreInitTime = DateTime.now();
    final coreInitDuration = coreInitTime.difference(firebaseStartTime);

    final Preferences pref = locator<Preferences>();

    // Only enable Crashlytics on mobile platforms (not web)
    if (!kIsWeb) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      FirebaseCrashlytics.instance
          .setUserIdentifier("${pref.deviceName!} ${pref.imei}");
    }

    // Configure messaging
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Get token for messaging
    ConstantName.msgToken = await messaging.getToken();
    log("Token ${ConstantName.msgToken}");

    // Configure background messaging handler (not supported on web)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    }

    // Handle notification click when app was terminated
    FirebaseMessaging.instance.getInitialMessage().then((message) async {
      if (message != null) {
        if (message.data["url"] != null) {
          final Uri url = Uri.parse(message.data["url"]);
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            // print("Could not launch URL");
          }
        }
      }
    });

    // Handle notification click when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      if (message.data["url"] != null) {
        final Uri url = Uri.parse(message.data["url"]);
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        }
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kIsWeb) {
        // On web, the tab being visible means the browser hands the push to
        // this Dart-side handler instead of showing an OS notification — by
        // design (avoids redundant popups when the user is already on the
        // page). awesome_notifications doesn't render on web, so we surface
        // the message as an in-page toast instead, matching the convention
        // used by Slack / Gmail Web.
        final notification = message.notification;
        if (notification != null) {
          final title = notification.title ?? '';
          final body = notification.body ?? '';
          final text = [title, body].where((s) => s.isNotEmpty).join('\n');
          if (text.isNotEmpty) {
            final ctx = getNavigatorContext();
            if (ctx != null && ctx.mounted) {
              ResponsiveSnackBar.showInfo(ctx, text);
            }
          }
        }
      } else {
        handleNotificationMessage(message);
      }
      _messageStreamController.sink.add(message);
    });

    // Update initialization state after successful Firebase initialization
    FirebaseHelper.setInitialized(true);

    final firebaseEndTime = DateTime.now();
    final totalFirebaseDuration = firebaseEndTime.difference(firebaseStartTime);
  } catch (e) {
    // Don't update the provider state if initialization fails
  }
}

void _clearBadgeOnStartup() async {
  // await AwesomeNotifications().cancelAll();
  await AwesomeNotifications().resetGlobalBadge();
}

// The detached chart popout window (`/chart-popout`). It's a second Flutter
// instance opened from the logged-in app; it feeds from the alternate socket
// and must run isolated from the main window's saved chart session.
bool _isChartPopoutRoute() {
  if (!kIsWeb) return false;
  final path = Uri.base.path;
  return path == '/chart-popout' || path.startsWith('/chart-popout/');
}

// Public web routes that don't require auth and shouldn't trigger
// notification permission prompts or Firebase messaging init on load.
bool _isPublicWebRoute() {
  if (!kIsWeb) return false;
  final path = Uri.base.path;
  return path == '/dailypnl' ||
      path.startsWith('/dailypnl/') ||
      _isChartPopoutRoute();
}

// This method represents the project's entry level.
void main() async {
  // Track startup time
  final startTime = DateTime.now();

  // Enable path-based URLs for web (removes #/ from URLs)
  // This allows proper browser history and shareable links
  // MUST be called BEFORE WidgetsFlutterBinding.ensureInitialized()
  if (kIsWeb) {
    usePathUrlStrategy();
    // Initialize GoRouter for web URL-based navigation
    initializeWebRouter();
  }

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize resources - web uses extended resources, mobile uses base
  if (kIsWeb) {
    initializeWebResources(); // Includes web fonts, colors AND base resources
  } else {
    initializeResources();
  }
  if (!kIsWeb && TargetPlatform.android == defaultTargetPlatform) {
    await FlutterDisplayMode.setHighRefreshRate();
  }
  if (!kIsWeb) {
    applyHttpOverrides();
  }
  setupLocator();

  // Detached popout window: flip the chart session store into throwaway mode
  // BEFORE the ProviderScope mounts, so its ChartEngineSessionNotifier never
  // hydrates from — or persists to — the main window's saved session.
  if (_isChartPopoutRoute()) {
    kChartPopoutMode = true;
  }

  final bool isPublicRoute = _isPublicWebRoute();

  // Initialize preferences and notifications in parallel for faster startup.
  // Public viewer skips notification init — visitors shouldn't see permission prompts.
  final Preferences pref = locator<Preferences>();
  await Future.wait([
    if (!isPublicRoute) NotificationService.initializeNotification(),
    pref.init(),
  ]);

  // Token-based auto-login. Partner portals open the web app with the client id
  // and Noren session in the URL: https://app.mynt.in/?uid=clientId&token=session.
  // Stash the values in memory only — SplashScreen validates them and commits a
  // real session ONLY on success. We deliberately do NOT write them to the
  // session prefs here: committing before validation would let a wrong/expired
  // link overwrite (and log out) the user who is already signed in. The router
  // redirects uid+token URLs through /splash so the validation runs.
  if (kIsWeb) {
    final q = Uri.base.queryParameters;
    final uid = (q['uid'] ?? '').trim();
    final token = (q['token'] ?? '').trim();
    if (uid.isNotEmpty && token.isNotEmpty) {
      AutoLoginHandoff.uid = uid;
      AutoLoginHandoff.token = token;
    }
  }

  try {
    _clearBadgeOnStartup();
  } catch (e) {
  }
  // Run the app first without waiting for Firebase
  final beforeFirebase = DateTime.now();
  final startupDuration = beforeFirebase.difference(startTime);

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(const ProviderScope(child: MyApp()));

  // Warm the accessibility-panel SVG icons into flutter_svg's cache so they
  // paint on the first frame the panel opens (no blank-frame gap, no per-icon
  // loader needed). Web-only — the panel is a web feature. Fire-and-forget so
  // it never delays the first frame.
  if (kIsWeb) {
    precacheAccessibilityIcons();
  }

  // Initialize Firebase after the app has started (non-blocking).
  // Skip on public routes to avoid messaging permission prompts for visitors.
  if (!isPublicRoute) {
    initializeFirebaseAsync();
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the entire provider for web to ensure proper theme updates
    // For mobile, we optimize by only watching themeMode
    final themeProvide = kIsWeb
        ? ref.watch(themeProvider) // Web: watch entire provider for theme sync
        : ref.read(themeProvider); // Mobile: read once for performance

    final themeMode = ref.watch(themeProvider.select((t) => t.themeMode));
    themeProvide.getThemeData();

    // SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    //     statusBarIconBrightness: themeProvide.isDarkMode
    //         ? Brightness.light
    //         : Brightness.dark, // For Android (dark icons)
    //     statusBarBrightness:
    //         themeProvide.isDarkMode ? Brightness.light : Brightness.dark,
    //     statusBarColor: themeProvide.isDarkMode ? Colors.black :Colors.white));

    // Use MaterialApp.router with GoRouter for web (enables URL routing)
    // Use MaterialApp for mobile (standard navigation)
    if (kIsWeb) {
      return shadcn.ShadcnApp.router(
        routerConfig: webRouter,
        title: 'MYNT',
        debugShowCheckedModeBanner: false,
        theme: shadcn.ThemeData(
          colorScheme: themeProvide
              .getShadcnColorScheme(), // Use provider method for proper sync
          radius: 0,
          // Note: shadcn components inherit from DefaultTextStyle below
          // If shadcn.ThemeData supports textTheme, you can set it here
        ),
        builder: (context, child) {
          return Consumer(
            builder: (context, consumerRef, _) {
              final a11y = consumerRef.watch(accessibilityProvider);
              // MediaQuery must sit ABOVE shadcn.DrawerOverlay so drawers
              // opened via shadcn.openDrawer() inherit the scaled textScaler.
              // Previously it was inside DrawerOverlay → sidebar text stayed
              // at 1.0x while the main content scaled.
              // Dyslexia mode swaps to a web-safe, more legible font and
              // boosts letter spacing / line height — applied at the root
              // DefaultTextStyle so every descendant inherits it.
              // Dyslexia mode uses the OpenDyslexic asset bundled in pubspec,
              // falling back to Comic Sans MS and Arial (harmless on CanvasKit
              // — only OpenDyslexic actually resolves, but the fallbacks keep
              // the stack intact for any HTML-renderer build).
              // letterSpacing: 0.02em ≈ 0.32 at base 16px; word spacing defaults to 0.
              const TextStyle dyslexiaStyle = TextStyle(
                fontFamily: 'OpenDyslexic',
                fontFamilyFallback: <String>['Comic Sans MS', 'Arial'],
                letterSpacing: 0.32,
                fontFeatures: [FontFeature.proportionalFigures()],
              );

              final TextStyle baseTextStyle = a11y.dyslexiaSupportEnabled
                  ? dyslexiaStyle
                  : const TextStyle(
                      fontFamily: 'Geist',
                      fontFeatures: [FontFeature.proportionalFigures()],
                    );

              Widget content = MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(a11y.textScale),
                ),
                child: shadcn.DrawerOverlay(
                  child: Stack(
                    children: [
                      DefaultTextStyle(
                        style: baseTextStyle,
                        child: child!,
                      ),
                      const ChartOverlayWidget(),
                    ],
                  ),
                ),
              );

              // Shadcn widgets resolve their font from Theme.typography.sans,
              // which hardcodes 'GeistSans' and beats DefaultTextStyle. When
              // Dyslexia Support is on we override that typography so every
              // shadcn Text/Button/Dialog picks up the dyslexia-friendly font.
              //
              // IMPORTANT: this wrapper — and the ColorFiltered / _AdhdSpotlight
              // wrappers below — are ALWAYS mounted, even when their toggle is
              // off (they simply do nothing then). Previously they were added
              // and removed with `if (toggle) content = Wrapper(content)`, which
              // changed the tree depth above the router content every time a
              // toggle flipped. That reparented the split-home screen's
              // GlobalKey'd subtree while an inherited widget (MediaQuery/Theme)
              // was notifying, tripping InheritedElement.notifyClients ("not a
              // descendant") and red-screening the panel. Keeping the depth
              // constant makes that reparent — and the crash — impossible.
              final shadcnTheme = shadcn.Theme.of(context);
              content = shadcn.Theme(
                data: a11y.dyslexiaSupportEnabled
                    ? shadcnTheme.copyWith(
                        typography: () => shadcnTheme.typography.copyWith(
                          sans: () => dyslexiaStyle,
                        ),
                      )
                    : shadcnTheme, // no-op: re-inject the current theme unchanged
                child: content,
              );

              // Single, always-present colour filter for the mutually-exclusive
              // colour modes (Grayscale / Invert / Blue-Light / Smart-Contrast /
              // Theme-Tone — exclusivity is enforced in AccessibilityNotifier).
              // At most one matrix is ever active; when none is,
              // [_activeColorFilter] returns null and the wrapper paints the
              // child directly — NO offscreen color-filter layer and NO
              // per-frame full-screen composite in the (common) all-off case.
              // The wrapper stays mounted at all times so the subtree below
              // never reparents; only its internal paint branch changes. This
              // also collapses the five separate filters into one shared source
              // (resolves the former a11y Fix 7 TODO).
              content = _ConditionalColorFilter(
                colorFilter: _activeColorFilter(a11y),
                child: content,
              );

              // Highlight Links (WCAG 1.4.11): outline every semantics-declared
              // button/link. Always wraps; paints only when enabled.
              content = HighlightLinksOverlay(
                enabled: a11y.highlightLinksEnabled,
                child: content,
              );

              // Focus Indicator (WCAG 2.4.7): high-contrast ring on the widget
              // holding primary focus. Always wraps; paints only when enabled.
              content = FocusIndicatorOverlay(
                enabled: a11y.focusIndicatorEnabled,
                child: content,
              );

              // ADHD Focus Assist: dark curtain above the cursor line to narrow
              // visual attention. Always mounted; paints only when enabled.
              content = _AdhdSpotlight(
                enabled: a11y.adhdFocusAssistEnabled,
                child: content,
              );

              // The Flutter-canvas colour work above does not touch the chart
              // HTML platform views (composited outside the canvas), so mirror
              // the same adjustments onto their DOM host elements via CSS. The
              // Theme Tone rides along as its raw [r,g,b] channel scales so the
              // chart background lands on the exact same tone colour as the app.
              // Idempotent + observes the DOM, so charts opened later inherit it.
              final toneTint = themeToneTint(a11y.themeTone);
              ChartA11yFilter.instance.apply(
                filter: composeChartCssFilter(a11y),
                toneTint: toneTint == null
                    ? null
                    : <double>[toneTint.r, toneTint.g, toneTint.b],
                blueLight: a11y.blueLightFilterEnabled,
              );
              return content;
            },
          );
        },
      );
    } else {
      return MaterialApp(
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        themeMode: themeMode,
        theme: themeProvide.currentTheme,
        darkTheme: MyThemes.darkTheme,
        title: 'MYNT',
        debugShowCheckedModeBanner: false,
        initialRoute: Routes.splash,
        onGenerateRoute: AppRoutes.router,
        navigatorObservers: [routeObserver],
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              const ChartOverlayWidget(),
            ],
          );
        },
      );
    }
  }
}

/// Wraps [_activeColorMatrix] as a [ColorFilter], returning null when no colour
/// mode is active so [_ConditionalColorFilter] can skip the offscreen layer
/// entirely (see its paint()).
ColorFilter? _activeColorFilter(AccessibilityNotifier a11y) {
  final List<double>? matrix = _activeColorMatrix(a11y);
  return matrix == null ? null : ColorFilter.matrix(matrix);
}

/// Returns the colour matrix for whichever mutually-exclusive colour mode is
/// active — Grayscale, Invert, Blue-Light, Smart-Contrast or Theme-Tone — or
/// null when none is. Exclusivity is enforced in [AccessibilityNotifier]
/// (enabling one clears the rest), so this can select the first match rather
/// than compose several. Single source of truth for the on-canvas matrices;
/// the chart surfaces mirror these via [ChartA11yFilter].
List<double>? _activeColorMatrix(AccessibilityNotifier a11y) {
  if (a11y.grayscaleEnabled) {
    return const <double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0,      0,      0,      1, 0,
    ];
  }
  if (a11y.invertColoursEnabled) {
    return const <double>[
      -1,  0,  0, 0, 255,
       0, -1,  0, 0, 255,
       0,  0, -1, 0, 255,
       0,  0,  0, 1,   0,
    ];
  }
  if (a11y.blueLightFilterEnabled) {
    // Warm amber tint — dampens blue, nudges red/green.
    return const <double>[
      1.0, 0,   0,   0, 15,
      0,   1.0, 0,   0, 5,
      0,   0,   0.7, 0, 0,
      0,   0,   0,   1, 0,
    ];
  }
  if (a11y.smartContrastEnabled) {
    // Contrast boost: multiply each channel by 1.3 and recenter around
    // mid-grey (128 * (1 - 1.3) = -38.4).
    return const <double>[
      1.3, 0,   0,   0, -38.4,
      0,   1.3, 0,   0, -38.4,
      0,   0,   1.3, 0, -38.4,
      0,   0,   0,   1,   0,
    ];
  }
  final toneTint = themeToneTint(a11y.themeTone);
  if (toneTint != null) {
    // Diagonal matrix scaling each RGB channel toward the tone colour —
    // mathematically identical to multiplying content by the tint, but on the
    // same ColorFilter.matrix path as the modes above (ColorFilter.mode +
    // BlendMode.multiply blanked the whole page flat on this CanvasKit build).
    return <double>[
      toneTint.r, 0, 0, 0, 0,
      0, toneTint.g, 0, 0, 0,
      0, 0, toneTint.b, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
  return null;
}

/// Always-mounted colour-filter wrapper that only pays the compositing cost
/// when a colour mode is actually active.
///
/// [ColorFiltered] always pushes a [ColorFilterLayer] and composites its whole
/// subtree through it every frame — even with an identity matrix. Because this
/// wrapper is kept permanently mounted (to avoid a GlobalKey reparent crash),
/// that meant the entire app paid a per-frame full-screen offscreen composite
/// even when every colour mode was off — the common case.
///
/// This wrapper stays mounted identically, but when [colorFilter] is null it
/// paints the child directly with no layer at all; it only pushes the
/// color-filter layer when a mode is on. The child's element position never
/// changes, so the reparent-crash protection is preserved.
class _ConditionalColorFilter extends SingleChildRenderObjectWidget {
  const _ConditionalColorFilter({
    required this.colorFilter,
    required Widget super.child,
  });

  final ColorFilter? colorFilter;

  @override
  _RenderConditionalColorFilter createRenderObject(BuildContext context) =>
      _RenderConditionalColorFilter(colorFilter);

  @override
  void updateRenderObject(
      BuildContext context, _RenderConditionalColorFilter renderObject) {
    renderObject.colorFilter = colorFilter;
  }
}

class _RenderConditionalColorFilter extends RenderProxyBox {
  _RenderConditionalColorFilter(this._colorFilter);

  ColorFilter? _colorFilter;
  ColorFilter? get colorFilter => _colorFilter;
  set colorFilter(ColorFilter? value) {
    if (value == _colorFilter) return;
    // Switching between "no layer" and "color-filter layer" flips whether this
    // box needs compositing, so refresh the compositing bits on that boundary.
    final bool toggledPresence = (value == null) != (_colorFilter == null);
    _colorFilter = value;
    if (toggledPresence) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  // Only forces a compositing layer while a filter is actually active.
  @override
  bool get alwaysNeedsCompositing => child != null && _colorFilter != null;

  @override
  ColorFilterLayer? get layer => super.layer as ColorFilterLayer?;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final ColorFilter? filter = _colorFilter;
    if (filter == null) {
      // No colour mode active: draw the child straight through — no offscreen
      // full-screen composite, no ColorFilterLayer allocation.
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer =
        context.pushColorFilter(offset, filter, super.paint, oldLayer: layer);
  }
}

/// Spotlight overlay for the ADHD Focus Assist toggle. Tracks the cursor via
/// a translucent [MouseRegion] (so clicks/hover still reach the app below)
/// and paints a dark veil above the cursor line.
///
/// Always mounted (see the wrapper comment in [MyApp.build]); when [enabled]
/// is false it stops tracking and paints nothing, but its internal
/// MouseRegion→Stack structure stays identical so [child] never reparents.
class _AdhdSpotlight extends StatefulWidget {
  const _AdhdSpotlight({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  State<_AdhdSpotlight> createState() => _AdhdSpotlightState();
}

class _AdhdSpotlightState extends State<_AdhdSpotlight> {
  Offset? _pos;

  @override
  void didUpdateWidget(covariant _AdhdSpotlight old) {
    super.didUpdateWidget(old);
    // Clear any stale cursor position when the toggle turns off so a later
    // re-enable doesn't flash the veil at the old spot before the next hover.
    if (!widget.enabled && _pos != null) {
      _pos = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onHover: widget.enabled
          ? (e) {
              if (_pos != e.position) setState(() => _pos = e.position);
            }
          : null,
      onExit: widget.enabled
          ? (_) {
              if (_pos != null) setState(() => _pos = null);
            }
          : null,
      child: Stack(
        children: [
          widget.child,
          // Leaf overlay (no GlobalKey): adding/removing it at index 1 does not
          // reparent [child] at index 0, so this stays crash-safe.
          if (widget.enabled)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _SpotlightPainter(_pos),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.pos);
  final Offset? pos;

  // Curtain mode: solid black veil covers everything ABOVE the cursor with a
  // hard edge at the cursor line. Everything below stays fully clear so the
  // user can read down the page line by line.
  static const double _veilAlpha = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final veil = Paint()..color = Colors.black.withValues(alpha: _veilAlpha);

    if (pos == null) {
      canvas.drawRect(rect, veil);
      return;
    }

    final cutoff = pos!.dy.clamp(0.0, size.height);
    if (cutoff > 0) {
      canvas.drawRect(Rect.fromLTRB(0, 0, size.width, cutoff), veil);
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.pos != pos;
}

// HttpOverrides implementation moved to `utils/http_overrides.dart` with a web stub

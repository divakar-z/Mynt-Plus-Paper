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
import 'package:mynt_plus/sharedWidget/chart_overlay_widget.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import 'package:mynt_plus/notification/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
// Web URL strategy - enables path-based URLs instead of hash-based
import 'package:flutter_web_plugins/url_strategy.dart';
import 'locator/locator.dart';
import 'locator/preference.dart';
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
   

      handleNotificationMessage(message);
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

// Public web routes that don't require auth and shouldn't trigger
// notification permission prompts or Firebase messaging init on load.
bool _isPublicWebRoute() {
  if (!kIsWeb) return false;
  final path = Uri.base.path;
  return path == '/dailypnl' || path.startsWith('/dailypnl/');
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

  final bool isPublicRoute = _isPublicWebRoute();

  // Initialize preferences and notifications in parallel for faster startup.
  // Public viewer skips notification init — visitors shouldn't see permission prompts.
  final Preferences pref = locator<Preferences>();
  await Future.wait([
    if (!isPublicRoute) NotificationService.initializeNotification(),
    pref.init(),
  ]);

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
          return shadcn.DrawerOverlay(
            child: Stack(
              children: [
                MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.0),
                  ),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontFeatures: const [FontFeature.proportionalFigures()],
                    ),
                    child: child!,
                  ),
                ),
                const ChartOverlayWidget(),
              ],
            ),
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

// HttpOverrides implementation moved to `utils/http_overrides.dart` with a web stub

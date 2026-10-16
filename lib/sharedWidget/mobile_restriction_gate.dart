import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart'
    show kChartPopoutMode;

/// Below this viewport width the web platform is considered "mobile" and is
/// blocked. 768px is [AppBreakpoints.md] — every phone in portrait, and most in
/// landscape once browser chrome is subtracted, lands under it.
const double kMobileGateMaxWidth = 768;

/// A phone held in landscape can be wider than [kMobileGateMaxWidth] (e.g.
/// 844x390) while still being far too short for the trading layout, so height
/// is gated as well.
const double kMobileGateMinHeight = 480;

const String kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.mynt.trading_app_zebu';
const String kAppStoreUrl =
    'https://apps.apple.com/in/app/mynt-stocks-options-ipo-mf/id6478270319';

/// Blocks the web app on mobile-sized viewports and points the visitor at the
/// native Mynt app instead.
///
/// The gate is ALWAYS mounted (it simply passes [child] through when the
/// viewport is large enough) so the depth of the tree above the router content
/// never changes — the same constraint the accessibility wrappers in
/// `main.dart` are built around. When it does block, [child] stays in the tree
/// but is made inert for pointer, focus and screen-reader input rather than
/// being torn down, so resizing back to desktop restores the session intact.
class MobileRestrictionGate extends StatelessWidget {
  const MobileRestrictionGate({
    super.key,
    required this.isDark,
    required this.child,
  });

  /// Passed in rather than read from `Theme.of` — the web shell runs on
  /// `ShadcnApp`, which has no Material [Theme] ancestor to resolve.
  final bool isDark;

  final Widget child;

  static bool isRestricted(Size size) =>
      size.width < kMobileGateMaxWidth || size.height < kMobileGateMinHeight;

  @override
  Widget build(BuildContext context) {
    // The detached chart popout is a desktop window the user can size freely,
    // so it is never gated. [kChartPopoutMode] is fixed at startup, so the tree
    // depth still never changes.
    final bool blocked =
        !kChartPopoutMode && isRestricted(MediaQuery.sizeOf(context));

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: blocked,
          child: ExcludeFocus(
            excluding: blocked,
            child: IgnorePointer(ignoring: blocked, child: child),
          ),
        ),
        if (blocked) _MobileRestrictionScreen(isDark: isDark),
      ],
    );
  }
}

class _MobileRestrictionScreen extends StatelessWidget {
  const _MobileRestrictionScreen({required this.isDark});

  final bool isDark;

  /// One vertical gap between every block — logo, title, message, badges.
  static const double _gap = 20;

  @override
  Widget build(BuildContext context) {
    final Color background =
        isDark ? WebColors.backgroundColorDark : WebColors.backgroundColor;
    final Color title =
        isDark ? WebColors.textPrimaryDark : WebColors.textPrimary;
    final Color body =
        isDark ? WebColors.textSecondaryDark : WebColors.textSecondary;

    // On web Flutter resolves [defaultTargetPlatform] from the browser's user
    // agent, so the gate can offer only the store that actually serves the
    // device it is being viewed on.
    final TargetPlatform platform = defaultTargetPlatform;
    // iPadOS Safari asks for the desktop site and so reports itself as macOS.
    final bool isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final bool isAndroid = platform == TargetPlatform.android;

    final Widget playStore = _StoreBadge(
      caption: 'GET IT ON',
      store: 'Google Play',
      semanticsLabel: 'Get it on Google Play',
      mark: const _GooglePlayMark(),
      url: kPlayStoreUrl,
      isDark: isDark,
    );
    final Widget appStore = _StoreBadge(
      caption: 'Download on the',
      store: 'App Store',
      semanticsLabel: 'Download on the App Store',
      mark: const Icon(Icons.apple, size: 22, color: Colors.white),
      url: kAppStoreUrl,
      isDark: isDark,
    );

    final List<Widget> storeButtons;
    if (isApple) {
      storeButtons = <Widget>[appStore];
    } else if (isAndroid) {
      storeButtons = <Widget>[playStore];
    } else {
      // A desktop browser narrowed past the breakpoint — or a user agent that
      // reports nothing recognisable, e.g. an Android phone in "Desktop site"
      // mode — says nothing about which phone the visitor owns, so both stores
      // stay on offer.
      storeButtons = <Widget>[playStore, appStore];
    }

    // No tap-absorbing wrapper needed: the app underneath is already wrapped in
    // IgnorePointer by [MobileRestrictionGate].
    return ColoredBox(
      color: background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SvgPicture.asset(
                      assets.appLogoIcon,
                      width: 120,
                      height: 44,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: _gap),
                  Text(
                    'Trade on Mobile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: title,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: _gap),
                  Text(
                    'Mynt Web is designed for larger screens. For the best '
                    'trading experience on your mobile device, please use '
                    'the Mynt app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: body, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: _gap),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: storeButtons,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The familiar black store badge — brand mark, a small caption and the store
/// name — rather than a themed CTA button, so it reads as the real download
/// affordance visitors already recognise.
class _StoreBadge extends StatelessWidget {
  const _StoreBadge({
    required this.caption,
    required this.store,
    required this.semanticsLabel,
    required this.mark,
    required this.url,
    required this.isDark,
  });

  final String caption;
  final String store;
  final String semanticsLabel;
  final Widget mark;
  final String url;
  final bool isDark;

  Future<void> _open() async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      link: true,
      label: semanticsLabel,
      // The badge splits its name across two lines at two different sizes;
      // announcing those fragments would read as gibberish, so the label above
      // is the accessible name.
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _open,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                // A black badge on the dark background would otherwise have no
                // edge to it.
                border: isDark
                    ? Border.all(color: MyntColors.dividerDark)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  mark,
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caption,
                        style: const TextStyle(
                          color: MyntColors.textWhite,
                          fontSize: 7.5,
                          height: 1.2,
                          letterSpacing: 0.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        store,
                        style: const TextStyle(
                          color: MyntColors.textWhite,
                          fontSize: 13.5,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The four-colour Google Play triangle. Drawn inline rather than shipped as an
/// asset — it is four flat polygons meeting at a single point.
class _GooglePlayMark extends StatelessWidget {
  const _GooglePlayMark();

  static const String _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#00A0FF" d="M5.7 1.5 16.24 12 5.7 22.5Z"/>
  <path fill="#00E676" d="M5.7 1.5 19.8 8.4 16.24 12Z"/>
  <path fill="#FFCE00" d="M19.8 8.4 23.5 12 19.8 15.6 16.24 12Z"/>
  <path fill="#FF3A44" d="M16.24 12 19.8 15.6 5.7 22.5Z"/>
</svg>''';

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(_svg, width: 20, height: 20);
}

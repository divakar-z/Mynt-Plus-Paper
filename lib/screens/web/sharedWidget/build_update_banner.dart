import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../provider/web_build_update_provider.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';

/// Floating "new build available" pill, shown top-center above the shell
/// content. Mounted in the shell's overlay Stack (NOT the body Column and
/// NOT an OverlayEntry — the Navigator overlay is covered by shadcn sheets,
/// a known issue). Renders nothing while up to date or snoozed.
///
/// Inverted surface: dark pill on the light theme, light pill on the dark
/// theme, built from the house palette so it pops against either ground.
/// Fully driven by [webBuildUpdateProvider]: close = dismissed for this
/// visit (returns on the next page load, or sooner if an even newer build
/// is hosted), and while the update is applying the button shows a
/// spinner + "Updating…" until the page reloads.
// TEMPORARY — forces the pill visible for UI review in a local run.
// MUST be false before commit/deploy (with true, every user sees it always).
const bool _kForceShowForUiReview = false;

class BuildUpdateBanner extends ConsumerWidget {
  const BuildUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updater = ref.watch(webBuildUpdateProvider);
    if (!_kForceShowForUiReview && !updater.showStrip) {
      return const Positioned(top: 0, left: 0, child: SizedBox.shrink());
    }

    // Inverted vs the app theme (user's design): dark pill on the light
    // theme — a white pill wasn't visible enough there — light pill on the
    // dark theme. `dark:` = value used in dark mode.
    final pillBg = resolveThemeColor(context,
        dark: const Color(0xFFF5F7FA),
        // Softer slate navy, slightly translucent — lighter than the near-
        // black original, without the repaint cost of a BackdropFilter blur.
        light: const Color(0xFF283349).withValues(alpha: 0.96));
    final pillFg = resolveThemeColor(context,
        dark: MyntColors.textPrimary, light: Colors.white);
    final closeFg = resolveThemeColor(context,
        dark: const Color(0xFF5C6570), light: const Color(0xFF98A2B8));
    // White link on the dark pill (user's call); on the light pill white
    // would vanish, so there it stays Mynt primary blue.
    final linkFg = resolveThemeColor(context,
        dark: MyntColors.primary, light: Colors.white);
    // Hairline only where it helps: around the light pill on dark theme.
    final pillBorder = resolveThemeColor(context,
        dark: const Color(0xFFE8ECF0), light: Colors.transparent);

    final versionSuffix = updater.serverVersionLabel == null
        ? ''
        : ' (${updater.serverVersionLabel})';

    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            color: pillBg,
            shape: StadiumBorder(side: BorderSide(color: pillBorder)),
            elevation: 8,
            shadowColor: Colors.black
                .withValues(alpha: isDarkMode(context) ? 0.4 : 0.25),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 5, 5, 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'A new version of Mynt is available$versionSuffix',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: webText(context,
                          size: MyntFonts.bodySmall, color: pillFg),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap:
                        updater.applying ? null : () => updater.applyUpdate(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 6),
                      child: updater.applying
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: linkFg.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Updating…',
                                  style: MyntWebTextStyles.buttonSm(context,
                                      color:
                                          linkFg.withValues(alpha: 0.85)),
                                ),
                              ],
                            )
                          : Text(
                              'Update',
                              style: MyntWebTextStyles.buttonSm(context,
                                      color: linkFg)
                                  .copyWith(
                                decoration: TextDecoration.underline,
                                decorationColor: linkFg,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    onPressed: updater.applying ? null : updater.dismiss,
                    icon: Icon(Icons.close, size: 14, color: closeFg),
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                    padding: EdgeInsets.zero,
                    splashRadius: 14,
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

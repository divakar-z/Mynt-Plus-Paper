import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../provider/web_build_update_provider.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';

/// Full-width strip shown at the very top of the shell when a newer web
/// build has been hosted. Renders nothing while the app is up to date or
/// the strip is snoozed. Styling follows the retired _buildOldVersionBanner
/// pattern in customizable_split_home_screen.dart (same colors and type
/// scale).
class BuildUpdateBanner extends ConsumerWidget {
  const BuildUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updater = ref.watch(webBuildUpdateProvider);
    if (!updater.showStrip) return const SizedBox.shrink();

    final versionSuffix = updater.serverVersionLabel == null
        ? ''
        : ' (${updater.serverVersionLabel})';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: const Color(0xFF1A1D21), light: const Color(0xFFF5F7FA)),
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: const Color(0xFF2A2D31), light: const Color(0xFFE8ECF0)),
            width: 1,
          ),
        ),
      ),
      // Transparent Material so InkWell hover/ripple paint above the opaque
      // strip color instead of invisibly behind it on the Scaffold.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'A new version of Mynt is available$versionSuffix',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap:
                          updater.applying ? null : () => updater.applyUpdate(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 6),
                        child: Text(
                          updater.applying ? 'Updating…' : 'Update now',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            color: resolveThemeColor(context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: updater.applying ? null : updater.snooze,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

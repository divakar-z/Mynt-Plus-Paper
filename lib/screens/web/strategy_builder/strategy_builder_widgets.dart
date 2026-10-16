import 'package:flutter/material.dart';
import 'package:mynt_plus/provider/strategy_builder_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/common_search_fields_web.dart';
import 'package:mynt_plus/utils/rupee_convert_format.dart';

/// Shared search bar + action buttons (Chain/Add, Refresh, Clear).
/// Does NOT include the dropdown — use [buildStrategySearchDropdown] separately
/// at the caller's top-level Stack for proper overlay positioning.
Widget buildStrategySearchSection({
  required BuildContext context,
  required TextEditingController searchController,
  required StrategyBuilderProvider provider,
  required bool isDark,
  required String placeholder,
  required String chainButtonLabel,
  required double buttonHeight,
  required bool showClearButton,
  required VoidCallback? onChainPressed,
  required VoidCallback onRefreshPressed,
  required VoidCallback onClearBasket,
  required ValueChanged<String> onSearchChanged,
  required VoidCallback onClearSearch,
  required LayerLink searchLayerLink,
  required GlobalKey searchFieldKey,
}) {
  return Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Expanded(
          child: CompositedTransformTarget(
            link: searchLayerLink,
            child: MyntSearchTextField.withSmartClear(
              key: searchFieldKey,
              controller: searchController,
              placeholder: placeholder,
              leadingIcon: assets.searchIcon,
              textCapitalization: TextCapitalization.characters,
              // Shows what the user types; search still gets uppercase.
              onChanged: (value) => onSearchChanged(value.toUpperCase()),
              onClear: onClearSearch,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Clear basket button (only on main layout)
        if (showClearButton && provider.basket.isNotEmpty) ...[
          _buildOutlinedButton(
            context: context,
            label: 'Clear',
            isDark: isDark,
            height: buttonHeight,
            onPressed: onClearBasket,
          ),
          const SizedBox(width: 8),
        ],
        // Chain/Add button
        _buildOutlinedButton(
          context: context,
          label: chainButtonLabel,
          isDark: isDark,
          height: buttonHeight,
          onPressed: onChainPressed,
        ),
        // Refresh button
        if (provider.basket.isNotEmpty) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Refresh entry prices to current LTP',
            child: OutlinedButton(
              onPressed: onRefreshPressed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size(36, buttonHeight),
                side: BorderSide(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Icon(
                Icons.refresh,
                size: 18,
                color: isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Shared search results dropdown overlay.
/// Place this at the caller's top-level Stack (outside scrollable content)
/// so it renders above everything without pushing layout.
Widget buildStrategySearchDropdown({
  required BuildContext context,
  required StrategyBuilderProvider provider,
  required bool isDark,
  required TextEditingController searchController,
  required Future<void> Function(Map<String, dynamic> result) onStockSelected,
  required ValueSetter<String> onLastSelectedSymbolChanged,
  required LayerLink searchLayerLink,
  required GlobalKey searchFieldKey,
  required VoidCallback onDismiss,
}) {
  if (!provider.searchDropdownVisible) return const SizedBox.shrink();

  return CompositedTransformFollower(
    link: searchLayerLink,
    targetAnchor: Alignment.bottomLeft,
    followerAnchor: Alignment.topLeft,
    offset: const Offset(0, 4),
    child: Builder(
      builder: (context) {
        final width = (searchFieldKey.currentContext?.findRenderObject() as RenderBox?)?.size.width;
        return SizedBox(
          width: width,
          child: Material(
            elevation: 8,
            color: resolveThemeColor(context,
                dark: MyntColors.overlayBgDark, light: MyntColors.overlayBg),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(
                  color: resolveThemeColor(context,
                      dark: MyntColors.borderMutedDark,
                      light: MyntColors.borderMuted),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: provider.searchLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: provider.searchResults.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 0,
                          color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                        ),
                        itemBuilder: (context, index) {
                          final result = provider.searchResults[index];
                          final displayName = result['displayName'] ?? result['tsym'] ?? '';
                          final exchange = result['exch'] ?? '';
                          return InkWell(
                            onTap: () async {
                              searchController.text = displayName;
                              onLastSelectedSymbolChanged(displayName);
                              FocusScope.of(context).unfocus();
                              await onStockSelected(result);
                            },
                            hoverColor: resolveThemeColor(
                              context,
                              dark: MyntColors.primaryDark,
                              light: MyntColors.primary,
                            ).withValues(alpha: 0.08),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          displayName.toUpperCase(),
                                          style: MyntWebTextStyles.body(
                                            context,
                                            fontWeight: MyntFonts.medium,
                                            darkColor: MyntColors.textPrimaryDark,
                                            lightColor: MyntColors.textPrimary,
                                          ),
                                        ),
                                        if (exchange.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: resolveThemeColor(context,
                                                      dark: const Color.fromARGB(255, 49, 61, 75),
                                                      light: MyntColors.primary)
                                                  .withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              exchange,
                                              style: MyntWebTextStyles.caption(
                                                context,
                                                color: resolveThemeColor(context,
                                                    dark: MyntColors.primaryDark,
                                                    light: MyntColors.primary),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Shared outlined button used in the search section.
Widget _buildOutlinedButton({
  required BuildContext context,
  required String label,
  required bool isDark,
  required double height,
  VoidCallback? onPressed,
}) {
  return OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      minimumSize: Size(70, height),
      side: BorderSide(
        color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
    ),
    child: Text(
      label,
      style: MyntWebTextStyles.bodySmall(
        context,
        darkColor: MyntColors.textPrimaryDark,
        lightColor: MyntColors.textBlack,
      ),
    ),
  );
}

/// Shared analyze header widget.
Widget buildStrategyAnalyzeHeader({
  required BuildContext context,
  required StrategyBuilderProvider provider,
  required bool isDark,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Icon(
          Icons.analytics_outlined,
          size: 18,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
        const SizedBox(width: 8),
        Text(
          'Analyzing: ${provider.selectedSymbol}',
          style: MyntWebTextStyles.body(
            context,
            fontWeight: MyntFonts.semiBold,
          ),
        ),
        const SizedBox(width: 12),
        if (provider.spotPrice > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Spot: ${provider.spotPrice.toIndianFormat()}',
              style: MyntWebTextStyles.bodySmall(
                context,
                color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
      ],
    ),
  );
}

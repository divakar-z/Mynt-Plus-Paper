import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../../provider/portfolio_provider.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/assets.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../sharedWidget/snack_bar.dart' as snackBar;
import '../../../../sharedWidget/common_buttons_web.dart';
import 'position_group_symbol_web.dart';

final _assets = Assets();

class PositionListBottomSheet extends ConsumerWidget {
  final String grpName;
  const PositionListBottomSheet({super.key, required this.grpName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionBook = ref.watch(portfolioProvider);

    // Filter to show only F&O positions (with expiry date)
    final fnoPositions = positionBook.postionBookModel!
        .where((position) => isFutureOrOption(jsonDecode(jsonEncode(position))))
        .toList();

    return PointerInterceptor(
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: Container(
              width: 500,
              constraints: const BoxConstraints(maxHeight: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: shadcn.Theme.of(context).colorScheme.border,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add to $grpName',
                          style: MyntWebTextStyles.title(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                        ),
                        MyntCloseButton(
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: fnoPositions.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: NoDataFound(
                              title: "No F&O positions available",
                              subtitle: "Only F&O positions with expiry dates can be added to groups",
                              primaryEnabled: false,
                              secondaryEnabled: false,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            separatorBuilder: (BuildContext context, int index) {
                              return Divider(
                                height: 1,
                                thickness: 0.5,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.dividerDark,
                                    light: MyntColors.divider),
                              );
                            },
                            itemCount: fnoPositions.length,
                            itemBuilder: (BuildContext context, index) {
                              final position = fnoPositions[index];
                              final isInGroup = positionBook.isPositionInGroup(position, grpName);

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    if (!isInGroup) {
                                      // Validate before adding to any group (default or custom)
                                      final groupData = positionBook.groupedBySymbol[grpName];
                                      final groupList = (groupData?['groupList'] as List?) ?? [];
                                      Map data = jsonDecode(jsonEncode(position));

                                      // Validate the addition
                                      final validationError = validateCustomGroupAddition(data, groupList, grpName);

                                      if (validationError != null) {
                                        // Show error
                                        snackBar.error(context, validationError);
                                        return;
                                      }

                                      // Validation passed - add the symbol
                                      await positionBook.fetchAddGroupSymbol(
                                          grpName, context, data);
                                    } else {
                                      await positionBook.fetchDeleteGroupSymbol(
                                          grpName, context, "${position.tsym}");
                                    }
                                  },
                                  hoverColor: isDarkMode(context)
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.05),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        // Position details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    "${position.masterName ?? position.symbol!.toUpperCase()} ",
                                                    style: MyntWebTextStyles.body(
                                                      context,
                                                      fontWeight: MyntFonts.medium,
                                                      color: resolveThemeColor(
                                                        context,
                                                        dark: MyntColors.textPrimaryDark,
                                                        light: MyntColors.textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                  Flexible(
                                                    child: Text(
                                                      "${position.masterName == null ? (position.option ?? '') : ''}",
                                                      style: MyntWebTextStyles.body(
                                                        context,
                                                        fontWeight: MyntFonts.medium,
                                                        color: resolveThemeColor(
                                                          context,
                                                          dark: MyntColors.textPrimaryDark,
                                                          light: MyntColors.textPrimary,
                                                        ),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "${position.exch}  ${position.masterName == null ? (position.expDate ?? '') : ''}",
                                              style: MyntWebTextStyles.para(
                                                context,
                                                color: resolveThemeColor(
                                                  context,
                                                  dark: MyntColors.textSecondaryDark,
                                                  light: MyntColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Bookmark icon - filled blue when saved, outline with icon color when unsaved
                                      SvgPicture.asset(
                                        isInGroup ? _assets.bookmarkIcon : _assets.bookmarkedIcon,
                                        width: 20,
                                        height: 20,
                                        colorFilter: ColorFilter.mode(
                                          isInGroup
                                              ? resolveThemeColor(context,
                                                  dark: MyntColors.primaryDark,
                                                  light: MyntColors.primary)
                                              : resolveThemeColor(context,
                                                  dark: MyntColors.iconDark,
                                                  light: MyntColors.icon),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
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

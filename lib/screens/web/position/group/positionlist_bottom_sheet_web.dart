import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../../provider/portfolio_provider.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/assets.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../sharedWidget/snack_bar.dart' as snack_bar;
import '../../../../sharedWidget/common_buttons_web.dart';
import '../../../../sharedWidget/common_search_fields_web.dart';
import 'position_group_symbol_web.dart';

final _assets = Assets();

class PositionListBottomSheet extends ConsumerStatefulWidget {
  final String grpName;
  const PositionListBottomSheet({super.key, required this.grpName});

  @override
  ConsumerState<PositionListBottomSheet> createState() =>
      _PositionListBottomSheetState();
}

class _PositionListBottomSheetState
    extends ConsumerState<PositionListBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _lastSearchText = '';

  // The search field's X button only empties the text box; it never fires
  // onChanged. Rebuild the list here when the box goes from text to empty.
  void _onSearchTextChanged() {
    final text = _searchController.text;
    final wasNotEmpty = _lastSearchText.isNotEmpty;
    _lastSearchText = text;
    if (text.isEmpty && wasNotEmpty && mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final positionBook = ref.watch(portfolioProvider);

    // Filter to show only F&O positions (with expiry date)
    final fnoPositions = positionBook.postionBookModel!
        .where((position) => isFutureOrOption(jsonDecode(jsonEncode(position))))
        .toList();

    // Sort by symbol name first, then by strike price
    fnoPositions.sort((a, b) {
      // 1. Compare by symbol name (underlying)
      final symbolA = (a.masterName ?? a.symbol ?? '').toUpperCase();
      final symbolB = (b.masterName ?? b.symbol ?? '').toUpperCase();
      final symbolCompare = symbolA.compareTo(symbolB);
      if (symbolCompare != 0) return symbolCompare;

      // 2. Compare by strike price extracted from option field
      final strikeA = _extractStrike(a.option);
      final strikeB = _extractStrike(b.option);
      return strikeA.compareTo(strikeB);
    });

    // Multi-word smart search filter (e.g. "NIFTY 24000" matches "NIFTY 01 SEP 26 24000 CE")
    final rawQuery = _searchController.text.trim().toLowerCase();
    final queryWords = rawQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final filteredPositions = queryWords.isEmpty
        ? fnoPositions
        : fnoPositions.where((position) {
            final combined = [
              position.masterName,
              position.symbol,
              position.option,
              position.tsym,
              position.expDate,
              position.exch,
            ].map((e) => (e ?? '').toLowerCase()).join(' ');

            return queryWords.every((word) => combined.contains(word));
          }).toList();

    return PointerInterceptor(
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 480,
              height: 480,
              child: Column(
                children: [
                  // Header with Title, Search Bar, and Close Button
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: shadcn.Theme.of(context).colorScheme.border,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final titleText = 'Add to ${widget.grpName}';
                              final style = MyntWebTextStyles.title(
                                context,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary,
                                ),
                              );

                              final textWidget = Text(
                                titleText,
                                style: style,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              );

                              final span =
                                  TextSpan(text: titleText, style: style);
                              final tp = TextPainter(
                                text: span,
                                maxLines: 1,
                                textDirection: TextDirection.ltr,
                                textScaler: MediaQuery.textScalerOf(context),
                              )..layout(maxWidth: constraints.maxWidth);

                              if (tp.didExceedMaxLines) {
                                return Tooltip(
                                  message: widget.grpName,
                                  waitDuration:
                                      const Duration(milliseconds: 300),
                                  child: textWidget,
                                );
                              }
                              return textWidget;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 200,
                          child: MyntSearchTextField.withSmartClear(
                            controller: _searchController,
                            height: 36,
                            placeholder: 'Search',
                            leadingIcon: _assets.searchIcon,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9& \-]')),
                              TextInputFormatter.withFunction(
                                  (oldValue, newValue) {
                                if (newValue.text.startsWith(' ')) {
                                  return oldValue;
                                }
                                return newValue;
                              }),
                            ],
                            onChanged: (value) => setState(() {}),
                            onClear: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        MyntCloseButton(
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Content - fixed Expanded to prevent jumping/shrinking
                  Expanded(
                    child: fnoPositions.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: NoDataFound(
                                title: "No F&O positions available",
                                subtitle:
                                    "Only F&O positions with expiry dates can be added to groups",
                                primaryEnabled: false,
                                secondaryEnabled: false,
                              ),
                            ),
                          )
                        : filteredPositions.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: NoDataFound(
                                    title: "No matching positions",
                                    subtitle:
                                        "No positions match \"${_searchController.text}\"",
                                    primaryEnabled: false,
                                    secondaryEnabled: false,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                separatorBuilder:
                                    (BuildContext context, int index) {
                                  return Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.dividerDark,
                                        light: MyntColors.divider),
                                  );
                                },
                                itemCount: filteredPositions.length,
                                itemBuilder: (BuildContext context, index) {
                                  final position = filteredPositions[index];
                                  final isInGroup = positionBook
                                      .isPositionInGroup(position, widget.grpName);

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        if (!isInGroup) {
                                          // Validate before adding to any group (default or custom)
                                          final groupData = positionBook
                                              .groupedBySymbol[widget.grpName];
                                          final groupList = (groupData?['groupList']
                                                  as List?) ??
                                              [];
                                          Map data = jsonDecode(
                                              jsonEncode(position));

                                          // Validate the addition
                                          final validationError =
                                              validateCustomGroupAddition(data,
                                                  groupList, widget.grpName);

                                          if (validationError != null) {
                                            // Show error
                                            snack_bar.error(
                                                context, validationError);
                                            return;
                                          }

                                          // Validation passed - add the symbol
                                          await positionBook.fetchAddGroupSymbol(
                                              widget.grpName, context, data);
                                        } else {
                                          await positionBook
                                              .fetchDeleteGroupSymbol(
                                                  widget.grpName,
                                                  context,
                                                  "${position.tsym}",
                                                  "${position.sPrdtAli ?? ''}");
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        "${position.masterName ?? position.symbol!.toUpperCase()} ",
                                                        style: MyntWebTextStyles
                                                            .body(
                                                          context,
                                                          fontWeight:
                                                              MyntFonts.medium,
                                                          color:
                                                              resolveThemeColor(
                                                            context,
                                                            dark: MyntColors
                                                                .textPrimaryDark,
                                                            light: MyntColors
                                                                .textPrimary,
                                                          ),
                                                        ),
                                                      ),
                                                      Flexible(
                                                        child: Text(
                                                          "${position.masterName == null ? (position.option ?? '') : ''}",
                                                          style:
                                                              MyntWebTextStyles
                                                                  .body(
                                                            context,
                                                            fontWeight:
                                                                MyntFonts
                                                                    .medium,
                                                            color:
                                                                resolveThemeColor(
                                                              context,
                                                              dark: MyntColors
                                                                  .textPrimaryDark,
                                                              light: MyntColors
                                                                  .textPrimary,
                                                            ),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "${position.exch}  ${position.masterName == null ? (position.expDate ?? '') : ''}",
                                                    style: MyntWebTextStyles
                                                        .para(
                                                      context,
                                                      color: resolveThemeColor(
                                                        context,
                                                        dark: MyntColors
                                                            .textSecondaryDark,
                                                        light: MyntColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Bookmark icon - filled blue when saved, outline with icon color when unsaved
                                            SvgPicture.asset(
                                              isInGroup
                                                  ? _assets.bookmarkIcon
                                                  : _assets.bookmarkedIcon,
                                              width: 20,
                                              height: 20,
                                              colorFilter: ColorFilter.mode(
                                                isInGroup
                                                    ? resolveThemeColor(
                                                        context,
                                                        dark: MyntColors
                                                            .primaryDark,
                                                        light:
                                                            MyntColors.primary)
                                                    : resolveThemeColor(
                                                        context,
                                                        dark:
                                                            MyntColors.iconDark,
                                                        light:
                                                            MyntColors.icon),
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

/// Extracts the numeric strike price from an option string like "25000CE" or "24500PE".
/// Returns 0 for futures or if parsing fails.
double _extractStrike(String? option) {
  if (option == null || option.isEmpty) return 0;
  // Remove trailing CE/PE/CA/PA and parse the remaining number
  final cleaned = option.replaceAll(RegExp(r'[A-Za-z]+$'), '');
  return double.tryParse(cleaned) ?? 0;
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_expanded_tile/flutter_expanded_tile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../../../models/order_book_model/place_order_model.dart';
import '../../../../models/portfolio_model/position_book_model.dart';
import '../../../../provider/auth_provider.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../provider/order_provider.dart';
import '../../../../provider/portfolio_provider.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../../res/assets.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/responsive_extensions.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../sharedWidget/snack_bar.dart';
import '../../../../sharedWidget/common_buttons_web.dart';
import 'group_pnl_chart_dialog.dart';
import 'position_group_listcard_web.dart';
import 'position_group_table_web.dart';
import 'positionlist_bottom_sheet_web.dart';
import '../position_detail_screen_web.dart';

final assets = Assets();

bool isFutureOrOption(dynamic position) {
  final expDate = position['expDate']?.toString() ?? '';

  // F&O must have a valid expiry date
  return expDate.isNotEmpty && expDate != '' && expDate != '-';
}

String getBaseSymbol(dynamic position) {
  final symbol = position['symbol']?.toString() ?? '';
  // The symbol field contains the underlying like "NIFTY", "BANKNIFTY", "SENSEX", etc.
  return symbol.toUpperCase().trim();
}

String? validateCustomGroupAddition(
    dynamic position, List groupList, String groupName) {

  // Rule 1: Only F&O positions are allowed in groups
  if (!isFutureOrOption(position)) {
    return "Only Futures & Options can be grouped. Positions without expiry date cannot be added to groups.";
  }

  // Empty group - allow first F&O position
  if (groupList.isEmpty) {
    return null;
  }

  // Rule 2: Check for duplicate position (same token + prd)
  final newToken = position['token']?.toString() ?? '';
  final newPrd = position['prd']?.toString() ?? '';


  for (var existingPos in groupList) {
    final existingToken = existingPos['token']?.toString() ?? '';
    final existingPrd = existingPos['prd']?.toString() ?? '';


    if (newToken == existingToken && newPrd == existingPrd) {
      return "This position is already added to the group.";
    }
  }


  // Rule 3: All F&O positions in the group must have the same underlying symbol
  final newBaseSymbol = getBaseSymbol(position);

  // Get base symbol from existing positions
  final existingBaseSymbol = getBaseSymbol(groupList.first);

  if (newBaseSymbol != existingBaseSymbol) {
    return "Cannot add $newBaseSymbol to this group. This group contains $existingBaseSymbol positions only.";
  }

  return null; // Validation passed
}

class PositionGroupSymbol extends ConsumerStatefulWidget {
  final String? filterType; // 'default', 'custom', or null for all

  const PositionGroupSymbol({super.key, this.filterType});

  @override
  ConsumerState<PositionGroupSymbol> createState() =>
      _PositionGroupSymbolState();
}

class _PositionGroupSymbolState extends ConsumerState<PositionGroupSymbol> {
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _setupSocketSubscription();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  void _setupSocketSubscription() {
    // Delayed to ensure context is available
    Future.microtask(() {
      final websocket = ref.read(websocketProvider);
      final positionBook = ref.read(portfolioProvider);

      _socketSubscription = websocket.socketDataStream.listen((socketDatas) {
        // Use post-frame callback to update after current build completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          bool needsUpdate = false;

          try {
            // Create a snapshot of groups to avoid modification during iteration
            final groupSymbols =
                List<String>.from(positionBook.groupPositionSym);

            // Update positions with real-time data
            for (final groupSymbol in groupSymbols) {
              final groupData = positionBook.groupedBySymbol[groupSymbol];

              // Safety check: Ensure group exists
              if (groupData == null || groupData['groupList'] == null) continue;

              final originalGroupList = groupData['groupList'] as List;

              // Safety check: Ensure list is not empty
              if (originalGroupList.isEmpty) continue;

              // Update each position in the group directly (like normal position screen)
              // This ensures ALL positions get updated, even if multiple have same token
              for (var i = 0; i < originalGroupList.length; i++) {
                final position = originalGroupList[i];
                if (position == null) continue;

                final token = position['token'];
                if (token == null) continue;

                if (socketDatas.containsKey(token)) {
                  final socketData = socketDatas[token];
                  if (socketData == null) continue;

                  // Update LTP if valid
                  final lp = socketData['lp']?.toString();
                  if (lp != null &&
                      lp != "null" &&
                      lp != position['lp']) {
                    position['lp'] = lp;
                    needsUpdate = true;
                  }

                  // Update percent change if available
                  final pc = socketData['pc']?.toString();
                  if (pc != null &&
                      pc != "null" &&
                      pc != position['perChange']) {
                    position['perChange'] = pc;
                    needsUpdate = true;
                  }

                  // Update change if available
                  final chng = socketData['chng']?.toString();
                  if (chng != null &&
                      chng != "null" &&
                      chng != position['chng']) {
                    position['chng'] = chng;
                    needsUpdate = true;
                  }
                }
              }

              // Recalculate group totals only if data changed
              if (needsUpdate) {
                try {
                  positionBook.positionGroupCal(
                      positionBook.isDay,
                      originalGroupList,
                      groupSymbol,
                      groupData["isCustomGrp"] ?? false);
                } catch (e) {
                  // Skip if calculation fails
                }
              }
            }

            // FIX: Always update UI immediately when price data changes
            if (needsUpdate && mounted) {
              setState(() {});
            }
          } catch (e) {
            // Catch any errors to prevent crashes
          }
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final positionBook = ref.watch(portfolioProvider);

    // Show loader if data is being modified
    if (positionBook.posloader || positionBook.groupPositionSym.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Wrap in try-catch to handle any unexpected errors gracefully
    try {
      // Create immutable snapshots to prevent concurrent modification errors
      // Ensure we have valid data before proceeding
      if (positionBook.groupPositionSym.isEmpty &&
          positionBook.groupedBySymbol.isEmpty) {
        return NoDataFound(
          title: "No Groups Available",
          subtitle: "There are no position groups available at the moment.",
          primaryEnabled: false,
          secondaryEnabled: false,
        );
      }

      final groupSymbolsSnapshot =
          List<String>.from(positionBook.groupPositionSym);
      final groupedBySymbolSnapshot =
          Map<String, dynamic>.from(positionBook.groupedBySymbol);

      // Safety check: Ensure snapshot is valid
      if (groupSymbolsSnapshot.isEmpty) {
        return NoDataFound(
          title: widget.filterType == 'default'
              ? "No Default Groups"
              : widget.filterType == 'custom'
                  ? "No Custom Groups"
                  : "No Groups Available",
          subtitle: widget.filterType == 'default'
              ? "Default groups are automatically created for F&O positions with the same underlying symbol."
              : widget.filterType == 'custom'
                  ? "Create a custom group to organize your F&O positions as you like."
                  : "There are no F&O groups available at the moment.",
          primaryEnabled: false,
          secondaryEnabled: false,
        );
      }

      // Apply filter based on widget.filterType
      final filteredGroupSymbols = widget.filterType == null
          ? groupSymbolsSnapshot
          : groupSymbolsSnapshot.where((groupSymbol) {
              final groupData = groupedBySymbolSnapshot[groupSymbol];
              if (groupData == null) return false;

              final isCustomGrp = groupData["isCustomGrp"] ?? false;
              final groupList = (groupData['groupList'] as List?) ?? [];

              // For custom groups, show even if empty (user just created it)
              // For default groups, only show if it has F&O positions
              if (!isCustomGrp) {
                // Default group - must have F&O positions
                final hasFnoPositions = groupList.any((pos) =>
                  pos != null && isFutureOrOption(pos)
                );
                if (!hasFnoPositions) return false;
              }
              // Custom groups are always shown (even if empty)

              if (widget.filterType == 'default') {
                return !isCustomGrp;
              } else if (widget.filterType == 'custom') {
                return isCustomGrp;
              }
              return true;
            }).toList();

      // If no groups match the filter, show empty state
      if (filteredGroupSymbols.isEmpty) {
        return NoDataFound(
          title: widget.filterType == 'default'
              ? "No Default Groups"
              : widget.filterType == 'custom'
                  ? "No Custom Groups"
                  : "No Groups Available",
          subtitle: widget.filterType == 'default'
              ? "Default groups are automatically created for F&O positions with the same underlying symbol."
              : widget.filterType == 'custom'
                  ? "Create a custom group to organize your F&O positions as you like."
                  : "There are no F&O groups available at the moment.",
          primaryEnabled: false,
          secondaryEnabled: false,
        );
      }

      final itemCount = filteredGroupSymbols.length;
      // maxOpened should never exceed itemCount to avoid RangeError
      // Use a key based on itemCount to force rebuild when groups change
      // Ensure itemCount is valid before proceeding
      if (itemCount <= 0) {
        return NoDataFound(
          title: widget.filterType == 'default'
              ? "No Default Groups"
              : widget.filterType == 'custom'
                  ? "No Custom Groups"
                  : "No Groups Available",
          subtitle: widget.filterType == 'default'
              ? "Default groups are automatically created for F&O positions with the same underlying symbol."
              : widget.filterType == 'custom'
                  ? "Create a custom group to organize your F&O positions as you like."
                  : "There are no F&O groups available at the moment.",
          primaryEnabled: false,
          secondaryEnabled: false,
        );
      }

      return ExpandedTileList.separated(
              key: ValueKey(
                  'groups_${widget.filterType ?? 'all'}_${itemCount}_${filteredGroupSymbols.join('_')}'),
              padding: EdgeInsets.zero,
              itemCount: itemCount,
              maxOpened: itemCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index, controller) {
                try {
                  // Safety check: Ensure index is within bounds
                  if (index < 0 || index >= filteredGroupSymbols.length) {
                    return ExpandedTile(
                      controller: controller,
                      title: const SizedBox.shrink(),
                      content: const SizedBox.shrink(),
                    );
                  }
          
                  // Safety check: Ensure group symbol exists
                  final groupSymbol = filteredGroupSymbols[index];
                  final groupData = groupedBySymbolSnapshot[groupSymbol];
          
                  if (groupData == null) {
                    return ExpandedTile(
                      controller: controller,
                      title: const SizedBox.shrink(),
                      content: const SizedBox.shrink(),
                    );
                  }
          
                  // Create snapshot of groupList to avoid concurrent modification
                  final rawGroupList = groupData['groupList'];
                  final groupList = rawGroupList != null && rawGroupList is List
                      ? List.from(rawGroupList)
                      : <dynamic>[];
                  final isCustomGrp = groupData["isCustomGrp"] ?? false;
                  final totPnl = (groupData['totPnl'] ?? '0.00').toString();
                  final totMtm = (groupData['totMtm'] ?? '0.00').toString();
          
                  return ExpandedTile(
                    contentseparator: 0.0, // Remove the grey line separator
                    theme: ExpandedTileThemeData(
                        // Show background only when expanded - this covers the full header area
                        headerColor: controller.isExpanded
                            ? (isDarkMode(context)
                                ? const Color(0xffB5C0CF).withValues(alpha: 0.15)
                                : const Color(0xffF1F3F8))
                            : Colors.transparent,
                        headerPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12), // Padding for header
                        contentBackgroundColor: Colors.transparent,
                        contentSeparatorColor:
                            Colors.transparent, // Remove separator color
                        headerBorder:
                            const OutlineInputBorder(borderSide: BorderSide.none),
                        contentBorder:
                            const OutlineInputBorder(borderSide: BorderSide.none),
                        footerBorder:
                            const OutlineInputBorder(borderSide: BorderSide.none),
                        fullExpandedBorder:
                            const OutlineInputBorder(borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.all(0),
                        trailingPadding: const EdgeInsets.symmetric(horizontal: 0)),
                    controller: controller,
                    trailing: const SizedBox.shrink(), // Hide the arrow icon
                    onTap: () {
                      // Toggle expansion and rebuild to show/hide background
                      setState(() {});
                    },
                    title: Padding(
                      padding: EdgeInsets
                          .zero, // Remove padding from title since headerPadding handles it
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Header with symbol, action buttons (when expanded), and P&L
                          GroupTileHeader(
                            groupSymbol: groupSymbol,
                            itemCount: groupList.length,
                            totPnl: totPnl,
                            totMtm: totMtm,
                            isNetPnl: positionBook.isNetPnl,
                            isExpanded: controller.isExpanded,
                            isCustomGrp: isCustomGrp,
                            groupList: groupList,
                          ),
                        ],
                      ),
                    ),
                    content: GroupContentArea(
                      groupSymbol: groupSymbol,
                      groupList: groupList,
                      isCustomGrp: isCustomGrp,
                    ),
                  );
                } catch (e) {
                  // Return empty tile if any error occurs
                  return ExpandedTile(
                    controller: controller,
                    title: const SizedBox.shrink(),
                    content: const SizedBox.shrink(),
                  );
                }
              },
              separatorBuilder: (BuildContext context, int index) {
                // Safety check: separatorBuilder indices are 0 to (itemCount-2)
                // Ensure index is within valid range
                if (index < 0 || index >= itemCount - 1) {
                  return const SizedBox.shrink();
                }
                // Return a visible divider line between groups (not for last item)
                return Divider(
                  height: 1,
                  thickness: 0.5,
                  color: resolveThemeColor(context,
                      dark: MyntColors.dividerDark,
                      light: MyntColors.divider),
                );
              });
    } catch (e) {
      // If any error occurs during build, show empty state instead of crashing
      return const Center(
        child: Text('Unable to load groups'),
      );
    }
  }
}

/// Header widget for group tile showing symbol name, P&L, and action buttons when expanded
class GroupTileHeader extends ConsumerWidget {
  final String groupSymbol;
  final int itemCount;
  final String totPnl;
  final String totMtm;
  final bool isNetPnl;
  final bool isExpanded;
  final bool isCustomGrp;
  final List groupList;

  const GroupTileHeader({
    super.key,
    required this.groupSymbol,
    required this.itemCount,
    required this.totPnl,
    required this.totMtm,
    required this.isNetPnl,
    required this.isExpanded,
    required this.isCustomGrp,
    required this.groupList,
  });

  Color _getPnlColor(String value, BuildContext context) {
    if (value.startsWith("-")) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    } else if (value == "0.00") {
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    }
    return resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = isNetPnl ? totPnl : totMtm;

    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: Symbol name + Action buttons (when expanded)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                groupSymbol,
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium,
                ),
              ),
              // Action buttons - only show when expanded, right next to group name
              if (isExpanded) ...[
                const SizedBox(width: 12),
                // For custom groups: Add Symbol and Delete buttons
                if (isCustomGrp) ...[
                  _HeaderActionButton(
                    icon: assets.bookmarkedIcon,
                    tooltip: 'Add Symbol',
                    onTap: () => _showAddSymbolDialog(context, ref),
                  ),
                  const SizedBox(width: 4),
                  _HeaderActionButton(
                    icon: assets.trash,
                    tooltip: 'Delete Group',
                    onTap: () => _showDeleteGroupDialog(context, ref),
                    iconSize: 14,
                    iconColor: resolveThemeColor(context,
                        dark: MyntColors.errorDark,
                        light: MyntColors.error),
                  ),
                  const SizedBox(width: 4),
                ],
                // Exit button for all groups (when has exitable positions)
                _HeaderExitButton(
                  groupSymbol: groupSymbol,
                  groupList: groupList,
                ),
                const SizedBox(width: 4),
                // P&L chart button
                _HeaderActionButton(
                  icon: assets.linechart,
                  tooltip: 'P&L Chart',
                  onTap: () => showGroupPnlChartDialog(
                    context,
                    ref: ref,
                    groupName: groupSymbol,
                    groupList: groupList,
                  ),
                ),
              ],
            ],
          ),
          // Right side: P&L value only
          Text(
            value,
            style: MyntWebTextStyles.title(
              context,
              color: _getPnlColor(value, context),
              fontWeight: MyntFonts.medium,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSymbolDialog(BuildContext context, WidgetRef ref) async {
    final positionBook = ref.read(portfolioProvider);
    await positionBook.cusGrpSelectPosition(groupList);
    if (context.mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: resolveThemeColor(
          context,
          dark: MyntColors.modalBarrierDark,
          light: MyntColors.modalBarrierLight,
        ),
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return PositionListBottomSheet(grpName: groupSymbol);
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: curvedAnimation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
              child: child,
            ),
          );
        },
      );
    }
  }

  void _showDeleteGroupDialog(BuildContext context, WidgetRef ref) {
    final positionBook = ref.read(portfolioProvider);
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: resolveThemeColor(
        context,
        dark: MyntColors.modalBarrierDark,
        light: MyntColors.modalBarrierLight,
      ),
      builder: (dialogContext) => DeleteGroupDialog(
        groupSymbol: groupSymbol,
        onDelete: () async {
          await positionBook.fetchDeleteGroupName(groupSymbol, context);
          if (context.mounted) {
            Navigator.of(context).maybePop();
          }
        },
      ),
    );
  }
}

/// Small action button for header (icon only)
class _HeaderActionButton extends StatelessWidget {
  final String icon;
  final String tooltip;
  final VoidCallback onTap;
  final double? iconSize;
  final Color? iconColor;

  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconSize,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = iconSize ?? 18.0;
    final color = iconColor ??
        resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          splashColor: isDarkMode(context)
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.15),
          highlightColor: isDarkMode(context)
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SvgPicture.asset(
              icon,
              width: size,
              height: size,
              colorFilter: ColorFilter.mode(
                color,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Exit button for header - only shows if group has exitable positions
class _HeaderExitButton extends ConsumerWidget {
  final String groupSymbol;
  final List groupList;

  const _HeaderExitButton({
    required this.groupSymbol,
    required this.groupList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionBook = ref.watch(portfolioProvider);

    // Check if group has any positions with qty != "0"
    bool hasExitablePositions = false;

    for (var item in groupList) {
      if (item == null) continue;

      final token = item['token']?.toString();
      final tsym = item['tsym']?.toString();
      final exch = item['exch']?.toString();

      if (token == null || tsym == null || exch == null) {
        final qty = item['qty']?.toString() ?? "0";
        final netQty = (item['netqty'] ?? item['qty'])?.toString() ?? "0";
        if (qty != "0" && netQty != "0") {
          hasExitablePositions = true;
          break;
        }
        continue;
      }

      try {
        PositionBookModel? actualPosition;
        if (positionBook.postionBookModel != null) {
          try {
            actualPosition = positionBook.postionBookModel!.firstWhere(
              (pos) => pos.token == token && pos.tsym == tsym && pos.exch == exch,
            );
          } catch (e) {
            actualPosition = null;
          }
        }

        if (actualPosition != null) {
          final qty = actualPosition.qty ?? "0";
          final netQty = actualPosition.netqty ?? "0";
          if (qty != "0" && netQty != "0") {
            hasExitablePositions = true;
            break;
          }
        } else {
          final qty = item['qty']?.toString() ?? "0";
          final netQty = (item['netqty'] ?? item['qty'])?.toString() ?? "0";
          if (qty != "0" && netQty != "0") {
            hasExitablePositions = true;
            break;
          }
        }
      } catch (e) {
        final qty = item['qty']?.toString() ?? "0";
        final netQty = (item['netqty'] ?? item['qty'])?.toString() ?? "0";
        if (qty != "0" && netQty != "0") {
          hasExitablePositions = true;
          break;
        }
      }
    }

    if (!hasExitablePositions) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: 'Exit All Positions',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showExitAllDialog(context, ref),
          splashColor: isDarkMode(context)
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.15),
          highlightColor: isDarkMode(context)
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              "Exit",
              style: MyntWebTextStyles.body(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.errorDark, light: MyntColors.loss),
                fontWeight: MyntFonts.semiBold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showExitAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: resolveThemeColor(
        context,
        dark: MyntColors.modalBarrierDark,
        light: MyntColors.modalBarrierLight,
      ),
      builder: (dialogContext) => ExitAllGroupDialog(
        groupSymbol: groupSymbol,
        groupList: groupList,
        onExit: () async {
          final positionBook = ref.read(portfolioProvider);
          await _exitAllGroupPositions(context, positionBook, ref);
          if (context.mounted) {
            Navigator.of(context).maybePop();
            // Refresh positions to reflect exited orders
            positionBook.fetchPositionBook(context, positionBook.isDay,
                isRefresh: true);
          }
        },
      ),
    );
  }

  Future<void> _exitAllGroupPositions(
      BuildContext context, dynamic positionBook, WidgetRef ref) async {
    try {
      // Check if this is a custom group or automatic group
      final groupData = positionBook.groupedBySymbol[groupSymbol];
      final isCustomGrp = groupData?['isCustomGrp'] ?? false;

      // Build a set of position identifiers for this group (for custom groups)
      final Set<String> groupPositionKeys = {};
      if (isCustomGrp) {
        for (var groupItem in groupList) {
          if (groupItem == null) continue;
          final token = groupItem['token']?.toString();
          final tsym = groupItem['tsym']?.toString();
          final exch = groupItem['exch']?.toString();
          if (token != null && tsym != null && exch != null) {
            groupPositionKeys.add("$token|$tsym|$exch");
          }
        }
      }

      // Iterate through all positions and exit those belonging to this group
      for (var element in positionBook.postionBookModel ?? []) {
        bool belongsToGroup = false;
        if (isCustomGrp) {
          final positionKey = "${element.token}|${element.tsym}|${element.exch}";
          belongsToGroup = groupPositionKeys.contains(positionKey);
        } else {
          belongsToGroup = element.symbol == groupSymbol;
        }

        if (belongsToGroup && element.qty != "0") {
          if (((element.sPrdtAli == "MIS" || element.sPrdtAli == "CNC") ||
              element.sPrdtAli == "NRML")) {
            PlaceOrderInput placeOrderInput = PlaceOrderInput(
              amo: "",
              blprc: '',
              bpprc: '',
              dscqty: "",
              exch: "${element.exch}",
              prc: "0",
              prctype: "MKT",
              prd: "${element.prd}",
              qty: element.qty!.replaceAll("-", ""),
              ret: "DAY",
              trailprc: '',
              trantype: int.parse(element.qty!) < 0 ? 'B' : 'S',
              trgprc: "",
              tsym: "${element.tsym}",
              mktProt: '',
              channel: defaultTargetPlatform == TargetPlatform.android
                  ? '${ref.read(authProvider).deviceInfo["brand"]}'
                  : "${ref.read(authProvider).deviceInfo["model"]}",
            );

            final orderProv = ref.read(orderProvider);
            final placeOrderModel = await positionBook.api.getPlaceOrder(
                placeOrderInput, orderProv.ip);

            if (placeOrderModel.stat?.toLowerCase() != "ok") {
              // Continue with remaining positions instead of stopping
            }
          }
        }
      }
    } catch (e) {
    }
  }
}

/// Analyse button widget for groups
/// Only shows if group contains F&O positions (not equity-only)
class GroupAnalyseButton extends ConsumerWidget {
  final String groupSymbol;
  final List groupList;

  const GroupAnalyseButton({
    super.key,
    required this.groupSymbol,
    required this.groupList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderProv = ref.read(orderProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          try {
            // Convert groupList items (Maps) to PositionBookModel objects
            final array = <PositionBookModel>[];
            
            for (var groupItem in groupList) {
              if (groupItem == null) continue;
              
              // Convert Map to PositionBookModel
              try {
                final position = PositionBookModel.fromJson(
                  groupItem as Map<String, dynamic>
                );
                array.add(position);
              } catch (e) {
                // Skip invalid items
                continue;
              }
            }

            // Validate that group has positions
            if (array.isEmpty) {
              error(context, "No positions in this group");
              return;
            }

            // Filter positions with non-zero net quantity; analysis not useful for flat positions
            final positionsToAnalyse = array
                .where((p) =>
                    (double.tryParse(p.netqty ?? '0') ?? 0).abs() > 0)
                .toList();

            if (positionsToAnalyse.isEmpty) {
              error(context,
                  "Net quantity is zero. Please select positions with quantity to analyse");
              return;
            }

            // Extract symbols and expiry dates (only for positions with qty)
            List<String> symbols = [];
            List<String> expDates = [];

            for (var position in positionsToAnalyse) {
              String symbol;
              String expDate;

              // Use existing symbol and expDate if available, otherwise extract
              if (position.symbol != null && position.symbol!.isNotEmpty &&
                  position.expDate != null && position.expDate!.isNotEmpty) {
                symbol = position.symbol!;
                expDate = position.expDate!;
              } else {
                // Extract from position data similar to how it's done in portfolio provider
                if (position.exch == "BFO" && position.dname != null && position.dname != "null") {
                  List<String> splitVal = position.dname!.split(" ");
                  symbol = splitVal[0];
                  // BFO: keep dname's day+month, append the year from the tsym. (TC_440)
                  expDate = bfoExpiryWithYear(splitVal, position.tsym);
                } else {
                  Map spilitSymbol = spilitTsym(value: "${position.tsym}");
                  symbol = "${spilitSymbol["symbol"]}";
                  expDate = "${spilitSymbol["expDate"]}";
                }
              }

              symbols.add(symbol);
              expDates.add(expDate);
            }

            // Check if all symbols are the same
            bool allSymbolsSame =
                symbols.every((symbol) => symbol == symbols[0]);
            // Check if all expiry dates are the same
            bool allExpDatesSame =
                expDates.every((expDate) => expDate == expDates[0]);

            if (!allSymbolsSame) {
              String errorMessage = "";
              if (!allSymbolsSame && !allExpDatesSame) {
                errorMessage = "Please select positions with the same symbol and expiry date";
              } else if (!allSymbolsSame) {
                errorMessage = "Please select positions with the same symbol";
              } else {
                errorMessage = "Please select positions with the same expiry date";
              }

              error(context, errorMessage);
              return;
            }
      // final List<Map<String, dynamic>> legs = [];
      
      for (var position in positionsToAnalyse) {

        try {
      final tsym = position.tsym ?? '';
      final symbolName = position.symbol ?? '';
      final netQty = double.tryParse(position.netqty ?? '0') ?? 0;
      final isBuy = netQty > 0;
      final absQty = netQty.abs();
      
      final leg = {
            'dname': position.dname ?? tsym,
            'token': position.token ?? '',
            'pp': position.pp ?? '',
            'ti': position.ti ?? '',
            'ls': position.ls ?? '',
            'amo': '', 
            'blprc': '', 
            'bpprc': '', 
            'dscqty': '', 
            'exch': position.exch ?? '',
            'prc': position.avgPrc ?? '',
            'prctype': '', 
            'prd': position.prd ?? '', 
            'ordType': position.sPrdtAli ?? '', 
            'qty': absQty.toString(), 
            'ret': '', 
            'trailprc': '', 
            'trantype': isBuy ? 'B' : 'S', 
            'trgprc': '', 
            'tsym': position.tsym ?? '',
            'mktProt': '', 
            'lp': position.lp ?? '', 
            'pc': position.perChange ?? '', 
            'symbol': symbolName,
            'expDate': position.expDate ?? '',
            'option': position.option ?? '',
          };
      // orderProv.addPayoffLeg(leg);
    } on Exception catch (e) {
    }
      }
  // orderProv.setPayoffLegs(orderProv.payoffLegs);
    
      // Fetch basket margin using payoffLegs before fetching chart
      // if (orderProv.payoffLegs.isNotEmpty) {
      //   await orderProv.fetchBasketMarginFromPayoffLegs();
      // }
    
    //   orderProv.fetchpayoffchart(
    //         orderProv.payoffLegs,
    //         '',
    //         'position',
    //         isCalculate: false,
    //     );
    //  Navigator.pushNamed(context, Routes.payofffMainScreen);
      }
      catch(e){
      error(context, "Failed to analyse positions");
      }
      },
      // Set payoff legs - do this BEFORE fetching chart data to ensure legs are available
      // if (legs.isNotEmpty) {
      //   orderProv.setPayoffLegs(legs);
       

      
            
      //       Navigator.pushNamed(context, Routes.payofffMainScreen);
      //       orderProv.fetchpayoffchart(orderProv.payoffLegs, "", 'position');
      //       // Handle error silently or show message if needed
      //       debugPrint("Error in GroupAnalyseButton: $e");
      //     }
        splashColor: isDarkMode(context)
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.15),
        highlightColor: isDarkMode(context)
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            "Analyse",
            style: MyntWebTextStyles.body(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.secondary, light: MyntColors.secondary),
              fontWeight: MyntFonts.semiBold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Add Symbol button widget for custom groups
class GroupAddSymbolButton extends ConsumerWidget {
  final String groupSymbol;
  final List groupList;

  const GroupAddSymbolButton({
    super.key,
    required this.groupSymbol,
    required this.groupList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionBook = ref.read(portfolioProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          await positionBook.cusGrpSelectPosition(groupList);
          if (context.mounted) {
            showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
              barrierColor: resolveThemeColor(
                context,
                dark: MyntColors.modalBarrierDark,
                light: MyntColors.modalBarrierLight,
              ),
              transitionDuration: const Duration(milliseconds: 200),
              pageBuilder: (context, animation, secondaryAnimation) {
                return PositionListBottomSheet(grpName: groupSymbol);
              },
              transitionBuilder: (context, animation, secondaryAnimation, child) {
                final curvedAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                  reverseCurve: Curves.easeIn,
                );

                return FadeTransition(
                  opacity: curvedAnimation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
                    child: child,
                  ),
                );
              },
            );
          }
        },
        splashColor: isDarkMode(context)
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.15),
        highlightColor: isDarkMode(context)
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SvgPicture.asset(
            assets.bookmarkedIcon,
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              resolveThemeColor(context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary),
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

/// Delete Group button widget for custom groups
class GroupDeleteGroupButton extends ConsumerWidget {
  final String groupSymbol;

  const GroupDeleteGroupButton({
    super.key,
    required this.groupSymbol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionBook = ref.read(portfolioProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _showDeleteDialog(context, ref, positionBook),
        splashColor: isDarkMode(context)
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.15),
        highlightColor: isDarkMode(context)
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.delete_outline,
            size: 20,
            color: resolveThemeColor(context,
                dark: MyntColors.lossDark, light: MyntColors.loss),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic positionBook,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: resolveThemeColor(
        context,
        dark: MyntColors.modalBarrierDark,
        light: MyntColors.modalBarrierLight,
      ),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return DeleteGroupDialog(
          groupSymbol: groupSymbol,
          onDelete: () async {
            await positionBook.fetchDeleteGroupName(groupSymbol, context);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}

/// Popup menu widget for group actions (DEPRECATED - now using buttons in toolbar)
class GroupPopupMenu extends ConsumerStatefulWidget {
  final String groupSymbol;
  final List groupList;
  final bool isCustomGrp;

  const GroupPopupMenu({
    super.key,
    required this.groupSymbol,
    required this.groupList,
    required this.isCustomGrp,
  });

  @override
  ConsumerState<GroupPopupMenu> createState() => _GroupPopupMenuState();
}

class _GroupPopupMenuState extends ConsumerState<GroupPopupMenu> {
  String selectedAction = 'Add Symbol'; // Track selected action

  @override
  Widget build(BuildContext context) {
    final positionBook = ref.read(portfolioProvider);

    if (!widget.isCustomGrp) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      color: resolveThemeColor(context,
          dark: MyntColors.searchBgDark, light: MyntColors.searchBg),
      offset: const Offset(0, 40), // Position menu below the button
      onSelected: (String selected) async {
        setState(() {
          selectedAction = selected;
        });
        if (selected == 'delete') {
          _showDeleteDialog(context, ref, positionBook);
        } else if (selected == 'add_symbol') {
          await positionBook.cusGrpSelectPosition(widget.groupList);
          if (context.mounted) {
            showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
              barrierColor: resolveThemeColor(
                context,
                dark: MyntColors.modalBarrierDark,
                light: MyntColors.modalBarrierLight,
              ),
              transitionDuration: const Duration(milliseconds: 200),
              pageBuilder: (context, animation, secondaryAnimation) {
                return PositionListBottomSheet(grpName: widget.groupSymbol);
              },
              transitionBuilder: (context, animation, secondaryAnimation, child) {
                final curvedAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                  reverseCurve: Curves.easeIn,
                );

                return FadeTransition(
                  opacity: curvedAnimation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
                    child: child,
                  ),
                );
              },
            );
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'add_symbol',
          child: Row(
            children: [
              Text(
                'Add / Delete Symbol',
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                  fontWeight: MyntFonts.medium,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Text(
                'Delete Group',
                style: MyntWebTextStyles.body(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.lossDark, light: MyntColors.loss),
                  fontWeight: MyntFonts.medium,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: isDarkMode(context)
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.15),
          highlightColor: isDarkMode(context)
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset(
              assets.threedots,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic positionBook,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: resolveThemeColor(
        context,
        dark: MyntColors.modalBarrierDark,
        light: MyntColors.modalBarrierLight,
      ),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return DeleteGroupDialog(
          groupSymbol: widget.groupSymbol,
          onDelete: () async {
            await positionBook.fetchDeleteGroupName(widget.groupSymbol, context);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}

/// Delete button widget for custom groups
class GroupDeleteButton extends ConsumerWidget {
  final String groupSymbol;

  const GroupDeleteButton({
    super.key,
    required this.groupSymbol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionBook = ref.read(portfolioProvider);

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        customBorder: const CircleBorder(),
        splashColor: isDarkMode(context)
            ? MyntColors.rippleDark
            : MyntColors.rippleLight,
        highlightColor: isDarkMode(context)
            ? MyntColors.highlightDark
            : MyntColors.highlightLight,
        onTap: () => _showDeleteDialog(context, ref, positionBook),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(
            Icons.delete_outline,
            size: 20,
            color: resolveThemeColor(context,
                dark: MyntColors.lossDark, light: MyntColors.loss),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic positionBook,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: resolveThemeColor(
        context,
        dark: MyntColors.modalBarrierDark,
        light: MyntColors.modalBarrierLight,
      ),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return DeleteGroupDialog(
          groupSymbol: groupSymbol,
          onDelete: () async {
            await positionBook.fetchDeleteGroupName(groupSymbol, context);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}

/// Confirmation dialog for deleting a group - Web style
class DeleteGroupDialog extends StatefulWidget {
  final String groupSymbol;
  final Future<void> Function() onDelete;

  const DeleteGroupDialog({
    super.key,
    required this.groupSymbol,
    required this.onDelete,
  });

  @override
  State<DeleteGroupDialog> createState() => _DeleteGroupDialogState();
}

class _DeleteGroupDialogState extends State<DeleteGroupDialog> {
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      await widget.onDelete();
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: Container(
              width: 400,
              constraints: const BoxConstraints(maxHeight: 250),
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
                          'Delete Group',
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
                          onPressed: _isDeleting
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Are you sure you want to delete "${widget.groupSymbol}"?',
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.body(
                              context,
                              fontWeight: FontWeight.w500,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          MyntButton(
                            type: MyntButtonType.primary,
                            size: MyntButtonSize.large,
                            label: 'Delete',
                            isFullWidth: true,
                            isLoading: _isDeleting,
                            backgroundColor: resolveThemeColor(
                              context,
                              dark: MyntColors.errorDark,
                              light: MyntColors.tertiary,
                            ),
                            onPressed: _isDeleting ? null : _handleDelete,
                          ),
                        ],
                      ),
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

/// Add symbol button widget
class AddSymbolButton extends ConsumerWidget {
  final String groupSymbol;
  final List groupList;

  const AddSymbolButton({
    super.key,
    required this.groupSymbol,
    required this.groupList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionBook = ref.read(portfolioProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await positionBook.cusGrpSelectPosition(groupList);
          if (context.mounted) {
            showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
              barrierColor: resolveThemeColor(
                context,
                dark: MyntColors.modalBarrierDark,
                light: MyntColors.modalBarrierLight,
              ),
              transitionDuration: const Duration(milliseconds: 200),
              pageBuilder: (context, animation, secondaryAnimation) {
                return PositionListBottomSheet(grpName: groupSymbol);
              },
              transitionBuilder: (context, animation, secondaryAnimation, child) {
                final curvedAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                  reverseCurve: Curves.easeIn,
                );

                return FadeTransition(
                  opacity: curvedAnimation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
                    child: child,
                  ),
                );
              },
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                "Add",
                style: MyntWebTextStyles.body(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.primaryDark, light: MyntColors.primary),
                  fontWeight: MyntFonts.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty group state widget
class EmptyGroupState extends StatelessWidget {
  final String groupSymbol;
  final List groupList;

  const EmptyGroupState({
    super.key,
    required this.groupSymbol,
    required this.groupList,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "No symbols added yet",
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.body(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Separator widget for group items
class GroupItemSeparator extends StatelessWidget {
  final dynamic groupItem;

  const GroupItemSeparator({
    super.key,
    required this.groupItem,
  });

  @override
  Widget build(BuildContext context) {
    final qty = groupItem?['qty']?.toString() ?? "";

    return Container(
      color: isDarkMode(context)
          ? qty == "0"
              ? MyntColors.backgroundColorDark
              : MyntColors.listItemBgDark
          : qty == "0"
              ? MyntColors.backgroundColor
              : MyntColors.listItemBg,
      height: 1,
    );
  }
}

/// Individual group symbol list item wrapper
class GroupSymbolListItem extends ConsumerWidget {
  final dynamic groupItem;

  const GroupSymbolListItem({
    super.key,
    required this.groupItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketWatch = ref.read(marketWatchProvider);
    final positionBook = ref.watch(portfolioProvider); // Watch to get updates

    // For custom groups, get the actual current position data instead of snapshot
    // This ensures closed positions show the correct background
    Map<String, dynamic> actualGroupData = groupItem;

    // Try to find the actual position in the current position book
    final token = groupItem['token']?.toString();
    final tsym = groupItem['tsym']?.toString();
    final exch = groupItem['exch']?.toString();
    final prd = groupItem['prd']?.toString();

    if (token != null &&
        tsym != null &&
        exch != null &&
        positionBook.postionBookModel != null) {
      try {
        final actualPosition = positionBook.postionBookModel!.firstWhere(
          (pos) =>
              pos.token == token &&
              pos.tsym == tsym &&
              pos.exch == exch &&
              (prd == null || pos.prd == prd),
        );

        // Update the groupData with actual current values
        actualGroupData = Map<String, dynamic>.from(groupItem);
        actualGroupData['qty'] = actualPosition.qty ?? groupItem['qty'];
        actualGroupData['netqty'] =
            actualPosition.netqty ?? groupItem['netqty'];
        actualGroupData['lp'] = actualPosition.lp ?? groupItem['lp'];
        actualGroupData['profitNloss'] =
            actualPosition.profitNloss ?? groupItem['profitNloss'];
        actualGroupData['mTm'] = actualPosition.mTm ?? groupItem['mTm'];
        actualGroupData['rpnl'] = actualPosition.rpnl ?? groupItem['rpnl'];
        actualGroupData['avgPrc'] =
            actualPosition.avgPrc ?? groupItem['avgPrc'];
        actualGroupData['netavgprc'] =
            actualPosition.netavgprc ?? groupItem['netavgprc'];
        actualGroupData['netupldprc'] =
            actualPosition.netupldprc ?? groupItem['netupldprc'];
      } catch (e) {
        // Position not found, use original groupItem data
        actualGroupData = groupItem;
      }
    }

    return InkWell(
      onTap: () => _handleTap(context, marketWatch, positionBook),
      child: PositionListGrpCard(groupData: actualGroupData),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    dynamic marketWatch,
    dynamic positionBook,
  ) async {
    // Save parent context for navigation
    final parentCtx = context;

    // Fetch linked scrip data
    await marketWatch.fetchLinkeScrip(
      "${groupItem['token']}",
      "${groupItem['exch']}",
      context,
    );

    // Fetch scrip quote
    await marketWatch.fetchScripQuote(
      "${groupItem['token']}",
      "${groupItem['exch']}",
      context,
    );

    // Handle NSE/BSE specific data
    if (groupItem['exch'] == "NSE" || groupItem['exch'] == "BSE") {
      await marketWatch.fetchTechData(
        context: context,
        exch: "${groupItem['exch']}",
        tradeSym: "${groupItem['tsym']}",
        lastPrc: "${groupItem['lp']}",
      );
    }

    // Navigate to position detail using shadcn.openSheet (same as Positions tab)
    if (context.mounted) {
      // Find the position by token, tsym, exch AND product
      PositionBookModel? foundPosition;
      try {
        final token = groupItem['token']?.toString();
        final tsym = groupItem['tsym']?.toString();
        final exch = groupItem['exch']?.toString();
        final prd = groupItem['prd']?.toString();

        foundPosition = positionBook.postionBookModel!.firstWhere(
          (pos) =>
              pos.token == token &&
              pos.tsym == tsym &&
              pos.exch == exch &&
              (prd == null || pos.prd == prd),
        );
      } catch (e) {
        // If not found, use first position as fallback
        if (positionBook.postionBookModel != null &&
            positionBook.postionBookModel!.isNotEmpty) {
          foundPosition = positionBook.postionBookModel!.first;
        }
      }

      // If position not found, show error message
      if (foundPosition == null) {
        showResponsiveWarningMessage(context, "Position not found");
        return;
      }

      // Show web detail screen in shadcn sheet (matching Positions tab behavior)
      shadcn.openSheet(
        context: context,
        barrierColor: Colors.transparent,
        builder: (sheetContext) {
          final screenWidth = MediaQuery.of(sheetContext).size.width;
          final sheetWidth = screenWidth < 1300 ? screenWidth * 0.3 : 480.0;
          return Container(
            width: sheetWidth,
            decoration: BoxDecoration(
              color: resolveThemeColor(
                context,
                dark: MyntColors.backgroundColorDark,
                light: MyntColors.backgroundColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 5,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: PositionDetailScreenWeb(
              positionList: foundPosition!,
              parentContext: parentCtx,
            ),
          );
        },
        position: shadcn.OverlayPosition.end,
      );
    }
  }
}

/// Main content area for group tile (handles empty state and list display)
class GroupContentArea extends StatelessWidget {
  final String groupSymbol;
  final List groupList;
  final bool isCustomGrp;

  const GroupContentArea({
    super.key,
    required this.groupSymbol,
    required this.groupList,
    required this.isCustomGrp,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = groupList.isEmpty;

    // Group content - show table or empty state (action buttons moved to header)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Space between header and content
        const SizedBox(height: 8),
        // Show empty state for custom groups if no items
        if (isEmpty && isCustomGrp)
          EmptyGroupState(
            groupSymbol: groupSymbol,
            groupList: groupList,
          ),
        // Only render content if groupList is not empty
        if (groupList.isNotEmpty)
          // Use table view for both default and custom groups
          PositionGroupTable(
            groupSymbol: groupSymbol,
            groupList: groupList,
            isCustomGrp: isCustomGrp,
          ),
      ],
    );
  }
}

/// Exit All button widget for groups
class GroupExitAllButton extends ConsumerWidget {
  final String groupSymbol;
  final List groupList;

  const GroupExitAllButton({
    super.key,
    required this.groupSymbol,
    required this.groupList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionBook = ref.watch(portfolioProvider);

    // Check if group has any positions with qty != "0"
    // For custom groups, we need to check the actual current position data
    // instead of relying on the snapshot which might be stale
    bool hasExitablePositions = false;

    // Check each position in the groupList against the actual position data
    for (var item in groupList) {
      if (item == null) continue;

      // Get token and tsym to find the actual position
      final token = item['token']?.toString();
      final tsym = item['tsym']?.toString();
      final exch = item['exch']?.toString();

      if (token == null || tsym == null || exch == null) {
        // Fallback to checking the snapshot data
        final qty = item['qty']?.toString() ?? "0";
        final netQty = (item['netqty'] ?? item['qty'])?.toString() ?? "0";
        if (qty != "0" && netQty != "0") {
          hasExitablePositions = true;
          break;
        }
        continue;
      }

      // Find the actual position in the current position book
      try {
        PositionBookModel? actualPosition;
        if (positionBook.postionBookModel != null) {
          try {
            actualPosition = positionBook.postionBookModel!.firstWhere(
              (pos) =>
                  pos.token == token && pos.tsym == tsym && pos.exch == exch,
            );
          } catch (e) {
            // Position not found, actualPosition remains null
            actualPosition = null;
          }
        }

        if (actualPosition != null) {
          // Check the actual current qty and netqty
          final qty = actualPosition.qty ?? "0";
          final netQty = actualPosition.netqty ?? "0";

          if (qty != "0" && netQty != "0") {
            hasExitablePositions = true;
            break;
          }
        } else {
          // Position not found in current list, check snapshot as fallback
          final qty = item['qty']?.toString() ?? "0";
          final netQty = (item['netqty'] ?? item['qty'])?.toString() ?? "0";
          if (qty != "0" && netQty != "0") {
            hasExitablePositions = true;
            break;
          }
        }
      } catch (e) {
        // Error finding position, use snapshot data as fallback
        final qty = item['qty']?.toString() ?? "0";
        final netQty = (item['netqty'] ?? item['qty'])?.toString() ?? "0";
        if (qty != "0" && netQty != "0") {
          hasExitablePositions = true;
          break;
        }
      }
    }

    if (!hasExitablePositions) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showExitAllDialog(context, ref),
        splashColor: isDarkMode(context)
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.15),
        highlightColor: isDarkMode(context)
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Exit",
                style: MyntWebTextStyles.body(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.lossDark, light: MyntColors.loss),
                  fontWeight: MyntFonts.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitAllDialog(
    BuildContext context,
    WidgetRef ref,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: resolveThemeColor(
        context,
        dark: MyntColors.modalBarrierDark,
        light: MyntColors.modalBarrierLight,
      ),
      builder: (dialogContext) => ExitAllGroupDialog(
        groupSymbol: groupSymbol,
        groupList: groupList,
        onExit: () async {
          final positionBook = ref.read(portfolioProvider);
          await _exitAllGroupPositions(context, positionBook, ref);
          if (context.mounted) {
            Navigator.of(context).maybePop();
            // Refresh positions to reflect exited orders
            positionBook.fetchPositionBook(context, positionBook.isDay,
                isRefresh: true);
          }
        },
      ),
    );
  }

  Future<void> _exitAllGroupPositions(
    BuildContext context,
    dynamic positionBook,
    WidgetRef ref,
  ) async {
    try {
      // Check if this is a custom group or automatic group
      final groupData = positionBook.groupedBySymbol[groupSymbol];
      final isCustomGrp = groupData?['isCustomGrp'] ?? false;
      
      // Build a set of position identifiers for this group (for custom groups)
      // For automatic groups, we'll check by symbol
      final Set<String> groupPositionKeys = {};
      if (isCustomGrp) {
        // For custom groups, build set of token+tsym+exch keys
        for (var groupItem in groupList) {
          if (groupItem == null) continue;
          final token = groupItem['token']?.toString();
          final tsym = groupItem['tsym']?.toString();
          final exch = groupItem['exch']?.toString();
          if (token != null && tsym != null && exch != null) {
            groupPositionKeys.add("$token|$tsym|$exch");
          }
        }
      }

      // Iterate through all positions directly (same as Exit All)
      // Check if each position belongs to this group, then exit it
      for (var element in positionBook.postionBookModel ?? []) {
        // Check if position belongs to this group
        bool belongsToGroup = false;
        if (isCustomGrp) {
          // Custom group: check if position key exists in groupPositionKeys
          final positionKey = "${element.token}|${element.tsym}|${element.exch}";
          belongsToGroup = groupPositionKeys.contains(positionKey);
        } else {
          // Automatic group: check by symbol
          belongsToGroup = element.symbol == groupSymbol;
        }

        // If position belongs to group, check if it can be exited
        if (belongsToGroup && element.qty != "0") {
          // Validate product type (same as exitPosition function)
          if (((element.sPrdtAli == "MIS" || element.sPrdtAli == "CNC") ||
              element.sPrdtAli == "NRML")) {
            // Create PlaceOrderInput for exit (same as Exit All - NO frzqty)
            PlaceOrderInput placeOrderInput = PlaceOrderInput(
              amo: "",
              blprc: '',
              bpprc: '',
              dscqty: "",
              exch: "${element.exch}",
              prc: "0",
              prctype: "MKT",
              prd: "${element.prd}",
              qty: element.qty!.replaceAll("-", ""),
              ret: "DAY",
              trailprc: '',
              trantype: int.parse(element.qty!) < 0 ? 'B' : 'S',
              trgprc: "",
              tsym: "${element.tsym}",
              mktProt: '',
              channel: defaultTargetPlatform == TargetPlatform.android
                  ? '${ref.read(authProvider).deviceInfo["brand"]}'
                  : "${ref.read(authProvider).deviceInfo["model"]}",
              // NO frzqty field - same as Exit All
            );

            // Execute exit directly (same as Exit All - direct API call)
            final orderProv = ref.read(orderProvider);
            final placeOrderModel = await positionBook.api.getPlaceOrder(
                placeOrderInput, orderProv.ip);

            if (placeOrderModel.stat?.toLowerCase() != "ok") {
              // Continue with remaining positions instead of stopping
            }
          }
        }
      }
    } catch (e) {
      // Stop on error (same as Exit All behavior)
    }
  }
}

/// Confirmation dialog for exiting all positions in a group - Web style (matches ExitAllPositionsDialogWeb)
class ExitAllGroupDialog extends StatefulWidget {
  final String groupSymbol;
  final List groupList;
  final VoidCallback onExit;

  const ExitAllGroupDialog({
    super.key,
    required this.groupSymbol,
    required this.groupList,
    required this.onExit,
  });

  @override
  State<ExitAllGroupDialog> createState() => _ExitAllGroupDialogState();
}

class _ExitAllGroupDialogState extends State<ExitAllGroupDialog> {
  bool _isExiting = false;

  @override
  Widget build(BuildContext context) {
    // Count positions that can be exited
    final exitCount = widget.groupList
        .where((item) =>
            item != null &&
            item['qty'] != null &&
            item['qty'].toString() != "0")
        .length;

    // Responsive dialog sizing (matching ExitAllPositionsDialogWeb)
    final dialogWidth = context.responsiveValue<double>(
      mobile: context.screenWidth * 0.9,
      smallTablet: 350,
      tablet: 380,
      desktop: 400,
    );
    final contentPadding = context.responsive<double>(
      mobile: 12,
      tablet: 14,
      desktop: 16,
    );
    final headerHorizontalPadding = context.responsive<double>(
      mobile: 12,
      tablet: 14,
      desktop: 16,
    );
    final buttonSpacing = context.responsive<double>(
      mobile: 18,
      tablet: 21,
      desktop: 24,
    );

    return PointerInterceptor(
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: Container(
              width: dialogWidth,
              constraints: const BoxConstraints(maxHeight: 250),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: headerHorizontalPadding,
                      vertical: 8,
                    ),
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
                          'Exit Positions',
                          style: context.isMobile
                              ? MyntWebTextStyles.title(
                                  context,
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary,
                                  ),
                                  fontWeight: MyntFonts.medium,
                                )
                              : MyntWebTextStyles.title(
                                  context,
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary,
                                  ),
                                ),
                        ),
                        MyntCloseButton(
                          onPressed: _isExiting
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.all(contentPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Are you sure you want to exit all $exitCount position(s) in ${widget.groupSymbol} group?',
                            textAlign: TextAlign.center,
                            style: context.isMobile
                                ? MyntWebTextStyles.body(
                                    context,
                                    fontWeight: FontWeight.w500,
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary,
                                    ),
                                  )
                                : MyntWebTextStyles.body(
                                    context,
                                    fontWeight: FontWeight.w500,
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary,
                                    ),
                                  ),
                          ),
                          SizedBox(height: buttonSpacing),
                          MyntButton(
                            type: MyntButtonType.primary,
                            size: context.isMobile
                                ? MyntButtonSize.medium
                                : MyntButtonSize.large,
                            label: 'Exit Order',
                            isFullWidth: true,
                            isLoading: _isExiting,
                            backgroundColor: resolveThemeColor(
                              context,
                              dark: MyntColors.secondary,
                              light: MyntColors.primary,
                            ),
                            onPressed: _isExiting
                                ? null
                                : () async {
                                    setState(() {
                                      _isExiting = true;
                                    });

                                    try {
                                      widget.onExit();
                                    } catch (e) {
                                      // Error handled by onExit callback
                                    }
                                  },
                          ),
                        ],
                      ),
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

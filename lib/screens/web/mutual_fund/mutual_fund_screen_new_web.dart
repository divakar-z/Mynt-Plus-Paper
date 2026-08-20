import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/provider/thems.dart';
import '../../../provider/mf_provider.dart';
import '../../../res/res.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../routes/route_names.dart';

import '../../../sharedWidget/list_divider.dart';

class MutualFundNewScreenWeb extends ConsumerStatefulWidget {
  final TabController tabController;
  final VoidCallback?
      onNfoTap; // Callback when NFO card is tapped (for web panel navigation)
  final Function(String title, String subtitle, String icon)?
      onCollectionTap; // Callback when collection is tapped
  final Function(String title, String subtitle, String icon)?
      onCategoryTap; // Callback when category is tapped
  final VoidCallback? onSipCalculatorTap;
  final VoidCallback? onCagrCalculatorTap;
  final VoidCallback? onStrategyTap;

  const MutualFundNewScreenWeb({
    super.key,
    required this.tabController,
    this.onNfoTap,
    this.onCollectionTap,
    this.onCategoryTap,
    this.onSipCalculatorTap,
    this.onCagrCalculatorTap,
    this.onStrategyTap,
  });

  @override
  ConsumerState<MutualFundNewScreenWeb> createState() =>
      _MutualFundNewScreenWebState();
}

class _MutualFundNewScreenWebState extends ConsumerState<MutualFundNewScreenWeb>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Add listener to update state when tab changes
    _tabController.addListener(() {
      setState(() {
        // This will trigger rebuild when tab changes
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mfData = ref.watch(mfProvider);
    final theme = ref.watch(themeProvider);
    final isSelected = _tabController.index;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Padding(
          //   padding: const EdgeInsets.all(16.0),
          //   child: SizedBox(
          //     child: Skeletonizer(
          //       enabled: mfData.holdstatload ?? false,
          //       child: Column(
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: [
          //           Row(
          //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //             children: [
          //               Column(
          //                 crossAxisAlignment: CrossAxisAlignment.start,
          //                 children: [
          //                   TextWidget.paraText(
          //                     text: "Invested",
          //                     color: theme.isDarkMode
          //                         ? colors.textPrimaryDark
          //                         : colors.textPrimaryLight,
          //                     textOverflow: TextOverflow.ellipsis,
          //                     theme: theme.isDarkMode,
          //                   ),
          //                   const SizedBox(height: 6),
          //                   TextWidget.titleText(
          //                       text:
          //                           "${(mfData.mfholdingnew?.summary?.invested == "" || mfData.mfholdingnew?.summary?.invested == null) ? "0.00" : mfData.mfholdingnew?.summary?.invested}",
          //                       color: theme.isDarkMode
          //                           ? colors.textSecondaryDark
          //                           : colors.textSecondaryLight,
          //                       textOverflow: TextOverflow.ellipsis,
          //                       theme: theme.isDarkMode,
          //                       fw: 0),
          //                 ],
          //               ),
          //               Column(
          //                 crossAxisAlignment: CrossAxisAlignment.end,
          //                 children: [
          //                   TextWidget.paraText(
          //                     text: "Profit / Loss",
          //                     color: theme.isDarkMode
          //                         ? colors.textPrimaryDark
          //                         : colors.textPrimaryLight,
          //                     textOverflow: TextOverflow.ellipsis,
          //                     theme: theme.isDarkMode,
          //                   ),
          //                   const SizedBox(height: 6),
          //                   TextWidget.titleText(
          //                       text:
          //                           "${(mfData.mfholdingnew?.summary?.absReturnValue == "" || mfData.mfholdingnew?.summary?.absReturnValue == null) ? "0.00" : mfData.mfholdingnew?.summary?.absReturnValue}",
          //                       color: theme.isDarkMode
          //                           ? colors.textSecondaryDark
          //                           : colors.textSecondaryLight,
          //                       textOverflow: TextOverflow.ellipsis,
          //                       theme: theme.isDarkMode,
          //                       fw: 0),
          //                 ],
          //               ),
          //             ],
          //           ),
          //           const SizedBox(height: 16),
          //           Row(
          //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //             children: [
          //               Column(
          //                 crossAxisAlignment: CrossAxisAlignment.start,
          //                 children: [
          //                   TextWidget.paraText(
          //                     text: "Current",
          //                     color: theme.isDarkMode
          //                         ? colors.textPrimaryDark
          //                         : colors.textPrimaryLight,
          //                     textOverflow: TextOverflow.ellipsis,
          //                     theme: theme.isDarkMode,
          //                   ),
          //                   const SizedBox(height: 6),
          //                   TextWidget.titleText(
          //                     text:
          //                         "${(mfData.mfholdingnew?.summary?.currentValue == "" || mfData.mfholdingnew?.summary?.currentValue == null) ? "0.00" : mfData.mfholdingnew?.summary?.currentValue}",
          //                     color: theme.isDarkMode
          //                         ? colors.textSecondaryDark
          //                         : colors.textSecondaryLight,
          //                     textOverflow: TextOverflow.ellipsis,
          //                     theme: theme.isDarkMode,
          //                     fw: 0,
          //                   ),
          //                 ],
          //               ),
          //               Column(
          //                 crossAxisAlignment: CrossAxisAlignment.end,
          //                 children: [
          //                   TextWidget.paraText(
          //                     text: "Abs Returns %",
          //                     color: theme.isDarkMode
          //                         ? colors.textPrimaryDark
          //                         : colors.textPrimaryLight,
          //                     textOverflow: TextOverflow.ellipsis,
          //                     theme: theme.isDarkMode,
          //                   ),
          //                   const SizedBox(height: 6),
          //                   TextWidget.titleText(
          //                       text:
          //                           "${mfData.mfholdingnew?.summary?.absReturnPercent?.toString() ?? "0"}%", // Ensures percentage is always a valid string
          //                       color: theme.isDarkMode
          //                           ? colors.textSecondaryDark
          //                           : colors.textSecondaryLight,
          //                       textOverflow: TextOverflow.ellipsis,
          //                       theme: theme.isDarkMode,
          //                       fw: 0),

          //                   //     Text(
          //                   //   _formatValue(mfData.mfholdingnew?.summary?.absReturnValue),
          //                   //   style: TextStyle(
          //                   //     fontSize: 14,
          //                   //     fontWeight: FontWeight.w500,
          //                   //     color: _getColorBasedOnValue(
          //                   //       mfData.mfholdingnew?.summary?.absReturnValue,
          //                   //     ),
          //                   //   ),
          //                   // ),
          //                 ],
          //               ),
          //             ],
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),

          // NFO Card in half-width layout (cols 6)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: nfoCard(context, mfData, theme),
                ),
                const SizedBox(width: 32),
                Expanded(child: _strategyCard(context, theme)),
              ],
            ),
          ),

          // Two-column layout for Collections and Categories
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column - Collections
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Collections Header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          "Collections",
                          style: MyntWebTextStyles.body(
                            context,
                            color: theme.isDarkMode
                                ? MyntColors.textSecondaryDark
                                : MyntColors.textSecondary,
                            fontWeight: MyntFonts.medium,
                          ),
                        ),
                      ),
                      // Collections List
                      Container(
                        decoration: BoxDecoration(
                          color: theme.isDarkMode
                              ? Colors.transparent
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.isDarkMode
                                ? colors.textSecondaryDark
                                : const Color(0xFFECEDEE),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: mfData.bestMFListStaticnew
                              .asMap()
                              .entries
                              .map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Column(
                              children: [
                                _buildCollectionRow(
                                  icon: item['image'] ??
                                      'assets/explore/default.svg',
                                  title: item['title'] ?? '',
                                  subtitle: item['subtitle'] ?? '',
                                  theme: theme,
                                  context: context,
                                  onTap: () {
                                    // Navigate immediately - title is passed as argument
                                    // No need to call changetitle() which triggers unnecessary rebuild
                                    if (widget.onCollectionTap != null) {
                                      widget.onCollectionTap!(
                                        item['title'] ?? '',
                                        item['subtitle'] ?? '',
                                        item['image'] ??
                                            'assets/explore/default.svg',
                                      );
                                    } else {
                                      Navigator.pushNamed(
                                        context,
                                        Routes.bestMfScreen,
                                        arguments: item['title'],
                                      );
                                    }
                                  },
                                ),
                                if (index !=
                                    mfData.bestMFListStaticnew.length - 1)
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: theme.isDarkMode
                                        ? colors.textSecondaryDark
                                            .withOpacity(0.3)
                                        : const Color(0xFFECEDEE),
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 32),

                // Right column - Categories
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Categories Header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          "Categories",
                          style: MyntWebTextStyles.body(
                            context,
                            color: theme.isDarkMode
                                ? MyntColors.textSecondaryDark
                                : MyntColors.textSecondary,
                            fontWeight: MyntFonts.medium,
                          ),
                        ),
                      ),
                      // Categories List
                      Container(
                        decoration: BoxDecoration(
                          color: theme.isDarkMode
                              ? Colors.transparent
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.isDarkMode
                                ? colors.textSecondaryDark
                                : const Color(0xFFECEDEE),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: mfData.mFCategoryTypesStatic
                              .asMap()
                              .entries
                              .map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Column(
                              children: [
                                _buildCategoryRow(
                                  icon: item['dataIcon'] ?? '',
                                  title: item['title'] ?? '',
                                  subtitle: item['description'] ?? '',
                                  theme: theme,
                                  context: context,
                                  onTap: () {
                                    final chips = item['sub'] as List<dynamic>?;
                                    if (chips?.isNotEmpty ?? false) {
                                      final firstChip =
                                          chips?[0]?.toString() ?? "";
                                      mfData.fetchcatdatanew(
                                          item['title'], firstChip);
                                      mfData.changetitle(firstChip);
                                      if (widget.onCategoryTap != null) {
                                        widget.onCategoryTap!(
                                          item['title'] ?? '',
                                          item['description'] ?? '',
                                          item['dataIcon'] ?? '',
                                        );
                                      } else {
                                        Navigator.pushNamed(
                                            context, Routes.mfCategoryList,
                                            arguments: item['title']);
                                      }
                                    }
                                  },
                                ),
                                if (index !=
                                    mfData.mFCategoryTypesStatic.length - 1)
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: theme.isDarkMode
                                        ? colors.textSecondaryDark
                                            .withOpacity(0.3)
                                        : const Color(0xFFECEDEE),
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calculator',
                        style: MyntWebTextStyles.title(
                          context,
                          color: theme.isDarkMode
                              ? MyntColors.textPrimaryDark
                              : MyntColors.textPrimary,
                          fontWeight: MyntFonts.semiBold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.isDarkMode
                              ? Colors.transparent
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.isDarkMode
                                ? colors.textSecondaryDark
                                : const Color(0xFFECEDEE),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            sipcaltor(context, mfData, theme),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: theme.isDarkMode
                                  ? colors.textSecondaryDark.withOpacity(0.3)
                                  : const Color(0xFFECEDEE),
                            ),
                            cargrcalss(context, mfData, theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                const Expanded(
                    child:
                        SizedBox()), // Empty column to match the 2-column layout spacing
              ],
            ),
          ),
          // const SizedBox(height: 80),
        ],
      ),
    );
  }

  // Collection item row widget
  Widget _buildCollectionRow({
    required String icon,
    required String title,
    required String subtitle,
    required ThemesProvider theme,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return InkWell(
      onTap: onTap,
      // borderRadius: BorderRadius.circular(10), // Removed as it is inside a card
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              icon,
              height: 24,
              width: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MyntWebTextStyles.body(
                      context,
                      color: theme.isDarkMode
                          ? MyntColors.textPrimaryDark
                          : MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: MyntWebTextStyles.para(
                      context,
                      color: theme.isDarkMode
                          ? MyntColors.textSecondaryDark
                          : MyntColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Category item row widget
  Widget _buildCategoryRow({
    required String icon,
    required String title,
    required String subtitle,
    required ThemesProvider theme,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return InkWell(
      onTap: onTap,
      // borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon.isNotEmpty)
              Image.asset(
                icon,
                height: 24,
                width: 24,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MyntWebTextStyles.body(
                      context,
                      color: theme.isDarkMode
                          ? MyntColors.textPrimaryDark
                          : MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: MyntWebTextStyles.para(
                      context,
                      color: theme.isDarkMode
                          ? MyntColors.textSecondaryDark
                          : MyntColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget tabButton(IconData icon, String title) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSlidingPanelContent(
      bestMFList, MFProvider mfData, ThemesProvider theme) {
    return Container(
      // padding: const EdgeInsets.all(16.0),
      // color:
      // const Color(0xFFF9F9F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const SizedBox(height: 9),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Collections",
                    textAlign: TextAlign.right,
                    style: MyntWebTextStyles.title(
                      context,
                      color: theme.isDarkMode
                          ? MyntColors.textPrimaryDark
                          : MyntColors.textPrimary,
                      fontWeight: MyntFonts.semiBold,
                    ),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Text("Find the right mutual fund across these asset classes",
                    textAlign: TextAlign.right,
                    style: MyntWebTextStyles.para(
                      context,
                      color: theme.isDarkMode
                          ? MyntColors.textSecondaryDark
                          : MyntColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          // const SizedBox(height: 24),
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    double screenWidth = MediaQuery.of(context).size.width;
                    double screenHeight = MediaQuery.of(context).size.height;

                    int crossAxisCount = screenWidth > 600 ? 3 : 2;
                    double childAspectRatio = 1.2;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap:
                              true, // Allow GridView to take only required space
                          physics:
                              const NeverScrollableScrollPhysics(), // Disable GridView's scrolling
                          separatorBuilder: (_, __) => const ListDivider(),
                          itemCount: bestMFList?.length ?? 0,
                          itemBuilder: (BuildContext context, int index) {
                            if (bestMFList == null ||
                                index >= bestMFList.length) {
                              return const SizedBox.shrink();
                            }

                            return InkWell(
                              onTap: () {
                                // Navigate immediately - title is passed as argument
                                Navigator.pushNamed(
                                  context,
                                  Routes.bestMfScreen,
                                  arguments: bestMFList[index]['title'],
                                );
                              },
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                dense: false,
                                leading: SvgPicture.asset(
                                  bestMFList[index]['image'] ??
                                      'assets/explore/default.svg',
                                  height: 40,
                                  width: 40,
                                ),
                                title: Text(
                                  bestMFList[index]['title'] ?? '',
                                  style: MyntWebTextStyles.body(
                                    context,
                                    color: theme.isDarkMode
                                        ? MyntColors.textPrimaryDark
                                        : MyntColors.textPrimary,
                                    fontWeight: MyntFonts.medium,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  "${bestMFList[index]['subtitle'] ?? ''}",
                                  style: MyntWebTextStyles.para(
                                    context,
                                    color: theme.isDarkMode
                                        ? MyntColors.textSecondaryDark
                                        : MyntColors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget buildCategoryCard(
      {required String? dataIcon,
      required BuildContext context,
      required String? title,
      required String? description,
      required List<dynamic>? chips,
      required MFProvider mfData,
      required ThemesProvider theme}) {
    if (dataIcon == null || title == null
        // ||
        // description == null
        //  ||
        // chips == null

        ) {
      return const SizedBox.shrink();
    }

    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: () async {
        if (chips?.isNotEmpty ?? false) {
          final firstChip = chips?[0]?.toString() ?? "";
          mfData.fetchcatdatanew(title, firstChip);
          mfData.changetitle(firstChip);
          if (widget.onCategoryTap != null) {
            widget.onCategoryTap!(
              title,
              description ?? '',
              dataIcon,
            ); // Pass the main category title
          } else {
            Navigator.pushNamed(context, Routes.mfCategoryList,
                arguments: title);
          }
        }
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minLeadingWidth: 25,
        dense: false,
        leading: Image.asset(
          dataIcon,
          width: 30,
          height: 30,
        ),
        title: Text(
          title,
          style: MyntWebTextStyles.body(
            context,
            color: theme.isDarkMode
                ? MyntColors.textPrimaryDark
                : MyntColors.textPrimary,
            fontWeight: MyntFonts.medium,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Container(
          margin: EdgeInsets.only(
            right: MediaQuery.of(context).size.width * 0.1,
          ),
          child: Text(
              description ?? '',
              style: MyntWebTextStyles.para(
                context,
                color: theme.isDarkMode
                    ? MyntColors.textSecondaryDark
                    : MyntColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget nfoCard(BuildContext context, MFProvider mf, ThemesProvider theme) {
    return InkWell(
      onTap: () async {
        // If callback is provided (web), use it to open in panel 2
        if (widget.onNfoTap != null) {
          widget.onNfoTap!();
        } else {
          Navigator.pushNamed(context, Routes.mfnfoscreen);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: theme.isDarkMode ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.isDarkMode
                ? colors.textSecondaryDark
                : const Color(0xFFECEDEE),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/explore/gift.svg',
              width: 25,
              height: 25,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "New Fund Offerings",
                    style: MyntWebTextStyles.body(
                      context,
                      color: theme.isDarkMode
                          ? MyntColors.textPrimaryDark
                          : MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Invest in new funds at launch price",
                    style: MyntWebTextStyles.para(
                      context,
                      color: theme.isDarkMode
                          ? MyntColors.textSecondaryDark
                          : MyntColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strategyCard(BuildContext context, ThemesProvider theme) {
    return InkWell(
      onTap: () {
        if (widget.onStrategyTap != null) {
          widget.onStrategyTap!();
        } else {
          Navigator.pushNamed(context, Routes.basketScreen);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: theme.isDarkMode ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.isDarkMode
                ? colors.textSecondaryDark
                : const Color(0xFFECEDEE),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
            assets.mfIcon,
              width: 25,
              height: 25,
               colorFilter: const ColorFilter.mode(MyntColors.primary, BlendMode.srcIn)
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "MF Strategy",
                    style: MyntWebTextStyles.body(
                      context,
                      color: theme.isDarkMode
                          ? MyntColors.textPrimaryDark
                          : MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Build & invest in custom fund baskets",
                    style: MyntWebTextStyles.para(
                      context,
                      color: theme.isDarkMode
                          ? MyntColors.textSecondaryDark
                          : MyntColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget sipcaltor(BuildContext context, MFProvider mf, ThemesProvider theme) {
    return InkWell(
      onTap: () async {
        if (widget.onSipCalculatorTap != null) {
          widget.onSipCalculatorTap!();
        } else {
          Navigator.pushNamed(context, Routes.mfsipcalscreen);
        }
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minLeadingWidth: 25,
        dense: false,
        leading: SvgPicture.asset(
          'assets/icon/watchlistIcon/calc.svg',
          width: 25,
          height: 25,
        ),
        title: Text(
          "SIP Calculator",
          style: MyntWebTextStyles.body(
            context,
            color: theme.isDarkMode
                ? MyntColors.textPrimaryDark
                : MyntColors.textSecondary,
            fontWeight: MyntFonts.medium,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget cargrcalss(BuildContext context, MFProvider mf, ThemesProvider theme) {
    return InkWell(
      onTap: () async {
        if (widget.onCagrCalculatorTap != null) {
          widget.onCagrCalculatorTap!();
        } else {
          Navigator.pushNamed(context, Routes.mfcagrcalss);
        }
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minLeadingWidth: 25,
        dense: false,
        leading: SvgPicture.asset(
          'assets/icon/watchlistIcon/calc.svg',
          width: 25,
          height: 25,
        ),
        title: Text(
          "CAGR Calculator",
          style: MyntWebTextStyles.body(
            context,
            color: theme.isDarkMode
                ? MyntColors.textPrimaryDark
                : MyntColors.textSecondary,
            fontWeight: MyntFonts.medium,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget buildCollectionsTab(MFProvider mfData, ThemesProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       TextWidget.titleText(
        //           align: TextAlign.right,
        //           text: "Collections",
        //           color: theme.isDarkMode
        //               ? colors.textPrimaryDark
        //               : colors.textPrimaryLight,
        //           textOverflow: TextOverflow.ellipsis,
        //           theme: theme.isDarkMode,
        //           fw: 1),
        //       const SizedBox(height: 10),
        //       TextWidget.paraText(
        //           align: TextAlign.right,
        //           text: "Find the right mutual fund across these asset classes",
        //           color: theme.isDarkMode
        //               ? colors.textSecondaryDark
        //               : colors.textSecondaryLight,
        //           textOverflow: TextOverflow.ellipsis,
        //           theme: theme.isDarkMode,
        //           fw: 3),
        //     ],
        //   ),
        // ),
        Column(
          children: [
            Builder(
              builder: (context) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, __) => const ListDivider(),
                      itemCount: mfData.bestMFListStaticnew.length,
                      itemBuilder: (BuildContext context, int index) {
                        if (index >= mfData.bestMFListStaticnew.length) {
                          return const SizedBox.shrink();
                        }

                        return InkWell(
                          onTap: () {
                            final title =
                                mfData.bestMFListStaticnew[index]['title'];
                            // Navigate immediately - title is passed as argument
                            if (widget.onCollectionTap != null) {
                              widget.onCollectionTap!(
                                title,
                                mfData.bestMFListStaticnew[index]['subtitle'] ??
                                    '',
                                mfData.bestMFListStaticnew[index]['image'] ??
                                    'assets/explore/default.svg',
                              );
                            } else {
                              Navigator.pushNamed(
                                context,
                                Routes.bestMfScreen,
                                arguments: title,
                              );
                            }
                          },
                          child: ListTile(
                            minLeadingWidth: 25,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            dense: false,
                            leading: SvgPicture.asset(
                              mfData.bestMFListStaticnew[index]['image'] ??
                                  'assets/explore/default.svg',
                              height: 30,
                              width: 30,
                            ),
                            title: Text(
                              mfData.bestMFListStaticnew[index]['title'] ?? '',
                              style: MyntWebTextStyles.body(
                                context,
                                color: theme.isDarkMode
                                    ? MyntColors.textPrimaryDark
                                    : MyntColors.textPrimary,
                                fontWeight: MyntFonts.medium,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              "${mfData.bestMFListStaticnew[index]['subtitle'] ?? ''}",
                              style: MyntWebTextStyles.para(
                                context,
                                color: theme.isDarkMode
                                    ? MyntColors.textSecondaryDark
                                    : MyntColors.textSecondary,
                                fontWeight: MyntFonts.medium,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        )
      ],
    );
  }

  Widget buildCategoriesTab(MFProvider mfData, ThemesProvider theme) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Padding(
          //   padding: const EdgeInsets.only(left: 16, top: 14, bottom: 8),
          //   child: TextWidget.titleText(
          //       align: TextAlign.right,
          //       text: "All Categories",
          //       color: theme.isDarkMode
          //           ? colors.textPrimaryDark
          //           : colors.textPrimaryLight,
          //       textOverflow: TextOverflow.ellipsis,
          //       theme: theme.isDarkMode,
          //       fw: 1),
          // ),
          ListView.separated(
            padding: EdgeInsets.zero,
            separatorBuilder: (_, __) => const ListDivider(),
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemBuilder: (BuildContext context, int index) {
              return buildCategoryCard(
                  context: context,
                  dataIcon: mfData.mFCategoryTypesStatic[index]['dataIcon'],
                  title: mfData.mFCategoryTypesStatic[index]['title'],
                  description: mfData.mFCategoryTypesStatic[index]
                      ['description'],
                  chips: mfData.mFCategoryTypesStatic[index]['sub'],
                  mfData: mfData,
                  theme: theme);
            },
            itemCount: mfData.mFCategoryTypesStatic.length,
          ),
        ],
      ),
    );
  }
}










// LayoutBuilder(
//                         builder: (context, constraints) {
//                           return SizedBox(
//                             width: constraints.maxWidth,
//                             child: GridView.builder(
//                               shrinkWrap:
//                                   true, // Allow GridView to take only required space
//                               physics:
//                                   const NeverScrollableScrollPhysics(), // Disable GridView's scrolling
//                               gridDelegate:
//                                   SliverGridDelegateWithFixedCrossAxisCount(
//                                 crossAxisCount: crossAxisCount,
//                                 crossAxisSpacing: screenWidth * 0.04,
//                                 mainAxisSpacing: screenHeight * 0.02,
//                                 childAspectRatio: childAspectRatio,
//                               ),
//                               itemCount: bestMFList?.length ?? 0,
//                               itemBuilder: (BuildContext context, int index) {
//                                 if (bestMFList == null ||
//                                     index >= bestMFList.length) {
//                                   return const SizedBox.shrink();
//                                 }

//                                 return GestureDetector(
//                                   onTap: () async {
//                                     mfData.changetitle(
//                                         bestMFList[index]['title']);
//                                     Navigator.pushNamed(
//                                       context,
//                                       Routes.bestMfScreen,
//                                       arguments: bestMFList[index]['title'],
//                                     );
//                                   },
//                                   child: Container(
//                                     height: 150,
//                                     padding: const EdgeInsets.symmetric(
//                                         vertical: 16, horizontal: 16),
//                                     decoration: BoxDecoration(
//                                       color: theme.isDarkMode
//                                           ? const Color.fromARGB(255, 0, 0, 0)
//                                           : colors.colorWhite,
//                                       borderRadius: BorderRadius.circular(8),
//                                     ),
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start, 
//                                       children: [
//                                         SvgPicture.asset(
//                                           bestMFList[index]['image'] ??
//                                               'assets/explore/default.svg',
//                                           height: 50,
//                                           width: 60,
//                                         ),
//                                         const SizedBox(
//                                           height: 12,
//                                         ),
//                                         TextWidget.subText(
//                                             align: TextAlign.left,
//                                             text: bestMFList[index]['title'] ??
//                                                 '',
//                                             color: theme.isDarkMode
//                                                 ? colors.textPrimaryDark
//                                                 : colors.textPrimaryLight,
//                                             textOverflow: TextOverflow.ellipsis,
//                                             theme: theme.isDarkMode,
//                                             fw: 0),
//                                             const SizedBox(
//                                           height: 12,
//                                         ),
//                                         TextWidget.paraText(
//                                             align: TextAlign.left,
//                                             text:
//                                                 "${bestMFList[index]['subtitle'] ?? ''}",
//                                             color: theme.isDarkMode
//                                                 ? colors.textSecondaryDark
//                                                 : colors.textSecondaryLight,
//                                             maxLines: 2,
//                                             textOverflow: TextOverflow.ellipsis,
//                                             theme: theme.isDarkMode,
//                                             fw: 3),
//                                       ],
//                                     ),
//                                   ),
//                                 );
//                               },
//                             ),
//                           );
//                         },
//                       ),







//chips old ui

//  Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//            TextWidget.subText(
          //   align: TextAlign.right,
          //   text: title,
          //   color: theme.isDarkMode
          //       ? colors.textPrimaryDark
          //       : colors.textPrimaryLight,
          //   textOverflow: TextOverflow.ellipsis,
          //   theme: theme.isDarkMode,
          // ),
         
          // const SizedBox(height: 8),
         
          // const SizedBox(height: 8),
          // TextWidget.paraText(
          //     align: TextAlign.right,
          //     text: description,
          //     color: theme.isDarkMode
          //         ? colors.textSecondaryDark
          //         : colors.textSecondaryLight,
          //     textOverflow: TextOverflow.ellipsis,
          //     theme: theme.isDarkMode,
          //     fw: 3),
          // const SizedBox(height: 16),
          // SizedBox(
          //   height: 35, // Match your chip height
          //   child: ListView.separated(
          //     scrollDirection: Axis.horizontal,
          //     itemCount: chips.length,
          //     separatorBuilder: (context, index) => const SizedBox(width: 8),
          //     itemBuilder: (context, index) {
          //       final chipText = chips[index]?.toString() ?? "";
      
          //       return TextButton(
          //         onPressed: () async {
          //           mfData.fetchcatdatanew(title, chipText);
          //           mfData.changetitle(chipText);
          //           Navigator.pushNamed(
          //             context,
          //             Routes.mfCategoryList,
          //             arguments: title,
          //           );
          //           FocusScope.of(context).unfocus();
          //         },
          //         style: TextButton.styleFrom(
          //           padding: const EdgeInsets.symmetric(
          //               horizontal: 12, vertical: 0),
          //           backgroundColor: !theme.isDarkMode
          //               ? const Color(0xffF1F3F8)
          //               : colors.colorbluegrey,
          //           shape: RoundedRectangleBorder(
          //             borderRadius: BorderRadius.circular(4),
          //             side: BorderSide(
          //               color: colors.primaryLight,
          //               width: 1,
          //             ),
          //           ),
          //         ),
          //         child: TextWidget.paraText(
          //             align: TextAlign.right,
          //             text: chipText,
          //             color: theme.isDarkMode
          //                 ? colors.textPrimaryDark
          //                 : colors.textPrimaryLight,
          //             textOverflow: TextOverflow.ellipsis,
          //             theme: theme.isDarkMode,
          //             fw: 0),
          //       );
          //     },
          //   ),
          // )
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mynt_plus/models/mf_model/mutual_fundmodel.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import '../../../provider/mf_provider.dart';
import '../../../provider/thems.dart';
import '../../../res/global_state_text.dart';
import '../../../res/res.dart';
import '../../../routes/route_names.dart';
 
 
 
import '../../../sharedWidget/list_divider.dart';
import '../../../utils/no_emoji_inputformatter.dart';
import 'mf_stock_detail_screen_web.dart';

class MfCommonSearchWeb extends ConsumerStatefulWidget {
  const MfCommonSearchWeb({super.key});

  @override
  ConsumerState<MfCommonSearchWeb> createState() => _MfCommonSearchWebState();
}

class _MfCommonSearchWebState extends ConsumerState<MfCommonSearchWeb> {
  late FocusNode searchFocusNode;

  @override
  void initState() {
    super.initState();
    searchFocusNode = FocusNode();

    searchFocusNode.addListener(() {
      if (searchFocusNode.hasFocus) {
      }
    });

    // Automatically focus the field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(searchFocusNode);
    });
  }

  @override
  void dispose() {
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mfData = ref.watch(mfProvider);
    final theme = ref.watch(themeProvider);
    
    

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
                mfData.clearMfSearchResult();
                mfData.mfsearchcontroller.clear();
                // FocusScope.of(context).unfocus();
        if (!didPop) {
          Navigator.pop(context);
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(
            elevation: 0,
            leadingWidth: 48,
            centerTitle: false,
            titleSpacing: 0,
            leading: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                customBorder: const CircleBorder(),
                splashColor: theme.isDarkMode
                    ? colors.splashColorDark
                    : colors.splashColorLight,
                highlightColor: theme.isDarkMode
                    ? colors.highlightDark
                    : colors.highlightLight,
                onTap: () {
                  mfData.clearMfSearchResult();
                  mfData.mfsearchcontroller.clear();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 44, // Increased touch area
                  height: 44,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_back_ios_outlined,
                    size: 18,
                    color: theme.isDarkMode
                        ? colors.colorWhite
                        : colors.colorBlack,
                  ),
                ),
              ),
            ),
            title: Container(
              padding: const EdgeInsets.only(right: 12, top: 8, bottom: 7),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: theme.isDarkMode
                ? colors.searchBgDark
                : colors.searchBg,
                  borderRadius: BorderRadius.circular(5),
                  // border: Border.all(
                  //   color: theme.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                  //   width: 1,
                  // ),
                ),
                child: Row(
                  children: [
                    // Search icon
                    const SizedBox(width: 12),
                    SvgPicture.asset(
                      assets.searchIcon,
                      color: theme.isDarkMode
                          ? colors.textSecondaryDark
                          : colors.textSecondaryLight,
                      width: 18,
                      height: 18,
                    ),
                    const SizedBox(width: 8),
                    // Text input
                    Expanded(
                      child: TextFormField(
                          focusNode: searchFocusNode,
                          controller: mfData.mfsearchcontroller,
                          style: TextWidget.textStyle(
                            fontSize: 16,
                            color: theme.isDarkMode
                                ? colors.textPrimaryDark
                                : colors.textPrimaryLight,
                            theme: theme.isDarkMode,
                          ),
                          // textCapitalization:
                          //     TextCapitalization.characters,
                          inputFormatters: [
                            NoEmojiInputFormatter(),
                            FilteringTextInputFormatter.deny(
                                RegExp('[π£•₹€℅™∆√¶/.,]'))
                          ],
                          // keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Search Mutual Fund",
                            hintStyle: TextWidget.textStyle(
                              fontSize: 14,
                              theme: theme.isDarkMode,
                              color: (theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight).withOpacity(0.4),
                              fw: 0,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 12),
                          ),
                          onChanged: (value) async {
                            if (value.isNotEmpty) {
                              mfData.fetchmfCommonsearch(value, context);
                             }else{
                            mfData.clearMfSearchResult();
                          }
                          }),
                    ),
        
                    // Clear button
                    if (mfData.mfsearchcontroller.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              mfData.mfsearchcontroller.clear();
                              // mfData.fetchmfCommonsearch("", context);
                              mfData.clearMfSearchResult();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SvgPicture.asset(
                                assets.removeIcon,
                                color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
                                width: 20,
                                height: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          body: MyntLoaderOverlay(
            isLoading: mfData.bestmfloader ?? false,
            child: Column(
              children: [
                if (mfData.mutualFundsearchdata != null) ...[
                  mfData.mutualFundsearchdata!.isNotEmpty
                      ? Expanded(
                        child: ListView.separated(
                            shrinkWrap: true,
                            // padding: const EdgeInsets.symmetric(horizontal: 8),
                            separatorBuilder: (context, index) =>
                                const ListDivider(),
                            physics: const ClampingScrollPhysics(),
                            itemCount: mfData.mutualFundsearchdata!.length,
                            itemBuilder: (BuildContext context, int index) {
                              final fund = mfData.mutualFundsearchdata![index];
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  splashColor: theme.isDarkMode
                                      ? Colors.white.withOpacity(0.15)
                                      : Colors.black.withOpacity(0.15),
                                  highlightColor: theme.isDarkMode
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.08),
                                  onTap: () async {
                                    try {
                                      mfData.loaderfun();
                                      if (fund.iSIN != null) {
                                        await mfData.fetchFactSheet(fund.iSIN!);
                                        mfData.fetchmatchisan(fund.iSIN!);
                                        if (mfData.factSheetDataModel?.stat !=
                                            "Not Ok") {
                                          showModalBottomSheet(
                                            isScrollControlled: true,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(16),
                                                topRight: Radius.circular(16),
                                              ),
                                            ),
                                            isDismissible: true,
                                            enableDrag: false,
                                            useSafeArea: true,
                                            context: context,
                                            builder: (context) => Container(
                                                padding: EdgeInsets.only(
                                                  bottom: MediaQuery.of(context)
                                                      .viewInsets
                                                      .bottom,
                                                ),
                                                child: MFStockDetailScreenWeb(
                                                    mfStockData: fund, fromSearch: true)),
                                          );
                                          // Navigator.pushNamed(
                                          //   context,
                                          //   Routes.mfStockDetail,
                                          //   arguments: fund,
                                          // );
                                        } else {
                                            successMessage(
                                                context, "No Single Page Data"
                                          );
                                          final jsondata =
                                              MutualFundList.fromJson(
                                                  fund.toJson());
                                          Navigator.pushNamed(
                                            context,
                                            Routes.mforderScreen,
                                            arguments: jsondata,
                                          );
                                          mfData.orderchangetitle("One-time");
                                          mfData.chngOrderType("One-time");
                                        }
                                      } else {
                                          successMessage(
                                              context, "Invalid fund data"
                                        );
                                      }
                                    } catch (e) { successMessage(context,
                                            "Error loading fund details"
                                      );
                                    }
                                  },
                                  child: ListTile(
                                    //  visualDensity:const VisualDensity(horizontal: -4, vertical: 0),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    dense: false,
                                    leading: CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        "https://v3.mynt.in/mfapi/static/images/mf/${fund.aMCCode ?? "default"}.png",
                                      ),
                                    ),
                                    title: Container(
                                      margin: EdgeInsets.only(
                                        right:
                                            MediaQuery.of(context).size.width *
                                                0.1,
                                      ),
                                      padding: const EdgeInsets.only(
                                        bottom: 4,
                                      ),
                                      child: TextWidget.subText(
                                        text: fund.mfsearchnamename ?? "",
                                        theme: theme.isDarkMode,
                                        color: theme.isDarkMode
                                            ? colors.textPrimaryDark
                                            : colors.textPrimaryLight,
                                        textOverflow: TextOverflow.ellipsis,
                                        // softWrap: true,
                                        maxLines: 2,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: TextWidget.paraText(
                                        text: fund.type ?? "",
                                        textOverflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        color: theme.isDarkMode
                                            ? colors.textSecondaryDark
                                            : colors.textSecondaryLight,
                                        theme: false,
                                      ),
                                    ),
                                    trailing: Material(
                                      color: Colors.transparent,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        splashColor:
                                            Colors.grey.withOpacity(0.3),
                                        highlightColor:
                                            Colors.grey.withOpacity(0.2),
                                        onTap: () async {
                                          if (fund.iSIN != null) {
                                            await mfData.fetchcommonsearchWadd(
                                              fund.iSIN!,
                                              fund.isAdd == true
                                                  ? "delete"
                                                  : "add",
                                              context,
                                              false,
                                            );
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: SvgPicture.asset(
                                            color: fund.isAdd == true
                                                ? colors.colorBlue
                                                : colors.colorGrey,
                                            fund.isAdd == true
                                                ? assets.bookmarkIcon
                                                : assets.bookmarkedIcon,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                        
                                  // CustomExchBadge(
                                  //         exch: fund.type ?? ""),
                                  // const SizedBox(width: 5),
                                  // CustomExchBadge(
                                  //     exch: fund.subtype ?? ""),
                                ),
                        
                                //  Container(
                                //   padding: const EdgeInsets.all(8),
                                //   child: Column(
                                //     crossAxisAlignment:
                                //         CrossAxisAlignment.start,
                                //     children: [
                                //       Row(
                                //         mainAxisAlignment:
                                //             MainAxisAlignment.spaceBetween,
                                //         children: [
                                //           CircleAvatar(
                                //             backgroundImage: NetworkImage(
                                //               "https://v3.mynt.in/mfapi/static/images/mf/${fund.aMCCode ?? "default"}.png",
                                //             ),
                                //           ),
                                //           const SizedBox(width: 10),
                                //           Expanded(
                                //             child: Column(
                                //               crossAxisAlignment:
                                //                   CrossAxisAlignment.start,
                                //               children: [
                                //                 SizedBox(
                                //                   width: MediaQuery.of(context)
                                //                           .size
                                //                           .width *
                                //                       0.6,
                                //                   child: Text(
                                //                     fund.mfsearchnamename ?? "",
                                //                     maxLines: 2,
                                //                     overflow:
                                //                         TextOverflow.ellipsis,
                                //                     style: textStyles
                                //                         .scripNameTxtStyle
                                //                         .copyWith(
                                //                       color: isDarkMode
                                //                           ? colors.colorWhite
                                //                           : colors.colorBlack,
                                //                     ),
                                //                   ),
                                //                 ),
                                //                 const SizedBox(height: 8),
                                //                 SizedBox(
                                //                   height: 18,
                                //                   child: ListView(
                                //                     scrollDirection:
                                //                         Axis.horizontal,
                                //                     children: [
                                //                       CustomExchBadge(
                                //                           exch:
                                //                               fund.type ?? ""),
                                //                       const SizedBox(width: 5),
                                //                       CustomExchBadge(
                                //                           exch: fund.subtype ??
                                //                               ""),
                                //                     ],
                                //                   ),
                                //                 ),
                                //               ],
                                //             ),
                                //           ),
                                //           IconButton(
                                //             splashRadius: 20,
                                //             onPressed: () async {
                                //               if (fund.iSIN != null) {
                                //                 await mfData
                                //                     .fetchcommonsearchWadd(
                                //                   fund.iSIN!,
                                //                   fund.isAdd == true
                                //                       ? "delete"
                                //                       : "add",
                                //                   context,
                                //                   false,
                                //                 );
                                //               }
                                //             },
                                //             icon: SvgPicture.asset(
                                //               color: colors.colorBlue,
                                //               fund.isAdd == true
                                //                   ? assets.bookmarkIcon
                                //                   : assets.bookmarkedIcon,
                                //             ),
                                //           ),
                                //         ],
                                //       ),
                                //       const SizedBox(height: 8),
                                //       Divider(
                                //         color: isDarkMode
                                //             ? colors.darkColorDivider
                                //             : colors.colorDivider,
                                //         thickness: 1.0,
                                //       ),
                                //     ],
                                //   ),
                                // ),
                              );
                            },
                          ),
                      )
                      : const Expanded(
                        child: Center(
                            child: NoDataFound(
                              title: "No Results Found",
                              subtitle: "Try searching with different keywords",
                              primaryEnabled: false,
                              secondaryEnabled: false,
                            ),
                          ),
                      )
                ] else ...[
                  const Expanded(
                    child: Center(
                      child: NoDataFound(
                        title: "No Results Found",
                        subtitle: "Try searching with different keywords",
                        primaryEnabled: false,
                        secondaryEnabled: false,
                      ),
                    ),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
















//  Padding(
//             padding: const EdgeInsets.only(right: 18.0),
//             child: Container(
//               height: 60,
//               padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
//               child: TextFormField(
//                 focusNode: searchFocusNode,
//                 controller: mfData.mfsearchcontroller,
//                 style: textStyle(
//                   isDarkMode ? colors.colorWhite : colors.colorBlack,
//                   16,
//                   FontWeight.w600,
//                 ),
//                 decoration: InputDecoration(
//                   fillColor: isDarkMode ? colors.darkGrey : colors.kColorLightGrey,
//                   filled: true,
//                   hintStyle: textStyle(
//                     isDarkMode ? Colors.white : const Color.fromARGB(255, 0, 0, 0),
//                     14,
//                     FontWeight.w600,
//                   ),
//                   prefixIconColor: const Color(0xff586279),
//                   prefixIconConstraints: const BoxConstraints(
//                     minWidth: 0,
//                   ),
//                   prefixIcon: Padding(
//                     padding: const EdgeInsets.only(left: 8, right: 8),
//                     child: Icon(
//                       Icons.search,
//                       color: isDarkMode ? Colors.white : Colors.black54,
//                     ),
//                   ),
//                   suffixIcon: ValueListenableBuilder<TextEditingValue>(
//                     valueListenable: mfData.mfsearchcontroller,
//                     builder: (context, value, child) {
//                       return value.text.isNotEmpty
//                           ? InkWell(
//                               onTap: () {
//                                 mfData.mfsearchcontroller.clear();
//                                 mfData.fetchmfCommonsearch("", context);
//                               },
//                               child: Padding(
//                                 padding: const EdgeInsets.symmetric(horizontal: 20.0),
//                                 child: SvgPicture.asset(
//                                   assets.removeIcon,
//                                   fit: BoxFit.scaleDown,
//                                   width: 20,
//                                 ),
//                               ),
//                             )
//                           : const SizedBox.shrink();
//                     },
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide.none,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide.none,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   hintText: "Search Mutual Fund",
//                   contentPadding: const EdgeInsets.only(top: 20),
//                 ),
//                 onChanged: (value) async => mfData.fetchmfCommonsearch(value, context),
//               ),
//             ),
//           ),
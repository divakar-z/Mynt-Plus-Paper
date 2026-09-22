import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../../provider/portfolio_provider.dart';
import '../../../../../provider/thems.dart';
import '../../../../../res/global_state_text.dart';
import '../../../../../res/res.dart';
import '../../../../../sharedWidget/custom_drag_handler.dart';
import '../../../../../sharedWidget/custom_exch_badge.dart';
import '../../../../../sharedWidget/list_divider.dart';

class PositionListBottomSheet extends ConsumerWidget {
  final String grpName;
  const PositionListBottomSheet({super.key, required this.grpName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionBook = ref.watch(portfolioProvider);

    final theme = ref.read(themeProvider);

    return DraggableScrollableSheet(
        initialChildSize:
            positionBook.postionBookModel!.length > 3 ? 0.79 : 0.35,
        minChildSize: 0.25,
        maxChildSize: positionBook.postionBookModel!.length < 3 ? 0.5 : 0.9,
        expand: false,
        builder: (_, controller) {
          return Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
                boxShadow: const [
                  BoxShadow(
                      color: Color(0xff999999),
                      blurRadius: 4.0,
                      offset: Offset(2.0, 0.0))
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CustomDragHandler(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: TextWidget.titleText(
                      text: "Group Position Symbol $grpName",
                      theme: theme.isDarkMode,
                      fw: 1),
                ),
                Divider(
                    height: 3,
                    color: theme.isDarkMode
                        ? colors.darkColorDivider
                        : colors.colorDivider),
                Expanded(
                    child: ListView.separated(
                        controller: controller,
                        physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics()),
                        separatorBuilder: (BuildContext context, int index) {
                          return const ListDivider();
                        },
                        itemCount: positionBook.postionBookModel!.length,
                        itemBuilder: (BuildContext context, index) {
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            dense: true,
                            title: Row(
                              children: [
                                TextWidget.subText(
                                    text: positionBook
                                        .postionBookModel![index].symbol!
                                        .toUpperCase(),
                                    theme: theme.isDarkMode,
                                    fw: 1),
                                TextWidget.subText(
                                    text:
                                    " ${positionBook.postionBookModel![index].option}",
                                    theme: theme.isDarkMode,
                                    fw: 1,
                                    textOverflow: TextOverflow.ellipsis),
                              ],
                            ),
                            subtitle: Row(children: [
                              CustomExchBadge(
                                  exch: positionBook
                                      .postionBookModel![index].exch!),
                              TextWidget.paraText(
                                  text:
                                  "  ${positionBook.postionBookModel![index].expDate}",
                                  theme: theme.isDarkMode,
                                  fw: 0,
                                  textOverflow: TextOverflow.ellipsis),
                            ]),
                            trailing: IconButton(
                                onPressed: () async {
                                
if (!positionBook.postionBookModel![index].isExitSelection!) {
    Map data = jsonDecode(jsonEncode(
                                      positionBook.postionBookModel![index]));
   await positionBook.fetchAddGroupSymbol(
                                      grpName, context, data);
} else {
  await positionBook. fetchDeleteGroupSymbol(grpName,context,"${positionBook.postionBookModel![index].tsym}","${positionBook.postionBookModel![index].sPrdtAli ?? ''}");
}
                                 
                                },
                                icon: SvgPicture.asset( !positionBook.postionBookModel![index].isExitSelection!? assets.bookmarkedIcon:assets.bookmarkIcon)),
                          );
                        }))
              ],
            ),
          );
        });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/sharedWidget/list_divider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../provider/change_password_provider.dart';
import '../../../provider/user_profile_provider.dart';
import '../../../res/res.dart';
import '../../../routes/route_names.dart';
import '../../../locator/locator.dart';
import '../../../locator/preference.dart';
import '../../../provider/api_key_provider.dart';
import '../../../provider/thems.dart';
import '../../../res/global_state_text.dart';
import '../../../sharedWidget/custom_back_btn.dart';
import '../../../sharedWidget/functions.dart';
import '../../../sharedWidget/snack_bar.dart';
import 'topt_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersettings = ref.watch(userProfileProvider);
    final apikeys = ref.read(apikeyprovider);
    final theme = ref.read(themeProvider);

    final Preferences pref = locator<Preferences>();
    return Scaffold(
      appBar: AppBar(
        elevation: .2,
        centerTitle: false,
        leadingWidth: 41,
        titleSpacing: 6,
        leading: const CustomBackBtn(),
        title: TextWidget.titleText(
            text: "Settings",
            theme: false,
            color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
            fw: 1),
      ),
      body: Column(
        children: [
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, int index) {
              return ListTile(
                onTap: () async {
                  if (index == 0) {
                    copyToClipboard("${apikeys.apikeyres!.apikey}",
                        apikeys.apikeyres!.apistatus, context);
                  } else if (index == 1) {
                    await apikeys.fetchTotp();
                    showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        isDismissible: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        builder: (_) => TotpScreen(
                            secretKey: ref.read(apikeyprovider).totpkey!.pwd));
                  } else if (index == 2) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: ref.read(themeProvider).isDarkMode
                              ? const Color.fromARGB(255, 18, 18, 18)
                              : colors.colorWhite,
                          titleTextStyle: textStyles.appBarTitleTxt.copyWith(
                              color: ref.read(themeProvider).isDarkMode
                                  ? colors.colorWhite
                                  : colors.colorBlack),
                          titlePadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(14))),
                          scrollable: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          insetPadding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          title: TextWidget.titleText(
                              text: "Freeze Account!",
                              theme: theme.isDarkMode,
                              fw: 0),
                          content: SizedBox(
                              width: MediaQuery.of(context).size.width,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget.titleText(
                                        text:
                                            "Are you sure you want to Freeze yor Account?",
                                        theme: false,
                                        color: theme.isDarkMode
                                            ? colors.colorWhite
                                            : colors.colorBlack,
                                        fw: 1),
                                    const SizedBox(height: 10),
                                    TextWidget.paraText(
                                        text:
                                            "* Note: Open order(s) will be cancelled, but position(s) will not be closed",
                                        theme: false,
                                        color: colors.colorGrey,
                                        fw: 1),
                                  ])),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: TextWidget.subText(
                                  text: "Cancel",
                                  theme: false,
                                  color: theme.isDarkMode
                                      ? colors.colorLightBlue
                                      : colors.colorBlue,
                                  fw: 0),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                usersettings.fetchFreezeAc(context);
                              },
                              style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: theme.isDarkMode
                                      ? colors.colorbluegrey
                                      : colors.colorBlack,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50))),
                              child: TextWidget.subText(
                                  text: "Continue",
                                  theme: false,
                                  color: theme.isDarkMode
                                      ? colors.colorWhite
                                      : colors.colorBlack,
                                  fw: 0),
                            ),
                          ],
                        );
                      },
                    );
                  } else if (index == 3) {
                    ref.read(changePasswordProvider).userIdController.text =
                        "${pref.clientId}";
                    Navigator.pushNamed(context, Routes.changePass,
                        arguments: "Yes");
                  } else if (index == 5) {
                    // String pwd = apikeys.totpkey!.pwd;
                    // _showAlertDialog(context, pwd, theme);
                    Navigator.pushNamed(context, Routes.logError);
                  } else if (index == 4) {
                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: theme.isDarkMode
                                ? const Color.fromARGB(255, 18, 18, 18)
                                : colors.colorWhite,
                            shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(16))),
                            scrollable: true,
                            actionsPadding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 14, top: 3),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            insetPadding:
                                const EdgeInsets.symmetric(horizontal: 40),
                            titlePadding: const EdgeInsets.only(left: 16),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextWidget.titleText(
                                    text: "Choose theme",
                                    theme: theme.isDarkMode,
                                    color: theme.isDarkMode
                                        ? colors.colorWhite
                                        : colors.colorBlack,
                                    fw: 1),
                                IconButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                  ),
                                  color: theme.isDarkMode
                                      ? const Color(0xffBDBDBD)
                                      : colors.colorGrey,
                                )
                              ],
                            ),
                            content: SizedBox(
                                height: 115,
                                width: MediaQuery.of(context).size.width,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Divider(
                                          color: theme.isDarkMode
                                              ? colors.darkColorDivider
                                              : colors.colorDivider,
                                          height: 0),
                                      const SizedBox(height: 10),
                                      ListView.builder(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
                                        itemCount: theme.themeTypes.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          return ListTile(
                                            onTap: () async {
                                              theme.toggleTheme(
                                                  themeMod:
                                                      theme.themeTypes[index]);
                                              Navigator.pop(context);
                                            },
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 0, vertical: 0),
                                            dense: true,
                                            minLeadingWidth: 22,
                                            leading: SvgPicture.asset(theme
                                                    .isDarkMode
                                                ? theme.themeTypes[index] ==
                                                        theme.deviceTheme
                                                    ? assets.darkActProductIcon
                                                    : assets.darkProductIcon
                                                : theme.themeTypes[index] ==
                                                        theme.deviceTheme
                                                    ? assets.actProductIcon
                                                    : assets.productIcon),
                                            title: TextWidget.subText(
                                                text: theme.themeTypes[index],
                                                theme: theme.isDarkMode,
                                                color: theme.isDarkMode
                                                    ? Color(theme.themeTypes[
                                                                index] ==
                                                            theme.deviceTheme
                                                        ? 0xffffffff
                                                        : 0xff666666)
                                                    : Color(
                                                        theme.themeTypes[
                                                                    index] ==
                                                                theme
                                                                    .deviceTheme
                                                            ? 0xff000000
                                                            : 0xff666666,
                                                      ),
                                                fw: 0),
                                          );
                                        },
                                      )
                                    ])),
                          );
                        });
                  } else if (index == 6) {
                    Navigator.pushNamed(context, Routes.orderPrefer);
                  }
                },
                dense: true,
                minLeadingWidth: 20,
                leading: index == 2
                    ? const Icon(
                        Icons.lock_outline_rounded,
                        size: 21,
                      )
                    : SvgPicture.asset(
                        usersettings.settingmenu[index]['leading'],
                        width: 19,
                        color: const Color(0xff666666),
                      ),
                title: TextWidget.titleText(
                    text: usersettings.settingmenu[index]['title'],
                    theme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? const Color(0xffffffff)
                        : const Color(0xff000000),
                    fw: 0),
                subtitle: Row(
                  children: [
                    if (index == 0) ...[
                      Row(
                        children: [
                          apikeys.apikeyres!.apistatus == "VALID"
                              ? Row(
                                  children: [
                                    TextWidget.paraText(
                                        text: "${apikeys.apikeyres!.apikey}"
                                            .substring(0, 4),
                                        theme: theme.isDarkMode,
                                        color: const Color(0xff666666),
                                        fw: 0),
                                    TextWidget.paraText(
                                        text: ".........",
                                        theme: theme.isDarkMode,
                                        color: const Color(0xff666666),
                                        fw: 0),
                                    TextWidget.paraText(
                                        text: ".........",
                                        theme: theme.isDarkMode,
                                        color: const Color(0xff666666),
                                        fw: 0),
                                    TextWidget.paraText(
                                        text: "${apikeys.apikeyres!.apikey}"
                                            .substring(28, 32),
                                        theme: theme.isDarkMode,
                                        color: const Color(0xff666666),
                                        fw: 0),
                                    const SizedBox(width: 5),
                                    apikeys.apikeyres!.apistatus == "VALID"
                                        ? InkWell(
                                            onTap: () async {
                                              await Share.share(
                                                "API Key\n${apikeys.apikeyres!.apikey}",
                                              );
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 5),
                                              child: TextWidget.subText(
                                                text: "Share",
                                                theme: theme.isDarkMode,
                                                color: colors.colorBlue,
                                                fw: 0,
                                              ),
                                            ),
                                          )
                                        : Container()
                                  ],
                                )
                              : Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  width: 180,
                                  child: TextWidget.paraText(
                                      text:
                                          "API Key is Experied please generate a new key",
                                      theme: theme.isDarkMode,
                                      color: const Color(0xff666666),
                                      fw: 0),
                                ),
                        ],
                      ),
                    ],
                    TextWidget.paraText(
                        text: index != 0
                            ? usersettings.settingmenu[index]['subTitle']
                            : "",
                        theme: theme.isDarkMode,
                        color: const Color(0xff666666),
                        fw: 0,
                        textOverflow: TextOverflow.ellipsis),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index == 0) ...[
                      apikeys.apikeyres!.apistatus == "VALID"
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const SizedBox(
                                  height: 8,
                                ),
                                TextWidget.subText(
                                  text: "Expire on",
                                  theme: theme.isDarkMode,
                                  color: theme.isDarkMode
                                      ? colors.colorGrey
                                      : colors.colorBlack,
                                  fw: 0,
                                ),
                                TextWidget.subText(
                                  text: readTimestamp(int.parse(
                                      "${apikeys.apikeyres!.exd}000")),
                                  theme: theme.isDarkMode,
                                  color: theme.isDarkMode
                                      ? colors.colorWhite
                                      : colors.colorBlack,
                                  fw: 0,
                                ),
                              ],
                            )
                          : SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    backgroundColor: const Color(0xff000000),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50),
                                    )),
                                onPressed: () async {
                                  await ref
                                      .read(apikeyprovider)
                                      .fetchregenerateapikey(context, "1 year");
                                  await ref
                                      .read(apikeyprovider)
                                      .fetchapikey(context);
                                      successMessage(context,
                                          'API Key as been ${apikeys.generateApikey?.status}');
                                },
                                child: TextWidget.subText(
                                  text: "API Key",
                                  theme: theme.isDarkMode,
                                  color: const Color(0xffffffff),
                                  fw: 0,
                                  align: TextAlign.center,
                                ),
                              ),
                            ),
                    ],
                    index != 2 && index != 0
                        ? SvgPicture.asset(
                            usersettings.settingmenu[index]['trailing'])
                        : Container()
                  ],
                ),
              );
            },
            shrinkWrap: true,
            itemCount: usersettings.settingmenu.length,
            separatorBuilder: (BuildContext context, int index) {
              return const ListDivider();
            },
          ),
        ],
      ),
    );
  }

  // void _showAlertDialog(
  //     BuildContext context, String pwd, ThemesProvider theme) {
  //   bool isHidden = true; // Local variable to track visibility

  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return StatefulBuilder(
  //         builder: (BuildContext context, StateSetter setState) {
  //           return AlertDialog(
  //             titleTextStyle: textStyles.appBarTitleTxt,
  //             contentTextStyle: textStyles.menuTxt,
  //             titlePadding:
  //                 const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  //             shape: const RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.all(Radius.circular(14))),
  //             scrollable: true,
  //             contentPadding: const EdgeInsets.symmetric(
  //               horizontal: 14,
  //             ),
  //             insetPadding: const EdgeInsets.symmetric(horizontal: 20),
  //             title: Text("Sensitive Information"),
  //             content: Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 // Display sensitive text
  //                 Expanded(
  //                   child: Text(
  //                     isHidden ? "••••••••••••••••••••••••••••••••" : "$pwd",
  //                     style: TextStyle(fontSize: 16),
  //                     overflow: TextOverflow.ellipsis,
  //                   ),
  //                 ),
  //                 const SizedBox(width: 10),
  //                 // Toggle button
  //                 IconButton(
  //                   icon: Icon(
  //                     isHidden ? Icons.visibility_off : Icons.visibility,
  //                   ),
  //                   onPressed: () {
  //                     setState(() {
  //                       isHidden = !isHidden; // Toggle visibility
  //                     });
  //                   },
  //                 ),
  //               ],
  //             ),
  //             actions: [
  //               Row(
  //                 children: [
  //                   SizedBox(
  //                     child: ElevatedButton(
  //                         onPressed: () {},
  //                         style: ElevatedButton.styleFrom(
  //                             elevation: 0,
  //                             backgroundColor: theme.isDarkMode
  //                                 ? colors.colorbluegrey
  //                                 : colors.colorBlack,
  //                             padding: const EdgeInsets.symmetric(vertical: 13),
  //                             shape: RoundedRectangleBorder(
  //                               borderRadius: BorderRadius.circular(30),
  //                             )),
  //                         child: Text("Proceed", style: textStyles.btnText)),
  //                   ),
  //                   SizedBox(
  //                     child: ElevatedButton(
  //                         onPressed: () {},
  //                         style: ElevatedButton.styleFrom(
  //                             elevation: 0,
  //                             backgroundColor: theme.isDarkMode
  //                                 ? colors.colorbluegrey
  //                                 : colors.colorBlack,
  //                             padding: const EdgeInsets.symmetric(vertical: 13),
  //                             shape: RoundedRectangleBorder(
  //                               borderRadius: BorderRadius.circular(30),
  //                             )),
  //                         child: Text("Proceed", style: textStyles.btnText)),
  //                   ),
  //                 ],
  //               )
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  TextStyle textStyle(Color color, double fontSize, fWeight) {
    return dysInter(
        textStyle:
            TextStyle(fontWeight: fWeight, color: color, fontSize: fontSize));
  }

  copyToClipboard(String text, String? status, BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    if (status == "VALID") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: TextWidget.titleText(
          text: 'Text copied to clipboard',
          theme: false,
          color: colors.colorBlue,
          fw: 0,
        )),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: TextWidget.titleText(
          text: 'Click on API Key button to Generate API Key',
          theme: false,
          color: colors.colorBlack,
          fw: 0,
        )),
      );
    }
  }
}

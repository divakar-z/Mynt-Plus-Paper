import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/api/core/api_link.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/provider/auth_provider.dart';
import 'package:mynt_plus/provider/network_state_provider.dart';
import 'package:mynt_plus/res/global_state_text.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/routes/route_names.dart';
import 'package:mynt_plus/sharedWidget/no_internet_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';


// import '../../provider/user_profile_provider.dart';


class PreviousLoginDecive extends StatefulWidget {
  const PreviousLoginDecive({super.key});

  @override
  State<PreviousLoginDecive> createState() => _PreviousLoginDeciveState();
}

class _PreviousLoginDeciveState extends State<PreviousLoginDecive> {
  @override
  void initState() {
    // ref.read(networkStateProvider).networkStream();
    super.initState();
  }

  final Preferences pref = locator<Preferences>();
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents default back behavior
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // If system handled back, do nothing

        await showExitPopup(); // Call the exit popup function
      },
      child: Consumer(builder: (context, WidgetRef ref, _) {
        final loggedUser = ref.watch(authProvider);
        // final user = ref.watch(userProfileProvider);
        final internet = ref.watch(networkStateProvider);
        return Scaffold(
          appBar: AppBar(
              elevation: .2,
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              title: TextWidget.titleText(
                text: "Previously signed in account's on this device",
                theme: false,
                color: const Color(0xff000000),
                fw: 1,
                textOverflow: TextOverflow.ellipsis,
              )),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: loggedUser.loggedMobile.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return Divider(
                            height: 1,
                            thickness: 1,
                            color: colors.colorDivider);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return ListTile(
                          onTap: internet.connectionStatus ==
                                  ConnectivityResult.none
                              ? null
                              : () async {
                                  pref.setClientId(
                                      loggedUser.loggedMobile[index].clientId);

                                  pref.setClientMob(
                                      loggedUser.loggedMobile[index].mobile);
                                  pref.setClientSession(
                                      loggedUser.loggedMobile[index].sesstion);
                                  pref.setClientName(
                                      loggedUser.loggedMobile[index].userName);

                                  final localstorage =
                                      await SharedPreferences.getInstance();

                                  // localstorage.setString("mobileNum",
                                  //     loggedUser.loggedMobile[index].mobile);
                                  // localstorage.setString("userId",
                                  //     loggedUser.loggedMobile[index].clientId);
                                  // localstorage.setString("session",
                                  //     loggedUser.loggedMobile[index].sesstion);
                                  localstorage.setString("userName",
                                      loggedUser.loggedMobile[index].userName);

                                  setState(() {
                                    ApiLinks.userName = ApiLinks.userName =
                                        localstorage.getString("userName") ??
                                            "";
                                    // ApiLinks.userID =
                                    //     localstorage.getString("userId") ?? "";
                                    // ApiLinks.session =
                                    //     localstorage.getString("session") ?? "";
                                  });

                                  // await user.fetchUserDetail(
                                  //     context,
                                  //     loggedUser.loggedMobile[index].clientId,
                                  //     loggedUser.loggedMobile[index].sesstion,
                                  //     "preLoginDecive");
                                  // if (initRoute != "initialRoute") {
                                  //   if (user.userDetailModel!.stat == "Ok") {
                                  //     Navigator.pop(context);
                                  //   }
                                  // }

                                  // loggedUser.loginMethCtrl.text =
                                  //     loggedUser.loggedMobile[index].mobile;
                                  // if (user.userDetailModel!.emsg ==
                                  //     "Session Expired :  Invalid Session Key") {
                                  //   loggedUser.loginMethCtrl.text =
                                  //       localstorage.getString("userId") ?? "";

                                  //   Navigator.of(context).pop();
                                  //   ScaffoldMessenger.of(context).showSnackBar(
                                  //       errorSnackBar('${user.userDetailModel!.emsg}'));
                                  //   Navigator.pushNamedAndRemoveUntil(
                                  //       context,
                                  //       Routes.loginScreen,
                                  //       arguments: "deviceLogin",
                                  //       (route) => false);
                                  // } else if (initRoute == "initialRoute") {
                                  //   await loggedUser.fetchLocalData();
                                  //   await loggedUser.deviceAuth(context);
                                  //   // context
                                  //   //     .read(indexListProvider)
                                  //   //     .getDeafultIndexList(context);
                                  //   // await context
                                  //   //     .read(marketWatchProvider)
                                  //   //     .fetchMWList(context);
                                  //   Navigator.of(context).pop();
                                  //   Navigator.pushNamedAndRemoveUntil(
                                  //       context, Routes.homeScreen, (route) => false);
                                  // } else {
                                  //   Navigator.of(context).pop();
                                  // }
                                },
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          title: TextWidget.subText(
                            text: loggedUser.loggedMobile[index].mobile,
                            theme: false,
                            color: const Color(0xff000000),
                            fw: 1,
                          ),
                          subtitle: TextWidget.paraText(
                            text:
                                "User ID ${loggedUser.loggedMobile[index].clientId}",
                            theme: false,
                            color: const Color(0xff666666),
                            fw: 0,
                          ),
                          trailing: loggedUser.loggedMobile[index].clientId ==
                                  pref.clientId
                              ? TextWidget.subText(
                                  text: "Last active",
                                  theme: false,
                                  color: const Color(0xff0037B7),
                                  fw: 1,
                                )
                              : Container(
                                  width: .3,
                                ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, Routes.loginScreen,
                              arguments: "login");
                        },
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                width: 1.4, color: Color(0xff000000)),
                            padding: const EdgeInsets.symmetric(vertical: 10.5),
                            shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(30)))),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(assets.addCircleIcon,
                                  color: const Color(0xff000000)),
                              const SizedBox(width: 8),
                              TextWidget.subText(
                                text: "Add another account",
                                theme: false,
                                color: const Color(0xff000000),
                                fw: 1,
                              )
                            ])),
                  ),
                  if (defaultTargetPlatform == TargetPlatform.iOS)
                    const SizedBox(height: 20)
                ],
              ),
              if (internet.connectionStatus == ConnectivityResult.none) ...[
                const NoInternetWidget()
              ]
            ],
          ),
        );
      }),
    );
  }

  Future<bool> showExitPopup() async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
                titleTextStyle: textStyles.appBarTitleTxt,
                contentTextStyle: textStyles.menuTxt,
                titlePadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14))),
                scrollable: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                ),
                insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: TextWidget.titleText(
                  text: "Exit App",
                  theme: false,
                  color: Color(0xff000000),
                  fw: 0,
                ),
                content: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextWidget.paraText(
                            text: "Do you want to Exit an App?",
                            theme: false,
                            color: Color(0xff000000),
                            fw: 0,
                          )
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: TextWidget.subText(
                        text: "No",
                        theme: false,
                        color: colors.colorBlue,
                        fw: 0,
                      )),
                  ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xff0037B7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          )),
                      child: TextWidget.subText(
                        text: "Yes",
                        theme: false,
                        color: const Color(0xffFFFFFF),
                        fw: 0,
                      ))
                ]);
          },
        ) ??
        false;
  }

  TextStyle textStyle(Color color, double fontSize, fWeight) {
    return dysInter(
        textStyle:
            TextStyle(fontWeight: fWeight, color: color, fontSize: fontSize));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/res/global_state_text.dart';
import 'package:mynt_plus/res/res.dart';
import 'window_setting_tabbar_screens/navigationsetting.dart';
import 'window_setting_tabbar_screens/productsetting.dart';

class WindowSettings extends StatefulWidget {
  const WindowSettings({super.key});

  @override
  State<WindowSettings> createState() => _WindowSettingsState();
}

class _WindowSettingsState extends State<WindowSettings>
    with TickerProviderStateMixin {
  late TabController tabCtrl;
  List<Tab> tabList = const [
    Tab(
      text: 'Navigation Setting',
    ),
    Tab(
      text: 'Product Setting',
    )
  ];
  @override
  void initState() {
    tabCtrl =
        TabController(length: tabList.length, vsync: this, initialIndex: 0);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFFFFFF),
      appBar: AppBar(
        leadingWidth: 41,
        titleSpacing: 6,
        leading: InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: SvgPicture.asset(assets.backArrow))),
        backgroundColor: const Color(0xffFFFFFF),
        elevation: 0.3,
        iconTheme: const IconThemeData(color: Color(0xff000000)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(125),
            child: Container(
              decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(
                color: Color.fromARGB(44, 44, 45, 03),
              ))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget.headText(
                          text: 'Window Settings',
                          theme: false,
                          color: const Color(0xff000000),
                          fw: 1,
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        TextWidget.subText(
                          text: 'View bank details and add new banks.',
                          theme: false,
                          color: const Color(0xff666666),
                          fw: 0,
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                      indicatorColor: const Color(0xff0037B7),
                      unselectedLabelColor: const Color(0XFF777777),
                      unselectedLabelStyle: dysInter(
                          textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.28)),
                      labelColor: const Color(0XFF0037B7),
                      labelStyle: dysInter(
                          textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.28)),
                      controller: tabCtrl,
                      tabs: tabList),
                ],
              ),
            )),
      ),
      body: TabBarView(
        controller: tabCtrl,
        children: const [NavigationSettings(), ProductSettings()],
      ),
    );
  }
}

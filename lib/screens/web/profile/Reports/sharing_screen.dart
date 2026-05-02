import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/ledger_provider.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../provider/thems.dart';
import '../../../../../res/global_state_text.dart';
import '../../../../../res/res.dart';
import '../../../../../sharedWidget/cust_text_formfield.dart';
import '../../../../../sharedWidget/snack_bar.dart';

class SharingScreen extends StatefulWidget {
  const SharingScreen({super.key});

  @override
  State<SharingScreen> createState() => _SharingScreen();
}

class DropdownItem {
  final String value;
  final String label;
  final bool isEnabled;

  DropdownItem({
    required this.value,
    required this.label,
    this.isEnabled = true,
  });
}

class _SharingScreen extends State<SharingScreen> {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenheight = MediaQuery.of(context).size.height;
    double notional = 0.0;

    return Consumer(builder: (context, WidgetRef ref, _) {
      final ledgerprovider = ref.watch(ledgerProvider);
      final theme = ref.read(themeProvider);

      // final myController = TextEditingController(text: ledgerprovider.selectnetpledge.text);
      // String selectedValue = ledgerprovider.segmentvalue;

      String sharingapiforcalendar = 'https://app.mynt.in/dailypnl?ucode=';

// Optional: remove duplicates if needed (based on value)
      final seen = <String>{};

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (ledgerprovider.listforpledge == []) {
            ledgerprovider.changesegvaldummy('');
          }
          Navigator.pop(context);
        },
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: theme.isDarkMode
                    ? Color.fromARGB(255, 0, 0, 0)
                    : Color.fromARGB(255, 255, 255, 255)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    color: const Color.fromARGB(255, 219, 218, 218),
                    width: 40,
                    height: 4.0,
                    padding: EdgeInsets.only(
                        top: 10, bottom: 25, left: 20, right: 20),
                    margin: EdgeInsets.only(top: 16),
                  ),
                ],
              ),
              Padding(
                padding:
                    const EdgeInsets.only(top: 16.0, left: 16.0, bottom: 8.0),
                child: TextWidget.heroText(
                    text: "Grab your URL",
                    textOverflow: TextOverflow.ellipsis,
                    theme: theme.isDarkMode,
                    fw: 1),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: 2.0,
                  bottom: 6.0,
                ),
                child: Divider(
                  color: theme.isDarkMode
                      ? const Color(0xffB5C0CF).withValues(alpha: .15)
                      : const Color(0xffF1F3F8),
                  thickness: 6.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget.paraText(
                            text: "Share this link Or copy link",
                            textOverflow: TextOverflow.ellipsis,
                            theme: theme.isDarkMode,
                            fw: 0),
                        Row(
                          children: [
                            Container(
                              width: screenWidth * 0.7,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 14),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  color: theme.isDarkMode
                                      ? const Color(0xffB5C0CF).withValues(alpha: .15)
                                      : const Color(0xffF1F3F8)),
                              child: TextWidget.paraText(
                                  text:
                                      "$sharingapiforcalendar${ledgerprovider.ucode}",
                                  textOverflow: TextOverflow.ellipsis,
                                  theme: theme.isDarkMode,
                                  fw: 0),
                            ),
                            IconButton(
                              iconSize: 20,
                              icon: Icon(Icons.copy_all_rounded,
                                  color: ledgerprovider.notsharing == false
                                      ? Colors.black
                                      : Colors.grey),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(
                                    text:
                                        "$sharingapiforcalendar${ledgerprovider.ucode}"));
                                successMessage(context, 'Text copied'
                                );
                                Navigator.pop(context);
                              },
                            ),
                            IconButton(
                              iconSize: 20,
                              icon: Icon(Icons.share_outlined,
                                  color: ledgerprovider.notsharing == false
                                      ? Colors.black
                                      : Colors.grey),
                              onPressed: () async {
                                final url =
                                    "$sharingapiforcalendar${ledgerprovider.ucode}";
                                final twitterUrl =
                                    "https://twitter.com/intent/tweet?text=Excited about my recent trading triumph using Zebu—profits surging! Skillful moves on the Zebu app have significantly boosted my success !&url=$sharingapiforcalendar${ledgerprovider.ucode}&hashtags=Traders #Traders via @zebuetrade ";
                                if (await canLaunchUrl(Uri.parse(twitterUrl))) {
                                  await launchUrl(Uri.parse(twitterUrl),
                                      mode: LaunchMode.externalApplication);
                                  Navigator.pop(context);
                                } else {
                                  error(context, 'Could not launch Twitter');
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 20.0,
              ),
            ]),
          ),
        ),
      );
    });
  }
}

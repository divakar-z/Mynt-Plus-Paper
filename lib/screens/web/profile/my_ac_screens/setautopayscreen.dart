import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';

import 'package:mynt_plus/routes/route_names.dart';

class UpiPayement extends StatefulWidget {
  const UpiPayement({super.key});

  @override
  State<UpiPayement> createState() => _UpiPayementState();
}

class _UpiPayementState extends State<UpiPayement> {
  bool datachange = true;
  void changedata() {
    setState(() {
      datachange = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: datachange == false
              ? ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xff000000),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      )),
                  onPressed: () {
                    Navigator.pushNamed(context, Routes.setautopay);
                  },
                  child: Text(
                    'Continue Autopay!',
                    style:
                        textStyle(const Color(0xffFFFFFF), 14, FontWeight.w600),
                  ))
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xff000000),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      )),
                  onPressed: changedata,
                  child: Text(
                    'Set Autopay!',
                    style:
                        textStyle(const Color(0xffFFFFFF), 14, FontWeight.w600),
                  ))),
      appBar: AppBar(
          backgroundColor: const Color(0xffFFFFFF),
          shadowColor: const Color.fromARGB(44, 44, 45, 03),
          leadingWidth: 30,
          iconTheme: const IconThemeData(color: Color(0xff000000)),
          ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automatic Payments',
                  style:
                      textStyle(const Color(0xff000000), 18, FontWeight.w600),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  'View bank details and add new banks.',
                  style:
                      textStyle(const Color(0xff666666), 14, FontWeight.w500),
                ),
              ],
            ),
            Column(
              children: [
                // SvgPicture.asset('assets/profile/upilogo.svg'),
                datachange == false
                    ? const SizedBox(
                        height: 5,
                      )
                    : const SizedBox(
                        height: 20,
                      ),
                datachange == false
                    ? Text(
                        'How it works',
                        style: dysInter(
                            fontSize: 18,
                            color: const Color(0xff000000),
                            letterSpacing: 0.36,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      )
                    : Text(
                        'No automatic payments are set',
                        style: dysInter(
                            fontSize: 18,
                            color: const Color(0xff000000),
                            letterSpacing: 0.36,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                datachange == false
                    ? const SizedBox(
                        height: 6,
                      )
                    : const SizedBox(
                        height: 14,
                      ),
                datachange == false
                    ? Text(
                        'You can use your UPI id and initiate fund transfer using the below steps:',
                        style: textStyle(
                            const Color(0xff666666), 14, FontWeight.w500),
                        textAlign: TextAlign.center,
                      )
                    : Text(
                        'These autopay will be link to your stock SIP for automatic transfer of funds to trading account.',
                        style: textStyle(
                            const Color(0xff666666), 14, FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                datachange == false
                    ? const SizedBox(
                        height: 24,
                      )
                    : const SizedBox(
                        height: 0,
                      ),
                datachange == false
                    ? Column(
                        children: [
                          ListTile(
                            minLeadingWidth: 10,
                            leading: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: SvgPicture.asset(
                                  'assets/profile/blueline.svg'),
                            ),
                            title: Text(
                              'Select your bank account to set up the UPI autopay',
                              style: textStyle(
                                  const Color(0xff0037B7), 14, FontWeight.w600),
                            ),
                          ),
                          ListTile(
                            minLeadingWidth: 10,
                            leading: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: SvgPicture.asset(
                                  'assets/profile/blueline.svg'),
                            ),
                            title: Text(
                              'Select the UPI app or enter your UPI ID to set up the autopay',
                              style: textStyle(
                                  const Color(0xff0037B7), 14, FontWeight.w600),
                            ),
                          ),
                          ListTile(
                            minLeadingWidth: 10,
                            leading: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: SvgPicture.asset(
                                  'assets/profile/blueline.svg'),
                            ),
                            title: Text(
                              'Enter the autopay amount to continue the payment steps',
                              style: textStyle(
                                  const Color(0xff0037B7), 14, FontWeight.w600),
                            ),
                          ),
                        ],
                      )
                    : Container(),
                datachange == false
                    ? const SizedBox(
                        height: 24,
                      )
                    : const SizedBox(
                        height: 0,
                      ),
                datachange == false
                    ? Text(
                        'By Continuing, I agree to with the Disclaimer and T&C of Zebu Trade',
                        textAlign: TextAlign.center,
                        style: textStyle(
                            const Color(0xff666666), 12, FontWeight.w500),
                      )
                    : Container()
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextStyle textStyle(Color color, double fontSize, fWeight) {
    return dysInter(
        textStyle: TextStyle(
      fontWeight: fWeight,
      color: color,
      fontSize: fontSize,
    ));
  }
}

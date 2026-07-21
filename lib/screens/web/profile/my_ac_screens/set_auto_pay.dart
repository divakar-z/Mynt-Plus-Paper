import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';

class SetAutoPay extends StatefulWidget {
  const SetAutoPay({super.key});

  @override
  State<SetAutoPay> createState() => _SetAutoPayState();
}

class _SetAutoPayState extends State<SetAutoPay> {
  int _selectedIndex = 0;

  int? buttonchange;
  List<Bankdetails> bankdata = [
    Bankdetails(
        img: 'assets/profile/punjabbanklogo.png',
        bankname: 'Punjab National Bank',
        acno: 'A/C No: 45**********2323',
        clickimg: 'assets/profile/radiobuttongreentick.svg',
        iselecetd: true),
    Bankdetails(
        img: 'assets/profile/kotakbanklogo.png',
        bankname: 'Kotak Mahindra Bank',
        acno: 'A/C No: 24**********8926',
        clickimg: 'assets/profile/radiobuttonoutline.svg',
        iselecetd: false),
  ];

  String imagePath = 'assets/profile/radiobuttonoutline.svg';
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xffFFFFFF),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xff000000),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                )),
            onPressed: () {},
            child: Text(
              'Continue Autopay!',
              style: textStyle(const Color(0xffFFFFFF), 14, FontWeight.w600),
            )),
      ),
      appBar: AppBar(
          backgroundColor: const Color(0xffFFFFFF),
          shadowColor: const Color.fromARGB(44, 44, 45, 03),
          leadingWidth: 30,
          iconTheme: const IconThemeData(color: Color(0xff000000)),
         ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automatic Payments',
                  style: textStyle(const Color(0xff000000), 18, FontWeight.w600),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  'View bank details and add new banks.',
                  style: textStyle(const Color(0xff666666), 14, FontWeight.w500),
                ),
              ],
            ),
            Center(
                child: Column(
              children: [
                SvgPicture.asset('assets/profile/setautopaylogo.svg'),
                Text(
                  'How it works',
                  style: dysInter(
                      fontSize: 18,
                      color: const Color(0xff000000),
                      letterSpacing: 0.36,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(
                  height: 24,
                ),
                GridView.builder(
                    itemCount: bankdata.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            childAspectRatio: 4.10,
                            crossAxisSpacing: 200,
                            mainAxisSpacing: 16),
                    itemBuilder: (BuildContext ctx, int index) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        width: screenWidth,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xffDDDDDD))),
                        child: Column(
                          children: [
                            ListTile(
                              onTap: () {},
                              trailing: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = index;
                                    });
                                  },
                                  child: _selectedIndex == index
                                      ? SvgPicture.asset(
                                          'assets/profile/radiobuttongreentick.svg')
                                      : SvgPicture.asset(
                                          'assets/profile/radiobuttonoutline.svg')),
                              leading: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2.5, vertical: 2.5),
                                    decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(170),
                                        border: Border.all(
                                            color: const Color(0xffD9DEE8))),
                                    child: Image.asset(bankdata[index].img)),
                              ),
                              title: Text(
                                bankdata[index].bankname,
                                style: textStyle(const Color(0xff000000), 14,
                                    FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(
                                    height: 2,
                                  ),
                                  Text(
                                    bankdata[index].acno,
                                    style: textStyle(const Color(0xff666666),
                                        12, FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                const SizedBox(
                  height: 24,
                ),
                Text(
                  '+ Add New Bank Account',
                  style:
                      textStyle(const Color(0xff0037B7), 14, FontWeight.w600),
                ),
                const SizedBox(
                  height: 32,
                ),
                Text(
                  'By Continuing, I agree to with the Disclaimer and T&C of Zebu Trade',
                  textAlign: TextAlign.center,
                  style:
                      textStyle(const Color(0xff666666), 12, FontWeight.w500),
                )
              ],
            )),
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

class Bankdetails {
  String img;
  String bankname;
  String acno;
  String clickimg;
  bool iselecetd;

  Bankdetails({
    required this.img,
    required this.bankname,
    required this.acno,
    required this.clickimg,
    required this.iselecetd,
  });
}

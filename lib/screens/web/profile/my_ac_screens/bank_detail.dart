import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';

import 'package:mynt_plus/provider/user_profile_provider.dart';
import 'package:mynt_plus/res/res.dart';

class BankDetail extends ConsumerWidget {
  const BankDetail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
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
              child: SvgPicture.asset(assets.backArrow),
            ),
          ),
          backgroundColor: const Color(0xffFFFFFF),
          elevation: 0.3,
          iconTheme: const IconThemeData(color: Color(0xff000000)),
          title: Text('Bank Accounts Linked',
              style: textStyle(const Color(0xff000000), 14, FontWeight.w600)),
         ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("View bank details.",
                style: textStyle(const Color(0xff666666), 14, FontWeight.w500)),
            const SizedBox(height: 22),
            Text(
                "${userProfile.clientDetailModel!.bankdetails!.length} Account Linked",
                style: textStyle(const Color(0xff666666), 16, FontWeight.w600)),
            const SizedBox(height: 22),
            ListView.separated(
              shrinkWrap: true,
              itemCount: userProfile.clientDetailModel!.bankdetails!.length,
              itemBuilder: (context, int index) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xffDDDDDD))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              "${userProfile.clientDetailModel!.bankdetails![index].bankn}",
                              style: textStyle(const Color(0xff000000), 14,
                                  FontWeight.w600)),
                          index == 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffF1F3F8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text("PRIMARY",
                                      style: textStyle(const Color(0xff666666),
                                          9, FontWeight.w600)))
                              : Container()
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                          "A/C No: *******${userProfile.clientDetailModel!.bankdetails![index].acctnum!.substring((userProfile.clientDetailModel!.bankdetails![index].acctnum!.length - 4).clamp(0, userProfile.clientDetailModel!.bankdetails![index].acctnum!.length))}",
                          style: textStyle(
                              const Color(0xff666666), 12, FontWeight.w500)),
                      const SizedBox(height: 16),
                      Text("IFSC Code",
                          style: textStyle(
                              const Color(0xff666666), 12, FontWeight.w500)),
                      const SizedBox(height: 5),
                      Text(
                          "${userProfile.clientDetailModel!.bankdetails![index].ifscCode}",
                          style: textStyle(
                              const Color(0xff000000), 14, FontWeight.w500))
                    ],
                  ),
                );
              },
              separatorBuilder: (BuildContext context, int index) {
                return const SizedBox(height: 14);
              },
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';

import 'package:mynt_plus/provider/user_profile_provider.dart';
import 'package:mynt_plus/res/res.dart';

class ProfileDetails extends ConsumerWidget {
  const ProfileDetails({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    return Scaffold(
      backgroundColor: const Color(0xffFFFFFF),
      appBar: AppBar(
          backgroundColor: const Color(0xffFFFFFF),
          elevation: 0.3,
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
          title: Text('Profile Details',
              style: textStyle(const Color(0xff000000), 14, FontWeight.w600)),
          
          ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              "We use these details for all communication related to your account.",
              style: textStyle(const Color(0xff666666), 14, FontWeight.w500)),
          const SizedBox(height: 26),
          Text("Personal Details",
              style: textStyle(const Color(0xff666666), 16, FontWeight.w600)),
          const SizedBox(height: 18),
          headerText("Name"),
          const SizedBox(height: 06),
          valueText("${userProfile.clientDetailModel!.cliname}"),
          const Divider(color: Color(0xffDDDDDD)),
          const SizedBox(height: 16),
          headerText("Email Address"),
          const SizedBox(height: 06),
          valueText("${userProfile.clientDetailModel!.email}"),
          const Divider(color: Color(0xffDDDDDD)),
          const SizedBox(height: 16),
          headerText("Phone Number"),
          const SizedBox(height: 06),
          valueText("${userProfile.clientDetailModel!.mNum}"),
          const Divider(color: Color(0xffDDDDDD)),
          const SizedBox(height: 16),
          headerText("PAN Number"),
          const SizedBox(height: 06),
          valueText(
              "*******${userProfile.clientDetailModel!.pan!.substring(7)}"),
          const Divider(color: Color(0xffDDDDDD)),
          const SizedBox(height: 16),
          headerText("Date of Birth"),
          const SizedBox(height: 06),
          valueText(userProfile.clientDetailModel!.dob!.isEmpty
              ? "---"
              : "${userProfile.clientDetailModel!.dob}"),
          const Divider(color: Color(0xffDDDDDD)),
          // SizedBox(height: 16),
          // headerText("Gender"),
          // SizedBox(height: 06),
          // valueText("MALE"),
          // Divider(color: Color(0xffDDDDDD)),
          const SizedBox(height: 28),
          Text("Trading and Demat Account",
              style: textStyle(const Color(0xff666666), 16, FontWeight.w600)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerText("Depository Name"),
                    const SizedBox(height: 06),
                    valueText("CDSL"),
                    const Divider(color: Color(0xffDDDDDD)),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerText("User ID"),
                    const SizedBox(height: 06),
                    valueText("${userProfile.clientDetailModel!.actid}"),
                    const Divider(color: Color(0xffDDDDDD)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerText("UCC"),
                    const SizedBox(height: 06),
                    valueText("${userProfile.clientDetailModel!.actid}"),
                    const Divider(color: Color(0xffDDDDDD)),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerText("DP ID"),
                    const SizedBox(height: 06),
                    valueText(userProfile
                        .clientDetailModel!.dpAcctNum![0].dpnum!
                        .substring(0, 8)),
                    const Divider(color: Color(0xffDDDDDD)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          headerText("Demat Account Number (BOID)"),
          const SizedBox(height: 06),
          valueText("${userProfile.clientDetailModel!.dpAcctNum![0].dpnum}"),
        ],
      ),
    );
  }

  Text valueText(String text) {
    return Text(text,
        style: textStyle(const Color(0xff000000), 16, FontWeight.w500));
  }

  Text headerText(String text) {
    return Text(text,
        style: textStyle(const Color(0xff666666), 14, FontWeight.w500));
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

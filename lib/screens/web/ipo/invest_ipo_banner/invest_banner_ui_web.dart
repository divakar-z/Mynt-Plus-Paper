import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/res.dart';

class InvestIPO extends ConsumerWidget {
  const InvestIPO({super.key});

  static const Color _primaryColor = Color(0xff834EDA);
  static const Color _titleColor = Color(0xffFEFDFD);
  static const Color _subtitleColor = Color(0xffE6DCF8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.all(Radius.circular(5))),
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              ListTile(
                title: Text("Invest in IPOs",
                    style: dysInter(
                        textStyle: _textStyle(_titleColor, 20, FontWeight.w600))),
                subtitle: const Column(
                  children: [
                    SizedBox(height: 3),
                    Text(
                        "Initial public offering a new stock issuance for the first time.",
                        style: TextStyle(
                            color: _subtitleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.only(left: 14),
                child: ElevatedButton(
                  onPressed: () {
                    // Add your button functionality here
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 0),
                    backgroundColor: theme.isDarkMode
                        ? colors.colorWhite
                        : colors.colorBlack,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(50)),
                    ),
                  ),
                  child: Text(
                    "Apply for an IPO",
                    style: TextStyle(
                      color: theme.isDarkMode
                          ? colors.colorBlack
                          : colors.colorWhite,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10)
            ],
          ),
        ),
      ],
    );
  }

  static TextStyle _textStyle(Color color, double fontSize, FontWeight fWeight) {
    return TextStyle(
      fontWeight: fWeight,
      color: color,
      fontSize: fontSize,
    );
  }
}

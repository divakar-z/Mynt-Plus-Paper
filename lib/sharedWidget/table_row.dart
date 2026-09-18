import 'package:flutter/material.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';

class RowTable extends StatelessWidget {
  final String title;
  final String value;
  final bool showShadow;

  const RowTable(
      {super.key,
      required this.showShadow,
      required this.title,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: showShadow ? const Color(0xffFAFAFA) : const Color(0xffffffff),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: textStyle(const Color(0xff666666), 12, FontWeight.w600)),
          Text(value, style: textStyle(const Color(0xff000000), 12, FontWeight.w500)),
        ],
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

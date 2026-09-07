import 'package:flutter/material.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';

class CustomOutlineBtn extends StatelessWidget {
  final String label;
  final Function onPress;
  const CustomOutlineBtn(
      {super.key, required this.label, required this.onPress});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(width: 1, color: Color(0xff0037B7)),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(40))),
      ),
      onPressed: () => onPress(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7.0),
        child: Text(
          label,
          style: dysInter(
              textStyle:
                  textStyle(const Color(0xff0037B7), 14, FontWeight.w600)),
        ),
      ),
    );
  }

  TextStyle textStyle(Color color, double fontSize, fWeight) {
    return TextStyle(
      fontWeight: fWeight,
      color: color,
      fontSize: fontSize,
    );
  }
}

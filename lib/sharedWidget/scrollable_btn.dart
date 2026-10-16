import 'package:flutter/material.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';

class ScrollableBtn extends StatefulWidget {
  final List<String> btnName;
  final List<bool> btnActive;

  const ScrollableBtn({
    super.key,
    required this.btnName,
    required this.btnActive,
  });

  @override
  State<ScrollableBtn> createState() => _ScrollableBtnState();
}

class _ScrollableBtnState extends State<ScrollableBtn> {
  int selectBtn = 0;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: widget.btnName.length,
          itemBuilder: (BuildContext context, int index) {
            return OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  width: 1,
                  color: widget.btnActive[index]
                      ? const Color(0xff000000)
                      : const Color(0xff666666),
                ),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(40))),
              ),
              onPressed: () {
                setState(() {
                  for (var i = 0; i < widget.btnName.length; i++) {
                    widget.btnActive[i] = false;
                  }

                  widget.btnActive[index] = true;
                  selectBtn = index;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5.0),
                child: Text(
                  widget.btnName[index],
                  style: dysInter(
                      textStyle: textStyle(
                          widget.btnActive[index]
                              ? const Color(0xff000000)
                              : const Color(0xff666666),
                          14,
                          FontWeight.w600)),
                ),
              ),
            );
          },
          separatorBuilder: (BuildContext context, int index) {
            return const SizedBox(width: 8);
          },
        ));
  }

  TextStyle textStyle(Color color, double fontSize, fWeight) {
    return TextStyle(
      fontWeight: fWeight,
      color: color,
      fontSize: fontSize,
    );
  }
}

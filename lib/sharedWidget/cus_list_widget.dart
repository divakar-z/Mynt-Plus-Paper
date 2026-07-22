import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';

import '../../res/res.dart';
import '../provider/thems.dart';
import '../res/global_state_text.dart';

class ListWidgets extends ConsumerWidget {
  final String text;
  const ListWidgets({super.key, required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeProvider);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
          padding: EdgeInsets.only(top: 2), child: Icon(Icons.circle, size: 7)),
      const SizedBox(width: 8),
      Expanded(
        child: TextWidget.paraText(
            text: text,
            theme: false,
            color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
            fw: 0),
      )
    ]);
  }

  TextStyle textStyle(Color color, double fontSize, fWeight) {
    return dysInter(
        textStyle:
            TextStyle(fontWeight: fWeight, color: color, fontSize: fontSize));
  }
}

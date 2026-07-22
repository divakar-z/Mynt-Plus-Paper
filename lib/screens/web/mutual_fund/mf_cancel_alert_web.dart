// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
// import 'package:mynt_plus/models/fund_model_testing_copy/fund_direct_payment_model.dart';
import 'package:mynt_plus/models/mf_model/mf_order_det_model.dart';
// import 'package:mynt_plus/models/mf_model/mutual_fundmodel.dart';
// import '../../../models/ipo_model/ipo_place_order_model.dart';
import '../../../provider/mf_provider.dart';
import '../../../provider/thems.dart';
import '../../../res/res.dart';
import '../../../res/global_state_text.dart';

class MfCancelAlertWeb extends ConsumerWidget {
  final Data mfcancel;
  final String message; 
  
  const MfCancelAlertWeb({
    super.key, 
    required this.mfcancel, 
    required this.message
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final mfData = ref.watch(mfProvider);
    final isDarkMode = theme.isDarkMode;
    
    // Safe access to scheme name with fallback
    final schemeName = mfcancel.name ?? "this mutual fund";
    final orderNumber = mfcancel.orderId;
    
    return AlertDialog(
      backgroundColor: isDarkMode
          ? const Color.fromARGB(255, 18, 18, 18)
          : colors.colorWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10))
      ),
      scrollable: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      titlePadding: const EdgeInsets.all(0),
      title: Padding(
        padding: const EdgeInsets.all(10),
        child: SvgPicture.asset("assets/icon/ipo_cancel_icon.svg"),
      ),
      content: Column(
        children: [
          Text(
            "Are you sure you want to cancel the ($schemeName) order",
            textAlign: TextAlign.center,
            style: textStyle(
              isDarkMode ? colors.colorWhite : colors.colorBlack,
              16,
              FontWeight.w600
            )
          )
        ],
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // No button
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xffF1F3F8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  )
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: TextWidget.captionText(
                  text: "No",
                  theme: theme.isDarkMode,
                  fw: 1,
                  color: colors.colorGrey,
                )
              ),
            ),
            const SizedBox(width: 16),
            
            // Yes button
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: isDarkMode
                    ? colors.colorbluegrey
                    : colors.colorBlack,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  )
                ),
                onPressed: () async {
                  if (orderNumber != null) {
                    try {
                      await mfData.cancelredumorder(context, orderNumber);
                    } catch (e) {
                      // Handle error silently
                    }
                  }
                  Navigator.pop(context);
                },
                child: mfData.loading == true
                  ? const SizedBox(
                      height: 15,
                      width: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromARGB(99, 48, 48, 48)
                        ),
                        backgroundColor: Color.fromARGB(255, 255, 255, 255),
                      ),
                    )
                  : Text(
                      "Yes",
                      style: textStyle(
                        isDarkMode
                          ? colors.colorBlack
                          : colors.colorWhite,
                        12,
                        FontWeight.w600
                      )
                    )
              ),
            )
          ],
        ),
      ],
    );
  }

  TextStyle textStyle(Color color, double fontSize, FontWeight fWeight) {
    return dysInter(
      textStyle: TextStyle(
        fontWeight: fWeight, 
        color: color, 
        fontSize: fontSize
      )
    );
  }
}



// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/models/bonds_model/bonds_order_book_model.dart';
import 'package:mynt_plus/provider/bonds_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import '../../../../../provider/thems.dart';
import '../../../../../res/res.dart';

class BondCancelAlertWeb extends ConsumerWidget {
  final BondsOrderBookModel bondcancel;
  final bool closeSidebar;
  const BondCancelAlertWeb({super.key, required this.bondcancel, this.closeSidebar = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final isDark = theme.isDarkMode;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Cancel Bond Order",
                    style: dysInter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Divider(
              height: 1,
              color: isDark ? Colors.white12 : Colors.grey[300],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Text(
                'Are you sure you want to cancel "${bondcancel.symbol}"?',
                style: dysInter(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Cancel Button (Red)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleCancelOrder(context, ref, bondcancel, closeSidebar),
                  style: ElevatedButton.styleFrom(
                     backgroundColor: isDark
                         ? MyntColors.errorDark
                         : MyntColors.tertiary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(
                    "Cancel",
                    style: dysInter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: SvgPicture.asset("assets/icon/ipo_cancel_icon.svg"),
    );
  }
}





class _NoButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(155, 40),
        elevation: 0,
        backgroundColor: const Color(0xffF1F3F8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      onPressed: () => Navigator.pop(context),
      child: Text(
        "No",
        style: _textStyle(colors.colorGrey, 12, FontWeight.w500),
      ),
    );
  }
}

class _YesButton extends ConsumerWidget {
  final BondsOrderBookModel bondcancel;
  final BondsProvider bonds;
  final ThemesProvider theme;

  const _YesButton({
    required this.bondcancel,
    required this.bonds,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(155, 40),
        elevation: 0,
        backgroundColor: theme.isDarkMode
            ? colors.colorbluegrey
            : colors.colorBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      onPressed: () => _handleCancelOrder(context, ref, bondcancel, false),
      child: Text(
        "Yes",
        style: _textStyle(
          theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
          12,
          FontWeight.w500,
        ),
      ),
    );
  }

   
}

TextStyle _textStyle(Color color, double fontSize, FontWeight fWeight) {
  return dysInter(
    textStyle: TextStyle(
      fontWeight: fWeight,
      color: color,
      fontSize: fontSize,
    ),
  );
}


_handleCancelOrder(BuildContext context, WidgetRef ref, BondsOrderBookModel bondcancel, bool closeSidebar) async {
    Map<String, dynamic> bondOrderData = {};
    bondOrderData["clientApplicationNumber"] = bondcancel.clientApplicationNumber;
    bondOrderData["orderNumber"] = bondcancel.orderNumber;
    bondOrderData["symbol"] = bondcancel.symbol;
    bondOrderData["investmentValue"] = bondcancel.investmentValue;
    bondOrderData["price"] = bondcancel.bidDetail?.price ?? 0;

    Navigator.pop(context); // Close dialog
    if (closeSidebar) {
      Navigator.pop(context); // Close sidebar only if opened from sidebar
    }

    await ref.read(bondsProvider).cancelBondOrder(context, bondOrderData);
  }

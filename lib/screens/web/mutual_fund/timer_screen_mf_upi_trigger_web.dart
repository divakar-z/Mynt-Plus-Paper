import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/ledger_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/global_state_text.dart';
import '../../../../res/res.dart';
import '../../../../sharedWidget/cust_text_formfield.dart';
import '../../../provider/mf_provider.dart';
import 'create_mandate_dialogue_web.dart';

class TimmerScreenForUPIWeb extends StatefulWidget {
  final dynamic data;
  const TimmerScreenForUPIWeb({super.key, required this.data});

  @override
  State<TimmerScreenForUPIWeb> createState() => _TimmerScreenForUPIWebState();
}

class DropdownItem {
  final String value;
  final String label;
  final bool isEnabled;

  DropdownItem({
    required this.value,
    required this.label,
    this.isEnabled = true,
  });
}

class _TimmerScreenForUPIWebState extends State<TimmerScreenForUPIWeb> {
  @override
  Widget build(BuildContext context) {
    double screenheight = MediaQuery.of(context).size.height;

    return Consumer(builder: (context, WidgetRef ref, _) {
      final theme = ref.read(themeProvider);
      final ledgerdata = ref.watch(ledgerProvider); 
    // final fund = ref.watch(fundProvider);
    final mfOrder = ref.watch(mfProvider);
       

      

       

// Optional: remove duplicates if needed (based on value)
     

      return WillPopScope(
        onWillPop: () async {
          if (ledgerdata.listforpledge == []) {
            ledgerdata.changesegvaldummy('');
          }
          Navigator.pop(context);
          return true;
        },
        child: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 22.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
          left: 16.0,
          right: 16.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mfOrder.mfOrderTpye == "SIP") ...[
            TextWidget.titleText(
                text: "Mandates",
                theme: theme.isDarkMode,
                fw: 1),
            const SizedBox(height: 4),
            if (mfOrder.mandateData!.isNotEmpty) ...[
              DropdownButtonHideUnderline(
                child: DropdownButton2(
                  menuItemStyleData: MenuItemStyleData(
                    customHeights: mfOrder.mandateHeight(),
                  ),
                  buttonStyleData: ButtonStyleData(
                    padding: const EdgeInsets.only(top: 4, left: 16),
                    height: 50,
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: theme.isDarkMode
                          ? colors.darkGrey
                          : const Color(0xffF1F3F8),
                      borderRadius: const BorderRadius.all(Radius.circular(32)),
                    ),
                  ),
                  dropdownStyleData: DropdownStyleData(
                      decoration:
                          BoxDecoration(borderRadius: BorderRadius.circular(4)),
                      offset: const Offset(0, 1)),
                  isExpanded: true,
                  style: TextWidget.textStyle(
                      fontSize: 13,
                      theme: theme.isDarkMode,
                      fw: 0,
                      color: theme.isDarkMode
                          ? colors.colorWhite
                          : const Color(0XFF000000)),
                  hint: TextWidget.subText(
                    text: mfOrder.mandateId ?? "Select a Mandate",
                    theme: theme.isDarkMode,
                    fw: 0,
                    color: const Color(0XFF000000),
                  ),
                  items: mfOrder.mandateDividers(),
                  value: mfOrder
                          .mandateDividers()
                          .any((item) => item.value == mfOrder.mandateId)
                      ? mfOrder.mandateId
                      : null,
                  onChanged: (value) async {
                    // if (value != null) {
                    //   // mfOrder.chngMandate("$value");
                    // }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),

            ElevatedButton(
                onPressed: () async {
                  showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (BuildContext context) {
                        return const CreateMandateDialogue();
                      });
                },
                style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: !theme.isDarkMode
                        ? colors.primaryLight
                        : colors.primaryDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5))),
                child: TextWidget.subText(
                    text: "Create mandate",
                    theme: theme.isDarkMode,
                    fw: 0,
                    color: !theme.isDarkMode
                        ? colors.colorWhite
                        : colors.colorBlack)),
          ],
            if (mfOrder.mfOrderTpye != "SIP") ...[
            const SizedBox(height: 14),

            TextWidget.titleText(
              text: "Payment method",
              theme: theme.isDarkMode,
              fw: 1,
            ),
            const SizedBox(height: 14),
            DropdownButtonHideUnderline(
              child: DropdownButton2<String>(
                dropdownStyleData: DropdownStyleData(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: theme.isDarkMode
                        ? colors.colorWhite
                        : const Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
                buttonStyleData: ButtonStyleData(
                  decoration: BoxDecoration(
                    color: theme.isDarkMode
                        ? const Color(0xffB5C0CF).withOpacity(.15)
                        : const Color(0xffF1F3F8),
                    borderRadius: const BorderRadius.all(Radius.circular(32)),
                  ),
                ),
                menuItemStyleData: MenuItemStyleData(
                  customHeights: mfOrder.getCustItemsHeight(),
                ),
                isExpanded: true,
                style: TextWidget.textStyle(
                  fontSize: 13,
                  theme: theme.isDarkMode,
                  fw: 0,
                  color: const Color.fromARGB(255, 0, 0, 0),
                ),
                hint: TextWidget.subText(
                  text: mfOrder.paymentName,
                  theme: theme.isDarkMode,
                  fw: 0,
                  color: const Color(0XFF000000),
                ),
                items:
                    mfOrder.investloader == false ? mfOrder.addDividers() : [],
                value: mfOrder.paymentName,
                onChanged: (value) async {
                  mfOrder.chngPayName("$value");
                },
              ),
            ),
            const SizedBox(height: 18),
            TextWidget.titleText(
              text: "Bank account ",
              theme: theme.isDarkMode,
              fw: 1,
            ),
            const SizedBox(height: 12),
            DropdownButtonHideUnderline(
              child: DropdownButton2(
                menuItemStyleData: MenuItemStyleData(
                  customHeights: mfOrder.getBankCustItemsHeight(),
                ),
                buttonStyleData: ButtonStyleData(
                  padding: const EdgeInsets.only(top: 10, left: 16),
                  height: 50,
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    color: theme.isDarkMode
                        ? colors.darkGrey
                        : const Color(0xffF1F3F8),
                    borderRadius: const BorderRadius.all(Radius.circular(32)),
                  ),
                ),
                dropdownStyleData: DropdownStyleData(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  offset: const Offset(0, 1),
                ),
                isExpanded: true,
                style: TextWidget.textStyle(
                  fontSize: 13,
                  theme: theme.isDarkMode,
                  fw: 0,
                  color: theme.isDarkMode
                      ? colors.colorWhite
                      : const Color(0XFF000000),
                ),
                hint: TextWidget.subText(
                  text: mfOrder.accNum,
                  theme: theme.isDarkMode,
                  fw: 0,
                  color: theme.isDarkMode
                      ? colors.colorWhite
                      : const Color(0XFF000000),
                ),
                items: mfOrder.addBankDividers(),
                value: mfOrder.accNum,
                onChanged: (value) async {
                  mfOrder.chngBankAcc("$value");
                },
              ),
            ),
            const SizedBox(height: 8),

            // Conditional UPI section
            if (mfOrder.paymentName == "UPI") ...[
              const SizedBox(height: 12),
              TextWidget.titleText(
                text: "UPI ID (Virtual payment address)",
                theme: theme.isDarkMode,
                fw: 1,
              ),
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 44,
                child: CustomTextFormField(
                  textAlign: TextAlign.start,
                  fillColor: theme.isDarkMode
                      ? colors.darkGrey
                      : const Color(0xffF1F3F8),
                  hintText: 'example@upi',
                 hintStyle: TextWidget.textStyle(
                                      fontSize: 14,
                                      theme: theme.isDarkMode,
                                     color: (theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight).withOpacity(0.4),
                                    fw: 0,
                                    ),
                   style: TextWidget.textStyle(
                                    fontSize: 16,
                                    color: theme.isDarkMode
                                        ? colors.textPrimaryDark
                                        : colors.textPrimaryLight,
                                    theme: theme.isDarkMode,
                                    fw: 0,
                                  ),
                  textCtrl: mfOrder.upiId,
                  onChanged: (value) {
                    mfOrder.isValidUpiId(widget.data,'');
                  },
                ),
              ),
              // if (mfOrder.upiError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TextWidget.captionText(
                    text: "${mfOrder.upiError}",
                    theme: theme.isDarkMode,
                    fw: 0,
                    color: colors.kColorRedText,
                  ),
                ),
            ],
            ],
             Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  width: MediaQuery.of(context).size.width,
                  child: ElevatedButton(
                      onPressed: () async {
                        mfOrder.chngPayName("UPI");
                        if (mfOrder.upiError == '' && mfOrder.mfOrderTpye != "SIP" ) {
                           mfOrder.upipaymenttrigger(context,mfOrder.mfPlaceOrderResponces!.orderId,mfOrder.mfPlaceOrderResponces!.orderVal,mfOrder.upiId.text, mfOrder.mfOrderTpye);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16.0),
                        backgroundColor:
                            // mfOrder.invAmtError == null &&
                            //         mfOrder.upiError == null
                            //     ? (theme.isDarkMode
                            //         ? colors.colorbluegrey
                            //         : colors.colorBlack)
                            //     :
                            (theme.isDarkMode
                                ? colors.primaryDark
                                : colors.primaryLight),
                      ),
                      child: mfOrder.investloader == true
                          ? const SizedBox(
                              height: 15,
                              width: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color.fromARGB(99, 48, 48, 48)),
                                backgroundColor:
                                    Color.fromARGB(255, 255, 255, 255),
                              ),
                            )
                          : TextWidget.subText(
                              text: mfOrder.mfOrderTpye == "SIP"
                                  ? "SIP"
                                  : mfOrder.mfOrderTpye,
                              theme: theme.isDarkMode,
                              fw: 1,
                              color: theme.isDarkMode
                                  ? colors.colorBlack
                                  : const Color(0xffffffff))),
                ),
            
          ],
        ),
      )
      );
    });
  }
}

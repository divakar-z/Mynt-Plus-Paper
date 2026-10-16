import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/provider/fund_provider.dart';
import 'package:mynt_plus/provider/profile_all_details_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/global_state_text.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/routes/route_names.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';

class ProfileDetailsBank extends ConsumerStatefulWidget {
  const ProfileDetailsBank({super.key});

  @override
  ConsumerState<ProfileDetailsBank> createState() => _ProfileDetailsBankState();
}

class _ProfileDetailsBankState extends ConsumerState<ProfileDetailsBank> {
  @override
  void initState() {
    ref.read(profileAllDetailsProvider).fetchClientProfileAllDetails();
    super.initState();
  }

  var _formKey = GlobalKey<FormState>();
  var isLoading = false;

  void _submit() {
    final isValid = _formKey.currentState?.validate();
    if (!isValid!) {
      return;
    }
    _formKey.currentState?.save();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, WidgetRef ref, _) {
        final profileprovider = ref.watch(profileAllDetailsProvider);
        final theme = ref.watch(themeProvider);

        final incomeLabels = [
          "Latest 6 months Bank Statement",
          "Latest ITR Copy",
          "Latest 6 months salary slip",
          "DP holding statement as on date",
          "Net worth Certificate",
          "Copy of Form 16 in case of salary income",
        ];

        final bankchip = [
          'Savings Account',
          'Current Account',
        ];

        return Scaffold(
          // backgroundColor:
          //     theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
          // appBar: AppBar(
          //   backgroundColor:
          //       theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
          //   elevation: 0,
          //   leadingWidth: 41,
          //   titleSpacing: 6,
          //   leading: InkWell(
          //     onTap: () {
          //       Navigator.pop(context);
          //     },
          //     child: Padding(
          //       padding: const EdgeInsets.symmetric(horizontal: 9),
          //       child: SvgPicture.asset(assets.backArrow),
          //     ),
          //   ),
          //   title: Text('Profile Details',
          //       style: textStyle(
          //           theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
          //           14,
          //           FontWeight.w600)),
          // ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget.titleText(
                    text: "Bank Accounts Linked",
                    theme: theme.isDarkMode,
                    fw: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextWidget.subText(
                      text: "View bank details and add new banks.",
                      theme: theme.isDarkMode),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  // physics: NeverScrollableScrollPhysics(),
                  itemCount:
                      profileprovider.clientAllDetails.bankData?.length ?? 0,
                  itemBuilder: (BuildContext context, int index) {
                    // var bankData = profileprovider.clientAllDetails!.bankData![index];
                    // print(index);
                    

                    // String firstPart= profileprovider.clientAllDetails.bankData![index].bankAcNo?.substring(0, 2);
                    // String lastPart= profileprovider.clientAllDetails.bankData![index].bankAcNo?.substring(0, 2);
                    // String bankAccDisplay = 'A/C No: ${firstPart} ********* ${lastPart}';
                   
                    return Card(
                      color: theme.isDarkMode
                          ? colors.colorBlack
                          : colors.colorWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                        side: const BorderSide(
                          color: Color.fromARGB(255, 214, 214, 214),
                        ),
                      ),
                      elevation: 0,
                      clipBehavior: Clip.hardEdge,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bank Name and Primary Label
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // CircleAvatar(
                                //   backgroundColor: Colors.white,
                                //   radius: 20,
                                //   backgroundImage: NetworkImage(
                                //     "https://rekycbe.mynt.in/autho/banklogo?bank=${(profileprovider.clientAllDetails!.bankData![index].iFSCCode ?? "").substring(0, 4).toLowerCase()}&type=svg&t=${DateTime.now().millisecondsSinceEpoch}",
                                //   ),
                                //   onBackgroundImageError: (exception, stackTrace) {
                                //     debugPrint("Error loading bank logo: $exception");
                                //     debugPrint("Image URL: https://rekycbe.mynt.in/autho/banklogo?bank=${(profileprovider.clientAllDetails!.bankData![index].iFSCCode ?? "").substring(0, 4).toLowerCase()}&type=svg");
                                //   },
                                // ),

                                // const CircleAvatar(
                                //   backgroundColor: const Color
                                //       .fromARGB(255, 255, 255,
                                //       255), // Placeholder for logo
                                //   child: Icon(Icons.account_balance,
                                //       color: const Color.fromARGB(
                                //           255, 119, 115, 115)),
                                // ),

                                // SizedBox(width: 10),

                                // CircleAvatar(
                                //       minRadius: 24,
                                //       backgroundColor: theme.isDarkMode
                                //           ? colors.colorbluegrey
                                //           : const Color(0xffF1F3F8),
                                //       child: TextWidget.custmText(
                                //           text: profileprovider
                                //                       .clientAllDetails.clientData?.panName !=
                                //                   null
                                //               ? '${profileprovider.clientAllDetails.clientData?.panName![0]}'
                                //               : "",
                                //           textOverflow: TextOverflow.ellipsis,
                                //           theme: theme.isDarkMode,
                                //           fs: 24,
                                //           fw: 1),
                                //     ),
                                // SizedBox(width: 8,),

                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: colors.colorGrey,
                                      radius: 20.5,
                                      child: CircleAvatar(
                                        backgroundColor: colors.colorWhite,
                                        radius: 20,
                                        child: SvgPicture.network(
                                          "https://rekycbe.mynt.in/autho/banklogo?bank=${(profileprovider.clientAllDetails!.bankData![index].iFSCCode ?? "").substring(0, 4).toLowerCase()}&type=svg&t=${DateTime.now().millisecondsSinceEpoch}",
                                          fit: BoxFit.contain,
                                          // width:150,
                                          height: 25,
                                          alignment: Alignment.center,
                                          placeholderBuilder: (BuildContext
                                                  context) =>
                                              const CircularProgressIndicator(),
                                        ),
                                      ),
                                    ),
                                   const SizedBox(
                                      width: 8,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            TextWidget.subText(
                                                text:
                                                    "${profileprovider.clientAllDetails.bankData![index].bankName}",
                                                textOverflow:
                                                    TextOverflow.ellipsis,
                                                theme: theme.isDarkMode,
                                                fw: 1),
                                            const SizedBox(
                                              width: 8,
                                            ),
                                            if ("${profileprovider.clientAllDetails.bankData![index].defaultAc}" ==
                                                "Yes")
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: theme.isDarkMode
                                                      ? colors.colorGrey
                                                      : colors.darkGrey,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: TextWidget.captionText(
                                                    text: 'PRIMARY',
                                                    theme: theme.isDarkMode,
                                                    fw: 1),
                                              ),
                                          ],
                                        ),
                                        // Text("${(profileprovider.clientAllDetails.bankData![index].bankAcNo?.length?? 0) }") ,
                                        TextWidget.paraText(
                                          text:'A/C No: ${profileprovider.formateDataToDisplay(profileprovider.clientAllDetails.bankData![index].bankAcNo??"",2,4)}',
                                              // 'A/C No: ${profileprovider.clientAllDetails.bankData![index].bankAcNo?.substring(0, 2)} ********* ${profileprovider.clientAllDetails!.bankData![index].bankAcNo?.substring(11)}',
                                          theme: theme.isDarkMode,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  width: 8,
                                ),

                                if ("${profileprovider.clientAllDetails!.bankData![index].defaultAc}" ==
                                    "Yes")
                                  InkWell(
                                    onTap: () async {
                                      await ref
                                          .read(fundProvider)
                                          .fetchHstoken(context);
                                      Navigator.pushNamed(
                                          context, Routes.profileWebViewApp,
                                          arguments: "bank");
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          color: theme.isDarkMode
                                              ? colors.colorLightBlue
                                              : colors.colorBlue,
                                          size: 17,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 4),
                            Divider(
                                color: theme.isDarkMode
                                    ? colors.colorbluegrey
                                    : colors.colorDivider),
                            const SizedBox(height: 4),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget.paraText(
                                        text: 'IFSC CODE',
                                        theme: theme.isDarkMode),
                                    SizedBox(height: 8),
                                    TextWidget.subText(
                                        text:
                                            "${profileprovider.clientAllDetails!.bankData![index].iFSCCode}",
                                        theme: theme.isDarkMode,
                                        fw: 1),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget.paraText(
                                        text: 'A/C Type',
                                        theme: theme.isDarkMode),
                                    SizedBox(height: 8),
                                    TextWidget.subText(
                                        text:
                                            '${profileprovider.clientAllDetails!.bankData![index].bANKACCTYPE}',
                                        theme: theme.isDarkMode,
                                        fw: 1),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        profileprovider.clearProfilePop(context, 'bankifsc');

                        await ref.read(fundProvider).fetchHstoken(context);
                        Navigator.pushNamed(context, Routes.profileWebViewApp,
                            arguments: "bank");

                        // showModalBottomSheet(
                        //   context: context,
                        //   isDismissible: false,
                        //   enableDrag: false,
                        //   isScrollControlled: true,
                        //   shape: RoundedRectangleBorder(
                        //     borderRadius: BorderRadius.vertical(
                        //         top: Radius.circular(20.0)),
                        //   ),
                        //   builder: (context) {
                        //     return Consumer(
                        //       builder: (context, watch, _) {
                        //         // final selectedbankchin =
                        //         //     ref.watch(selectedbankchipprovi);
                        //         // final popproprv = ref.watch(profileProvider);

                        //         // final selectedDropdownValue =
                        //         //     ref.watch(dropdownProvider).state;
                        //         // final isActive =
                        //         //     ref.watch(radioButtonProvider).state;
                        //         return Container(
                        //           padding: EdgeInsets.all(16),
                        //           child: Column(
                        //             crossAxisAlignment:
                        //                 CrossAxisAlignment.start,
                        //             children: [
                        //               SizedBox(height: 40),

                        //               const Text(
                        //                 '  Bank change request  ',
                        //                 style: TextStyle(
                        //                     fontSize: 20,
                        //                     fontWeight:
                        //                         FontWeight.bold),
                        //               ),
                        //               SizedBox(height: 20),
                        //               Row(
                        //                 children: [
                        //                   Wrap(
                        //                     spacing:
                        //                         10, // Horizontal space between chips
                        //                     runSpacing:
                        //                         10, // Vertical space between chips
                        //                     children: List.generate(
                        //                         bankchip.length,
                        //                         (index) {
                        //                       return ChoiceChip(
                        //                         label: Text(
                        //                             bankchip[
                        //                                 index]),
                        //                         selected: true,
                        //                         // selectedbankchin ==
                        //                         //     index,
                        //                         onSelected:
                        //                             (isSelected) {
                        //                           // context
                        //                           //     .read(
                        //                           //         selectedbankchipprovi
                        //                           //             .notifier)
                        //                           //     .selectedchipba(
                        //                           //         isSelected
                        //                           //             ? index
                        //                           //             : -1);
                        //                         },
                        //                         selectedColor: Colors
                        //                             .black, // Selected background color
                        //                         backgroundColor: Colors
                        //                                 .grey[
                        //                             300], // Unselected background color
                        //                         labelStyle:
                        //                             TextStyle(
                        //                           color: true
                        //                               // selectedbankchin ==
                        //                               //         index
                        //                               ? Colors.white
                        //                               : Colors
                        //                                   .black,
                        //                         ),
                        //                       );
                        //                     }),
                        //                   ),
                        //                 ],
                        //               ),
                        //               SizedBox(height: 15),
                        //               Text(" Bank A/C No *",
                        //                   style: textStyle(
                        //                       const Color.fromARGB(
                        //                           255, 0, 0, 0),
                        //                       15,
                        //                       FontWeight.w600)),
                        //               TextFormField(
                        //                 controller: profileprovider
                        //                     .newBankAccController,
                        //                 onChanged: (value) {
                        //                   // context
                        //                   //         .read(bankifscprov)
                        //                   //         .state =
                        //                   //     value; // Update state
                        //                 },
                        //                 decoration:
                        //                     const InputDecoration(
                        //                   hintText:
                        //                       'Enter Bank A/C no',
                        //                   border:
                        //                       UnderlineInputBorder(),
                        //                 ),
                        //               ),

                        //               SizedBox(height: 20),
                        //               Text("IFSC Code *",
                        //                   style: textStyle(
                        //                       const Color.fromARGB(
                        //                           255, 0, 0, 0),
                        //                       15,
                        //                       FontWeight.w600)),
                        //               TextFormField(
                        //                 controller: profileprovider
                        //                     .newBankIFSCController,
                        //                 onChanged: (value) {
                        //                   // context
                        //                   //     .read(
                        //                   //         bankaccnoprov.notifier)
                        //                   //     .state = value;

                        //                   // String bankisfctext = context
                        //                   //     .read(newaddprov.notifier)
                        //                   //     .state;

                        //                   profileprovider
                        //                       .ifscapiporov(value);
                        //                 },
                        //                 decoration:
                        //                     const InputDecoration(
                        //                   hintText:
                        //                       'Enter  IFSC  code',
                        //                   border:
                        //                       UnderlineInputBorder(),
                        //                 ),
                        //               ),

                        //               SizedBox(height: 5),
                        //               Text(
                        //                   "${profileprovider.ifsccoderess}"),

                        //               SizedBox(height: 0),
                        //               Text("Proof Type *",
                        //                   style: textStyle(
                        //                       const Color.fromARGB(
                        //                           255, 0, 0, 0),
                        //                       15,
                        //                       FontWeight.w600)),
                        //               Padding(
                        //                 padding: const EdgeInsets
                        //                     .symmetric(
                        //                     vertical: 15.0),
                        //                 child:
                        //                     DropdownButtonFormField<
                        //                         String>(
                        //                   value: profileprovider
                        //                       .selectedBankProofTypeValue,
                        //                   hint: const Text(
                        //                       "Select Bank Proof"),
                        //                   items: [
                        //                     "Passbook",
                        //                     "Latest Statement",
                        //                     "Cancelled Cheque",
                        //                   ].map((String value) {
                        //                     return DropdownMenuItem<
                        //                         String>(
                        //                       value: value,
                        //                       child: Text(value),
                        //                     );
                        //                   }).toList(),
                        //                   onChanged: (newValue) {
                        //                     // Use context.read instead of watch to update the state
                        //                     // context
                        //                     //         .read(dropdownProvider
                        //                     //             .notifier)
                        //                     //         .state =
                        //                     //     newValue; // Correct way to update state
                        //                   },
                        //                   decoration:
                        //                       const InputDecoration(
                        //                     border:
                        //                         UnderlineInputBorder(
                        //                       // Only bottom border
                        //                       borderSide: BorderSide(
                        //                           color: Colors
                        //                               .black), // Customize the color if needed
                        //                     ),
                        //                   ),
                        //                 ),
                        //               ),

                        //               ElevatedButton(
                        //                 child: Text('UPLOAD FILE'),
                        //                 onPressed: () async {
                        //                   var picked =
                        //                       await FilePicker
                        //                           .platform
                        //                           .pickFiles();

                        //                   if (picked != null &&
                        //                       picked.files.first
                        //                               .path !=
                        //                           null) {
                        //                     String filePath = picked
                        //                         .files.first.path!;
                        //                     String fileName = picked
                        //                         .files.first.name;

                        //                     print(
                        //                         "Selected File: $fileName");
                        //                     print(
                        //                         "File Path: $filePath");

                        //                     // Store file path in provider
                        //                     // context
                        //                     //     .read(filePathProvider)
                        //                     //     .state = filePath;
                        //                   }

                        //                   Text("elseee");
                        //                 },
                        //                 style: ElevatedButton
                        //                     .styleFrom(
                        //                   elevation: 0,
                        //                   backgroundColor:
                        //                       colors.colorBlack,
                        //                   padding: const EdgeInsets
                        //                       .symmetric(
                        //                       vertical: 12,
                        //                       horizontal: 12),
                        //                   shape:
                        //                       RoundedRectangleBorder(
                        //                     borderRadius:
                        //                         BorderRadius
                        //                             .circular(25),
                        //                   ),
                        //                 ),
                        //               ),
                        //               Row(
                        //                 children: [
                        //                   Radio<bool>(
                        //                     value: false,
                        //                     groupValue: profileprovider
                        //                         .selectedBankTypeValue,
                        //                     onChanged: (value) {
                        //                       // Toggle the value between true and false
                        //                       // context
                        //                       //         .read(
                        //                       //             radioButtonProvider
                        //                       //                 .notifier)
                        //                       //         .state =
                        //                       //     !isActive; // Toggle state on each click
                        //                     },
                        //                     activeColor:
                        //                         Colors.black,
                        //                   ),
                        //                   const Text(
                        //                       "Set As Primary"),
                        //                 ],
                        //               ),
                        //               const SizedBox(height: 20),
                        //               // Display current selection
                        //               // Text(
                        //               //   "Primary is: ${isActive ? 'True' : 'False'}",
                        //               //   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        //               // ),

                        //               // // Display Selected Dropdown Value
                        //               // Padding(
                        //               //   padding: const EdgeInsets.only(top: 10),
                        //               //   child: Text(
                        //               //     "Selected: $selectedDropdownValue",
                        //               //     style: textStyle(const Color(0xff000000), 16, FontWeight.w500),
                        //               //   ),
                        //               // ),

                        //               const Divider(
                        //                   color: Color(0xffDDDDDD)),
                        //               SizedBox(height: 30),
                        //               Row(
                        //                 children: [
                        //                   Expanded(
                        //                     flex:
                        //                         1, // Takes 50% width
                        //                     child: OutlinedButton(
                        //                       onPressed: () {
                        //                         Navigator.pop(
                        //                             context);
                        //                       },
                        //                       style: OutlinedButton
                        //                           .styleFrom(
                        //                         side: BorderSide(
                        //                             color: colors
                        //                                 .colorBlack), // Border color
                        //                         backgroundColor: Colors
                        //                             .white, // Background color
                        //                         padding:
                        //                             const EdgeInsets
                        //                                 .symmetric(
                        //                                 vertical:
                        //                                     12,
                        //                                 horizontal:
                        //                                     12),
                        //                         shape:
                        //                             RoundedRectangleBorder(
                        //                           borderRadius:
                        //                               BorderRadius
                        //                                   .circular(
                        //                                       25),
                        //                         ),
                        //                       ),
                        //                       child: Text(
                        //                         'Close',
                        //                         style: TextStyle(
                        //                             color: colors
                        //                                 .colorBlack), // Text color
                        //                       ),
                        //                     ),
                        //                   ),

                        //                   SizedBox(
                        //                       width:
                        //                           10), // Adds spacing between buttons
                        //                   Expanded(
                        //                     flex:
                        //                         1, // Takes 50% width
                        //                     child: ElevatedButton(
                        //                       onPressed: () {
                        //                         // String bankisfctext =
                        //                         //     context
                        //                         //         .read(
                        //                         //             bankifscprov)
                        //                         //         .state;
                        //                         // String bankacctext =
                        //                         //     context
                        //                         //         .read(
                        //                         //             bankaccnoprov)
                        //                         //         .state;

                        //                         // String filePath = context
                        //                         //     .read(
                        //                         //         filePathProvider)
                        //                         //     .state;

                        //                         // if (filePath.isEmpty) {
                        //                         //   ScaffoldMessenger.of(
                        //                         //           context)
                        //                         //       .showSnackBar(
                        //                         //     SnackBar(
                        //                         //         content: Text(
                        //                         //             "Please select a file first!")),
                        //                         //   );
                        //                         //   return;
                        //                         // }
                        //                         // String
                        //                         //     finalDropdownValue =
                        //                         //     selectedDropdownValue ??
                        //                         //         'Default Value';
                        //                         // String isActiveString =
                        //                         //     isActive
                        //                         //         ? 'True'
                        //                         //         : 'False';
                        //                         // profileprovider
                        //                         //     .addbankprovui(
                        //                         //   bankisfctext,
                        //                         //   bankacctext,
                        //                         //   filePath,
                        //                         //   finalDropdownValue,
                        //                         //   isActiveString,
                        //                         //   bankchip[
                        //                         //       selectedbankchin],
                        //                         //   (profileprovider.clientAllDetails
                        //                         //       .clientData),
                        //                         //   jsonEncode(profileprovider.clientAllDetails
                        //                         //           .bankData ??
                        //                         //       []),
                        //                         // );
                        //                       },
                        //                       style: ElevatedButton
                        //                           .styleFrom(
                        //                         elevation: 0,
                        //                         backgroundColor:
                        //                             colors
                        //                                 .colorBlack,
                        //                         padding:
                        //                             const EdgeInsets
                        //                                 .symmetric(
                        //                                 vertical:
                        //                                     12,
                        //                                 horizontal:
                        //                                     12),
                        //                         shape:
                        //                             RoundedRectangleBorder(
                        //                           borderRadius:
                        //                               BorderRadius
                        //                                   .circular(
                        //                                       25),
                        //                         ),
                        //                       ),
                        //                       child: Text('Submit'),
                        //                     ),
                        //                   ),
                        //                 ],
                        //               ),
                        //             ],
                        //           ),
                        //         );
                        //       },
                        //     );
                        //   },
                        // );
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: theme.isDarkMode
                            ? colors.colorWhite
                            : colors.colorBlack,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: TextWidget.subText(
                          text: "Add Bank Account",
                          theme: !theme.isDarkMode,
                          fw: 1),

                      // Text("Add Bank Account",
                      //     style: textStyles.btnText),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextWidget.paraText(
                    text:
                        "*As per the regulation, you can have upto 5 bank a/c linked to trading a/c",
                    theme: theme.isDarkMode),
                // Text(
                //   "*As per the regulation, you can have upto 5 bank a/c linked to trading a/c",
                //   style: textStyle(
                //       const Color(0xff666666), 12, FontWeight.w400),
                // ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget changeEmailBottomSheetWidget(
      ProfileProvider profileprovider, ThemesProvider theme) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SizedBox(height: 40),
              const Text(
                ' Email change request ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text("Old email id",
                  style: textStyle(
                      const Color.fromARGB(255, 0, 0, 0), 14, FontWeight.w600)),
              TextFormField(
                initialValue:
                    profileprovider.clientAllDetails.clientData?.cLIENTIDMAIL ??
                        "",
                readOnly: true, // Makes the field non-editable
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              Text("New email id *",
                  style: textStyle(
                      const Color.fromARGB(255, 0, 0, 0), 16, FontWeight.w600)),
              TextFormField(
                controller: profileprovider.newEmailController,
                //  autovalidate: true,
                autovalidateMode: AutovalidateMode.onUserInteraction,

                validator: (input) {
                  return RegExp(
                              r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                          .hasMatch(input ?? "")
                      ? null
                      : "Enter a valid email";
                },
                // onChanged: (value) {
                //       print("value :: $value");
                //        RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value) ? null : "Check your email";
                //     },
                decoration: const InputDecoration(
                  hintText: 'New email id',
                  border: UnderlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              if (profileprovider.responseval == "success send mail") ...[
                Text(
                  "Enter a 4-digit Otp *",
                  style: textStyle(
                    const Color.fromARGB(255, 0, 0, 0),
                    16,
                    FontWeight.w600,
                  ),
                ),
                TextFormField(
                  controller: profileprovider.newEmailOTPController,
                  onChanged: (value) {
                    // ref.read(emailotpver).state =
                    //     value;
                  },
                  decoration: const InputDecoration(
                    hintText: 'Enter Otp',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ],
              SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    flex: 1, // Takes 50% width
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        profileprovider.newEmailController.clear();
                        profileprovider.newEmailOTPController.clear();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: colors.colorBlack), // Border color
                        backgroundColor: Colors.white, // Background color
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(color: colors.colorBlack),
                        // Text color
                      ),
                    ),
                  ),

                  SizedBox(width: 10), // Adds spacing between buttons
                  if (profileprovider.responseval != "success send mail")
                    Expanded(
                      flex: 1, // Takes 50% width
                      child: ElevatedButton(
                        onPressed: () {
                          String enteredText = "";
                          // context
                          //   .read(textFieldProvider)
                          //   .state;

                          profileprovider.emaileotpfun(
                            enteredText,
                            (profileprovider
                                    .clientAllDetails.clientData?.cLIENTIDMAIL)
                                .toString(),
                            (profileprovider
                                    .clientAllDetails.clientData?.cLIENTNAME)
                                .toString(),
                            (profileprovider
                                    .clientAllDetails.clientData?.cLIENTDPCODE)
                                .toString(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: colors.colorBlack,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text('Submit'),
                      ),
                    ),

                  if (profileprovider.responseval == "success send mail")
                    Expanded(
                      flex: 1, // Takes 50% width
                      child: ElevatedButton(
                        onPressed: () {
                          // String emilotetext = context
                          //     .read(emailotpver)
                          //     .state;
                          // String newmailtext = context
                          //     .read(textFieldProvider)
                          //     .state;

                          // profileprovider.emailotpres(
                          //   emilotetext,
                          //   newmailtext,
                          // );
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: colors.colorBlack,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text('Submit otp'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget changeMobileBottomSheetWidget(
      ProfileProvider profileprovider, ThemesProvider theme) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text(
            //   ' Mobile change request ',
            //   style: TextStyle(
            //       fontSize: 20,
            //       fontWeight: FontWeight.bold),
            // ),
            const SizedBox(height: 40),
            const Text(
              ' Mobile change request ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 30),

            Text("Present Number",
                style: textStyle(
                    const Color.fromARGB(255, 0, 0, 0), 17, FontWeight.w600)),
            TextFormField(
              initialValue:
                  profileprovider.clientAllDetails.clientData?.mOBILENO ?? "",
              readOnly: true, // Makes the field non-editable
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Text("New Mobile number  *",
                style: textStyle(
                    const Color.fromARGB(255, 0, 0, 0), 17, FontWeight.w600)),
            TextFormField(
              controller: profileprovider.newMobController,
              onChanged: (value) {
                // ref.read(newmobilno).state =
                //     value; // Update state
              },
              decoration: const InputDecoration(
                hintText: 'New Mobile no',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (profileprovider.mobileotp == "otp sent") ...[
              Text(
                "Enter a 4-digit Otp *",
                style: textStyle(
                  const Color.fromARGB(255, 0, 0, 0),
                  15,
                  FontWeight.w600,
                ),
              ),
              TextFormField(
                controller: profileprovider.newMobOTPController,
                onChanged: (value) {
                  // ref.read(mobilotpval).state =
                  //     value; // Update state
                },
                decoration: const InputDecoration(
                  hintText: 'Enter Otp',
                  border: UnderlineInputBorder(),
                ),
              ),
            ],
            SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  flex: 1, // Takes 50% width
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side:
                          BorderSide(color: colors.colorBlack), // Border color
                      backgroundColor: Colors.white, // Background color
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(color: colors.colorBlack), // Text color
                    ),
                  ),
                ),

                SizedBox(width: 10), // Adds spacing between buttons

                if (profileprovider.mobileotp != "otp sent")
                  Expanded(
                    flex: 1, // Takes 50% width
                    child: ElevatedButton(
                      onPressed: () {
                        String newmobilenotext =
                            profileprovider.newMobOTPController.text;

                        profileprovider.mobileotpfun(
                            newmobilenotext,
                            (profileprovider
                                    .clientAllDetails.clientData?.cLIENTIDMAIL)
                                .toString(),
                            (profileprovider
                                    .clientAllDetails.clientData?.mOBILENO)
                                .toString(),
                            (profileprovider.clientAllDetails.clientData));
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: colors.colorBlack,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text('Submit'),
                    ),
                  ),

                if (profileprovider.mobileotp == "otp sent")
                  Expanded(
                    flex: 1, // Takes 50% width
                    child: ElevatedButton(
                      onPressed: () {
                        String newmobilenotext =
                            profileprovider.newMobController.text;
                        String mobileotptext =
                            profileprovider.newMobOTPController.text;
                        profileprovider.mobileotpverify(
                          newmobilenotext,
                          mobileotptext,
                          (profileprovider.clientAllDetails.clientData),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: colors.colorBlack,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text('Submit otp'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget changeAddressBottomSheetWidget(
      ProfileProvider profileprovider, ThemesProvider theme) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 40),
            const Text(
              ' Address change request ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 30),
            Text("Old Address",
                style: textStyle(
                    const Color.fromARGB(255, 0, 0, 0), 15, FontWeight.w600)),
            SizedBox(height: 10),
            Text(
              "${profileprovider.clientAllDetails.clientData?.cLRESIADD1}, ${profileprovider.clientAllDetails.clientData?.cLRESIADD2}, ${profileprovider.clientAllDetails.clientData?.cLRESIADD3}" ??
                  "",
              style: const TextStyle(
                color: Color(0xff666666),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
            const Divider(color: Color(0xffDDDDDD)),
            SizedBox(height: 20),
            Text(
              'New Address *',
              style: textStyle(
                theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                16,
                FontWeight.w600,
              ),
            ),
            TextFormField(
              controller: profileprovider.newAddressController,
              onChanged: (value) {
                // ref.read(newaddprov).state =
                //     value; // Update state
              },
              decoration: const InputDecoration(
                hintText: 'New Address ',
                border: UnderlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 1, // Takes 50% width
                  child: Column(
                    // Added a Column to wrap both Text and TextFormField
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pincode *',
                        style: textStyle(
                          const Color.fromARGB(255, 0, 0, 0),
                          16,
                          FontWeight.w600,
                        ), // Text color
                      ),
                      TextFormField(
                        controller: profileprovider.newAddressPincodeController,
                        onChanged: (value) {
                          // context
                          //         .read(pincodeprov)
                          //         .state =
                          //     value; // Update state
                        },
                        decoration: const InputDecoration(
                          hintText: 'Pincode',
                          border: UnderlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 10), // Adds spacing between buttons

                Expanded(
                  flex: 1, // Takes 50% width
                  child: Column(
                    // Added a Column to wrap both Text and TextFormField
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'District *',
                        style: textStyle(
                          const Color.fromARGB(255, 0, 0, 0),
                          16,
                          FontWeight.w600,
                        ), // Text color
                      ),
                      TextFormField(
                        controller:
                            profileprovider.newAddressDistrictController,
                        onChanged: (value) {
                          // context
                          //         .read(districtprov)
                          //         .state =
                          //     value; // Update state
                        },
                        decoration: const InputDecoration(
                          hintText: 'District ',
                          border: UnderlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 10),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 1, // Takes 50% width
                  child: Column(
                    // Added a Column to wrap both Text and TextFormField
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'State * ',
                        style: textStyle(
                          const Color.fromARGB(255, 0, 0, 0),
                          16,
                          FontWeight.w600,
                        ), // Text color
                      ),
                      TextFormField(
                        controller: profileprovider.newAddressStateController,
                        onChanged: (value) {
                          // context
                          //         .read(stateprov)
                          //         .state =
                          //     value; // Update state
                        },
                        decoration: const InputDecoration(
                          hintText: 'State ',
                          border: UnderlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 10), // Adds spacing between buttons

                Expanded(
                  flex: 1, // Takes 50% width
                  child: Column(
                    // Added a Column to wrap both Text and TextFormField
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Country *',
                        style: textStyle(
                          const Color.fromARGB(255, 0, 0, 0),
                          16,
                          FontWeight.w600,
                        ), // Text color
                      ),
                      TextFormField(
                        controller: profileprovider.newAddressCountryController,
                        onChanged: (value) {
                          // context
                          //         .read(countryprov)
                          //         .state =
                          //     value; // Update state
                        },
                        decoration: const InputDecoration(
                          hintText: 'Country ',
                          border: UnderlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 10),
              ],
            ),
            SizedBox(height: 20),
            Text(
              "Proof Type *",
              style: textStyle(
                theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                16,
                FontWeight.w600,
              ),
            ),
            TextFormField(
              controller: profileprovider.newAddressProofTypeController,
              onChanged: (value) {
                // ref.read(proofprov).state =
                //     value; // Update state
              },
              decoration: const InputDecoration(
                hintText: 'Proof Type',
                border: UnderlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('UPLOAD FILE'),
              onPressed: () async {
                var picked = await FilePicker.platform.pickFiles();

                if (picked != null && picked.files.first.path != null) {
                  String filePath = picked.files.first.path!;
                  String fileName = picked.files.first.name;


                  // Store file path in provider
                  // context
                  //     .read(filePathProvider)
                  //     .state = filePath;
                }

                Text("elseee");
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: colors.colorBlack,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            SizedBox(height: 50),
            // SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  flex: 1, // Takes 50% width
                  child: OutlinedButton(
                    onPressed: () {
                      profileprovider.clearProfilePop(context, 'manbank');
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side:
                          BorderSide(color: colors.colorBlack), // Border color
                      backgroundColor: Colors.white, // Background color
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(color: colors.colorBlack),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 1, // Takes 50% width
                  child: ElevatedButton(
                    onPressed: () {
                      // String newaddresswtext =
                      //     context
                      //         .read(newaddprov)
                      //         .state;
                      // String pincodetext = context
                      //     .read(pincodeprov)
                      //     .state;
                      // String districttext = context
                      //     .read(districtprov)
                      //     .state;
                      // String statetext = context
                      //     .read(stateprov)
                      //     .state;
                      // String countrytet = context
                      //     .read(countryprov)
                      //     .state;
                      // String prooftext = context
                      //     .read(proofprov)
                      //     .state;
                      // String filePath = context
                      //     .read(filePathProvider)
                      //     .state;

                      // if (filePath.isEmpty) {
                      //   ScaffoldMessenger.of(
                      //           context)
                      //       .showSnackBar(
                      //     SnackBar(
                      //         content: Text(
                      //             "Please select a file first!")),
                      //   );
                      //   return;
                      // }

                      // profileprovider
                      //     .addmanbankverf(
                      //   newaddresswtext,
                      //   pincodetext,
                      //   districttext,
                      //   statetext,
                      //   countrytet,
                      //   prooftext,
                      //   (profileprovider.clientAllDetails
                      //       .clientData),
                      //   filePath,
                      // );
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: colors.colorBlack,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Text valueText(String text) {
    return Text(text,
        style: textStyle(const Color(0xff000000), 16, FontWeight.w500));
  }

  Text headerText(String text, ThemesProvider theme) {
    return Text(text,
        style: textStyle(
            theme.isDarkMode ? colors.kColorGreyDarkTheme : colors.colorGrey,
            11,
            FontWeight.w600));
  }

  TextStyle textStyle(Color color, double fontSize, fWeight) {
    return dysInter(
      textStyle: TextStyle(
        fontWeight: fWeight,
        color: color,
        fontSize: fontSize,
      ),
    );
  }

//  Widget buildBottomSheetSection(ThemesProvider theme) {
//                            return  showModalBottomSheet(
//                                             isScrollControlled: true,
//                                             useSafeArea: true,
//                                             isDismissible: true,
//                                             shape: const RoundedRectangleBorder(
//                                                 borderRadius: BorderRadius.vertical(
//                                                     top: Radius.circular(16))),
//                                             context: context,
//                                             builder: (context) => Container(
//                                               padding: EdgeInsets.only(
//                                                 bottom: MediaQuery.of(context)
//                                                     .viewInsets
//                                                     .bottom,
//                                               ),
//                                               child: BottomSheetScreen(),
//                                             ),
//                                           );
//       }
}

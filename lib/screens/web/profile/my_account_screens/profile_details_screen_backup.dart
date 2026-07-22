import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/provider/profile_all_details_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
// import 'package:mynt_plus/screens/profile_screen/my_account_screens/bottomsheet_screen.dart';
import 'package:mynt_plus/res/res.dart';

class ProfileInfoDetails extends ConsumerStatefulWidget {
  const ProfileInfoDetails({super.key});

  @override
  ConsumerState<ProfileInfoDetails> createState() => _ProfileInfoDetailsState();
}

class _ProfileInfoDetailsState extends ConsumerState<ProfileInfoDetails> {

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
          backgroundColor:
              theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
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
          body: Container(
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7.0, vertical: 12),
              children: [
                // Column(
                //   crossAxisAlignment: CrossAxisAlignment.start,
                //   children: [
                //     // Display the selected chip value

                //     // SizedBox(height: 20),
                //     // Use a SingleChildScrollView to wrap the chips
                //     SingleChildScrollView(
                //       scrollDirection: Axis.horizontal,
                //       child: Row(
                //         children: profileprovider.allDetailsSectionList
                //             .asMap()
                //             .entries
                //             .map((eachSection) {
                //           // final index = eachSection.key;
                //           final label = eachSection.value;
                //           return Padding(
                //             padding: const EdgeInsets.only(right: 8.0),
                //             child: ChoiceChip(
                //               label: Text(
                //                 label,
                //                 style: TextStyle(
                //                     color: theme.isDarkMode
                //                         ? Color(profileprovider
                //                                     .allDetailsSelectedSection ==
                //                                 eachSection.value
                //                             ? 0xff000000
                //                             : 0xffffffff)
                //                         : Color(profileprovider
                //                                     .allDetailsSelectedSection ==
                //                                 eachSection.value
                //                             ? 0xffffffff
                //                             : 0xff000000)

                //                     // theme.isDarkMode?
                //                     // profileprovider.allDetailsSelectedSection == eachSection.value
                //                     //     ? colors.colorbluegrey : colors.colorBlack
                //                     //     :  profileprovider.allDetailsSelectedSection == eachSection.value
                //                     //     ?  colors.colorbluegrey : colors.colorBlack
                //                     ),
                //               ),
                //               selected:
                //                   profileprovider.allDetailsSelectedSection ==
                //                       eachSection.value,
                //               selectedColor: theme.isDarkMode
                //                   ? profileprovider.allDetailsSelectedSection ==
                //                           eachSection.value
                //                       ? colors.colorbluegrey
                //                       : const Color.fromARGB(255, 62, 63,
                //                           63) //.withOpacity(.15) //const Color(0xffB5C0CF).withOpacity(.15)
                //                   : profileprovider.allDetailsSelectedSection ==
                //                           eachSection.value
                //                       ? const Color.fromARGB(255, 0, 0, 0)
                //                       : const Color(0xffF1F3F8),
                //               backgroundColor: theme.isDarkMode
                //                   ? profileprovider.allDetailsSelectedSection ==
                //                           eachSection.value
                //                       ? colors.colorbluegrey
                //                       : const Color.fromARGB(255, 62, 63,
                //                           63) //.withOpacity(.15) //const Color(0xffB5C0CF).withOpacity(.15)
                //                   : profileprovider.allDetailsSelectedSection ==
                //                           eachSection.value
                //                       ? const Color.fromARGB(255, 0, 0, 0)
                //                       : const Color(0xffF1F3F8),
                //               onSelected: (selectedTab) {
                //                 setState(() {
                //                   profileprovider.setAllDetailsSelectedSection =
                //                       eachSection.value;
                //                 },);

                //                 // print("Called");
                //               },
                //             ),
                //           );
                //         }).toList(),
                //       ),
                //     ),
                //   ],
                // ),
                const Divider(color: Color(0xffDDDDDD)),

                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration:  BoxDecoration(
                          borderRadius:BorderRadius.circular(5),
                                  // shape:BoxShape.rectangle,
                                  border:Border.all(
                                    color: theme.isDarkMode
                                              ? colors
                                                  .colorWhite
                                              : colors
                                                  .colorBlack,
                                          width: 1),   
                                          // Border(
                                          //                       top: BorderSide(
                                          //                           color: theme.isDarkMode
                                          //                               ? colors
                                          //                                   .colorLightBlue
                                          //                               : colors
                                          //                                   .colorBlue,
                                          //                           width: 2)),
                                  color: theme.isDarkMode
                                      ? const Color(0xffB5C0CF).withOpacity(.15)
                                      : const Color(0xffF1F3F8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // SizedBox(height: 10,),
                                headerText("NAME AS PER PAN", theme),
                                // const SizedBox(height: 5),
                                 SizedBox(height: 2,),
                                 Text(
                                    profileprovider
                                          .clientAllDetails.clientData?.panName ??
                                      "",
                                  style: TextStyle(
                                    color: theme.isDarkMode
                                        ? colors.colorWhite
                                        : colors.colorBlack,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                  SizedBox(height: 10,),


                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        children: [
                                          headerText("PHONE NUMBER", theme),
                                           SizedBox(height: 2,),
                                            Text(
                                                  profileprovider
                                                        .clientAllDetails.clientData?.mOBILENO ??
                                                    "",
                                                style: TextStyle(
                                                  color: theme.isDarkMode
                                                      ? colors.colorWhite
                                                      : colors.colorBlack,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                        ],
                                      ),
                                      const Icon(
                                          Icons.edit,
                                          color: Color(0xFF0037B7),
                                          size: 17,
                                          // Blue color for the icon
                                        ),
                                     
                                    ],
                                  ),
                                    const SizedBox(height: 10,),

                                    Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                              headerText("EMAIL ADDRESS", theme),
                                                const SizedBox(height: 2,),
                                                Text(
                                                      profileprovider
                                                          .clientAllDetails.clientData?.cLIENTIDMAIL ??
                                                      "",
                                                    style: TextStyle(
                                                      color: theme.isDarkMode
                                                          ? colors.colorWhite
                                                          : colors.colorBlack,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                        ],
                                      ),
                                      const Icon(
                                          Icons.edit,
                                          color: Color(0xFF0037B7),
                                          size: 17,
                                          // Blue color for the icon
                                        ),
                                     
                                    ],
                                  ),
                              ],
                            ),
                          ),

                         Padding(
                           padding: const EdgeInsets.symmetric(horizontal: 16.0,vertical: 8.0),
                           child: Row(
                            // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            // spacing:50,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                
                                children: [
                                 headerText("BIRTH DATE", theme),
                                Text(
                                      profileprovider
                                                  .clientAllDetails.clientData?.bIRTHDATE ??
                                              "",
                                    style: TextStyle(
                                      color: theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                           
                                ],
                              ),
                           
                              Column(
                                children: [
                                  headerText("PAN NUMBER", theme),
                                  Text(
                                      "*******${profileprovider.clientAllDetails.clientData?.pANNO?.substring(7) ?? ''}",
                                    style: TextStyle(
                                      color: theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                           
                           
                                ],
                              ),

                            // Column(
                            //     children: [
                            //       headerText("MARITAL STATUS", theme),
                            //       Text(
                            //           profileprovider
                            //             .clientAllDetails.clientData?.maritalStatus ??
                            //         "",
                            //         style: TextStyle(
                            //           color: theme.isDarkMode
                            //               ? colors.colorWhite
                            //               : colors.colorBlack,
                            //           fontSize: 15,
                            //           fontWeight: FontWeight.w500,
                            //         ),
                            //       ),
                           
                           
                            //     ],
                            //   ),

                              
                           
                            ],
                            ),
                         ),

                         Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0,vertical: 8.0),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Expanded(
                                 child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                    //  const SizedBox(height: 10),
                                       headerText("ADDRESS", theme),                        
                                    Text(
                                      "${profileprovider.clientAllDetails.clientData?.cLRESIADD1}, ${profileprovider.clientAllDetails.clientData?.cLRESIADD2}, ${profileprovider.clientAllDetails.clientData?.cLRESIADD3}",
                                      overflow:TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),

                                   
                                   ],
                                 ),
                               ),

                                 const Icon(
                                    Icons.edit,
                                    color: Color(0xFF0037B7),
                                    size: 17,
                                    // Blue color for the icon
                                  ),

                             ],
                           ),
                         ),
                         
                        // TextFormField(
                        //   initialValue:
                        //       "${profileprovider.clientAllDetails.clientData?.cLRESIADD1}, ${profileprovider.clientAllDetails.clientData?.cLRESIADD2}, ${profileprovider.clientAllDetails.clientData?.cLRESIADD3}" ??
                        //           "",
                        //   readOnly: true,
                        //   decoration: InputDecoration(
                        //     focusedBorder:const UnderlineInputBorder(
                        //             borderSide:  BorderSide(width:1.5,color: Color.fromARGB(255, 0, 0, 0),),),
                        //      isDense:true,
                           
                        //     // border: UnderlineInputBorder(),
                        //     suffix: ElevatedButton(
                        //       onPressed: () async {
                        //         //  profileprovider.clearProfilePop(
                        //         //           context, 'email');
                        //         //       profileprovider.clearProfilePop(
                        //         //           context, 'emailotp');

                        //         showModalBottomSheet(
                        //           context: context,
                        //           isDismissible: false,
                        //           enableDrag: false,
                        //           isScrollControlled: true,
                        //           shape: const RoundedRectangleBorder(
                        //               //   borderRadius: BorderRadius.vertical(
                        //               //       top: Radius.circular(20.0),
                        //               //       ),
                        //               ),
                        //           builder: (context) {
                        //             return changeAddressBottomSheetWidget(
                        //                 profileprovider, theme);
                        //           },
                        //         );
                        //       },
                        //       style: ElevatedButton.styleFrom(
                        //         elevation: 0,
                        //         padding: EdgeInsets.symmetric(
                        //             horizontal: 0,
                        //             vertical: 0), // maximumSize:Size.square(2),
                        //         backgroundColor: theme.isDarkMode
                        //             ? colors.colorbluegrey
                        //             : colors.colorBlack,
                        //         shape: RoundedRectangleBorder(
                        //           borderRadius: BorderRadius.circular(5),
                        //         ),
                        //         minimumSize: const Size(55, 25),
                        //       ),
                        //       child: Text("EDIT",
                        //           style: textStyle(
                        //               !theme.isDarkMode
                        //                   ? colors.colorWhite
                        //                   : colors.colorBlack,
                        //               12,
                        //               FontWeight.w500)),
                        //     ),
                        //   ),
                        //   style: TextStyle(
                        //     color: theme.isDarkMode
                        //         ? colors.colorWhite
                        //         : colors.colorBlack,
                        //     fontSize: 15,
                        //     fontWeight: FontWeight.w500,
                        //   ),
                        // ),












      // ===================================================================================
                   const SizedBox(height: 105),
                  Padding(
                    padding:
                        const EdgeInsets.all(8.0), // Padding inside the card
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(
                        //   "Personal Details",
                        //   style: textStyle(
                        //     theme.isDarkMode
                        //         ? colors.colorWhite
                        //         : colors.colorBlack,
                        //     16,
                        //     FontWeight.w600,
                        //   ),
                        // ),
                        // Padding(
                        //   padding: const EdgeInsets.only(top: 8),
                        //   child: Text(
                        //     "We use these details for all communication related to your account.",
                        //     style: textStyle(
                        //         theme.isDarkMode
                        //             ? colors.colorWhite
                        //             : colors.colorBlack,
                        //         14,
                        //         FontWeight.w400),
                        //   ),
                        // ),
                        // const Divider(color: Color(0xffDDDDDD)),
                        // const SizedBox(height: 10),
                       

                        // Text(
                        //   profileprovider
                        //           .clientAllDetails.clientData?.panName ??
                        //       "",
                        //   style: TextStyle(
                        //     color: theme.isDarkMode
                        //         ? colors.colorWhite
                        //         : colors.colorBlack,
                        //     fontSize: 15,
                        //     fontWeight: FontWeight.w500,
                        //   ),
                        // ),

                        // Text("123555545678${profilestaqtres.emailstatprofile?.emailSession ?? "undd"}"),

                        // Text("123555545678${profilestaqtres.emailstatprofile?.emailStatus ?? ""}"),
                        const Divider(color: Color(0xffDDDDDD)),
                        const SizedBox(height: 16),
                        headerText("BIRTH DATE", theme),
                        // const SizedBox(height: 5),
                        TextFormField(
                          initialValue: profileprovider
                                  .clientAllDetails.clientData?.bIRTHDATE ??
                              "",
                          readOnly: true, // Makes the field non-editable
                          decoration: const InputDecoration(
                              enabled:false,
                              // border: UnderlineInputBorder(),
                              ),
                          style: TextStyle(
                            color: theme.isDarkMode
                                ? colors.colorWhite
                                : colors.colorBlack,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Text(
                        //   profileprovider
                        //           .clientAllDetails.clientData?.bIRTHDATE ??
                        //       "",
                        //   style: TextStyle(
                        //     color: theme.isDarkMode
                        //         ? colors.colorWhite
                        //         : colors.colorBlack,
                        //     fontSize: 15,
                        //     fontWeight: FontWeight.w500,
                        //   ),
                        // ),
                        const Divider(color: Color(0xffDDDDDD)),
                        const SizedBox(height: 16),
                        headerText("MARITAL STATUS", theme),
                        // const SizedBox(height: 5),
                        TextFormField(
                          initialValue: profileprovider
                                  .clientAllDetails.clientData?.maritalStatus ??
                              "",
                          readOnly: true, // Makes the field non-editable
                          decoration: const InputDecoration(
                              enabled:false,
                              // border: UnderlineInputBorder(),
                              ),
                          style: TextStyle(
                            color: theme.isDarkMode
                                ? colors.colorWhite
                                : colors.colorBlack,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        // Text(
                        //   profileprovider
                        //           .clientAllDetails.clientData?.maritalStatus ??
                        //       "",
                        //   style: TextStyle(
                        //     color: theme.isDarkMode
                        //         ? colors.colorWhite
                        //         : colors.colorBlack,
                        //     fontSize: 15,
                        //     fontWeight: FontWeight.w500,
                        //   ),
                        // ),
                        const Divider(color: Color(0xffDDDDDD)),
                        const SizedBox(height: 16),
                        headerText("PAN NUMBER", theme),
                        // const SizedBox(height: 5),
                        TextFormField(
                          initialValue:
                              "*******${profileprovider.clientAllDetails.clientData?.pANNO?.substring(7) ?? ''}",
                          readOnly: true, // Makes the field non-editable
                          decoration: const InputDecoration(
                              enabled:false,
                              // border: UnderlineInputBorder(),
                              ),
                          style: TextStyle(
                            color: theme.isDarkMode
                                ? colors.colorWhite
                                : colors.colorBlack,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Divider(color: Color(0xffDDDDDD)),
                        const SizedBox(height: 16),
                       
                             headerText("EMAIL ADDRESS", theme),
                            TextFormField(
                          initialValue: profileprovider
                                  .clientAllDetails.clientData?.cLIENTIDMAIL ??
                              "",
                          readOnly: true,
                          decoration: InputDecoration(
                            // enabled:false,
                            focusedBorder:const UnderlineInputBorder(
                                    borderSide:  BorderSide(width:1.5,color: Color.fromARGB(255, 0, 0, 0),),),
                            isDense:true,
                            // border: UnderlineInputBorder(),
                            suffix: ElevatedButton(
                              onPressed: () async {
                                profileprovider.clearProfilePop(
                                    context, 'email');
                                profileprovider.clearProfilePop(
                                    context, 'emailotp');

                                showModalBottomSheet(
                                  context: context,
                                  isDismissible: false,
                                  enableDrag: false,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                      //   borderRadius: BorderRadius.vertical(
                                      //       top: Radius.circular(20.0),
                                      //       ),
                                      ),
                                  builder: (context) {
                                    return changeEmailBottomSheetWidget(
                                        profileprovider, theme);
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 0), // maximumSize:Size.square(2),
                                backgroundColor: theme.isDarkMode
                                    ? colors.colorbluegrey
                                    : colors.colorBlack,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                minimumSize: const Size(55, 25),
                              ),
                              child: Text("EDIT",
                                  style: textStyle(
                                      !theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      12,
                                      FontWeight.w500)),
                            ),
                          ),
                          style: TextStyle(
                            color: theme.isDarkMode
                                ? colors.colorWhite
                                : colors.colorBlack,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),




                        const Divider(color: Color(0xffDDDDDD)),
                        const SizedBox(height: 16),
                        headerText("PHONE NUMBER", theme),
                        // const SizedBox(height: 5),
                        TextFormField(
                          initialValue: profileprovider
                                  .clientAllDetails.clientData?.mOBILENO ??
                              "",
                          readOnly: true,
                          decoration: InputDecoration(
                            focusedBorder:const UnderlineInputBorder(
                                    borderSide:  BorderSide(width:1.5,color: Color.fromARGB(255, 0, 0, 0),),),
                             isDense:true,
                            // border: UnderlineInputBorder(),
                            suffix: ElevatedButton(
                              onPressed: () async {
                                //  profileprovider.clearProfilePop(
                                //           context, 'email');
                                //       profileprovider.clearProfilePop(
                                //           context, 'emailotp');

                                showModalBottomSheet(
                                  context: context,
                                  isDismissible: false,
                                  enableDrag: false,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                      //   borderRadius: BorderRadius.vertical(
                                      //       top: Radius.circular(20.0),
                                      //       ),
                                      ),
                                  builder: (context) {
                                    return changeMobileBottomSheetWidget(
                                        profileprovider, theme);
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 0), // maximumSize:Size.square(2),
                                backgroundColor: theme.isDarkMode
                                    ? colors.colorbluegrey
                                    : colors.colorBlack,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                minimumSize: const Size(55, 25),
                              ),
                              child: Text("EDIT",
                                  style: textStyle(
                                      !theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      12,
                                      FontWeight.w500)),
                            ),
                          ),
                          style: TextStyle(
                            color: theme.isDarkMode
                                ? colors.colorWhite
                                : colors.colorBlack,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        // Row(
                        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        //   children: [
                        //     Text(
                        //       profileprovider
                        //               .clientAllDetails.clientData?.mOBILENO ??
                        //           "",
                        //       style: TextStyle(
                        //         color: theme.isDarkMode
                        //             ? colors.colorWhite
                        //             : colors.colorBlack,
                        //         fontSize: 15,
                        //         fontWeight: FontWeight.w500,
                        //       ),
                        //     ),
                        //     InkWell(
                        //       onTap: () {
                        //         profileprovider.clearProfilePop(
                        //             context, 'mobile');
                        //         profileprovider.clearProfilePop(
                        //             context, 'mobilotp');

                        //         showModalBottomSheet(
                        //           context: context,
                        //           isDismissible: false,
                        //           enableDrag: false,
                        //           isScrollControlled: true,
                        //           shape: const RoundedRectangleBorder(
                        //             borderRadius: BorderRadius.vertical(
                        //                 top: Radius.circular(20.0)),
                        //           ),
                        //           builder: (context) {
                        //             return changeMobileBottomSheetWidget(
                        //                 profileprovider, theme);
                        //           },
                        //         );
                        //       },
                        //       child: const Row(
                        //         mainAxisSize: MainAxisSize
                        //             .min, // Ensures that the Row doesn't take up full width
                        //         children: [
                        //           Icon(
                        //             Icons.edit,
                        //             color: Color(0xFF0037B7),
                        //             size: 17,
                        //             // Blue color for the icon
                        //           ),
                        //           Text(
                        //             'Edit',
                        //             style: TextStyle(
                        //               color: Color(
                        //                   0xFF0037B7), // Blue color for the text
                        //               fontSize:
                        //                   15, // You can adjust the size as needed
                        //               fontWeight: FontWeight.w500,
                        //             ),
                        //           ),
                        //         ],
                        //       ),
                        //     )
                        //   ],
                        // ),
                        const Divider(color: Color(0xffDDDDDD)),
                        const SizedBox(height: 16),
                        headerText("ADDRESS", theme),
                        // const SizedBox(height: 5),

                        TextFormField(
                          initialValue:
                              "${profileprovider.clientAllDetails.clientData?.cLRESIADD1}, ${profileprovider.clientAllDetails.clientData?.cLRESIADD2}, ${profileprovider.clientAllDetails.clientData?.cLRESIADD3}" ??
                                  "",
                          readOnly: true,
                          decoration: InputDecoration(
                            focusedBorder:const UnderlineInputBorder(
                                    borderSide:  BorderSide(width:1.5,color: Color.fromARGB(255, 0, 0, 0),),),
                             isDense:true,
                           
                            // border: UnderlineInputBorder(),
                            suffix: ElevatedButton(
                              onPressed: () async {
                                //  profileprovider.clearProfilePop(
                                //           context, 'email');
                                //       profileprovider.clearProfilePop(
                                //           context, 'emailotp');

                                showModalBottomSheet(
                                  context: context,
                                  isDismissible: false,
                                  enableDrag: false,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                      //   borderRadius: BorderRadius.vertical(
                                      //       top: Radius.circular(20.0),
                                      //       ),
                                      ),
                                  builder: (context) {
                                    return changeAddressBottomSheetWidget(
                                        profileprovider, theme);
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 0), // maximumSize:Size.square(2),
                                backgroundColor: theme.isDarkMode
                                    ? colors.colorbluegrey
                                    : colors.colorBlack,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                minimumSize: const Size(55, 25),
                              ),
                              child: Text("EDIT",
                                  style: textStyle(
                                      !theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      12,
                                      FontWeight.w500)),
                            ),
                          ),
                          style: TextStyle(
                            color: theme.isDarkMode
                                ? colors.colorWhite
                                : colors.colorBlack,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const Divider(color: Color(0xffDDDDDD)),
                      ],
                    ),
                  ),
         
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 0.0, vertical: 0),
                    child: Card(
                      elevation: 0, // No shadow
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(
                            color: Color.fromARGB(255, 255, 255, 255),
                            width: 1), // Outlined border
                        borderRadius:
                            BorderRadius.circular(8), // Rounded corners
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(
                            5.0), // Padding inside the card
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text(
                            //   "Demat Details",
                            //   style: textStyle(
                            //     theme.isDarkMode
                            //         ? colors.colorWhite
                            //         : colors.colorBlack,
                            //     16,
                            //     FontWeight.w600,
                            //   ),
                            // ),
                            // Padding(
                            //   padding: const EdgeInsets.only(top: 8),
                            //   child: Text(
                            //     "Allows you to sell your holdings with one-time authorisation.",
                            //     style: textStyle(const Color(0xff666666), 14,
                            //         FontWeight.w400),
                            //   ),
                            // ),
                            const Divider(color: Color(0xffDDDDDD)),
                            const SizedBox(height: 5),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 9, right: 10),
                                  child: Text(
                                    "Demat Account",
                                    style: textStyle(const Color(0xff666666),
                                        16, FontWeight.w600),
                                  ),
                                ),
                                Wrap(
                                  spacing: 5, // Adds spacing between the chips
                                  children: [
                                    Chip(
                                      backgroundColor: profileprovider
                                                  .clientAllDetails
                                                  .clientData!
                                                  .dDPI ==
                                              'N'
                                          ? const Color.fromARGB(
                                              255, 201, 67, 62)
                                          : const Color.fromARGB(
                                              255, 105, 231, 115),
                                      label:const Text(
                                        'DDPI',
                                        style:
                                            TextStyle(color: Color(0xffffffff)),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                       visualDensity: VisualDensity(horizontal: 0.0, vertical: -4)
                                    ),
                                    Chip(
                                      backgroundColor: profileprovider
                                                  .clientAllDetails
                                                  .clientData!
                                                  .pOA ==
                                              'N'
                                          ? const Color.fromARGB(
                                              255, 201, 67, 62)
                                          : const Color.fromARGB(
                                              255, 105, 231, 115),
                                      label:const Text(
                                        'POI',
                                        style:
                                            TextStyle(color: Color(0xffffffff)),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                       visualDensity: VisualDensity(horizontal: 0.0, vertical: -4)
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                headerText("DP ID : ", theme),
                                Text(
                                profileprovider
                                        .clientAllDetails.clientData?.cLIENTDPCODE ??
                                    "",
                                style: TextStyle(
                                  color: theme.isDarkMode
                                      ? colors.colorWhite
                                      : colors.colorBlack,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                               ),


                              ],
                            ),
                            // const SizedBox(height: 5),
                           



                            // const Divider(color: Color(0xffDDDDDD)),
                            // const SizedBox(height: 16),
                            // headerText("DP Name", theme),
                            // const SizedBox(height: 5),
                            // Text(
                            //   profileprovider
                            //           .clientAllDetails.clientData?.dPNAME ??
                            //       "",
                            //   style: TextStyle(
                            //     color: theme.isDarkMode
                            //         ? colors.colorWhite
                            //         : colors.colorBlack,
                            //     fontSize: 15,
                            //     fontWeight: FontWeight.w500,
                            //   ),
                            // ),
                            // const Divider(color: Color(0xffDDDDDD)),
                            const SizedBox(height: 24),
                            // Text(' Demat Debit and Pledge Instruction (DDPI)',
                            //     style: textStyle(const Color(0xff000000), 16,
                            //         FontWeight.w600)),
                            // Padding(
                            //   padding: const EdgeInsets.only(top: 5),
                            //   child: Text(
                            //       "DDPI is a document that allows a broker to debit the securities from the client's demat account and deliver them to the exchange. ",
                            //       style: textStyle(const Color(0xff666666), 14,
                            //           FontWeight.w500)),
                            // ),
                            // const Divider(color: Color(0xffDDDDDD)),
                            // const SizedBox(height: 14),
                            Text(
                                'Do you want to sell your stocks without CDSL T-PIN',
                                style: textStyle(const Color(0xff000000), 15,
                                    FontWeight.w600)),
                            if (profileprovider
                                    .clientAllDetails!.clientData!.dDPI ==
                                'N')
                              Padding(
                                padding: const EdgeInsets.only(top: 15),
                                child: SizedBox(
                                  width: double
                                      .infinity, // Makes the button occupy the full width
                                  child: ElevatedButton(
                                    onPressed: () {
                                      profileprovider.clearProfilePop(
                                          context, 'ddpibalace');
                                      profileprovider.ddpiledgerbaapi();
                                      showModalBottomSheet(
                                        context: context,
                                        isDismissible: false,
                                        enableDrag: false,
                                        isScrollControlled: true,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(20.0)),
                                        ),
                                        builder: (context) {
                                          return Consumer(builder:
                                              (context, WidgetRef ref, _) {
                                            // final popproprv = ref.watch(profileProvider);
                                            return Container(
                                              padding: EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(height: 40),
                                                  Text(
                                                    'Debit Alert ',
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  SizedBox(height: 20),
                                                  // SizedBox(height: 15),
                                                  Center(
                                                    child: Text(
                                                      "DDPI One Time Charges",
                                                      style: textStyle(
                                                        const Color.fromARGB(
                                                            255, 0, 0, 0),
                                                        15,
                                                        FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 10),
                                                  Center(
                                                    child: Card(
                                                      color: Colors.grey[
                                                          300], // Set the card background color to grey
                                                      elevation:
                                                          0, // Optional: Add elevation to give it a raised look
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                8), // Optional: Rounded corners for the card
                                                      ),
                                                      child: const Padding(
                                                        padding: EdgeInsets.all(
                                                            16.0), // Padding inside the card
                                                        child: Text(
                                                          "₹ 250", // Text you want to display
                                                          style: TextStyle(
                                                            color: Colors
                                                                .black, // Text color
                                                            fontSize:
                                                                20, // Font size
                                                            fontWeight: FontWeight
                                                                .bold, // Bold text
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 20),
                                                  Center(
                                                    child: Text(
                                                      " Available ledger ",
                                                      style: textStyle(
                                                        const Color.fromARGB(
                                                            255, 0, 0, 0),
                                                        17,
                                                        FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 5),
                                                  Center(
                                                    child: Text(
                                                      " ₹${profileprovider.ddpiledgerbalace}",
                                                      style: textStyle(
                                                        const Color.fromARGB(
                                                            255, 0, 0, 0),
                                                        17,
                                                        FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  // Text("11111111${profileprovider.ddpiledgerbalace}"),
                                                  const SizedBox(height: 15),

                                                  Builder(
                                                    builder: (context) {
                                                      String balanceString =
                                                          profileprovider
                                                              .ddpiledgerbalace!
                                                              .replaceAll(
                                                                  RegExp(
                                                                      r'[^0-9.]'),
                                                                  '');
                                                      double balance =
                                                          double.tryParse(
                                                                  balanceString) ??
                                                              0.0;
                                                      bool showApproveButton =
                                                          balance > 250;

                                                      return showApproveButton
                                                          ? ElevatedButton(
                                                              onPressed: () {
                                                                // Handle approve button press
                                                              },
                                                              child: Text(
                                                                  'Approve'),
                                                            )
                                                          : const SizedBox();
                                                    },
                                                  ),

                                                  // Column(
                                                  //   children: [
                                                  //     Row(
                                                  //       children: [
                                                  //         Radio<bool>(
                                                  //           value:
                                                  //               false, // Only one radio button
                                                  //           groupValue: isSelected,
                                                  //           onChanged: (bool? value) {
                                                  //             context
                                                  //                 .read(
                                                  //                     radioSelectionProvider)
                                                  //                 .state = value!;
                                                  //           },
                                                  //         ),
                                                  //         const Text('Set as Primary'),
                                                  //       ],
                                                  //     ),
                                                  //   ],
                                                  // ),

                                                  Builder(
                                                    builder: (context) {
                                                      String balanceString =
                                                          profileprovider
                                                                  .ddpiledgerbalace
                                                                  ?.replaceAll(
                                                                      RegExp(
                                                                          r'[^0-9.]'),
                                                                      '') ??
                                                              '0';
                                                      double balance =
                                                          double.tryParse(
                                                                  balanceString) ??
                                                              0.0;
                                                      bool showApproveButton =
                                                          balance > 250;

                                                      return Column(
                                                        children: [
                                                          if (!showApproveButton) // Equivalent to v-if="balance <= 250"
                                                            Container(
                                                              margin: const EdgeInsets
                                                                  .only(
                                                                  top:
                                                                      8), // Equivalent to mt-2
                                                              padding: const EdgeInsets
                                                                  .symmetric(
                                                                  vertical:
                                                                      4), // Equivalent to py-1
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .red
                                                                    .withOpacity(
                                                                        0.1), // Info type alert background
                                                                border: Border.all(
                                                                    color: Colors
                                                                        .red), // Outlined effect
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            5),
                                                              ),
                                                              child:
                                                                  const Center(
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          8.0),
                                                                  child: Text(
                                                                    "Insufficient Balance",
                                                                    style:
                                                                        const TextStyle(
                                                                      fontSize:
                                                                          15,
                                                                      color: Colors
                                                                          .black,
                                                                    ),
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),

                                                          // Other UI elements can go here...
                                                        ],
                                                      );
                                                    },
                                                  ),

                                                  SizedBox(height: 30),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        flex:
                                                            1, // Takes 50% width
                                                        child: OutlinedButton(
                                                          onPressed: () {
                                                            profileprovider
                                                                .clearProfilePop(
                                                                    context,
                                                                    'ddpibalace');
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                          style: OutlinedButton
                                                              .styleFrom(
                                                            side: BorderSide(
                                                                color: colors
                                                                    .colorBlack), // Border color
                                                            backgroundColor: Colors
                                                                .white, // Background color
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        12,
                                                                    horizontal:
                                                                        12),
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          25),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            'Close',
                                                            style: TextStyle(
                                                                color: colors
                                                                    .colorBlack), // Text color
                                                          ),
                                                        ),
                                                      ),

                                                      SizedBox(
                                                          width:
                                                              10), // Adds spacing between buttons
                                                      Expanded(
                                                        flex:
                                                            1, // Takes 50% width
                                                        child: Builder(
                                                          builder: (context) {
                                                            // Convert balance to a numeric value
                                                            String
                                                                balanceString =
                                                                profileprovider
                                                                    .ddpiledgerbalace!
                                                                    .replaceAll(
                                                                        RegExp(
                                                                            r'[^0-9.]'),
                                                                        '');
                                                            double balance =
                                                                double.tryParse(
                                                                        balanceString) ??
                                                                    0.0;
                                                            bool isEnabled =
                                                                balance >
                                                                    250; // Enable button if balance > 250

                                                            return ElevatedButton(
                                                              onPressed: isEnabled
                                                                  ? () {
                                                                      profileprovider.ddpifinalstep(profileprovider
                                                                          .clientAllDetails
                                                                          .clientData);
                                                                    }
                                                                  : null, // Disable button if condition is not met
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                elevation: 0,
                                                                backgroundColor:
                                                                    isEnabled
                                                                        ? colors
                                                                            .colorBlack
                                                                        : Colors
                                                                            .grey, // Change color if disabled
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        12,
                                                                    horizontal:
                                                                        12),
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              25),
                                                                ),
                                                              ),
                                                              child: Text(
                                                                  'Submit'),
                                                            );
                                                          },
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          });
                                        },
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: colors.colorBlack,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: Text("Activate DDPI",
                                        style: textStyles.btnText),
                                  ),
                                ),
                              ),
                            if ((profileprovider
                                    .clientAllDetails!.clientData!.dDPI ==
                                'Y')) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 15),
                                child: SizedBox(
                                  width: double
                                      .infinity, // Makes the button occupy the full width
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: colors.colorBlack,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: Text("DDPI Enabled",
                                        style: textStyles.btnText),
                                  ),
                                ),
                              )
                            ],
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                  " *As per the regulation, DDPI activation will be one time process. ",
                                  style: textStyle(const Color(0xff666666), 12,
                                      FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
               
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 0.0, vertical: 0),
                    child: Card(
                      elevation: 0, // No shadow
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            color: Color.fromARGB(255, 255, 255, 255),
                            width: 1), // Outlined border
                        borderRadius:
                            BorderRadius.circular(8), // Rounded corners
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(
                            5.0), // Padding inside the card
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Margin Trading Facility (MTF)",
                              style: textStyle(
                                theme.isDarkMode
                                    ? colors.colorWhite
                                    : colors.colorBlack,
                                16,
                                FontWeight.w600,
                              ),
                            ),
                            const Divider(color: Color(0xffDDDDDD)),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  " Would you like to activate Margin Trading Facility (MTF) on your account ",
                                  style: textStyle(const Color(0xff666666), 15,
                                      FontWeight.w600)),
                            ),
                            const Divider(color: Color(0xffDDDDDD)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 7, // Adds spacing between the chips
                                  children: [
                                    Chip(
                                      backgroundColor: profileprovider
                                                  .clientAllDetails
                                                  .clientData!
                                                  .dDPI ==
                                              'N'
                                          ? const Color.fromARGB(
                                              255, 201, 67, 62)
                                          : const Color.fromARGB(
                                              255, 105, 231, 115),
                                      label: Text(
                                        'DDPI',
                                        style:
                                            TextStyle(color: Color(0xffffffff)),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                       visualDensity: VisualDensity(horizontal: 0.0, vertical: -4)
                                    ),
                                    Chip(
                                      backgroundColor: profileprovider
                                                  .clientAllDetails
                                                  .clientData!
                                                  .pOA ==
                                              'N'
                                          ? const Color.fromARGB(
                                              255, 201, 67, 62)
                                          : const Color.fromARGB(
                                              255, 105, 231, 115),
                                      label: Text(
                                        'POI',
                                        style:
                                            TextStyle(color: Color(0xffffffff)),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                       visualDensity: VisualDensity(horizontal: 0.0, vertical: -4)
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              (profileprovider.clientAllDetails!.clientData!
                                              .dDPI ==
                                          'N' &&
                                      profileprovider.clientAllDetails!
                                              .clientData!.pOA ==
                                          "N")
                                  ? "You need to enable DDPI before you can proceed with processing MTF (Margin Trading Facility)."
                                  : "",
                              style: TextStyle(
                                color: Color.fromARGB(255, 206, 47, 47),
                              ),
                            ),
                            if ((profileprovider
                                        .clientAllDetails!.clientData!.mTFCl ==
                                    'Y' &&
                                profileprovider.clientAllDetails!.clientData!
                                        .mTFClAuto ==
                                    "Y")) ...[
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      'MTF Enabled',
                                      style: TextStyle(
                                          color:
                                              Color(0xff43a833)), // Text color
                                    ),
                                    backgroundColor:
                                        Color(0xffecf8f1), // Background color
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color:
                                            Color(0xffc1e7ba), // Border color
                                      ),
                                      borderRadius: BorderRadius.circular(
                                          7), // Rounded corners
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if ((profileprovider.clientAllDetails!.clientData!
                                            .mTFCl ==
                                        'N' &&
                                    profileprovider.clientAllDetails.clientData!
                                            .mTFClAuto ==
                                        'N') &&
                                (profileprovider.clientAllDetails!.clientData!
                                            .dDPI ==
                                        'Y' ||
                                    profileprovider.clientAllDetails!
                                            .clientData!.pOA ==
                                        "Y"))
                              Padding(
                                padding: const EdgeInsets.only(top: 15),
                                child: SizedBox(
                                  width: double
                                      .infinity, // Makes the button occupy the full width
                                  child: ElevatedButton(
                                    onPressed: () {
                                      profileprovider.mtfenbprovi(
                                          (profileprovider
                                              .clientAllDetails.clientData));
                                    },
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: colors.colorBlack,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: Text("Enable MTF",
                                        style: textStyles.btnText),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
             
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 0.0, vertical: 0),
                    child: Card(
                      elevation: 0, // No shadow
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            color: Color.fromARGB(255, 255, 255, 255),
                            width: 1), // Outlined border
                        borderRadius:
                            BorderRadius.circular(8), // Rounded corners
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(
                            5.0), // Padding inside the card
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Annual Income",
                              style: textStyle(
                                theme.isDarkMode
                                    ? colors.colorWhite
                                    : colors.colorBlack,
                                16,
                                FontWeight.w600,
                              ),
                            ),
                            const Divider(color: Color(0xffDDDDDD)),
                            // const SizedBox(height: 18),
                            headerText("Yearly Income Range", theme),
                            // const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  profileprovider.clientAllDetails.clientData
                                          ?.aNNUALINCOME ??
                                      "", // Replace with your actual data
                                  style: TextStyle(
                                    color: theme.isDarkMode
                                        ? colors.colorWhite
                                        : colors.colorBlack,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                ElevatedButton(
                              onPressed: () async {
                                  profileprovider.clearProfilePop(
                                        context, 'incomeotpres');

                              showModalBottomSheet(
                                      context: context,
                                      isDismissible: false,
                                      enableDrag: false,
                                      isScrollControlled: true,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(20.0)),
                                      ),
                                      builder: (context) {
                                        return Consumer(
                                          builder: (context, ref, child) {
                                            // No 'ScopedReader' needed
                                            // final popproprv =
                                            //     ref.watch(profileProvider);
                                            // final selectedChipIndex =
                                            //     ref.watch(selectedChipProvider);
                                            // final selectedIncomeIndex =
                                            //     ref.watch(selectedIncomeProvider);
                                            return Container(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(height: 40),
                                                  Text(
                                                    'Income change request',
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  SizedBox(height: 20),
                                                  Text(
                                                    "Select Income per annum",
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  SizedBox(height: 20),
                                                  //  Column(
                                                  //                       children: List.generate(incomeLabels.length, (index) {
                                                  //                         return RadioListTile<int>(
                                                  //                           title: Text(incomeLabels[index]),
                                                  //                           value: index,
                                                  //                           groupValue: selectedIncomeIndex,
                                                  //                           onChanged: (int? newValue) {
                                                  //                             if (newValue != null) {
                                                  //                               ref.read(selectedIncomeProvider.notifier).selectIncome(newValue);
                                                  //                               print('Selected income: ${incomeLabels[newValue]} at index $newValue');
                                                  //                             }
                                                  //                           },
                                                  //                           activeColor: Colors.black,
                                                  //                         );
                                                  //                       }),
                                                  //                     ),

                                                  Wrap(
                                                    spacing: 10,
                                                    runSpacing: 10,
                                                    children: List.generate(
                                                        profileprovider
                                                            .annualIncomeRangeList
                                                            .length, (index) {
                                                      return ChoiceChip(
                                                        label: Text(profileprovider
                                                                .annualIncomeRangeList[
                                                            index]),
                                                        selected: true,
                                                        // selectedChipIndex ==
                                                        //     index,
                                                        onSelected:
                                                            (isSelected) {
                                                          // context
                                                          //         .read(
                                                          //             selectedChipProvider
                                                          //                 .notifier)
                                                          //         .state =
                                                          //     isSelected
                                                          //         ? index
                                                          //         : -1;
                                                        },
                                                        selectedColor:
                                                            Colors.black,
                                                        backgroundColor:
                                                            Colors.grey[300],
                                                        labelStyle:
                                                            const TextStyle(
                                                          color: true
                                                              // selectedChipIndex ==
                                                              //         index
                                                              ? Colors.white
                                                              : Colors.black,
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                  // Text(
                                                  //   selectedChipIndex == -1
                                                  //       ? 'No chip selected'
                                                  //       : 'Selected chip: ${chipLabels[selectedChipIndex]}',
                                                  //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                  // ),
                                                  // Text("12345678${profileprovider.imcomeptsenres}"),

                                                  if (profileprovider
                                                              .selectedAnnualIncomeRangeValue !=
                                                          -1 &&
                                                      profileprovider
                                                                  .annualIncomeRangeList[
                                                              profileprovider
                                                                  .selectedAnnualIncomeRangeValue] ==
                                                          'Above 25L') ...[
                                                    Column(
                                                      mainAxisSize: MainAxisSize
                                                          .min, // Ensures it only takes necessary space
                                                      children: List.generate(
                                                          incomeLabels.length,
                                                          (index) {
                                                        return RadioListTile<
                                                            int>(
                                                          contentPadding: EdgeInsets
                                                              .zero, // Removes internal padding
                                                          title: Text(
                                                              incomeLabels[
                                                                  index]),
                                                          value: index,
                                                          groupValue:
                                                              profileprovider
                                                                  .selectedAnnualIncomeRangeValue,
                                                          onChanged:
                                                              (int? newValue) {
                                                            if (newValue !=
                                                                null) {
                                                              // context
                                                              //     .read(
                                                              //         selectedIncomeProvider
                                                              //             .notifier)
                                                              //     .selectIncome(
                                                              //         newValue);
                                                            }
                                                          },
                                                          activeColor:
                                                              Colors.black,
                                                          dense:
                                                              true, // Reduces vertical space between items
                                                        );
                                                      }),
                                                    ),
                                                    SizedBox(height: 20),
                                                    ElevatedButton(
                                                      child: const Text(
                                                          'UPLOAD FILE'),
                                                      onPressed: () async {
                                                        var picked =
                                                            await FilePicker
                                                                .platform
                                                                .pickFiles();

                                                        if (picked != null &&
                                                            picked.files.first
                                                                    .path !=
                                                                null) {
                                                          String filePath =
                                                              picked.files.first
                                                                  .path!;
                                                          String fileName =
                                                              picked.files.first
                                                                  .name;


                                                          // Store file path in provider
                                                          // context
                                                          //     .read(
                                                          //         filePathProvider)
                                                          //     .state = filePath;
                                                        }

                                                        Text("elseee");
                                                      },
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        elevation: 0,
                                                        backgroundColor:
                                                            colors.colorBlack,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 12,
                                                                horizontal: 12),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(25),
                                                        ),
                                                      ),
                                                    ),
                                                  ],

                                                  SizedBox(height: 30),
                                                  if (profileprovider
                                                          .imcomeptsenres ==
                                                      "otp send") ...[
                                                    Text("Mobile Number",
                                                        style: textStyle(
                                                            const Color
                                                                .fromARGB(
                                                                255, 0, 0, 0),
                                                            15,
                                                            FontWeight.w600)),
                                                    TextFormField(
                                                      initialValue: profileprovider
                                                              .clientAllDetails
                                                              .clientData
                                                              ?.mOBILENO ??
                                                          "",
                                                      readOnly:
                                                          true, // Makes the field non-editable
                                                      decoration:
                                                          const InputDecoration(
                                                        border:
                                                            UnderlineInputBorder(),
                                                      ),
                                                    ),
                                                    SizedBox(height: 20),
                                                    Text(
                                                      "OTP *",
                                                      style: TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                    TextFormField(
                                                      controller: profileprovider
                                                          .newIncomeOTPController,
                                                      onChanged: (value) {
                                                        // context
                                                        //         .read(incomeotppro
                                                        //             .notifier)
                                                        //         .state =
                                                        //     value; // Update state
                                                      },
                                                      decoration:
                                                          const InputDecoration(
                                                        hintText: 'Enter Otp',
                                                        border:
                                                            UnderlineInputBorder(),
                                                      ),
                                                    ),
                                                  ],
                                                  SizedBox(height: 30),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 1,
                                                        child: OutlinedButton(
                                                          onPressed: () {
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                          style: OutlinedButton
                                                              .styleFrom(
                                                            side: BorderSide(
                                                                color: Colors
                                                                    .black),
                                                            backgroundColor:
                                                                Colors.white,
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        12,
                                                                    horizontal:
                                                                        12),
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          25),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            'Close',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .black),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 10),
                                                      if (profileprovider
                                                              .imcomeptsenres !=
                                                          "otp send")
                                                        Expanded(
                                                          flex: 1,
                                                          child: ElevatedButton(
                                                            onPressed: () {
                                                              // popproprv
                                                              //     .incomeotpsenpro(
                                                              //   (profileprovider.clientAllDetails
                                                              //         .clientData
                                                              //           ?.mOBILENO)
                                                              //       .toString(),
                                                              // );
                                                            },
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              elevation: 0,
                                                              backgroundColor:
                                                                  Colors.black,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          12,
                                                                      horizontal:
                                                                          12),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            25),
                                                              ),
                                                            ),
                                                            child: Text(
                                                                'Submit btn'),
                                                          ),
                                                        ),
                                                      if (profileprovider
                                                              .imcomeptsenres ==
                                                          "otp send")
                                                        Expanded(
                                                          flex: 1,
                                                          child: ElevatedButton(
                                                            onPressed: () {
                                                              // String mobilotpval =
                                                              //     context
                                                              //         .read(
                                                              //             incomeotppro)
                                                              //         .state;
                                                              // String filePath = context
                                                              //     .read(
                                                              //         filePathProvider)
                                                              //     .state;
                                                              // Check if selectedIncomeIndex is valid before accessing incomeLabels
                                                              // if (selectedIncomeIndex >=
                                                              //         0 &&
                                                              //     selectedIncomeIndex <
                                                              //         incomeLabels
                                                              //             .length) {
                                                              //   // Call the function if the index is valid
                                                              //   popproprv
                                                              //       .incomeotpverpro(
                                                              //     mobilotpval,
                                                              //     profileprovider.clientAllDetails
                                                              //        .clientData,
                                                              //     chipLabels[
                                                              //         selectedChipIndex],
                                                              //     filePath,
                                                              //     incomeLabels[
                                                              //         selectedIncomeIndex],
                                                              //   );
                                                              // } else {
                                                              //   // Handle the case when selectedIncomeIndex is invalid
                                                              //   print(
                                                              //       "Invalid selectedIncomeIndex: $selectedIncomeIndex");
                                                              //   // You can also set a default value or show a message to the user
                                                              //   // For example, use a default label:
                                                              //   String
                                                              //       defaultIncome =
                                                              //       "Not Selected"; // Default value for invalid index
                                                              //   popproprv
                                                              //       .incomeotpverpro(
                                                              //     mobilotpval,
                                                              //     profileprovider.clientAllDetails
                                                              //        .clientData,
                                                              //     chipLabels[
                                                              //         selectedChipIndex],
                                                              //     filePath,
                                                              //     defaultIncome,
                                                              //   );
                                                              // }
                                                            },
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              elevation: 0,
                                                              backgroundColor:
                                                                  Colors.black,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          12,
                                                                      horizontal:
                                                                          12),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            25),
                                                              ),
                                                            ),
                                                            child: Text(
                                                                'Submit otp'),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  
                              },
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 0), // maximumSize:Size.square(2),
                                backgroundColor: theme.isDarkMode
                                    ? colors.colorbluegrey
                                    : colors.colorBlack,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                minimumSize: const Size(60, 25),
                              ),
                              child: Text("DECLARE",
                                  style: textStyle(
                                      !theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      11,
                                      FontWeight.w500)),
                            ),





                                // InkWell(
                                //   onTap: () {
                                //     profileprovider.clearProfilePop(
                                //         context, 'incomeotpres');
                                    
                                //   },
                                //   child: const Row(
                                //     mainAxisSize: MainAxisSize
                                //         .min, // Ensures that the Row doesn't take up full width
                                //     children: [
                                //       Icon(
                                //         Icons.edit,
                                //         color: Color(0xFF0037B7),
                                //         size: 17,
                                //         // Blue color for the icon
                                //       ),
                                //       Text(
                                //         'EDIT',
                                //         style: TextStyle(
                                //           color: Color(
                                //               0xFF0037B7), // Blue color for the text
                                //           fontSize:
                                //               15, // You can adjust the size as needed
                                //           fontWeight: FontWeight.w500,
                                //         ),
                                //       ),
                                //     ],
                                //   ),

                                //   // const Icon(Icons.edit),
                                // ),
                              ],
                            ),
                            const Divider(color: Color(0xffDDDDDD)),
                            const SizedBox(height: 16),
                            headerText("Last Updated Date", theme),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '2025-02-03', // Replace with actual data
                                  style: TextStyle(
                                    color: theme.isDarkMode
                                        ? colors.colorWhite
                                        : colors.colorBlack,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Color(0xffDDDDDD)),
                          ],
                        ),
                      ),
                    ),
                  ),
               
                 
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7.0, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Equities section
                                  Text(
                                    "Equities",
                                    style: textStyle(
                                      theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      16,
                                      FontWeight.w600,
                                    ),
                                  ),

                        const SizedBox(height: 5),
                        ...?profileprovider
                            .clientAllDetails.clientData!.segmentsData
                            ?.where((segment) => ['BSE_CASH', 'NSE_CASH']
                                .contains(segment
                                    .cOMPANYCODE)) // Assuming COMPANY_CODE is a field in SegmentsData
                            .map((segment) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(segment.cOMPANYCODE ?? 'N/A',
                              style: textStyle(
                                      theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      14,
                                      FontWeight.w500,
                                    )
                              ),

                                Chip(
                                      backgroundColor: segment.aCTIVEINACTIVE == "A"
                                          ? const Color.fromARGB(255, 6, 193, 3)
                                          : const Color.fromARGB(255, 246, 193, 4),
                                      label: Text(
                                        segment.aCTIVEINACTIVE == "A"? 'ACTIVE': "Inactive",

                                        style:
                                            textStyle(
                                      theme.isDarkMode
                                          ? colors.colorBlack
                                          : colors.colorWhite,
                                      10,
                                      FontWeight.w500,),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                       visualDensity: VisualDensity(horizontal: 0, vertical: -4)
                                    ),

                                  // Text(segment.aCTIVEINACTIVE == "A"
                                  //     ? 'ACTIVE'
                                  //     : "in"),

                              Text(segment.rEGISTRATIONDATE ?? 'N/A',
                               style: textStyle(
                                      theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      12,
                                      FontWeight.w500,
                                    )
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        }).toList(),

                        // F&O section
             
                                Text(
                                    "F&O",
                                    style: textStyle(
                                      theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      16,
                                      FontWeight.w600,
                                    ),
                                  ),
                        const SizedBox(height: 5),
                        ...?profileprovider
                            .clientAllDetails.clientData?.segmentsData
                            ?.where((segment) => ['BSE_FNO', 'NSE_FNO']
                                .contains(segment.cOMPANYCODE))
                            .map((segment) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(segment.cOMPANYCODE ?? 'N/A'),
                              Text(segment.aCTIVEINACTIVE == "A"
                                  ? 'ACTIVE'
                                  : "in"),
                              Text(segment.rEGISTRATIONDATE ?? 'N/A'),
                              const SizedBox(height: 8),
                            ],
                          );
                        }).toList(),

                        // Currency section
                               Text(
                                    "Currency",
                                    style: textStyle(
                                      theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      16,
                                      FontWeight.w600,
                                    ),
                                  ),
                        const SizedBox(height: 5),
                        ...?profileprovider
                            .clientAllDetails.clientData?.segmentsData
                            ?.where((segment) => ['CD_BSE', 'CD_NSE']
                                .contains(segment.cOMPANYCODE))
                            .map((segment) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(segment.cOMPANYCODE ?? 'N/A'),
                              Text(segment.aCTIVEINACTIVE == "A"
                                  ? 'ACTIVE'
                                  : "in"),
                              Text(segment.rEGISTRATIONDATE ?? 'N/A'),
                              const SizedBox(height: 8),
                            ],
                          );
                        }).toList(),

                        // Commodities section
                              Text(
                                    "Commodities",
                                    style: textStyle(
                                      theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      16,
                                      FontWeight.w600,
                                    ),
                                  ),
                        const SizedBox(height: 5),
                        ...?profileprovider
                            .clientAllDetails.clientData?.segmentsData
                            ?.where((segment) => ['MCX', 'BSE_COM', 'NSE_COM']
                                .contains(segment.cOMPANYCODE))
                            .map((segment) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(segment.cOMPANYCODE ?? 'N/A'),
                              Text(segment.aCTIVEINACTIVE == "A"
                                  ? 'ACTIVE'
                                  : "in"),
                              Text(segment.rEGISTRATIONDATE ?? 'N/A'),
                              const SizedBox(height: 8),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
           
                  Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0.0, vertical: 0),
                          child: Card(
                            elevation: 0, // No shadow
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  width: 1), // Outlined border
                              borderRadius:
                                  BorderRadius.circular(8), // Rounded corners
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(
                                  5.0), // Padding inside the card
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Account Closure",
                                    style: textStyle(
                                      theme.isDarkMode
                                          ? colors.colorWhite
                                          : colors.colorBlack,
                                      16,
                                      FontWeight.w600,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      "If you close your account, you won’t be able to trade with Zebu.",
                                      style: textStyle(const Color(0xff666666), 15,
                                          FontWeight.w500),
                                    ),
                                  ),
                                  const Divider(color: Color(0xffDDDDDD)),
                                  const SizedBox(height: 18),
                                  Text(" Would you like to close your account? ",
                                      style: textStyle(const Color(0xff666666), 17,
                                          FontWeight.w600)),
                                  const SizedBox(height: 06),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 15),
                                    child: SizedBox(
                                      width: double
                                          .infinity, // Makes the button occupy the full width
                                      child: ElevatedButton(
                                        onPressed: () {
                                          profileprovider.clearProfilePop(
                                              context, 'accclose');

                                          showModalBottomSheet(
                                            context: context,
                                            isDismissible: true,
                                            enableDrag: true,
                                            isScrollControlled: true,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.vertical(
                                                  top: Radius.circular(20.0)),
                                            ),
                                            builder: (context) {
                                              return Consumer(
                                                builder:
                                                    (context, WidgetRef ref, _) {
                                                  // final closeselectedval =
                                                  //     ref.watch(closedroup).state;
                                                  // final popproprv = ref.watch(profileProvider);
                                                  return Container(
                                                    padding: EdgeInsets.all(16),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        SizedBox(height: 40),
                                                        const Text(
                                                          '  Account Closure ? ',
                                                          style: TextStyle(
                                                              fontSize: 20,
                                                              fontWeight:
                                                                  FontWeight.bold),
                                                        ),

                                                        if (profileprovider
                                                                    .chackaccbalace[
                                                                'stage'] ==
                                                            null) ...{
                                                          SizedBox(height: 20),
                                                          const Text(
                                                            '  Are you sure you want to Deactivate your account ?',
                                                            style: TextStyle(
                                                                fontSize: 17,
                                                                fontWeight:
                                                                    FontWeight.bold),
                                                          ),
                                                          SizedBox(height: 20),

                                                          DropdownButton<String>(
                                                            value: profileprovider
                                                                .selectedAccountClosureReasonValue,
                                                            hint: const Text(
                                                                'Select an option'),
                                                            isExpanded: true,
                                                            items: const [
                                                              DropdownMenuItem<
                                                                  String>(
                                                                value:
                                                                    'High brokerage and charges',
                                                                child: Text(
                                                                    'High brokerage and charges'),
                                                              ),
                                                              DropdownMenuItem<
                                                                  String>(
                                                                value:
                                                                    'Annual maintenance charges',
                                                                child: Text(
                                                                    'Annual maintenance charges'),
                                                              ),
                                                              DropdownMenuItem<
                                                                  String>(
                                                                value: 'Faced losses',
                                                                child: Text(
                                                                    'Faced losses'),
                                                              ),
                                                              DropdownMenuItem<
                                                                  String>(
                                                                value:
                                                                    'No time to focus on trading',
                                                                child: Text(
                                                                    'No time to focus on trading'),
                                                              ),
                                                              DropdownMenuItem<
                                                                  String>(
                                                                value:
                                                                    'Moving to other broker',
                                                                child: Text(
                                                                    'Moving to other broker'),
                                                              ),
                                                            ],
                                                            onChanged:
                                                                (String? newValue) {
                                                              // context
                                                              //         .read(closedroup)
                                                              //         .state =
                                                              //     newValue; // ✅ Correct way to update state
                                                            },
                                                          ),

                                                          // Text("Stage: ${popproprv.chackaccbalace['stage'] ?? 'Loading...'}"),
                                                          // Text("Balance: ${popproprv.chackaccbalace['balance'] ?? 'Loading...'}"),
                                                          SizedBox(height: 20),

                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                flex: 1,
                                                                child: OutlinedButton(
                                                                  onPressed: () {
                                                                    Navigator.pop(
                                                                        context);
                                                                  },
                                                                  style:
                                                                      OutlinedButton
                                                                          .styleFrom(
                                                                    side: BorderSide(
                                                                        color: colors
                                                                            .colorBlack),
                                                                    backgroundColor:
                                                                        Colors.white,
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                12,
                                                                            horizontal:
                                                                                12),
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                                  25),
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    'Close',
                                                                    style: TextStyle(
                                                                        color: colors
                                                                            .colorBlack),
                                                                  ),
                                                                ),
                                                              ),
                                                              SizedBox(width: 10),
                                                              Expanded(
                                                                flex: 1,
                                                                child: ElevatedButton(
                                                                  onPressed: () {
                                                                    profileprovider
                                                                        .clearProfilePop(
                                                                            context,
                                                                            'accclose');

                                                                    profileprovider
                                                                        .closeaccnalprov(
                                                                      profileprovider
                                                                          .selectedAccountClosureReasonValue!,
                                                                      (profileprovider
                                                                          .clientAllDetails
                                                                          .clientData),
                                                                    );
                                                                  },
                                                                  style:
                                                                      ElevatedButton
                                                                          .styleFrom(
                                                                    elevation: 0,
                                                                    backgroundColor:
                                                                        colors
                                                                            .colorBlack,
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                12,
                                                                            horizontal:
                                                                                12),
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                                  25),
                                                                    ),
                                                                  ),
                                                                  child:
                                                                      Text('Submit'),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        },
                                                        // Text("1111Stage 2: Negative Balance${popproprv.chackaccbalace['balance'] }"),

                                                        if (profileprovider
                                                                    .chackaccbalace[
                                                                'stage'] ==
                                                            "Stage 2: Negative Balance") ...{
                                                          const SizedBox(height: 5),
                                                          Text(
                                                            "You have a ledger balance of Rs ${profileprovider.chackaccbalace['balance']} in your ${profileprovider.clientAllDetails.clientData?.cLIENTID ?? ""}. Please settle the outstanding amount so we can proceed further.",
                                                            style: const TextStyle(
                                                              color: Color.fromARGB(
                                                                  255, 0, 0, 0),
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight.w500,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 20),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                flex: 1,
                                                                child: OutlinedButton(
                                                                  onPressed: () {
                                                                    Navigator.pop(
                                                                        context);
                                                                  },
                                                                  style:
                                                                      OutlinedButton
                                                                          .styleFrom(
                                                                    side: BorderSide(
                                                                        color: colors
                                                                            .colorBlack),
                                                                    backgroundColor:
                                                                        const Color
                                                                            .fromARGB(
                                                                            255,
                                                                            0,
                                                                            0,
                                                                            0),
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                12,
                                                                            horizontal:
                                                                                12),
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                                  25),
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    'Close',
                                                                    style: TextStyle(
                                                                        color: colors
                                                                            .colorWhite),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        },

                                                        if (profileprovider
                                                                    .chackaccbalace[
                                                                'stage'] ==
                                                            "Stage 1: Positive Balance") ...{
                                                          const SizedBox(height: 5),
                                                          Text(
                                                            "Please withdraw your available balance of  ${profileprovider.clientAllDetails.clientData?.cLIENTID ?? ""}. before submitting your closure request.",
                                                            style: const TextStyle(
                                                              color: Color.fromARGB(
                                                                  255, 0, 0, 0),
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight.w500,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 20),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                flex: 1,
                                                                child: OutlinedButton(
                                                                  onPressed: () {
                                                                    Navigator.pop(
                                                                        context);
                                                                  },
                                                                  style:
                                                                      OutlinedButton
                                                                          .styleFrom(
                                                                    side: BorderSide(
                                                                        color: colors
                                                                            .colorBlack),
                                                                    backgroundColor:
                                                                        const Color
                                                                            .fromARGB(
                                                                            255,
                                                                            0,
                                                                            0,
                                                                            0),
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                12,
                                                                            horizontal:
                                                                                12),
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                                  25),
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    'Close',
                                                                    style: TextStyle(
                                                                        color: colors
                                                                            .colorWhite),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        },

                                                        if (profileprovider
                                                                    .chackaccbalace[
                                                                'stage'] ==
                                                            "Stage 5: Zero Balance & Some Holdings") ...{
                                                          SizedBox(height: 20),
                                                          const Text(
                                                            'Kindly transfer  your stocks to another demat account according to your wish',
                                                            style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight.bold),
                                                          ),
                                                          SizedBox(height: 20),
                                                          const Text(
                                                            'Please enter your another Demat account details',
                                                            style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight.bold),
                                                          ),
                                                          SizedBox(height: 20),
                                                          SizedBox(height: 15),
                                                          Text("DP ID *",
                                                              style: textStyle(
                                                                  const Color
                                                                      .fromARGB(
                                                                      255, 0, 0, 0),
                                                                  15,
                                                                  FontWeight.w600)),
                                                          TextFormField(
                                                            controller: profileprovider
                                                                .closureDPIDController,
                                                            onChanged: (value) {
                                                              // context
                                                              //         .read(closdpidpro)
                                                              //         .state =
                                                              //     value; // Update state
                                                            },
                                                            decoration:
                                                                const InputDecoration(
                                                              hintText: 'DP ID ',
                                                              border:
                                                                  UnderlineInputBorder(),
                                                            ),
                                                          ),
                                                          SizedBox(height: 15),
                                                          Text("BO ID *",
                                                              style: textStyle(
                                                                  const Color
                                                                      .fromARGB(
                                                                      255, 0, 0, 0),
                                                                  15,
                                                                  FontWeight.w600)),
                                                          TextFormField(
                                                            controller: profileprovider
                                                                .closureBOIDController,
                                                            onChanged: (value) {
                                                              // context
                                                              //         .read(closeboidprov)
                                                              //         .state =
                                                              //     value; // Update state
                                                            },
                                                            decoration:
                                                                const InputDecoration(
                                                              hintText: 'BO ID ',
                                                              border:
                                                                  UnderlineInputBorder(),
                                                            ),
                                                          ),
                                                          SizedBox(height: 20),
                                                          Text(
                                                              "Attach a copy of the CMR that is either digitally signed or sealed, and physically signed by the respective DP *",
                                                              style: textStyle(
                                                                  const Color
                                                                      .fromARGB(
                                                                      255, 0, 0, 0),
                                                                  15,
                                                                  FontWeight.w600)),
                                                          SizedBox(height: 15),
                                                          SizedBox(height: 0),
                                                          Text("Proof Type *",
                                                              style: textStyle(
                                                                  const Color
                                                                      .fromARGB(
                                                                      255, 0, 0, 0),
                                                                  15,
                                                                  FontWeight.w600)),
                                                          ElevatedButton(
                                                            child:
                                                                Text('UPLOAD FILE'),
                                                            onPressed: () async {
                                                              var picked =
                                                                  await FilePicker
                                                                      .platform
                                                                      .pickFiles();

                                                              if (picked != null &&
                                                                  picked.files.first
                                                                          .path !=
                                                                      null) {
                                                                String filePath =
                                                                    picked.files.first
                                                                        .path!;
                                                                String fileName =
                                                                    picked.files.first
                                                                        .name;


                                                                // Store file path in provider
                                                                // context
                                                                //     .read(filePathProvider)
                                                                //     .state = filePath;
                                                              }

                                                              Text("elseee");
                                                            },
                                                            style: ElevatedButton
                                                                .styleFrom(
                                                              elevation: 0,
                                                              backgroundColor:
                                                                  colors.colorBlack,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      vertical: 12,
                                                                      horizontal: 12),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(25),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 20),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                flex: 1,
                                                                child: OutlinedButton(
                                                                  onPressed: () {
                                                                    Navigator.pop(
                                                                        context);
                                                                  },
                                                                  style:
                                                                      OutlinedButton
                                                                          .styleFrom(
                                                                    side: BorderSide(
                                                                        color: colors
                                                                            .colorBlack),
                                                                    backgroundColor:
                                                                        Colors.white,
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                12,
                                                                            horizontal:
                                                                                12),
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                                  25),
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    'Close',
                                                                    style: TextStyle(
                                                                        color: colors
                                                                            .colorBlack),
                                                                  ),
                                                                ),
                                                              ),
                                                              SizedBox(width: 10),
                                                              Expanded(
                                                                flex: 1,
                                                                child: ElevatedButton(
                                                                  onPressed: () {
                                                                    // profileprovider.clearProfilePop(context, 'accclose');

                                                                    // String? clodpidtext =
                                                                    //     context
                                                                    //         .read(
                                                                    //             closdpidpro)
                                                                    //         .state;
                                                                    // String? closeboidtext =
                                                                    //     context
                                                                    //         .read(
                                                                    //             closeboidprov)
                                                                    //         .state;
                                                                    // String newmobilenotext =
                                                                    //     context
                                                                    //         .read(
                                                                    //             newmobilno)
                                                                    //         .state;
                                                                    // String filePath = context
                                                                    //     .read(
                                                                    //         filePathProvider)
                                                                    //     .state;
                                                                    // profileprovider
                                                                    //     .closeaccfinalspro(
                                                                    //   clodpidtext ?? "",
                                                                    //   closeboidtext ?? "",
                                                                    //   filePath ?? "",
                                                                    //   closeselectedval ??
                                                                    //       "",
                                                                    //   (profileprovider.clientAllDetails
                                                                    //      .clientData),
                                                                    //   jsonEncode(profileprovider.clientAllDetails
                                                                    //          .clientData
                                                                    //           ?.segmentsData ??
                                                                    //       []),
                                                                    // );
                                                                  },
                                                                  style:
                                                                      ElevatedButton
                                                                          .styleFrom(
                                                                    elevation: 0,
                                                                    backgroundColor:
                                                                        colors
                                                                            .colorBlack,
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                12,
                                                                            horizontal:
                                                                                12),
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                                  25),
                                                                    ),
                                                                  ),
                                                                  child:
                                                                      Text('Submit'),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        }
                                                      ],
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          );
                                        
                                        },
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor: colors.colorBlack,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 13),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                        ),
                                        child: Text("Click here to Initiate",
                                            style: textStyles.btnText),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Text(
                                        " *Clear your ledger debit if any to proceed with the account closure ",
                                        style: textStyle(const Color(0xff666666), 14,
                                            FontWeight.w500)),
                                  ),
                                  const Divider(color: Color(0xffDDDDDD)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      
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
                      return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(input??"") ? null : "Enter a valid email";
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
                        side:
                            BorderSide(color: colors.colorBlack), // Border color
                        backgroundColor: Colors.white, // Background color
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
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
                            borderRadius: BorderRadius.circular(25),
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
                            borderRadius: BorderRadius.circular(25),
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
                        borderRadius: BorderRadius.circular(25),
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
                          borderRadius: BorderRadius.circular(25),
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
                          borderRadius: BorderRadius.circular(25),
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
                  borderRadius: BorderRadius.circular(25),
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
                        borderRadius: BorderRadius.circular(25),
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
                        borderRadius: BorderRadius.circular(25),
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

  Widget buildSection(List segmentsData, String sectionTitle,
      List validCompanyCodes, ThemesProvider theme) {
    final sectionData = segmentsData
        .where((segment) => validCompanyCodes.contains(segment['COMPANY_CODE']))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerText(sectionTitle, theme),
        const SizedBox(height: 5),
        ...sectionData.map((segment) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              valueText(segment['COMPANY_CODE'] ?? 'N/A'),
              valueText(segment['ACTIVE_INACTIVE'] == "A"
                  ? 'ACTIVE'
                  : segment['Exchange_ACTIVE_INACTIVE']),
              valueText(segment['REGISTRATION_DATE'] ?? 'N/A'),
              const SizedBox(height: 8),
            ],
          );
        }).toList(),
      ],
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

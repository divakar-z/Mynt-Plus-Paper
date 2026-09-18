import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/provider/profile_all_details_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/res.dart';

class ProfileDetailsNominee extends ConsumerStatefulWidget {
  const ProfileDetailsNominee({super.key});

  @override
  ConsumerState<ProfileDetailsNominee> createState() => _ProfileDetailsNomineeState();
}

class _ProfileDetailsNomineeState extends ConsumerState<ProfileDetailsNominee> {

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

        return Scaffold(
          backgroundColor:
              theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
          body: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 7.0, vertical: 12),
            children: [
                const Divider(color: Color(0xffDDDDDD)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7.0, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                            "Nominee Details",
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
                              "Going with nomination is a clever move to safeguard your investments.",
                              style: textStyle(const Color(0xff666666), 14,
                                  FontWeight.w400),
                            ),
                          ),
                        const SizedBox(height: 20),
                        headerText("Nominee Name", theme),
                      TextFormField(
                        initialValue: profileprovider
                                .clientAllDetails.clientData?.nomineeName ??
                            "",
                        readOnly: true, // Makes the field non-editable
                        decoration: const InputDecoration(
                            enabled:false,
                            isDense: true,
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
                          
          
                      const SizedBox(height: 16),
                      headerText("Nominee Relation", theme),
                      // const SizedBox(height: 5),
                      TextFormField(
                        initialValue: profileprovider
                                .clientAllDetails.clientData?.nomineeRelation ??
                            "",
                        readOnly: true, // Makes the field non-editable
                        decoration: const InputDecoration(
                          isDense: true,
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
          
                      const SizedBox(height: 16),
                      headerText("Nominee DOB", theme),
                      // const SizedBox(height: 5),
                      TextFormField(
                        initialValue: profileprovider
                                .clientAllDetails.clientData?.nomineeDOB ??
                            "",
                        readOnly: true, // Makes the field non-editable
                        decoration: const InputDecoration(
                          isDense: true,
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
          
                        const SizedBox(height: 16),
                      headerText("Percentage", theme),
                      // const SizedBox(height: 5),
                      TextFormField(
                        initialValue: profileprovider
                                .clientAllDetails.clientData?.nomineeDOB ??
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
          
                        Row(
                          children: [
                            ElevatedButton(
                                    onPressed: () {
                                    },
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: colors.colorBlack,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10,horizontal: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: Text("Edit your Nominee",
                                        style: textStyles.btnText),
                                  ),
                                    const SizedBox(width: 15,),
                               ElevatedButton(
                                onPressed: () {
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: colors.colorBlack,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10,horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                child: Text("No,I will do later",
                                    style: textStyles.btnText),
                              ),
          
          
                          ],
                        ),
          
                       Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              "*As per the regulation, you can have up-to 3 nominee for your trading a/c",
                              style: textStyle(const Color(0xff666666), 14,
                                  FontWeight.w400),
                            ),
                          ),         
          // 
                    ],
                  ),
                ),
            ],
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

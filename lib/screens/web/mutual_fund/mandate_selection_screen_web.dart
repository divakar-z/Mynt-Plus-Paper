import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/provider/mf_provider.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/res/global_state_text.dart';
import 'package:mynt_plus/sharedWidget/list_divider.dart';
import 'create_mandate_dialogue_web.dart';
import '../../../../provider/thems.dart';

class MandateSelectionScreenWeb extends StatefulWidget {
  final String? currentMandateId;
  final Function(String) onMandateSelected;

  const MandateSelectionScreenWeb({
    super.key,
    this.currentMandateId,
    required this.onMandateSelected,
  });

  @override
  State<MandateSelectionScreenWeb> createState() => _MandateSelectionScreenStateWeb();
}

class _MandateSelectionScreenStateWeb extends State<MandateSelectionScreenWeb> {


 
  String formatDate(String input) {
    if (input.isEmpty) return "N/A";
    
    try {
      // Try multiple formats to handle variations
      List<DateFormat> formats = [
        DateFormat('MMM d yyyy  h:mma'), // "Jul 16 2024  7:14PM" (double space)
        DateFormat('MMM d yyyy h:mma'),  // "Jul 16 2024 7:14PM" (single space)
        DateFormat('MMM d yyyy H:mma'),  // "Jul 16 2024 19:14PM" (24-hour)
      ];
      
      DateTime? parsedDate;
      for (DateFormat format in formats) {
        try {
          parsedDate = format.parse(input);
          break;
        } catch (e) {
          continue;
        }
      }
      
      if (parsedDate != null) {
        final outputFormat = DateFormat('d/MM/yyyy H:mm');
        return outputFormat.format(parsedDate);
      } else {
        return input; // Return original if no format matches
      }
    } catch (e) {
      return input;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, WidgetRef ref, _) {
        final theme = ref.read(themeProvider);
        final mfOrder = ref.watch(mfProvider);

        return Scaffold(
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  splashColor: theme.isDarkMode
                      ? colors.splashColorDark
                      : colors.splashColorLight,
                  highlightColor: theme.isDarkMode
                      ? colors.highlightDark
                      : colors.highlightLight,
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.arrow_back_ios_outlined,
                    size: 18,
                    color:
                        theme.isDarkMode ? colors.colorGrey : colors.colorBlack,
                  ),
                ),
              ),
            ),
            elevation: 0,
            centerTitle: false,
            titleSpacing: -8,
            title: TextWidget.titleText(
                text: "Auto Pay (Mandates)",
                theme: theme.isDarkMode,
                color: theme.isDarkMode
                    ? colors.textPrimaryDark
                    : colors.textPrimaryLight,
                fw: 1),
          ),
          backgroundColor:
              theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
          body: SafeArea(
            child: Column(
              children: [
                // Mandate List
                Expanded(
                  child: mfOrder.mandateData != null &&
                          mfOrder.mandateData!.isNotEmpty
                      ? ListView.separated(
                        physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: mfOrder.mandateData!.length,
                          separatorBuilder: (context, index) =>
                              const ListDivider(),
                          itemBuilder: (context, index) {
                            final mandate = mfOrder.mandateData![index];
                            final isSelected =
                                mandate.mandateId == widget.currentMandateId;
                    
                            return InkWell(
                              onTap: () {
                                widget.onMandateSelected(mandate.mandateId ?? '');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (theme.isDarkMode
                                          ? colors.primaryDark.withOpacity(0.1)
                                          : colors.primaryLight.withOpacity(0.1))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? (theme.isDarkMode
                                            ? colors.primaryDark
                                            : colors.primaryLight)
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              SizedBox(
                                                width: MediaQuery.of(context).size.width * 0.5,
                                                child: TextWidget.subText(
                                                  text:
                                                      "Mandate Id : ${mandate.mandateId}",
                                                  theme: theme.isDarkMode,
                                                  color: theme.isDarkMode
                                                      ? colors.textPrimaryDark
                                                      : colors.textPrimaryLight,
                                                      textOverflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                      fw: 0,
                                                  
                                                ),
                                              ),
                                              TextWidget.subText(
                                                text: double.parse(mandate.amount ?? '0').toStringAsFixed(2),
                                                theme: theme.isDarkMode,
                                                 color: theme.isDarkMode
                                                    ? colors.textPrimaryDark
                                                    : colors.textPrimaryLight,
                                                    fw: 0,
                                              ),
                                              
                                              // const SizedBox(height: 4),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          
                                          if (mandate.bankName != null) ...[
                                            
                                            Row(
                                               mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                              children: [
                                                TextWidget.paraText(
                                                  text: "${mandate.bankName}",
                                                  theme: theme.isDarkMode,
                                                  color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
                                                  fw: 0,
                                                ),
                                                
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                           
                                          ],
                                          Row(
                                             mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              TextWidget.paraText(
                                                text: "${mandate.status}",
                                                theme: theme.isDarkMode,
                                                color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
                                                fw: 0,
                                              ),
                                               if (isSelected)
                                              Icon(
                                                Icons.check_circle,
                                                color: theme.isDarkMode
                                                    ? colors.primaryDark
                                                    : colors.primaryLight,
                                                size: 20,
                                              ),
                                              
                                            ],
                                          ),
                     const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              TextWidget.paraText(
                                                text: formatDate(mandate.regnDate ?? ''),
                                                theme: theme.isDarkMode,
                                                color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
                                                fw: 0,
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: colors.colorGrey,
                              ),
                              const SizedBox(height: 16),
                              TextWidget.subText(
                                text: "No Mandates Found",
                                theme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? colors.textPrimaryDark
                                    : colors.textPrimaryLight,
                                fw: 0,
                              ),
                              const SizedBox(height: 8),
                              TextWidget.paraText(
                                text: "Create a new mandate to get started",
                                theme: theme.isDarkMode,
                                color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
                                fw: 0,
                              ),
                            ],
                          ),
                        ),
                ),
                // Create Mandate Button at bottom
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (BuildContext context) {
                            return const CreateMandateDialogue();
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        minimumSize: const Size(0, 45),
                        backgroundColor: !theme.isDarkMode
                            ? colors.primaryLight
                            : colors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: TextWidget.subText(
                        text: "Create New Mandate",
                        theme: !theme.isDarkMode,
                        color:  colors.colorWhite,
                        fw: 2,
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
}

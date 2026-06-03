import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'dart:html' as html;
import 'tv_chart/chart_iframe_guard.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/res.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../sharedWidget/common_text_fields_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class SetAlertWeb extends StatefulWidget {
  final GetQuotes depthdata;
  final DepthInputArgs wlvalue;
  const SetAlertWeb(
      {super.key, required this.depthdata, required this.wlvalue});

  @override
  State<SetAlertWeb> createState() => _SetAlertWebState();
}

class _SetAlertWebState extends State<SetAlertWeb> {
  bool _handlesetalert = false;
  TextEditingController valueCtrl = TextEditingController();
  TextEditingController remark = TextEditingController();
  final List<String> alterItems = ['Above', 'Below'];
  final List<String> alertType = ["LTP"];
  String alertValue = "";
  String alertTypeVal = "";
  String validityTypeVal = "";
  String errorText = "";
 
  bool _valueTouched = false;
  late GetQuotes depthdata;

  @override
  void initState() {
    alertValue = alterItems[0];
    alertTypeVal = alertType[0];
    // Initialize with widget data
    depthdata = widget.depthdata;
    super.initState();
  }

  // Process depth data with socket updates
  void _processDepthData(Map<String, dynamic> socketData) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          // Price fields are nullable post-sanitisation (null when broker
          // emits "0"/"0.00" defaults for illiquid contracts). Fall back
          // to "0.00" so downstream double.parse() doesn't see "null".
          depthdata.ap = "${socketData['ap']}";
          depthdata.lp = socketData['lp']?.toString() ?? "0.00";
          depthdata.pc = socketData['pc']?.toString() ?? "0.00";
          depthdata.o = socketData['o']?.toString() ?? "0.00";
          depthdata.l = socketData['l']?.toString() ?? "0.00";
          depthdata.c = socketData['c']?.toString() ?? "0.00";
          depthdata.chng = socketData['chng']?.toString() ?? "0.00";
          depthdata.h = socketData['h']?.toString() ?? "0.00";
          depthdata.poi = "${socketData['poi']}";
          depthdata.v = "${socketData['v']}";
          depthdata.toi = "${socketData['toi']}";
        });
      }
    });
  }

  validatesetalret(value) {
    try {
      if (value == null || value.isEmpty) {
        // Only surface the empty-field error if the user has actually
        // interacted with the Value field, or if validation was triggered
        // by clicking Set Alert (caller flips _valueTouched first). This
        // prevents a red error from appearing on the untouched Value
        // field when the user merely flips Above/Below.
        errorText = _valueTouched ? "Alert Price cannot be empty" : "";
        return;
      }

      if (alertTypeVal == "LTP" && value.isNotEmpty) {
        double enteredValue = double.parse(value);
        double currentLtp = double.parse(depthdata.lp ?? "0.0");

        // Format numbers to always show 2 decimal places
        String formattedLtp = currentLtp.toStringAsFixed(2);
        String formattedEnteredValue = enteredValue.toStringAsFixed(2);

        if (alertValue == "Above" && enteredValue <= currentLtp) {
          errorText =
              "The Current LTP (₹$formattedLtp) is already above ₹$formattedEnteredValue";
        } else if (alertValue == "Below" && enteredValue >= currentLtp) {
          errorText =
              "The Current LTP (₹$formattedLtp) is already below ₹$formattedEnteredValue";
        } else {
          errorText = "";
        }
      }
      //  else if (alertTypeVal == "Perc.Change") {
      //   errorText = "";
      // }
      else {
        errorText = "";
      }
    } catch (e) {
      errorText = "Please enter a valid number";
    }
  }

  // Directly disable all chart iframes and reset cursor (like chart's onExit)
  void _disableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement &&
            iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'none';
          // Reset cursor style to prevent cursor bleeding
          iframe.style.cursor = 'default';
        }
      }
      // Also reset cursor on document body to ensure it's reset globally
      html.document.body?.style.cursor = 'default';
    } catch (e) {
    }
  }

  void _enableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement &&
            iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'auto';
          iframe.style.cursor = '';
        }
      }
      html.document.body?.style.cursor = '';
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, WidgetRef ref, _) {
        final scripInfo = ref.watch(marketWatchProvider);

        return PointerInterceptor(
          child: MouseRegion(
            cursor: SystemMouseCursors.basic,
            onEnter: (_) {
              ChartIframeGuard.acquire();
              _disableAllChartIframes();
            },
            onHover: (_) {
              _disableAllChartIframes();
            },
            onExit: (_) {
              ChartIframeGuard.release();
              _enableAllChartIframes();
            },
            child: Listener(
              onPointerMove: (_) {
                _disableAllChartIframes();
              },
              child: Dialog(
                backgroundColor: resolveThemeColor(context,
                    dark: MyntColors.dialogDark,
                    light: MyntColors.backgroundColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Container(
                  width: 350,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: shadcn.Theme.of(context)
                                    .colorScheme
                                    .border),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            StreamBuilder<Map>(
                              stream:
                                  ref.watch(websocketProvider).socketDataStream,
                              builder: (context, snapshot) {
                                final socketDatas = snapshot.data ?? {};

                                // Update depth data with WebSocket data if available
                                if (socketDatas
                                    .containsKey(widget.wlvalue.token)) {
                                  _processDepthData(
                                      socketDatas[widget.wlvalue.token]);
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${widget.wlvalue.symbol.toUpperCase()} ${widget.wlvalue.option}",
                                      style: MyntWebTextStyles.title(
                                        context,
                                        fontWeight: MyntFonts.medium,
                                        color: resolveThemeColor(
                                          context,
                                          dark: MyntColors.textPrimaryDark,
                                          light: MyntColors.textPrimary,
                                        ),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          "${depthdata.lp != "null" ? depthdata.lp ?? depthdata.c ?? 0.00 : '0.00'}",
                                          style: MyntWebTextStyles.price(
                                            context,
                                            fontWeight: MyntFonts.medium,
                                            color: (depthdata.chng == "null" ||
                                                        depthdata.chng ==
                                                            null) ||
                                                    depthdata.chng == "0.00"
                                                ? resolveThemeColor(
                                                    context,
                                                    dark: MyntColors
                                                        .textSecondaryDark,
                                                    light: MyntColors
                                                        .textSecondary,
                                                  )
                                                : depthdata.chng!
                                                            .startsWith("-") ||
                                                        depthdata.pc!
                                                            .startsWith("-")
                                                    ? resolveThemeColor(
                                                        context,
                                                        dark:
                                                            MyntColors.lossDark,
                                                        light: MyntColors.loss,
                                                      )
                                                    : resolveThemeColor(
                                                        context,
                                                        dark: MyntColors
                                                            .profitDark,
                                                        light:
                                                            MyntColors.profit,
                                                      ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "${(double.tryParse(depthdata.chng ?? '0.00') ?? 0.00).toStringAsFixed(2)} (${(double.tryParse(depthdata.pc ?? '0.00') ?? 0.00).toStringAsFixed(2)}%)",
                                          style: MyntWebTextStyles.priceChange(
                                            context,
                                            fontWeight: MyntFonts.medium,
                                            color: resolveThemeColor(
                                              context,
                                              dark: MyntColors.textPrimaryDark,
                                              light: MyntColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            MyntCloseButton(
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      // Content
                      SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 16, right: 16, bottom: 16, top: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Type Field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Type',
                                    style: MyntWebTextStyles.body(
                                      context,
                                      fontWeight: MyntFonts.semiBold,
                                      color: resolveThemeColor(
                                        context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 45,
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton2(
                                        dropdownStyleData: DropdownStyleData(
                                            decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          color: shadcn.Theme.of(context)
                                              .colorScheme
                                              .background,
                                          border: Border.all(
                                              color: shadcn.Theme.of(context)
                                                  .colorScheme
                                                  .border),
                                        )),
                                        buttonStyleData: ButtonStyleData(
                                            height: 45,
                                            decoration: BoxDecoration(
                                                color: resolveThemeColor(
                                                  context,
                                                  dark: MyntColors.transparent,
                                                  light: MyntColors.searchBg,
                                                ),
                                                border: Border.all(
                                                  color: resolveThemeColor(
                                                    context,
                                                    dark:
                                                        MyntColors.primaryDark,
                                                    light: MyntColors.primary,
                                                  ),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(5))),
                                        isExpanded: true,
                                        menuItemStyleData:
                                            const MenuItemStyleData(
                                          height: 32,
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 0),
                                        ),
                                        style: MyntWebTextStyles.body(
                                          context,
                                          color: resolveThemeColor(
                                            context,
                                            dark: MyntColors.textPrimaryDark,
                                            light: MyntColors.textPrimary,
                                          ),
                                        ),
                                        hint: Text(
                                          alertTypeVal,
                                          style: MyntWebTextStyles.body(
                                            context,
                                            color: resolveThemeColor(
                                              context,
                                              dark:
                                                  MyntColors.textSecondaryDark,
                                              light: MyntColors.textSecondary,
                                            ),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        items: alertType
                                            .map((String item) =>
                                                DropdownMenuItem<String>(
                                                  value: item,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 6),
                                                    child: Text(
                                                      item,
                                                      style: MyntWebTextStyles
                                                          .body(
                                                        context,
                                                        fontWeight:
                                                            MyntFonts.medium,
                                                        color:
                                                            resolveThemeColor(
                                                          context,
                                                          dark: MyntColors
                                                              .textPrimaryDark,
                                                          light: MyntColors
                                                              .textPrimary,
                                                        ),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ))
                                            .toList(),
                                        value: alertTypeVal,
                                        onChanged: (value) {
                                          setState(() {
                                            alertTypeVal = value!;
                                            valueCtrl.clear();
                                          });
                                          validatesetalret(value);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Alert me Field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Alert me',
                                    style: MyntWebTextStyles.body(
                                      context,
                                      fontWeight: MyntFonts.semiBold,
                                      color: resolveThemeColor(
                                        context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 45,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(5),
                                        splashColor: resolveThemeColor(
                                          context,
                                          dark: MyntColors.primaryDark,
                                          light: MyntColors.primary,
                                        ).withOpacity(0.1),
                                        highlightColor: resolveThemeColor(
                                          context,
                                          dark: MyntColors.primaryDark,
                                          light: MyntColors.primary,
                                        ).withOpacity(0.05),
                                        onTap: () {
                                          setState(() {
                                            alertValue = alertValue == "Above"
                                                ? "Below"
                                                : "Above";
                                          });
                                          validatesetalret(valueCtrl.text);
                                        },
                                        child: Container(
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: resolveThemeColor(
                                              context,
                                              dark: MyntColors.transparent,
                                              light: MyntColors.searchBg,
                                            ),
                                            border: Border.all(
                                                color: resolveThemeColor(
                                              context,
                                              dark: MyntColors.primaryDark,
                                              light: MyntColors.primary,
                                            )),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 12),
                                                child: Text(
                                                  alertValue,
                                                  style: MyntWebTextStyles.body(
                                                    context,
                                                    fontWeight:
                                                        MyntFonts.medium,
                                                    color: resolveThemeColor(
                                                      context,
                                                      dark: MyntColors
                                                          .textPrimaryDark,
                                                      light: MyntColors
                                                          .textPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 12),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.code,
                                                      color: resolveThemeColor(
                                                        context,
                                                        dark:
                                                            MyntColors.iconDark,
                                                        light: MyntColors.icon,
                                                      ),
                                                      size: 18,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // ENTER VALUE FIELD
                              Text(
                                'Enter Value',
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.semiBold,
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 45,
                                child: MyntTextField(
                                  controller: valueCtrl,
                                  placeholder: '0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                  ],
                                  textCapitalization: TextCapitalization.none,
                                  size: MyntTextFieldSize.medium,
                                  leadingIcon: assets.ruppeIcon,
                                  textStyle: MyntWebTextStyles.body(
                                    context,
                                    fontWeight: MyntFonts.medium,
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary,
                                    ),
                                  ),
                                  placeholderStyle: MyntWebTextStyles.body(
                                    context,
                                    fontWeight: MyntFonts.medium,
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary,
                                    ),
                                  ),
                                  backgroundColor: resolveThemeColor(
                                    context,
                                    dark: MyntColors.transparent,
                                    light: MyntColors.searchBg,
                                  ),
                                  borderColor: resolveThemeColor(
                                    context,
                                    dark: MyntColors.primaryDark,
                                    light: MyntColors.primary,
                                  ),
                                  onChanged: (value) {
                                    // Any keystroke counts as interaction
                                    // with the Value field — flips the
                                    // touched flag so subsequent empty
                                    // states show the inline error.
                                    _valueTouched = true;
                                    Future.microtask(() {
                                      if (mounted) {
                                        setState(() {
                                          validatesetalret(value);
                                        });
                                      }
                                    });
                                  },
                                ),
                              ),
                              if (errorText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  errorText,
                                  style: MyntWebTextStyles.para(
                                    context,
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.errorDark,
                                      light: MyntColors.error,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              // REMARK FIELD
                              Text(
                                'Remarks',
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.semiBold,
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 80,
                                child: MyntTextField(
                                  controller: remark,
                                  placeholder: 'Remarks',
                                  height: 80,
                                  maxLines: 3,
                                  textCapitalization: TextCapitalization.none,
                                  size: MyntTextFieldSize.medium,
                                  textStyle: MyntWebTextStyles.body(
                                    context,
                                    fontWeight: MyntFonts.medium,
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary,
                                    ),
                                  ),
                                  placeholderStyle: MyntWebTextStyles.body(
                                    context,
                                    fontWeight: MyntFonts.medium,
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary,
                                    ),
                                  ),
                                  backgroundColor: resolveThemeColor(
                                    context,
                                    dark: MyntColors.transparent,
                                    light: MyntColors.searchBg,
                                  ),
                                  borderColor: resolveThemeColor(
                                    context,
                                    dark: MyntColors.primaryDark,
                                    light: MyntColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              Builder(builder: (context) {
                               
                                final bool isDisabled = _handlesetalert;

                                return MyntPrimaryButton(
                                  label: 'Set alert',
                                  isFullWidth: true,
                                  isLoading:
                                      _handlesetalert || scripInfo.loading,
                                  onPressed: isDisabled
                                      ? null
                                      : () async {
                                          setState(() {
                                            _handlesetalert = true;
                                          });

                                          if (valueCtrl.text.isEmpty) {
                                            setState(() {
                                              // Clicking Set Alert counts
                                              // as interaction — flip the
                                              // touched flag so subsequent
                                              // re-validations (e.g. user
                                              // flipping Above/Below)
                                              // keep the empty error
                                              // showing instead of clearing
                                              // it.
                                              _valueTouched = true;
                                              errorText =
                                                  "Alert Price cannot be empty";
                                              _handlesetalert = false;
                                            });
                                            return;
                                          }

                                          if (valueCtrl.text == "0") {
                                            setState(() {
                                              _valueTouched = true;
                                              errorText =
                                                  "Alert Price cannot be 0";
                                              _handlesetalert = false;
                                            });
                                            return;
                                          }

                                          // Re-run validation so the latest
                                          // LTP-above / LTP-below check is
                                          // applied at click time. If the
                                          // entered price is still invalid
                                          // (e.g. "Above" target already below
                                          // current LTP), block the submit.
                                          validatesetalret(valueCtrl.text);
                                          if (errorText.isNotEmpty) {
                                            setState(() {
                                              _handlesetalert = false;
                                            });
                                            return;
                                          }

                                          try {
                                            await ref
                                                .read(marketWatchProvider)
                                                .fetchSetAlertWeb(
                                                  widget.wlvalue.exch,
                                                  widget.wlvalue.tsym,
                                                  valueCtrl.text,
                                                  alertValue == "Above" &&
                                                          alertTypeVal == "LTP"
                                                      ? "LTP_A"
                                                      : alertValue == "Below" &&
                                                              alertTypeVal ==
                                                                  "LTP"
                                                          ? "LTP_B"
                                                          : "LTP_B", // fallback
                                                  context,
                                                  scripInfo.alertPendingModel!
                                                      .length,
                                                  "${depthdata.lp}",
                                                  remark.text,
                                                );
                                          } finally {
                                            if (mounted) {
                                              setState(() {
                                                _handlesetalert = false;
                                              });
                                            }
                                          }
                                        },
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

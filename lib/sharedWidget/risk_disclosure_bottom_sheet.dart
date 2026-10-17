import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mynt_plus/locator/preference.dart';
import '../utils/sebi_message.dart';
import '../../provider/thems.dart';
import '../../res/res.dart';
import '../locator/locator.dart';
import '../res/global_state_text.dart';
import '../res/mynt_web_text_styles.dart';
import '../res/mynt_web_color_styles.dart';
import 'functions.dart';
import 'custom_drag_handler.dart';
import 'common_buttons_web.dart';

class RiskDisclousreBottomSheet extends ConsumerWidget {
  const RiskDisclousreBottomSheet({super.key, this.message});

  /// Today's SEBI message (web dialog). Null on the mobile bottom sheet.
  final SebiMessage? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeProvider);
    final Preferences pref = locator<Preferences>();

    // Check if running on web
    final isWeb = getResponsiveWidth(context) == 600;

    if (isWeb && message != null) {
      // Web dialog UI
      return _SebiWebDialog(message: message!);
    } else {
      // Mobile bottom sheet UI (existing design)
      return _buildMobileBottomSheet(context, theme, pref);
    }
  }

  Widget _buildMobileBottomSheet(
      BuildContext context, ThemesProvider theme, Preferences pref) {
    return SafeArea(
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
            border: Border(
              top: BorderSide(
                color: theme.isDarkMode
                    ? colors.textSecondaryDark.withOpacity(0.5)
                    : colors.colorWhite,
              ),
              left: BorderSide(
                color: theme.isDarkMode
                    ? colors.textSecondaryDark.withOpacity(0.5)
                    : colors.colorWhite,
              ),
              right: BorderSide(
                color: theme.isDarkMode
                    ? colors.textSecondaryDark.withOpacity(0.5)
                    : colors.colorWhite,
              ),
            ),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const CustomDragHandler(),
                const SizedBox(height: 10),
                Row(children: [
                  TextWidget.titleText(
                    text: '  Risk disclosures on derivatives',
                    theme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? colors.textPrimaryDark
                        : colors.textPrimaryLight,
                    fw: 1,
                    textOverflow: TextOverflow.ellipsis,
                  )
                ]),
                Column(children: [
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.circle,
                            size: 9.5, color: colors.primaryLight)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextWidget.subText(
                      text:
                          "9 out of 10 individual traders in the equity Futures and Options (F&O) segment incurred net losses.",
                      theme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? colors.textPrimaryDark
                          : colors.textPrimaryLight,
                      fw: 0,
                    ))
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.circle,
                            size: 9.5, color: colors.primaryLight)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextWidget.subText(
                      text:
                          "On average, the loss-making traders registered a net trading loss close to ₹50,000.",
                      theme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? colors.textPrimaryDark
                          : colors.textPrimaryLight,
                      fw: 0,
                    ))
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.circle,
                            size: 9.5, color: colors.primaryLight)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextWidget.subText(
                      text:
                          "Over and above the net trading losses incurred, loss makers expended an additional 28% of net trading losses as transaction costs.",
                      theme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? colors.textPrimaryDark
                          : colors.textPrimaryLight,
                      fw: 0,
                    ))
                  ]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.circle,
                            size: 9.5, color: colors.primaryLight)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextWidget.subText(
                      text:
                          "Those making net trading profits incurred between 15% to 50% of such profits as transaction costs.",
                      theme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? colors.textPrimaryDark
                          : colors.textPrimaryLight,
                      fw: 0,
                    ))
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    "Source: SEBI study dated January 25, 2023, on 'Analysis of Profit and Loss of Individual Traders dealing in equity Futures and Options (F&O) Segment,' wherein Aggregate Level findings are based on annual Profit/Loss incurred by individual traders in equity F&O during FY 2021-22.",
                    style: TextWidget.textStyle(
                      fontSize: 12,
                      theme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? colors.textSecondaryDark
                          : colors.textSecondaryLight,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12)
                ]),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () async {
                          pref.setRiskDiscloser(true);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: theme.isDarkMode
                                ? colors.primaryDark
                                : colors.primaryLight,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5))),
                        child: TextWidget.subText(
                          text: "I Understand",
                          color: colors.colorWhite,
                          theme: theme.isDarkMode,
                          fw: 2,
                        ),
                      )),
                ),
                const SizedBox(height: 14)
              ])),
    );
  }
}

/// Web dialog content: today's SEBI message (Project Jagrook / Risk Disclosure).
class _SebiWebDialog extends StatefulWidget {
  const _SebiWebDialog({required this.message});

  final SebiMessage message;

  @override
  State<_SebiWebDialog> createState() => _SebiWebDialogState();
}

class _SebiWebDialogState extends State<_SebiWebDialog> {
  final Preferences pref = locator<Preferences>();
  late bool _hindi = widget.message.hi != null && pref.sebiLang == 'hi';

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final block = _hindi ? m.hi! : m.en;
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final textSecondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final accent = _accent(context);
    final hindiFont = _hindi
        ? <String>[GoogleFonts.notoSansDevanagari().fontFamily!]
        : null;
    final kicker = block['kicker'];
    final source = block['source'];
    final note = block['note'];

    return Container(
      width: 500,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark,
            light: MyntColors.backgroundColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: tag + EN / हि switch (only when a Hindi block exists)
          Padding(
            padding:
                const EdgeInsets.only(left: 25, right: 25, top: 20, bottom: 4),
            child: Row(
              children: [
                Text(
                  m.isRisk ? 'Risk Disclosure' : 'Project Jagrook',
                  style: MyntWebTextStyles.title(
                    context,
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (m.hi != null) ...[
                  _langChip('EN', !_hindi, () => _setLang(false)),
                  const SizedBox(width: 6),
                  _langChip('हि', _hindi, () => _setLang(true)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
            child: Column(
              children: [
                if (kicker is String && kicker.isNotEmpty)
                  Text(
                    kicker,
                    textAlign: TextAlign.center,
                    style: MyntWebTextStyles.body(
                      context,
                      color: accent,
                      fontWeight: FontWeight.w500,
                    ).copyWith(fontFamilyFallback: hindiFont),
                  ),
                Text(
                  block['title'] as String,
                  textAlign: TextAlign.center,
                  style: MyntWebTextStyles.title(
                    context,
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ).copyWith(fontFamilyFallback: hindiFont),
                ),
              ],
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 25, right: 25, bottom: 16, top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final point in block['points'] as List) ...[
                      _bullet(point.toString(), textPrimary, hindiFont),
                      const SizedBox(height: 12),
                    ],
                    if (source is String && source.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        source,
                        style: MyntWebTextStyles.para(
                          context,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ).copyWith(height: 1.4, fontFamilyFallback: hindiFont),
                      ),
                    ],
                    if (note is String && note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: MyntWebTextStyles.para(
                          context,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ).copyWith(height: 1.4, fontFamilyFallback: hindiFont),
                      ),
                    ],
                    const SizedBox(height: 24),
                    MyntPrimaryButton(
                      label: 'I Understand',
                      isFullWidth: true,
                      onPressed: () {
                        pref.setSebiAck(m.ackValue);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setLang(bool hindi) {
    pref.setSebiLang(hindi ? 'hi' : 'en');
    setState(() => _hindi = hindi);
  }

  // Dark mode uses the secondary blue for accents (button stays primary).
  Color _accent(BuildContext context) => resolveThemeColor(context,
      dark: MyntColors.secondaryDark, light: MyntColors.primary);

  Widget _langChip(String label, bool selected, VoidCallback onTap) {
    final accent = _accent(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 44,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          border: Border.all(color: accent),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: MyntWebTextStyles.caption(
            context,
            color: selected ? Colors.white : accent,
            fontWeight: FontWeight.w600,
          ).copyWith(fontFamilyFallback: [
            GoogleFonts.notoSansDevanagari().fontFamily!
          ]),
        ),
      ),
    );
  }

  Widget _bullet(String text, Color color, List<String>? fontFallback) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent(context),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: MyntWebTextStyles.body(
              context,
              color: color,
              fontWeight: FontWeight.w500,
            ).copyWith(height: 1.5, fontFamilyFallback: fontFallback),
          ),
        ),
      ],
    );
  }
}

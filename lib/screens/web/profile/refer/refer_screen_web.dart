import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../locator/locator.dart';
import '../../../../locator/preference.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/common_text_fields_web.dart';
import '../../../../sharedWidget/snack_bar.dart';

class ReferScreenWeb extends ConsumerStatefulWidget {
  const ReferScreenWeb({super.key});

  @override
  ConsumerState<ReferScreenWeb> createState() => _ReferScreenWebState();
}

class _ReferScreenWebState extends ConsumerState<ReferScreenWeb> {
  /// Line height and visible line count of the editable message. Both are
  /// fixed so the message box has one exact height, which keeps the card row
  /// measurable (see `_buildMessagePreview`).
  static const double _messageLineHeight = 1.55;
  static const int _messageLines = 3;

  /// Width the chat preview takes in the hero row. It sits alone beside the
  /// copy now that the banner artwork is gone, so it gets the freed space.
  static const double _chatWidth = 420;

  /// Extra gap between the chat column and the hero card's right padding, so
  /// the bubbles are not pinned to the card edge.
  static const double _chatRightInset = 82;

  late final TextEditingController _linkController;
  late final _LinkHighlightController _messageController;
  late final String _refLink;
  late final String _avatarInitial;

  @override
  void initState() {
    super.initState();
    final Preferences pref = locator<Preferences>();
    _refLink = 'https://oa.mynt.in/?ref=${pref.clientId ?? ''}';
    _linkController = TextEditingController(text: _refLink);
    _messageController = _LinkHighlightController(text: _defaultMessage);
    final name = (pref.clientName ?? '').trim();
    _avatarInitial = name.isEmpty ? 'A' : name[0].toUpperCase();
  }

  /// The message we pre-write for the user, and what "Reset" restores.
  String get _defaultMessage =>
      "Hey! I've been trading with Zebu for a while, and it's honestly made "
      "things easier for me. I thought of you — if you're ever planning to "
      'start investing, this is my link: $_refLink';

  /// Single source for the referral message, so whatever the user has edited
  /// in the box is exactly what WhatsApp / the share sheet sends.
  String get _shareMessage => _messageController.text.trim();

  @override
  void dispose() {
    _linkController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.borderMutedDark, light: MyntColors.borderMuted);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroCard(context, borderColor),
          const SizedBox(height: 24),
          // IntrinsicHeight bounds the row so both cards can stretch to the
          // taller one; plain stretch would resolve to an infinite height
          // inside the scroll view.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildShareLinkCard(context, borderColor)),
                const SizedBox(width: 24),
                Expanded(child: _buildReferActionsCard(context, borderColor)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildStepsSection(context, borderColor),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(Color borderColor) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: borderColor, width: 1),
    );
  }

  /// Supporting copy across the page. Carried at medium weight — and at the
  /// primary text colour in dark mode, where the secondary grey reads too
  /// faint — so the descriptions hold their own next to the headings.
  TextStyle _bodyCopy(BuildContext context) => MyntWebTextStyles.body(
        context,
        fontWeight: MyntFonts.medium,
        darkColor: MyntColors.textPrimaryDark,
        lightColor: MyntColors.textSecondary,
      );

  /// Every card / section heading on the page.
  TextStyle _headingCopy(BuildContext context) => MyntWebTextStyles.body(
        context,
        fontWeight: MyntFonts.bold,
        darkColor: MyntColors.textPrimaryDark,
        lightColor: MyntColors.textPrimary,
      );

  Widget _buildHeroCard(BuildContext context, Color borderColor) {
    final bool dark = isDarkMode(context);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final surface = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);

    // Left-to-right brand wash: plain surface under the copy, deepening to a
    // blue tint under the conversation so the white bubble lifts off it.
    // Hero only — the cards below keep their flat `_cardDecoration`.
    Color tint(double alpha) =>
        Color.alphaBlend(primaryColor.withValues(alpha: alpha), surface);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
        // gradient: LinearGradient(
        //   begin: Alignment.centerLeft,
        //   end: Alignment.centerRight,
        //   colors: dark
        //       ? [surface, tint(0.03), tint(0.09), tint(0.16)]
        //       : [surface, tint(0.05), tint(0.13), tint(0.26)],
        //   stops: const [0.0, 0.42, 0.72, 1.0],
        // ),
      ),
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Copy | chat side by side when there is room, stacked otherwise.
          final bool isWide = constraints.maxWidth >= 720;
          final copy = _buildHeroCopy(context);
          final chat = _buildChatPreview(context);

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 20),
                chat,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 32),
              Padding(
                padding: const EdgeInsets.only(right: _chatRightInset),
                child: SizedBox(width: _chatWidth, child: chat),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroCopy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Refer your friends to Zebu',
          style: MyntWebTextStyles.body(
            context,
            fontWeight: MyntFonts.bold,
            darkColor: MyntColors.primaryDark,
            lightColor: MyntColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: webText(
              context,
              size: 28,
              weight: MyntFonts.bold,
              height: 1.25,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
            ),
            children: [
              const TextSpan(text: 'Your '),
              TextSpan(
                text: 'word',
                style: webText(
                  context,
                  size: 28,
                  weight: MyntFonts.bold,
                  height: 1.25,
                  darkColor: MyntColors.primaryDark,
                  lightColor: MyntColors.primary,
                ),
              ),
              const TextSpan(text: ' is worth more'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Someone once helped you take your first step in the market. '
            "Now it's your turn. Share Zebu with the friends and family you "
            'want to see grow — because their journey matters to you.',
            style: _bodyCopy(context),
          ),
        ),
      ],
    );
  }

  /// The "You, to a friend" conversation from the hero.
  Widget _buildChatPreview(BuildContext context) {
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final successColor = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final bubbleColor = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _chatWidth),
      child: _buildChatBubbles(
        context,
        primaryColor: primaryColor,
        successColor: successColor,
        bubbleColor: bubbleColor,
      ),
    );
  }

  Widget _buildChatBubbles(
    BuildContext context, {
    required Color primaryColor,
    required Color successColor,
    required Color bubbleColor,
  }) {
    final bool dark = isDarkMode(context);
    // Messaging-app fills: the outgoing bubble stays on the plain surface so
    // it reads white against the hero's tinted wash, and the reply takes the
    // pale mint mixed from the theme's profit green.
    final Color replyFill = Color.alphaBlend(
      successColor.withValues(alpha: dark ? 0.22 : 0.16),
      bubbleColor,
    );
    // Tinted borders matching the screenshot: primary-blue for the outgoing
    // bubble, success-green for the reply. Slightly more opaque in dark mode
    // so they hold against the darker surface.
    final Border outgoingBorder = Border.all(
      color: primaryColor.withValues(alpha: dark ? 0.35 : 0.22),
      width: 1,
    );
    final Border replyBorder = Border.all(
      color: successColor.withValues(alpha: dark ? 0.45 : 0.30),
      width: 1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Outgoing message
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(8),
            border: outgoingBorder,
            boxShadow: dark ? MyntShadows.cardDark : MyntShadows.card,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _avatarInitial,
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    fontWeight: MyntFonts.bold,
                    color: dark ? MyntColors.textBlack : MyntColors.textWhite,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You, to a friend',
                      style: MyntWebTextStyles.para(
                        context,
                        fontWeight: MyntFonts.bold,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '"I\'ve been trading with Zebu for a while now. '
                      'Thought of you — I think you\'d really like it."',
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        fontWeight: MyntFonts.medium,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                      ).copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Reply
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: replyFill,
                borderRadius: BorderRadius.circular(8),
                border: replyBorder,
                boxShadow: dark ? MyntShadows.cardDark : MyntShadows.card,
              ),
              child: Text(
                '"That means a lot. Send me the link!"',
                style: MyntWebTextStyles.bodySmall(
                  context,
                  fontWeight: MyntFonts.medium,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ).copyWith(height: 1.45),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShareLinkCard(BuildContext context, Color borderColor) {
    return Container(
      decoration: _cardDecoration(borderColor),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '1.',
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.bold,
                  darkColor: MyntColors.primaryDark,
                  lightColor: MyntColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text('Share your referral link', style: _headingCopy(context)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Copy the referral link below and share it with your family and friends.',
            style: _bodyCopy(context),
          ),
          const SizedBox(height: 16),
          MyntTextField(
            controller: _linkController,
            placeholder: 'Referral link',
            readOnly: true,
            textStyle: MyntWebTextStyles.input(
              context,
              fontWeight: MyntFonts.semiBold,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
            ),
            leadingWidget: Icon(
              Icons.person_outline,
              size: 18,
              color: resolveThemeColor(context,
                  dark: MyntColors.iconDark, light: MyntColors.icon),
            ),
            trailingWidget: IconButton(
              icon: Icon(
                Icons.copy,
                size: 18,
                color: resolveThemeColor(context,
                    dark: MyntColors.iconDark, light: MyntColors.icon),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _refLink));
                successMessage(context, 'Referral link copied!');
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferActionsCard(BuildContext context, Color borderColor) {
    return Container(
      decoration: _cardDecoration(borderColor),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '2.',
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.bold,
                  darkColor: MyntColors.primaryDark,
                  lightColor: MyntColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text('Refer your family and friends',
                  style: _headingCopy(context)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "We've written the message for you — edit it, or send it as is.",
            style: _bodyCopy(context),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  final message = Uri.encodeComponent(_shareMessage);
                  launchUrl(
                    Uri.parse('https://wa.me/?text=$message'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.chat, color: Colors.white, size: 18),
                label: Text(
                  'Refer on whatsapp',
                  style: MyntWebTextStyles.buttonXl(context,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
                  minimumSize: const Size(0, 35),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {
                  Share.share(_shareMessage);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 35),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  // Brand-tinted outline instead of the muted grey, so the
                  // secondary action still reads as a button.
                  side: BorderSide(
                    color: resolveThemeColor(context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary)
                        .withValues(alpha: 0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
                  'More ways to share',
                  style: MyntWebTextStyles.buttonXl(
                    context,
                    darkColor: MyntColors.primaryDark,
                    lightColor: MyntColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMessagePreview(context),
        ],
      ),
    );
  }

  /// The pre-written WhatsApp message, shown below the share buttons.
  /// Editable, so the user can reword it before sending, and copyable.
  Widget _buildMessagePreview(BuildContext context) {
    final successColor = resolveThemeColor(context,
        dark: MyntColors.successDark, light: MyntColors.success);
    final iconColor = resolveThemeColor(context,
        dark: MyntColors.iconDark, light: MyntColors.icon);
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.borderMutedDark, light: MyntColors.borderMuted);

    final textStyle = MyntWebTextStyles.bodySmall(
      context,
      fontWeight: MyntFonts.semiBold,
      darkColor: MyntColors.textPrimaryDark,
      lightColor: MyntColors.textPrimary,
    ).copyWith(height: _messageLineHeight);
    final hintStyle = textStyle.copyWith(
      fontWeight: MyntFonts.regular,
      color: resolveThemeColor(context,
          dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary),
    );

    // Keeps the referral URL tinted while the text stays editable.
    _messageController.linkColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    return Container(
      width: double.infinity,
      // No fixed height — the card grows with the text at every viewport
      // width. IntrinsicHeight below makes the green accent rail stretch
      // to match the field's natural height.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.listItemBgDark, light: MyntColors.listItemBg),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent rail — stretches to the card's natural height.
            Container(width: 3, color: successColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        // Dynamic: grows line by line; no upper cap so the
                        // full message is always visible without scrolling.
                        maxLines: null,
                        minLines: _messageLines,
                        textAlignVertical: TextAlignVertical.top,
                        style: textStyle,
                        cursorColor: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Write your own message',
                          hintStyle: hintStyle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'Reset',
                      child: IconButton(
                        icon: Icon(Icons.refresh, size: 18, color: iconColor),
                        onPressed: () {
                          _messageController.text = _defaultMessage;
                          successMessage(context, 'Message reset');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Tooltip(
                      message: 'Copy message',
                      child: IconButton(
                        icon: Icon(Icons.copy, size: 18, color: iconColor),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _shareMessage));
                          successMessage(context, 'Message copied!');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "How it works" strip closing out the page.
  Widget _buildStepsSection(BuildContext context, Color borderColor) {
    const steps = <_ReferStep>[
      _ReferStep(
        number: '1',
        title: 'Copy your link',
        detail: 'It identifies you as the referrer — nothing else changes.',
      ),
      _ReferStep(
        number: '2',
        title: 'Share it with someone',
        detail: 'WhatsApp works best. Your words, or ours.',
      ),
      _ReferStep(
        number: '3',
        title: 'They start in minutes',
        detail: 'Fully digital account opening. You just helped someone you '
            'care about take their first step.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Three steps, start to finish',
          style: MyntWebTextStyles.head(
            context,
            fontWeight: MyntFonts.bold,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Copy your link, share it with someone you care about, and they '
          'open their account in minutes.',
          style: _bodyCopy(context),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final step in steps) ...[
                    _buildStepCard(context, borderColor, step),
                    if (step != steps.last) const SizedBox(height: 16),
                  ],
                ],
              );
            }

            // IntrinsicHeight gives the row a bounded height so the cards can
            // stretch to match the tallest one; plain stretch would resolve to
            // an infinite height inside the scroll view.
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final step in steps) ...[
                    Expanded(child: _buildStepCard(context, borderColor, step)),
                    if (step != steps.last) const SizedBox(width: 24),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStepCard(
    BuildContext context,
    Color borderColor,
    _ReferStep step,
  ) {
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    return Container(
      decoration: _cardDecoration(borderColor),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.number,
            style: webText(
              context,
              size: 24,
              weight: MyntFonts.bold,
              height: 1.1,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: _headingCopy(context)),
                const SizedBox(height: 6),
                Text(step.detail, style: _bodyCopy(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferStep {
  const _ReferStep({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;
}

/// Editable controller that tints any URL inside the text, so the referral
/// link reads as a link while the message stays fully editable.
class _LinkHighlightController extends TextEditingController {
  _LinkHighlightController({super.text});

  static final RegExp _urlPattern = RegExp(r'https?://\S+');

  Color? linkColor;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final color = linkColor;
    if (color == null) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final String source = text;
    final List<TextSpan> spans = [];
    int cursor = 0;

    for (final match in _urlPattern.allMatches(source)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: source.substring(cursor, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(color: color, fontWeight: MyntFonts.semiBold),
      ));
      cursor = match.end;
    }
    if (cursor < source.length) {
      spans.add(TextSpan(text: source.substring(cursor)));
    }

    return TextSpan(style: style, children: spans);
  }
}

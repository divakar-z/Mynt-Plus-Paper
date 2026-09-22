import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/support_ticket_model/support_html.dart';
import '../../../../models/support_ticket_model/support_ticket.dart';
import '../../../../provider/sidebar_provider.dart';
import '../../../../provider/support_ticket_provider.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/res.dart';
import '../../../../sharedWidget/common_buttons_web.dart';
import '../../../../sharedWidget/no_data_found_web.dart';
import '../../../../sharedWidget/snack_bar.dart';
import 'profile_circle.dart';
import 'support_bubble_shape.dart';
import 'support_download.dart';
import 'support_skeleton.dart';
import 'support_status_badge.dart';

/// Opens a ticket in the app's right-hand sidebar.
///
/// Uses [sidebarProvider] and the shell's `endDrawer`, which is how Holding
/// Details opens — a 400px square-cornered panel with no scrim, so the list
/// stays readable behind it. Not a dialog of our own: a second side-panel
/// mechanism would drift from that one the first time either changed.
void showTicketDetailPanel(
  WidgetRef ref, {
  required Color borderColor,
  required Color primaryColor,
  required VoidCallback onClose,
}) {
  ref.read(sidebarProvider.notifier)
    ..setSidebar(
      // Its own Material, edge to edge, as Holding Details does. Without it the
      // Drawer's default surface shows around the padded content as a band of
      // a slightly different colour down the side.
      // No padding. The header and the composer carry their own insets, so a
      // gutter here only pushed the thread away from the panel edges.
      Material(
        color: Colors.transparent,
        child: TicketDetailView(
          borderColor: borderColor,
          primaryColor: primaryColor,
          onBack: onClose,
        ),
      ),
      // A conversation needs more room than the 400 that suits a column of
      // label/value rows — capped so it never eats a small window whole.
      width: _panelWidth(ref),
    )
    ..openSidebar();
}

/// Panel width: roomy on a desktop, most of the window on something narrow.
double _panelWidth(WidgetRef ref) {
  final width = MediaQuery.sizeOf(ref.context).width;
  if (width < 620) return width * 0.92;
  return (width * 0.42).clamp(560.0, 760.0);
}

/// One ticket: its header, the conversation, and the reply box.
class TicketDetailView extends ConsumerWidget {
  const TicketDetailView({
    super.key,
    required this.borderColor,
    required this.primaryColor,
    required this.onBack,
  });

  final Color borderColor;
  final Color primaryColor;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(supportTicketProvider);
    final ticket = provider.activeTicket;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The header keeps its inset. Only the thread and the composer run to
        // the panel edges — a title pressed against the border reads as
        // clipped rather than as flush.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: _header(context, provider, ticket),
        ),
        Expanded(
          // The shadow is cast *by* the header but drawn as an overlay at the
          // top of the thread. In a Column the header paints first, so a
          // BoxShadow on it would be painted over by the thread's own
          // background the moment that covered the same pixels.
          child: Stack(
            children: [
              Positioned.fill(
                child: provider.activeError != null && ticket == null
                    ? ColoredBox(
                        color: resolveThemeColor(context,
                            dark: const Color(0xFF0D1117),
                            light: const Color(0xFFFAFAFB)),
                        child: Center(child: _errorState(provider)),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                              child: _conversation(context, provider, ticket)),
                          _replyBox(context, provider),
                        ],
                      ),
              ),
              // Ignores pointers, or it would eat taps on the first message.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 6,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.07),
                          Colors.black.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Header --------------------------------------------------------------

  Widget _header(
    BuildContext context,
    SupportTicketProvider provider,
    SupportTicket? ticket,
  ) {
    return Row(
      // Centre, not start: the close button is shorter than the title stack,
      // and top-aligning it left the ✕ riding high against the subject.
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // The subject leads. It is what the ticket is *about*, and the
              // only line here with anything to truncate — giving it the full
              // width means far less of it is lost.
              Text(
                ticket?.subject.isNotEmpty == true ? ticket!.subject : 'Ticket',
                // One line. Two let a long subject double the header's height,
                // and the full text is on the row that opened this panel.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MyntWebTextStyles.title(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
              ),
              if (ticket != null) ...[
                const SizedBox(height: 2),
                // Number and status share the line beneath — both are short,
                // and neither needs a row of its own.
                Row(
                  children: [
                    Text(
                      '#' + ticket.number,
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        fontWeight: MyntFonts.medium,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SupportStatusBadge(ticket.status, dense: true),
                    // The category the client picked when raising it, after
                    // the help topic it was filed under — "General ·
                    // Brokerage". The one filing choice they make, and until
                    // now the panel showed it nowhere: it arrives inside
                    // `custom_fields` as a label, which nothing here rendered.
                    //
                    // Flexible, not Expanded: it takes only the width it needs
                    // and gives the rest back, so a ticket with no category
                    // does not leave a gap beside the status badge.
                    if (ticket.categoryPath.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          ticket.categoryPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            fontWeight: MyntFonts.regular,
                            darkColor: MyntColors.textSecondaryDark,
                            lightColor: MyntColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Opposite the title, where a panel's dismiss belongs — on the left it
        // read as a back arrow for the list rather than a close for the panel.
        //
        // The pop runs on *this* context, the one inside the drawer: an
        // endDrawer is not a route on the page's navigator, so popping the
        // screen's context does nothing.
        MyntIconButton(
          icon: Icons.close,
          onPressed: () {
            final root = Navigator.of(context, rootNavigator: true);
            if (root.canPop()) {
              root.pop();
            } else {
              Navigator.of(context).pop();
            }
            onBack();
          },
        ),
      ],
    );
  }

  // --- Conversation --------------------------------------------------------

  /// Consecutive entries by the same author, of the same type, closer together
  /// than this collapse into one visual run: the name and time appear once and
  /// the follow-ups are bare bubbles.
  ///
  /// Without it a burst of replies repeats the same name four times and reads
  /// noisier than a plain list.
  static const Duration _kGroupWindow = Duration(minutes: 10);

  /// Held back from every bubble so the far side always reads as empty gutter —
  /// the gutter *is* the directional cue. Deliberately modest: the tint already
  /// says which side an entry is on, and the panel is narrow.
  static const double _kGutter = 96;

  static const double _kAvatarSize = 28;
  static const double _kAvatarGap = 8;

  bool _groupsWith(SupportThreadEntry entry, SupportThreadEntry? prev) {
    if (prev == null) return false;
    if (prev.poster != entry.poster || prev.type != entry.type) return false;
    final a = prev.created, b = entry.created;
    if (a == null || b == null) return false;
    return b.difference(a).abs() <= _kGroupWindow;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// True when the body says nothing the attachment list does not already say.
  ///
  /// Every upload posts its own `Attachment: <filename>` message — that is how
  /// osTicket models a client-attached file — so without this the name lands
  /// twice, once as a message and again in the file list below.
  ///
  /// Only an exact echo is suppressed: a real message that merely opens with
  /// the word "Attachment:" still has to be shown.
  bool _isAttachmentEcho(String plain, List<SupportAttachment> files) {
    if (files.isEmpty) return false;
    var s = plain.trim();
    final match =
        RegExp(r'^Attachments?\s*:\s*', caseSensitive: false).firstMatch(s);
    if (match == null) return false;
    s = s.substring(match.end).trim();
    for (final file in files) {
      s = s.replaceFirst(file.name, '').trim();
      s = s.replaceFirst(RegExp(r'^[,;]\s*'), '');
    }
    return s.isEmpty;
  }

  Widget _conversation(
    BuildContext context,
    SupportTicketProvider provider,
    SupportTicket? ticket,
  ) {
    if (provider.loadingActive && (ticket?.thread.isEmpty ?? true)) {
      return _loadingThread(context);
    }
    final thread = ticket?.thread ?? const [];
    final files = provider.activeAttachments;

    if (thread.isEmpty) {
      return Center(
        child: NoDataFoundWeb(
          title: 'Nothing here yet',
          subtitle: 'Messages on this ticket will appear here.',
          assetIcon: assets.documentIcon,
          iconSize: 100,
          primaryEnabled: false,
          secondaryEnabled: false,
        ),
      );
    }

    // Built as a flat list with the dividers already interleaved, rather than
    // grouped into sections — a divider is just another row, and treating it
    // as one keeps the grouping logic reading one entry at a time.
    // Attachments carry the id of the entry they were posted with, so they can
    // sit under their own message rather than in one pile at the end. Anything
    // whose entry is missing — a file on an entry the client cannot see — falls
    // through to the trailing block instead of vanishing.
    final byEntry = <int, List<SupportAttachment>>{};
    final orphans = <SupportAttachment>[];
    final entryIds = {for (final e in thread) e.id};
    for (final file in files) {
      final id = file.threadEntryId;
      if (id != null && entryIds.contains(id)) {
        byEntry.putIfAbsent(id, () => []).add(file);
      } else {
        orphans.add(file);
      }
    }

    final items = <Widget>[];
    DateTime? lastDay;
    SupportThreadEntry? prev;

    for (final entry in thread) {
      final created = entry.created;
      if (created != null && (lastDay == null || !_sameDay(lastDay, created))) {
        items.add(_dateDivider(context, created));
        lastDay = created;
        // The first row under a divider never groups with the one above it,
        // however close in time — the divider has already broken the run.
        prev = null;
      }
      items.add(_threadRow(
          context, provider, entry, prev, byEntry[entry.id] ?? const []));
      prev = entry;
    }

    if (orphans.isNotEmpty) {
      items.add(_attachmentsBlock(context, provider, orphans));
    }

    return ColoredBox(
      color: resolveThemeColor(context,
          dark: const Color(0xFF0D1117), light: const Color(0xFFFAFAFB)),
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          children: items,
        ),
      ),
    );
  }

  /// Placeholder bubbles while the conversation loads.
  ///
  /// Alternating sides, because a thread is a conversation — a column of
  /// same-side blocks would set up a shape the real data then contradicts.
  Widget _loadingThread(BuildContext context) {
    const widths = [180.0, 240.0, 150.0, 210.0];
    return SupportSkeletonGroup(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        itemCount: widths.length,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final mine = index.isOdd;
          return Padding(
            padding: EdgeInsets.only(
              bottom: 14,
              left: mine ? _kGutter : 0,
              right: mine ? 0 : _kGutter,
            ),
            child: Row(
              mainAxisAlignment:
                  mine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!mine) ...[
                  const SupportSkeleton(
                      width: _kAvatarSize, height: _kAvatarSize, radius: 99),
                  const SizedBox(width: _kAvatarGap),
                ],
                Column(
                  crossAxisAlignment:
                      mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    const SupportSkeleton(width: 96, height: 10),
                    const SizedBox(height: 6),
                    SupportSkeleton(
                        width: widths[index], height: 38, radius: 10),
                  ],
                ),
                if (mine) ...[
                  const SizedBox(width: _kAvatarGap),
                  const SupportSkeleton(
                      width: _kAvatarSize, height: _kAvatarSize, radius: 99),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dateDivider(BuildContext context, DateTime day) {
    final rule = Expanded(
      child: Container(
        height: 1,
        color: borderColor.withOpacity(0.7),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: Row(
        children: [
          rule,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _dayLabel(day).toUpperCase(),
              style: MyntWebTextStyles.caption(
                context,
                fontWeight: MyntFonts.semiBold,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
              ).copyWith(letterSpacing: 0.6),
            ),
          ),
          rule,
        ],
      ),
    );
  }

  /// One message.
  ///
  /// The name and time strip sits **outside** the bubble. Inside, it set the
  /// bubble's intrinsic width, so a one-word reply rendered as wide as a full
  /// paragraph and the column read as cards-pushed-to-one-side rather than as
  /// bubbles. Out here the bubble shrink-wraps its text and short messages
  /// finally look short.
  Widget _threadRow(
    BuildContext context,
    SupportTicketProvider provider,
    SupportThreadEntry entry,
    SupportThreadEntry? prev,
    List<SupportAttachment> files,
  ) {
    // The client is "you", so their own messages sit right. Keyed off the
    // entry type rather than the poster name, which an agent can change.
    final mine = entry.isFromClient;
    final grouped = _groupsWith(entry, prev);

    // The echo test runs on plain text: the body arrives as HTML, and
    // "Attachment: x.png" wrapped in a <p> would never match otherwise.
    final plain = supportHtmlToText(entry.body);
    // Matched against this entry's own files now, so the test is exact rather
    // than "does this name appear anywhere on the ticket".
    final echo = _isAttachmentEcho(plain, files);
    // An echo with nothing attached would leave a blank row.
    if (echo && files.isEmpty) return const SizedBox.shrink();

    // Their pair: a neutral grey against a brand-tinted blue. Both sides carry
    // their own fill, so neither depends on the canvas to be visible.
    final surface = mine
        ? resolveThemeColor(context,
            dark: const Color(0xFF16263C), light: const Color(0xFFEEF2FD))
        : resolveThemeColor(context,
            // The bubble carries no border, so this gap against the #FAFAFB
            // canvas is the only thing giving it an edge.
            dark: const Color(0xFF20242B), light: const Color(0xFFEBEDF2));

    final stamp = Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Text(
        _timeOnly(entry.created),
        style: MyntWebTextStyles.caption(
          context,
          fontWeight: MyntFonts.regular,
          darkColor: MyntColors.textSecondaryDark,
          lightColor: MyntColors.textSecondary,
        ),
      ),
    );

    // A short single-line message keeps its time on the same line, which is
    // how a chat reads. Anything longer puts it underneath — inlining a time
    // after a paragraph leaves it stranded mid-sentence at the wrap point.
    final short = !plain.contains('\n') && plain.length <= 56;

    final bubble = Container(
      constraints: const BoxConstraints(minWidth: 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // ShapeDecoration, not BoxDecoration: the tail extends beyond the box
      // and only a ShapeBorder can express that.
      //
      // No hairline. Both sides gained a fill, and an outline on top of a fill
      // made the bubble read as a form field rather than as something someone
      // said.
      decoration: ShapeDecoration(
        color: surface,
        shape: SupportBubbleShape(tailOnRight: mine),
      ),
      // Attachments live *inside* the bubble, above the time — a file is part
      // of the message it arrived with, and a chip floating loose beside a
      // bubble reads as belonging to neither.
      child: Column(
        // Always end, on both sides. The time sits bottom-right of the bubble
        // whichever side it is on — it is a corner stamp, not a signature that
        // follows the speaker. The body is the widest child and so still sets
        // the bubble's width; only the narrow stamp actually moves.
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A body that only echoed the filename is dropped: the chip below
          // already says the name, and an empty line above it says nothing.
          if (!echo && plain.isEmpty)
            Text(
              '(no message)',
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.regular,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
              ),
            )
          else if (!echo && short && files.isEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: _htmlBody(context, entry.body)),
                stamp,
              ],
            )
          else if (!echo)
            _htmlBody(context, entry.body),
          for (var i = 0; i < files.length; i++) ...[
            SizedBox(height: i == 0 && echo ? 0 : 6),
            _attachmentTile(context, provider, files[i]),
          ],
          // The inline case above already carried the time.
          if (echo || files.isNotEmpty || !short) stamp,
        ],
      ),
    );

    // The name alone. The time used to sit beside it and now lives in the
    // bubble, which is where a chat puts it — and it frees the whole line for
    // a long agent name.
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
      child: Text(
        mine ? 'You' : (entry.poster.isEmpty ? 'Support' : entry.poster),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MyntWebTextStyles.bodySmall(
          context,
          fontWeight: MyntFonts.semiBold,
          color: mine
              ? primaryColor
              : resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
        ),
      ),
    );

    // Reserved on the sender's side even when the avatar is hidden by
    // grouping, so a run of bubbles keeps one straight edge instead of
    // stepping in and out.
    final avatarSlot = SizedBox(
      width: _kAvatarSize,
      child: grouped ? null : _avatar(context, entry, mine),
    );

    final stack = Flexible(
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!grouped) header,
          bubble,
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: grouped ? 3 : 10,
        left: mine ? _kGutter : 0,
        right: mine ? 0 : _kGutter,
      ),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        // Bottom, not top. The tail leaves the bubble's bottom corner, and a
        // tail pointing at empty gutter is worse than no tail at all.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: mine
            ? [stack, const SizedBox(width: _kAvatarGap), avatarSlot]
            : [avatarSlot, const SizedBox(width: _kAvatarGap), stack],
      ),
    );
  }

  /// An agent's reply, rendered as the HTML it actually is.
  ///
  /// Bodies come back as raw stored HTML with no sanitized alternative, and
  /// flattening them to text lost every link and every list. `HtmlWidget` parses
  /// to widgets rather than injecting markup into the page, so a link is a real
  /// tap target and nothing scriptable survives the parse.
  ///
  /// Inline `cid:` images are not rewritten into fetchable URLs by the API, so
  /// they resolve to nothing and are left to fail quietly.
  Widget _htmlBody(BuildContext context, String html) {
    final accent = primaryColor;
    return ClipRect(
      child: HtmlWidget(
        html,
        // The same neutral on both sides, deliberately — blue ink on a blue
        // fill is the callout convention every docs site uses for "Note:"
        // boxes, so a reply stopped reading as something a person said. The
        // tint already says who wrote it; the letters only have to be read.
        textStyle: MyntWebTextStyles.body(
          context,
          fontWeight: MyntFonts.medium,
          darkColor: MyntColors.textPrimaryDark,
          lightColor: MyntColors.textPrimary,
        ),
        // Anchors are inert unless the URL is handed back to us to launch.
        onTapUrl: (url) async {
          final uri = Uri.tryParse(url);
          if (uri == null) return false;
          return launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        customStylesBuilder: (element) {
          switch (element.localName) {
            case 'b':
            case 'strong':
              return {'font-weight': '600'};
            case 'small':
            case 'sub':
            case 'sup':
              return {'font-size': '12px'};
            case 'a':
              return {
                'color': '#${accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
                'text-decoration': 'underline',
              };
            default:
              return null;
          }
        },
      ),
    );
  }

  Widget _avatar(BuildContext context, SupportThreadEntry entry, bool mine) {
    return ProfileCircle.fromName(
      mine ? 'You' : (entry.poster.isEmpty ? 'Support' : entry.poster),
      isSelf: mine,
      size: _kAvatarSize,
    );
  }

  /// `Today`, `Yesterday`, else the date — the year dropped when it is this
  /// one, since a divider is about placing a message in the recent past.
  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    if (_sameDay(day, now)) return 'Today';
    if (_sameDay(day, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat(day.year == now.year ? 'dd MMM' : 'dd MMM yyyy')
        .format(day);
  }

  /// Inline image preview box. Wide enough that a screenshot of an error is
  /// legible without opening it, short enough that a tall portrait cannot push
  /// the rest of the thread off screen.
  static const double _kPreviewWidth = 280;
  static const double _kPreviewHeight = 180;

  /// Fixed, so a ticket carrying several files renders a tidy stack rather
  /// than a ragged staircase.
  static const double _kChipWidth = 280;

  /// Files on the ticket, below the conversation.
  ///
  /// Thread entries carry no attachment array — files are a separate call — so
  /// they cannot be shown against the message they belong to.
  Widget _attachmentsBlock(
    BuildContext context,
    SupportTicketProvider provider,
    List<SupportAttachment> files,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ATTACHMENTS',
            style: MyntWebTextStyles.caption(
              context,
              fontWeight: MyntFonts.semiBold,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
            ).copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final file in files) _attachmentTile(context, provider, file),
            ],
          ),
        ],
      ),
    );
  }

  /// An image renders as a preview; everything else as a chip.
  Widget _attachmentTile(
    BuildContext context,
    SupportTicketProvider provider,
    SupportAttachment file,
  ) {
    if (!_isImage(file)) return _attachmentChip(context, provider, file);

    final bytes = provider.cachedAttachmentBytes(file.id);
    if (bytes == null) {
      // Kick the fetch off after this frame — starting it during build would
      // notify listeners mid-build and throw.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.ensureAttachmentBytes(file);
      });
      return _attachmentChip(context, provider, file, loading: true);
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The preview is cropped to fit the thread, so it is a thumbnail
          // rather than the image — tapping opens the whole thing.
          Tooltip(
            message: 'View',
            waitDuration: const Duration(milliseconds: 500),
            child: InkWell(
              onTap: () => _openImageViewer(context, provider, file, bytes),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _kPreviewWidth,
                  maxHeight: _kPreviewHeight,
                ),
                child: Image.memory(
                  bytes,
                  width: _kPreviewWidth,
                  fit: BoxFit.cover,
                  // A file that is not really an image must not leave a broken
                  // box in the thread — fall back to the chip, which still
                  // downloads.
                  errorBuilder: (context, _, __) =>
                      _attachmentChip(context, provider, file),
                ),
              ),
            ),
          ),
          SizedBox(
            width: _kPreviewWidth,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
              child: Row(
                children: [
                  Expanded(
                      child: _attachmentCaption(context, provider, file)),
                  const SizedBox(width: 6),
                  // The chip has one of these; the preview did not, so an image
                  // was the one attachment a client could see but not keep.
                  _downloadButton(context, provider, file),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens an image at full size.
  ///
  /// Bytes are already in hand from the preview, so this costs no request —
  /// which is why it is a viewer rather than a link out to a download.
  ///
  /// `InteractiveViewer` for pan and zoom: a screenshot of an error dialog is
  /// often only legible enlarged, and that is the whole reason a client
  /// attached it.
  void _openImageViewer(
    BuildContext context,
    SupportTicketProvider provider,
    SupportAttachment file,
    Uint8List bytes,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (dialogContext) => Stack(
        children: [
          // Tapping the backdrop closes, which is what a lightbox does. The
          // image itself absorbs its own taps so a drag to pan does not
          // dismiss it.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(dialogContext).pop(),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Download',
                  icon: const Icon(Icons.download_outlined, color: Colors.white),
                  onPressed: () => saveSupportAttachment(bytes, file.name),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentChip(
    BuildContext context,
    SupportTicketProvider provider,
    SupportAttachment file, {
    bool loading = false,
  }) {
    final chip = Container(
      width: _kChipWidth,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _typeBadge(context, file, loading: loading),
          const SizedBox(width: 10),
          Expanded(child: _attachmentCaption(context, provider, file)),
          const SizedBox(width: 6),
          _downloadButton(context, provider, file),
        ],
      ),
    );

    // Only a PDF opens in place — the browser has a viewer for it. Anything
    // else has no in-app representation, so the download button is the whole
    // affordance and a tap target that did nothing would be worse than none.
    final mime = loading ? null : _viewableMime(file);
    if (mime == null) return chip;

    return Tooltip(
      message: 'View',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openFileViewer(context, provider, file, mime),
        child: chip,
      ),
    );
  }

  /// What the browser can display for itself, given the bytes.
  ///
  /// PDF, SVG, video and plain text all have a native viewer behind an
  /// `<iframe>`. Word, Excel and the rest do not — for those the download
  /// button is the whole affordance, and a tap target that did nothing would
  /// be worse than none.
  ///
  /// Raster images are absent on purpose: they take the `Image.memory` path,
  /// which gives pan and zoom that an iframe does not.
  static const Map<String, String> _viewableTypes = {
    'pdf': 'application/pdf',
    'svg': 'image/svg+xml',
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'mov': 'video/quicktime',
    'm4v': 'video/x-m4v',
    'txt': 'text/plain',
    'csv': 'text/plain',
    'log': 'text/plain',
  };

  /// The MIME to publish the blob under, or null when nothing can show it.
  ///
  /// Keyed off the extension rather than `type`: that field is null whenever
  /// the underlying file row has gone, and the name survives.
  String? _viewableMime(SupportAttachment file) {
    final dot = file.name.lastIndexOf('.');
    if (dot < 0) return null;
    return _viewableTypes[file.name.substring(dot + 1).toLowerCase()];
  }

  /// Counts viewer opens, so each gets a view type of its own. Static: the
  /// registry is global, so the sequence has to be too.
  static int _viewerSeq = 0;

  /// Opens a file in place, in whatever viewer the browser has for it.
  ///
  /// Embedded as a blob in an `<iframe>` rather than rendered by a package: a
  /// browser already has a PDF viewer with paging, zoom, search and print, a
  /// video player with a scrubber, and an SVG renderer. None of that is worth
  /// reimplementing.
  ///
  /// Fetches on demand — unlike an image, none of these are previewed inline,
  /// so their bytes are not already in hand.
  Future<void> _openFileViewer(
    BuildContext context,
    SupportTicketProvider provider,
    SupportAttachment file,
    String mimeType,
  ) async {
    final bytes = provider.cachedAttachmentBytes(file.id) ??
        await provider.downloadAttachment(file);
    if (!context.mounted) return;
    if (bytes == null) {
      error(context, "Couldn't open that file — please try again.");
      return;
    }

    // Unique per *open*, not per file. The registry keeps the first factory
    // registered under a name, and the blob behind it is revoked when the
    // dialog closes — so re-opening the same file re-registered nothing and
    // the iframe pointed at a dead URL, which the browser reports as "it may
    // have been moved, edited, or deleted".
    final viewType = 'support-file-${file.id}-${_viewerSeq++}';
    final url =
        publishSupportBlob(bytes, viewType: viewType, mimeType: mimeType);

    if (!context.mounted) {
      releaseSupportBlob(url);
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: MyntFonts.semiBold,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Download',
                    icon: const Icon(Icons.download_outlined, size: 20),
                    onPressed: () => saveSupportAttachment(bytes, file.name),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
            Expanded(child: HtmlElementView(viewType: viewType)),
          ],
        ),
      ),
    );

    // The blob holds its bytes for the life of the tab otherwise.
    releaseSupportBlob(url);
  }

  /// 32x32 type tile: the extension in a tinted square, or a glyph when the
  /// filename has none.
  ///
  /// The extension reads faster than an icon — "XLSX" is unambiguous where a
  /// grid glyph could be a spreadsheet or a table.
  Widget _typeBadge(BuildContext context, SupportAttachment file,
      {bool loading = false}) {
    final tone = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final ext = _extensionOf(file.name);

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: loading
          ? const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2))
          : ext == null
              ? Icon(_iconFor(file), size: 17, color: tone)
              : Text(
                  // Four characters is the widest that fits without shrinking
                  // past legibility.
                  ext.length > 4 ? ext.substring(0, 4) : ext,
                  style: MyntWebTextStyles.caption(
                    context,
                    fontWeight: MyntFonts.bold,
                    color: tone,
                  ).copyWith(fontSize: ext.length > 3 ? 8 : 9),
                ),
    );
  }

  /// Saves the file.
  ///
  /// Fetches bytes through the authenticated route and hands them to the
  /// browser — there is no download URL to link to, by design, since one would
  /// carry its own auth knowing nothing about ticket ownership.
  Widget _downloadButton(
    BuildContext context,
    SupportTicketProvider provider,
    SupportAttachment file,
  ) {
    return Tooltip(
      message: 'Download',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () async {
          final bytes = await provider.downloadAttachment(file);
          if (!context.mounted) return;
          if (bytes == null) {
            error(context, "Couldn't download that file — please try again.");
            return;
          }
          saveSupportAttachment(bytes, file.name);
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.download_outlined,
            size: 16,
            color: resolveThemeColor(context,
                dark: MyntColors.iconDark, light: MyntColors.icon),
          ),
        ),
      ),
    );
  }

  String? _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    final ext = name.substring(dot + 1).toUpperCase();
    return ext.length > 5 ? null : ext;
  }

  /// Name over size.
  ///
  /// Two lines rather than one row: at a fixed chip width the filename gets the
  /// whole line instead of competing with the size for it, so far less of it is
  /// lost to the ellipsis.
  Widget _attachmentCaption(
    BuildContext context,
    SupportTicketProvider provider,
    SupportAttachment file,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: file.name,
          waitDuration: const Duration(milliseconds: 400),
          child: Text(
            file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: MyntWebTextStyles.bodySmall(
              context,
              fontWeight: MyntFonts.medium,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
            ),
          ),
        ),
        if (file.size != null)
          Text(
            _fileSize(file.size!),
            style: MyntWebTextStyles.caption(
              context,
              fontWeight: MyntFonts.regular,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
            ),
          ),
      ],
    );
  }

  /// Preview only what the browser can decode.
  ///
  /// The extension decides, not `type`. This install reports
  /// `application/octet-stream` for almost everything it stores — verified
  /// against the live API, where only one of five attachments carried a real
  /// MIME — so trusting `type` meant every PNG rendered as a plain chip with
  /// no preview and no way to open it.
  ///
  /// `type` is still consulted first when it says something meaningful, since
  /// a file named without an extension has nothing else to go on.
  bool _isImage(SupportAttachment file) {
    final type = (file.type ?? '').toLowerCase();
    if (type.startsWith('image/')) {
      // SVG needs a different decoder than Image.memory, and goes through the
      // browser viewer instead.
      return !type.contains('svg');
    }
    final name = file.name.toLowerCase();
    return name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp') ||
        name.endsWith('.bmp');
  }

  IconData _iconFor(SupportAttachment file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (name.endsWith('.xls') || name.endsWith('.xlsx') ||
        name.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    if (name.endsWith('.doc') || name.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    if (name.endsWith('.mp4') || name.endsWith('.mov') ||
        name.endsWith('.webm') || name.endsWith('.m4v')) {
      return Icons.videocam_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  // --- Reply ---------------------------------------------------------------

  /// The composer.
  ///
  /// A single bordered container holding the field, the staged files and the
  /// actions — rather than a field with controls floating either side of it.
  /// The border is what says "this is one thing you are composing"; controls
  /// outside it read as belonging to the panel instead of to the message.
  Widget _replyBox(BuildContext context, SupportTicketProvider provider) {
    final staged = provider.replyAttachments;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: MyntColors.cardDark, light: Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: TextField(
                controller: provider.reply,
                minLines: 2,
                maxLines: 6,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.regular,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Write a reply...',
                  hintStyle: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.regular,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                  ),
                  // The container already draws the edge; a second one inside
                  // it would box the text within the box.
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (staged.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < staged.length; i++)
                      Chip(
                        label: Text(staged[i].name),
                        visualDensity: VisualDensity.compact,
                        onDeleted: provider.sendingReply
                            ? null
                            : () => provider.removeReplyAttachmentAt(i),
                      ),
                  ],
                ),
              ),
            // Actions on the bottom edge of the same box: attach on the left
            // where it belongs to the message, send on the right where the
            // eye finishes.
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Row(
                children: [
                  MyntIconButton(
                    icon: Icons.attach_file,
                    onPressed: provider.sendingReply
                        ? null
                        : () async {
                            final failure =
                                await provider.pickReplyAttachments();
                            if (failure != null && context.mounted) {
                              error(context, failure);
                            }
                          },
                  ),
                  const Spacer(),
                  MyntPrimaryButton(
                    label: 'Send',
                    icon: Icons.send,
                    // After the word: the plane depicts the message leaving,
                    // which reads as the outcome of pressing rather than a
                    // label for what the button is.
                    iconAfterLabel: true,
                    size: MyntButtonSize.small,
                    isLoading: provider.sendingReply,
                    onPressed: () async {
                      final failure = await provider.sendReply();
                      if (failure != null && context.mounted) {
                        error(context, failure);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Bits ----------------------------------------------------------------

  Widget _errorState(SupportTicketProvider provider) {
    return NoDataFoundWeb(
      title: "Couldn't load this ticket",
      subtitle: provider.activeError,
      assetIcon: assets.documentIcon,
      iconSize: 120,
      primaryEnabled: true,
      primaryLabel: 'Retry',
      onPrimary: provider.refreshActiveTicket,
      secondaryEnabled: false,
    );
  }

  /// Just the clock time — the date divider above already says which day, so
  /// repeating the full date on every bubble is noise.
  String _timeOnly(DateTime? at) =>
      at == null ? '' : DateFormat('h:mm a').format(at);

  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

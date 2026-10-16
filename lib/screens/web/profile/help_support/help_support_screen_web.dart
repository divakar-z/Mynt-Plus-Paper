import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/common_buttons_web.dart';
import '../../../../provider/support_ticket_provider.dart';
import '../../../../models/support_ticket_model/support_ticket.dart';
import 'my_tickets_view.dart';
import 'ticket_detail_view.dart';
import 'raise_ticket_dialog.dart';
import '../../../../sharedWidget/common_text_fields_web.dart';
import '../../../../sharedWidget/snack_bar.dart';

class HelpSupportScreenWeb extends ConsumerStatefulWidget {
  const HelpSupportScreenWeb({super.key});

  @override
  ConsumerState<HelpSupportScreenWeb> createState() =>
      _HelpSupportScreenWebState();
}

class _HelpSupportScreenWebState extends ConsumerState<HelpSupportScreenWeb> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _locationController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _locationController = TextEditingController();

    // After the first frame: `ref.read` during initState touches a provider
    // that is still being wired up, and notifying listeners mid-build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(supportTicketProvider).loadTickets();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submitEnquiry() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final location = _locationController.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || location.isEmpty) {
      error(context, 'Please fill all fields');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uri = Uri.parse(
        'https://dwld.zebuetrade.com/openaccInit'
        '?name=${Uri.encodeComponent(name)}'
        '&phoneno=${Uri.encodeComponent(phone)}'
        '&email=${Uri.encodeComponent(email)}'
        '&location=${Uri.encodeComponent(location)}'
        '&ref=/contact',
      );

      final response = await http.get(uri);

      if (!mounted) return;

      if (response.statusCode == 200) {
        successMessage(context, 'Enquiry submitted successfully! We will call you back within 24 hours.');
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _locationController.clear();
      } else {
        error(context, 'Something went wrong. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        error(context, 'Failed to submit. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.borderMutedDark, light: MyntColors.borderMuted);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final iconColor = resolveThemeColor(context,
        dark: MyntColors.iconDark, light: MyntColors.icon);
    // Deliberately not a SingleChildScrollView. Inside one the height is
    // unbounded, so nothing below can use Expanded and the tickets table would
    // only ever be as tall as its content — Orders and Positions both fill the
    // panel. Contact & Help scrolls on its own instead, since that tab really
    // is a column of stacked cards.
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: _buildCustomerServices(
          context, borderColor, primaryColor, iconColor),
    );
  }

  BoxDecoration _cardDecoration(Color borderColor) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor, width: 1),
    );
  }

  /// One screen: the contact cards, then the client's tickets under them.
  ///
  /// No tabs. Contact details are reference material a client reads once, and
  /// hiding the ticket list behind a tab meant the thing they came for was
  /// never the thing on screen.
  Widget _buildCustomerServices(
      BuildContext context, Color borderColor, Color primaryColor, Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Customer Support & Assistance',
          style: MyntWebTextStyles.title(
            context,
            fontWeight: MyntFonts.semiBold,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        _buildContactRow(context, borderColor, primaryColor),
        const SizedBox(height: 20),
        _buildMyTicketsHeader(context, primaryColor),
        const SizedBox(height: 12),
        // Expanded, so the table fills whatever the cards leave rather than
        // sizing to its rows.
        Expanded(
          child: _buildMyTicketsTab(context, borderColor, primaryColor),
        ),
      ],
    );
  }

  /// The three contact cards, side by side.
  ///
  /// HQ and Address are deliberately not here. A logged-in client is not
  /// looking up the office to visit it, and the pair took a full row the ticket
  /// list now uses. Both are still built by [_buildHqAndAddressCard] if they
  /// are ever wanted back.
  ///
  /// `IntrinsicHeight` keeps the three the same height: the e-mail card is the
  /// tallest and the two phone cards would otherwise stop short of it.
  Widget _buildContactRow(
      BuildContext context, Color borderColor, Color primaryColor) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildContactCard(
              context,
              borderColor: borderColor,
              primaryColor: primaryColor,
              icon: Icons.headset_mic_outlined,
              title: 'Sales & Support',
              timing: 'Timing 09:00 AM To 11:00 PM',
              phone: '93 8010 8010',
              phoneRaw: '9380108010',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildContactCard(
              context,
              borderColor: borderColor,
              primaryColor: primaryColor,
              icon: Icons.support_agent,
              title: 'Dealing Desk',
              timing: 'Timing 9:00 AM To 11:55 PM',
              phone: '93 8030 8030',
              phoneRaw: '9380308030',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildEmailAndSocialCard(context, borderColor, primaryColor),
          ),
        ],
      ),
    );
  }

  /// Section heading for the ticket list, with the primary action opposite it.
  Widget _buildMyTicketsHeader(BuildContext context, Color primaryColor) {
    return Row(
      children: [
        Text(
          'My Tickets',
          style: MyntWebTextStyles.title(
            context,
            fontWeight: MyntFonts.semiBold,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
          ),
        ),
        const Spacer(),
        MyntPrimaryButton(
          label: 'Raise a Ticket',
          icon: Icons.add,
          onPressed: _openRaiseTicket,
        ),
      ],
    );
  }

  /// Opens one ticket in the app's sidebar.
  ///
  /// The fetch starts before the panel opens so the header shows the number,
  /// subject and status immediately — taken from the row already on screen —
  /// rather than sliding in over a spinner.
  void _openTicket(SupportTicket ticket, Color borderColor, Color primaryColor) {
    ref.read(supportTicketProvider).openTicket(ticket.id, preview: ticket);
    showTicketDetailPanel(
      ref,
      borderColor: borderColor,
      primaryColor: primaryColor,
      // Cleanup only — the panel closes itself, since only a context inside
      // the drawer can pop it.
      //
      // Tapping outside dismisses the drawer without running this, so the reply
      // draft would survive. It does not matter: `openTicket` clears the draft
      // too, so the next ticket opened starts empty either way.
      onClose: () => ref.read(supportTicketProvider).closeTicket(),
    );
  }

  /// The client's own tickets: filters, search and the list.
  Widget _buildMyTicketsTab(
      BuildContext context, Color borderColor, Color primaryColor) {
    final provider = ref.watch(supportTicketProvider);

    return MyTicketsView(
      borderColor: borderColor,
      primaryColor: primaryColor,
      tickets: provider.tickets,
      isLoading: provider.loadingTickets,
      errorMessage: provider.ticketsError,
      hasMore: provider.hasMoreTickets,
      total: provider.ticketsTotal,
      isLoadingMore: provider.loadingMore,
      onRetry: () => provider.loadTickets(force: true),
      onLoadMore: provider.loadMoreTickets,
      onOpenTicket: (ticket) => _openTicket(ticket, borderColor, primaryColor),
    );
  }

  /// Retired with the tabs. Kept because it is the only caller of
  /// [_buildHqAndAddressCard], and both come back together if the office
  /// details are ever wanted on this screen again.
  // ignore: unused_element
  Widget _buildContactAndHelpTab(
      BuildContext context, Color borderColor, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildContactCard(
                  context,
                  borderColor: borderColor,
                  primaryColor: primaryColor,
                  icon: Icons.headset_mic_outlined,
                  title: 'Sales & Support',
                  timing: 'Timing 09:00 AM To 11:00 PM',
                  phone: '93 8010 8010',
                  phoneRaw: '9380108010',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildContactCard(
                  context,
                  borderColor: borderColor,
                  primaryColor: primaryColor,
                  icon: Icons.support_agent,
                  title: 'Dealing Desk',
                  timing: 'Timing 9:00 AM To 11:55 PM',
                  phone: '93 8030 8030',
                  phoneRaw: '9380308030',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildHqAndAddressCard(context, borderColor, primaryColor),
        const SizedBox(height: 16),
        _buildEmailAndSocialCard(context, borderColor, primaryColor),
      ],
    );
  }

  /// Opens the raise-a-ticket form.
  void _openRaiseTicket() {
    showRaiseTicketDialog(context, ref: ref, screen: '/help-support');
  }

  Widget _buildContactCard(
    BuildContext context, {
    required Color borderColor,
    required Color primaryColor,
    required IconData icon,
    required String title,
    required String timing,
    required String phone,
    required String phoneRaw,
  }) {
    return Container(
      decoration: _cardDecoration(borderColor),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: resolveThemeColor(context,
              dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)),
          const SizedBox(height: 10),
          Text(
            title,
            style: MyntWebTextStyles.body(
              context,
              fontWeight: MyntFonts.semiBold,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timing,
            style: MyntWebTextStyles.body(
              context,
              fontWeight: MyntFonts.regular,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => launchUrl(Uri.parse('tel:$phoneRaw')),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, size: 16, color: primaryColor),
                const SizedBox(width: 6),
                Text(
                  phone,
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHqAndAddressCard(BuildContext context, Color borderColor, Color primaryColor) {
    return Container(
      decoration: _cardDecoration(borderColor),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Icon(Icons.groups_outlined, size: 36, color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)),
                const SizedBox(height: 10),
                Text(
                  'HQ in Chennai',
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => launchUrl(
                    Uri.parse('https://maps.google.com/?q=Zebu+Share+and+Wealth+Managements+Pvt+Ltd+Perungudi+Chennai'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, size: 16, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'சென்னை தலைமையகம்',
                        style: MyntWebTextStyles.body(
                          context,
                          fontWeight: MyntFonts.medium,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Address',
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.bold,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'No: 301, 4th Main Road,\nBurma Colony,\nPerungudi,\nChennai, Tamil Nadu 600096.',
                  textAlign: TextAlign.center,
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.regular,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static final List<Map<String, String>> _socialMediaIcons = [
    {"icon": "assets/icon/socialMedia/facebook.svg", "link": "https://www.facebook.com/zebuetrade/"},
    {"icon": "assets/icon/socialMedia/twitter-x.svg", "link": "https://twitter.com/zebuetrade?lang=en"},
    {"icon": "assets/icon/socialMedia/youtube.svg", "link": "https://www.youtube.com/channel/UCKbEVG1fH1TwkNDe6OM-zxg"},
    {"icon": "assets/icon/socialMedia/instagram.svg", "link": "https://www.instagram.com/zebu_official/"},
    {"icon": "assets/icon/socialMedia/pinterest.svg", "link": "https://in.pinterest.com/ZebuMarketing/"},
  ];

  Widget _buildEmailAndSocialCard(
      BuildContext context, Color borderColor, Color primaryColor) {
    return Container(
      decoration: _cardDecoration(borderColor),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => launchUrl(Uri.parse('mailto:assist@zebuetrade.com')),
            child: Row(
              children: [
                Icon(Icons.email_outlined, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                // Expanded, or the address is measured at its natural width and
                // overflows the card as soon as the panel is dragged narrow.
                Expanded(
                  child: Text(
                    'assist@zebuetrade.com',
                    style: MyntWebTextStyles.body(
                      context,
                      fontWeight: MyntFonts.medium,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => launchUrl(Uri.parse('mailto:grievance@zebuetrade.com')),
            child: Row(
              children: [
                Icon(Icons.email_outlined, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                // A Wrap, not a Row: when the two do not fit on one line the
                // address drops whole onto the next instead of being broken
                // across the middle of the domain.
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Investor grievance: ',
                        style: MyntWebTextStyles.body(
                          context,
                          fontWeight: MyntFonts.regular,
                          darkColor: MyntColors.textSecondaryDark,
                          lightColor: MyntColors.textSecondary,
                        ),
                      ),
                      Text(
                        'grievance@zebuetrade.com',
                        style: MyntWebTextStyles.body(
                          context,
                          fontWeight: MyntFonts.medium,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Follow us',
            style: MyntWebTextStyles.body(
              context,
              fontWeight: MyntFonts.bold,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Five fixed-width icons are a hard 220px in a Row, which overflows
          // the same narrow card the addresses above do.
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: _socialMediaIcons.map((item) {
              return Padding(
                padding: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => launchUrl(
                    Uri.parse(item['link']!),
                    mode: LaunchMode.externalApplication,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: SvgPicture.asset(
                    item['icon']!,
                    width: 28,
                    height: 28,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEnquireForm(
      BuildContext context, Color borderColor, Color primaryColor, Color iconColor) {
    return Container(
      decoration: _cardDecoration(borderColor),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enquire',
            style: MyntWebTextStyles.head(
              context,
              fontWeight: MyntFonts.bold,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: MyntTextField(
              controller: _nameController,
              placeholder: 'Name',
              leadingWidget: Icon(Icons.account_circle_outlined, size: 18, color: iconColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: MyntTextField(
              controller: _phoneController,
              placeholder: 'Phone Number',
              keyboardType: TextInputType.phone,
              leadingWidget: Icon(Icons.phone_outlined, size: 18, color: iconColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: MyntTextField(
              controller: _emailController,
              placeholder: 'Email',
              keyboardType: TextInputType.emailAddress,
              leadingWidget: Icon(Icons.send_outlined, size: 18, color: iconColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: MyntTextField(
              controller: _locationController,
              placeholder: 'Location',
              leadingWidget: Icon(Icons.location_on_outlined, size: 18, color: iconColor),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 35,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitEnquiry,
              style: ElevatedButton.styleFrom(
                backgroundColor: resolveThemeColor(context,
                    dark: MyntColors.secondary, light: MyntColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Submit',
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: MyntFonts.semiBold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Our representatives will give you a call back\nwithin the next 24 hours.',
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.body(
              context,
              fontWeight: MyntFonts.regular,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

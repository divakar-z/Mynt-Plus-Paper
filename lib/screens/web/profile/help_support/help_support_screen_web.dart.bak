import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildCustomerServices(context, borderColor, primaryColor, iconColor),
                ),
                // const SizedBox(width: 24),
                // Expanded(
                //   flex: 2,
                //   child: _buildEnquireForm(context, borderColor, primaryColor, iconColor),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(Color borderColor) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor, width: 1),
    );
  }

  Widget _buildCustomerServices(
      BuildContext context, Color borderColor, Color primaryColor, Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: 16),
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
                Text(
                  'assist@zebuetrade.com',
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.medium,
                    color: primaryColor,
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
          Row(
            children: _socialMediaIcons.map((item) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
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

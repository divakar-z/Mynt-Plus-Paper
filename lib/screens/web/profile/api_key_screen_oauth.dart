import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/provider/api_key_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/cust_text_formfield.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';

class ApiKeyScreenOAuth extends ConsumerStatefulWidget {
  const ApiKeyScreenOAuth({super.key});

  @override
  ConsumerState<ApiKeyScreenOAuth> createState() => _ApiKeyScreenOAuthState();
}

class _ApiKeyScreenOAuthState extends ConsumerState<ApiKeyScreenOAuth>
    with AutomaticKeepAliveClientMixin {
  // Error state variables like margin_calculator.dart
  String? _errorMessageUrl;
  String? _errorMessagePrimaryIp;
  String? _errorMessageBackupIp;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadApiKeyData();
  }

  void _loadApiKeyData() async {
    if (!mounted) return;
    await ref.read(apikeyprovider).fetchgenerateapikeynew(context);
  }

  void _toggleSecretVisibility() {
    ref.read(apikeyprovider).toggleSecretVisibility();
  }

  // Validation helper functions
  void _validateUrl(String value) {
    if (!mounted) return;
    if (value.trim().isEmpty) {
      setState(() {
        _errorMessageUrl = "Redirect URL is required";
      });
    } else {
      // URL format validation
      final uri = Uri.tryParse(value);
      if (uri == null || (!uri.hasScheme || (!uri.scheme.startsWith('http')))) {
        setState(() {
          _errorMessageUrl = "Please enter a valid URL";
        });
      } else {
        setState(() {
          _errorMessageUrl = null; // Clear error if valid
        });
      }
    }
  }

  void _validatePrimaryIp(String value) {
    if (!mounted) return;
    if (value.trim().isEmpty) {
      setState(() {
        _errorMessagePrimaryIp = "Primary IP is required";
      });
    } else {
      // IP address format validation
      final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
      if (!ipRegex.hasMatch(value.trim())) {
        setState(() {
          _errorMessagePrimaryIp = "Please enter a valid IP address";
        });
      } else {
        setState(() {
          _errorMessagePrimaryIp = null; // Clear error if valid
        });
      }
    }
  }

  void _validateBackupIp(String value) {
    if (!mounted) return;
    // Backup IP is optional but must be valid format if provided
    if (value.trim().isNotEmpty) {
      final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
      if (!ipRegex.hasMatch(value.trim())) {
        setState(() {
          _errorMessageBackupIp = "Please enter a valid IP address";
        });
      } else {
        setState(() {
          _errorMessageBackupIp = null; // Clear error if valid
        });
      }
    } else {
      setState(() {
        _errorMessageBackupIp = null; // Clear error if empty (optional field)
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    // Show message using project's successMessage
    successMessage(context, "Copied to clipboard");
  }

  void _showRegenerateConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: Container(
              width: 400,
              constraints: const BoxConstraints(maxHeight: 250),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: shadcn.Theme.of(ctx).colorScheme.border,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Regenerate Secret Code',
                          style: MyntWebTextStyles.title(
                            ctx,
                            color: resolveThemeColor(
                              ctx,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                        ),
                        MyntCloseButton(
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Are you sure you want to regenerate the secret code? This will generate a new secret code and the old one will no longer work.",
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.body(
                              ctx,
                              fontWeight: FontWeight.w500,
                              color: resolveThemeColor(
                                ctx,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          MyntButton(
                            type: MyntButtonType.primary,
                            size: MyntButtonSize.large,
                            label: 'Regenerate',
                            isFullWidth: true,
                            onPressed: () {
                              Navigator.pop(ctx);
                              ref.read(apikeyprovider).generateNewSecretCode();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitForm() async {
    final provider = ref.read(apikeyprovider);

    // Validate all fields using the helper functions
    _validateUrl(provider.urlController.text);
    _validatePrimaryIp(provider.primaryIpController.text);
    _validateBackupIp(provider.backupIpController.text);

    // Check if there are any errors
    bool hasErrors = _errorMessageUrl != null ||
        _errorMessagePrimaryIp != null ||
        _errorMessageBackupIp != null;

    // Return early if there are validation errors
    if (hasErrors) {
      return;
    }

    final apiData = provider.generateApikeyNew;
    if (apiData == null) {
      error(context, "API data not available. Please refresh and try again.");
      return;
    }

    final ipAddresses = <String>[];
    if (provider.primaryIpController.text.isNotEmpty) {
      ipAddresses.add(provider.primaryIpController.text);
    }
    if (provider.backupIpController.text.isNotEmpty) {
      ipAddresses.add(provider.backupIpController.text);
    }

    final userIds = apiData.userIds.isNotEmpty
        ? apiData.userIds.map((e) => e.userId).toList()
        : [apiData.appKey]; // Use app key as default user ID for new API keys

    final result = await provider.submitApiKeyNew(
      appKey: apiData.appKey,
      secretCode: provider.generatedSecretCode ??
          (apiData.stat == "Ok" ? apiData.secretCode : ""),
      redirectUrl: provider.urlController.text,
      displayName: apiData.displayName,
      ipAddresses: ipAddresses,
      userIds: userIds,
    );

    if (result?.stat == "Ok") {
      await provider.fetchgenerateapikeynew(context);
      successMessage(context, "API Key updated successfully");
    } else {
      error(context, result?.emsg ?? "");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final apiData = ref.watch(apikeyprovider).generateApikeyNew;
    final provider = ref.watch(apikeyprovider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            color: resolveThemeColor(context,
                dark: MyntColors.backgroundColorDark,
                light: MyntColors.backgroundColor),
            // border: Border(
            //   top: BorderSide(
            //     color: resolveThemeColor(context,
            //         dark: MyntColors.dividerDark,
            //         light: MyntColors.backgroundColor),
            //   ),
            //   left: BorderSide(
            //     color: resolveThemeColor(context,
            //         dark: MyntColors.dividerDark,
            //         light: MyntColors.backgroundColor),
            //   ),
            //   right: BorderSide(
            //     color: resolveThemeColor(context,
            //         dark: MyntColors.dividerDark,
            //         light: MyntColors.backgroundColor),
            //   ),
            // ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scrollable content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Client ID Section - Always show if we have API data
                  if (apiData != null) ...[
                    Row(
                      children: [
                        Text(
                          'Client Id :',
                          style: MyntWebTextStyles.bodySmall(context,
                              darkColor: MyntColors.textPrimaryDark,
                              lightColor: MyntColors.textPrimary,
                              fontWeight: MyntFonts.medium),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  "${apiData.appKey}",
                                  style: MyntWebTextStyles.title(context,
                                      darkColor: MyntColors.textPrimaryDark,
                                      lightColor: MyntColors.textPrimary,
                                      fontWeight: MyntFonts.medium),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.hardEdge,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => _copyToClipboard(apiData.appKey),
                                  child: SizedBox(
                                    height: 28,
                                    width: 28,
                                    child: Center(
                                      child: Icon(
                                        Icons.copy,
                                        size: 16,
                                        color: resolveThemeColor(context,
                                            dark: MyntColors.textSecondaryDark,
                                            light: MyntColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                              
                  // Form Fields (always visible but disabled when no API data)
                  // Redirect URL Label
                  Text(
                    'Redirect URL',
                    style: MyntWebTextStyles.bodySmall(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.medium),
                  ),
                  const SizedBox(height: 8),
                  // URL Input Field (project-styled)
                  CustomTextFormField(
                    textCtrl: provider.urlController,
                    textAlign: TextAlign.start,
                    keyboardType: TextInputType.url,
                    fillColor: resolveThemeColor(context,
                        dark: MyntColors.listItemBgDark,
                        light: MyntColors.listItemBg),
                    hintText: 'URL',
                    hintStyle: MyntWebTextStyles.para(context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary),
                    style: MyntWebTextStyles.para(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary),
                    onChanged: (value) {
                      _validateUrl(value);
                    },
                  ),
                  // Custom error message display like margin_calculator.dart
                  if (_errorMessageUrl != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _errorMessageUrl!,
                        style: MyntWebTextStyles.caption(context,
                            color: resolveThemeColor(context,
                                dark: MyntColors.lossDark,
                                light: MyntColors.loss)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                              
                  // IP Address Fields
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Primary IP Address',
                              style: MyntWebTextStyles.bodySmall(context,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary,
                                  fontWeight: MyntFonts.medium),
                            ),
                            const SizedBox(height: 8),
                            CustomTextFormField(
                              textCtrl: provider.primaryIpController,
                              textAlign: TextAlign.start,
                              keyboardType: TextInputType.number,
                              hintText: 'Primary IP Address',
                              fillColor: resolveThemeColor(context,
                                  dark: MyntColors.listItemBgDark,
                                  light: MyntColors.listItemBg),
                              hintStyle: MyntWebTextStyles.para(context,
                                  darkColor: MyntColors.textSecondaryDark,
                                  lightColor: MyntColors.textSecondary),
                              style: MyntWebTextStyles.para(context,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary),
                              inputFormate: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                              onChanged: (value) {
                                _validatePrimaryIp(value);
                              },
                            ),
                            // Custom error message display for Primary IP
                            if (_errorMessagePrimaryIp != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _errorMessagePrimaryIp!,
                                  style: MyntWebTextStyles.caption(context,
                                      color: resolveThemeColor(context,
                                dark: MyntColors.lossDark,
                                light: MyntColors.loss)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Backup IP Address',
                              style: MyntWebTextStyles.bodySmall(context,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary,
                                  fontWeight: MyntFonts.medium),
                            ),
                            const SizedBox(height: 8),
                            CustomTextFormField(
                              textCtrl: provider.backupIpController,
                              textAlign: TextAlign.start,
                              keyboardType: TextInputType.number,
                              hintText: 'Backup IP Address',
                              fillColor: resolveThemeColor(context,
                                  dark: MyntColors.listItemBgDark,
                                  light: MyntColors.listItemBg),
                              hintStyle: MyntWebTextStyles.para(context,
                                  darkColor: MyntColors.textSecondaryDark,
                                  lightColor: MyntColors.textSecondary),
                              style: MyntWebTextStyles.para(context,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary),
                              errorStyle: MyntWebTextStyles.caption(context,
                                  color: resolveThemeColor(context,
                                dark: MyntColors.lossDark,
                                light: MyntColors.loss) ),
                              onChanged: (value) {
                                _validateBackupIp(value);
                              },
                            ),
                            // Custom error message display for Backup IP
                            if (_errorMessageBackupIp != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _errorMessageBackupIp!,
                                  style: MyntWebTextStyles.caption(context,
                                      color: resolveThemeColor(context,
                                dark: MyntColors.lossDark,
                                light: MyntColors.loss)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                              
                  if (apiData != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Secret Code',
                          style: MyntWebTextStyles.bodySmall(context,
                              darkColor: MyntColors.textPrimaryDark,
                              lightColor: MyntColors.textPrimary,
                              fontWeight: MyntFonts.medium),
                        ),
                        // Regenerate button (only show for existing data)
                        if (apiData.stat == "Ok")
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(5),
                              onTap: () {
                                _showRegenerateConfirmation();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Text(
                                  'Regenerate',
                                  style: MyntWebTextStyles.para(context,
                                      color: isDarkMode(context) ? MyntColors.primaryDark : MyntColors.primary,
                                      fontWeight: MyntFonts.semiBold),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: resolveThemeColor(context,
                            dark: MyntColors.listItemBgDark,
                            light: MyntColors.listItemBg),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isDarkMode(context) ? MyntColors.primaryDark : MyntColors.primary,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                provider.hideSecret
                                    ? "•" *
                                        ((provider.generatedSecretCode
                                                        ?.length ??
                                                    0) >
                                                0
                                            ? provider
                                                .generatedSecretCode!.length
                                            : (apiData.stat == "Ok"
                                                ? apiData.secretCode.length
                                                : 0))
                                    : (provider.generatedSecretCode ??
                                        (apiData.stat == "Ok"
                                            ? apiData.secretCode
                                            : "")),
                                overflow: TextOverflow.ellipsis,
                                style: MyntWebTextStyles.para(context,
                                    darkColor: MyntColors.textPrimaryDark,
                                    lightColor: MyntColors.textPrimary),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.hardEdge,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                splashColor: resolveThemeColor(context,
                                    dark: MyntColors.rippleDark,
                                    light: MyntColors.rippleLight),
                                highlightColor: resolveThemeColor(context,
                                    dark: MyntColors.highlightDark,
                                    light: MyntColors.highlightLight),
                                onTap: _toggleSecretVisibility,
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(
                                    provider.hideSecret
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 20,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Material(
                              color: Colors.transparent,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.hardEdge,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                splashColor: resolveThemeColor(context,
                                    dark: MyntColors.rippleDark,
                                    light: MyntColors.rippleLight),
                                highlightColor: resolveThemeColor(context,
                                    dark: MyntColors.highlightDark,
                                    light: MyntColors.highlightLight),
                                onTap: () => _copyToClipboard(
                                    provider.generatedSecretCode ??
                                        (apiData.stat == "Ok"
                                            ? apiData.secretCode
                                            : "")),
                                child: SizedBox(
                                  height: 32,
                                  width: 32,
                                  child: Center(
                                    child: Icon(
                                      Icons.copy,
                                      size: 18,
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.textSecondaryDark,
                                          light: MyntColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Add extra padding at bottom for keyboard
                  // SizedBox(
                  //     height: MediaQuery.of(context).viewInsets.bottom > 0
                  //         ? 100
                  //         : 20),
                  Container(
                              // padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.backgroundColorDark,
                  light: MyntColors.backgroundColor),
                              ),
                              child: SizedBox(
              width: 200,
              height: 45,
              child: ElevatedButton(
                onPressed: apiData == null ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                backgroundColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
                foregroundColor: MyntColors.backgroundColor,
                // padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
                child: Text(
                  apiData?.stat == "Ok" ? "Update" : "Create",
                  style: MyntWebTextStyles.bodySmall(context,
                      color: Colors.white,
                      fontWeight: MyntFonts.semiBold),
                ),
              ),
                              ),
                            ),
                ],
              ),
        
              // Fixed bottom button
              
            ],
          ),
        ),
      ),
    );
  }
}

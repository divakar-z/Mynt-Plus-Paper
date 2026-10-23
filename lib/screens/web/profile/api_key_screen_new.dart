import 'dart:ui' show PathMetric;

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

class ApiKeyScreenNew extends ConsumerStatefulWidget {
  const ApiKeyScreenNew({super.key});

  @override
  ConsumerState<ApiKeyScreenNew> createState() => _ApiKeyScreenNewState();
}

class _ApiKeyScreenNewState extends ConsumerState<ApiKeyScreenNew>
    with AutomaticKeepAliveClientMixin {
  String? _errorMessageName;
  String? _errorMessageUrl;
  String? _errorMessagePrimaryIp;
  String? _errorMessageBackupIp;

  // True while the user is filling the form for a new app.
  bool _creating = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadApiKeyData();
  }

  void _loadApiKeyData() async {
    if (!mounted) return;
    final err = await ref.read(apikeyprovider).fetchOauthApps(context);
    if (err != null && mounted) error(context, err);
  }

  void _clearErrors() {
    _errorMessageName = null;
    _errorMessageUrl = null;
    _errorMessagePrimaryIp = null;
    _errorMessageBackupIp = null;
  }

  void _selectApp(int index) {
    setState(() {
      _creating = false;
      _clearErrors();
    });
    ref.read(apikeyprovider).selectOauthApp(index);
  }

  void _startCreate() {
    setState(() {
      _creating = true;
      _clearErrors();
    });
    ref.read(apikeyprovider).startOauthCreate();
  }

  void _cancelCreate() {
    final provider = ref.read(apikeyprovider);
    setState(() {
      _creating = false;
      _clearErrors();
    });
    provider.selectOauthApp(provider.selectedIdx);
  }

  // Validation helpers (rules from the OAuth apps API)
  bool _isIp(String v) {
    if (v.contains(':')) return RegExp(r'^[0-9a-fA-F:]+$').hasMatch(v);
    final parts = v.split('.');
    return parts.length == 4 &&
        parts.every((p) => RegExp(r'^\d{1,3}$').hasMatch(p) && int.parse(p) <= 255);
  }

  void _validateName(String value) {
    if (!mounted) return;
    setState(() {
      _errorMessageName = (value.length > 100 || value.contains('&'))
          ? "Use up to 100 characters, without &."
          : null;
    });
  }

  void _validateUrl(String value) {
    if (!mounted) return;
    final url = value.trim();
    setState(() {
      _errorMessageUrl = (!RegExp(r'^https?://[^\s&]+$').hasMatch(url) ||
              url.length > 500)
          ? "Enter a URL that starts with http:// or https://, without spaces or &."
          : null;
    });
  }

  void _validateIp(String value, bool primary) {
    if (!mounted) return;
    final v = value.trim();
    final msg = (v.isNotEmpty && !_isIp(v))
        ? "Enter a valid IP address, like 203.0.113.10."
        : null;
    setState(() {
      if (primary) {
        _errorMessagePrimaryIp = msg;
      } else {
        _errorMessageBackupIp = msg;
      }
    });
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    successMessage(context, message);
  }

  Future<void> _regenerateSecret() async {
    final err = await ref
        .read(apikeyprovider)
        .updateOauthApp(context, regenerate: true);
    if (!mounted) return;
    if (err == null) {
      ref.read(apikeyprovider).setSecretHidden(false);
      successMessage(context, "New secret code generated");
    } else {
      error(context, err);
    }
  }

  // Confirmation dialog shared by Regenerate and Delete (same layout as the
  // original Regenerate dialog).
  void _showConfirmDialog({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onConfirm,
    Color? actionColor,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: Container(
              width: 400,
              constraints: const BoxConstraints(maxHeight: 280),
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
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: MyntWebTextStyles.title(
                              ctx,
                              color: resolveThemeColor(
                                ctx,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
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
                            message,
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
                            label: actionLabel,
                            isFullWidth: true,
                            backgroundColor: actionColor,
                            onPressed: () {
                              Navigator.pop(ctx);
                              onConfirm();
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

  void _showRegenerateConfirmation(String appKey) {
    _showConfirmDialog(
      title: 'Generate a new secret code?',
      message:
          "The current secret code for $appKey stops working right away. Update the new code in your app to keep it logged in.",
      actionLabel: 'Generate new code',
      onConfirm: _regenerateSecret,
    );
  }

  void _showDeleteConfirmation(String appKey) {
    _showConfirmDialog(
      title: 'Delete $appKey?',
      message:
          "Its secret code stops working right away, and anything logged in with this app is disconnected. You can't undo this.",
      actionLabel: 'Delete app',
      actionColor: resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss),
      onConfirm: () async {
        final err = await ref.read(apikeyprovider).deleteOauthApp(context);
        if (!mounted) return;
        if (err == null) {
          successMessage(context, "$appKey deleted");
        } else {
          error(context, err);
        }
      },
    );
  }

  Future<void> _submitForm() async {
    final provider = ref.read(apikeyprovider);

    _validateName(provider.dnameController.text);
    _validateUrl(provider.urlController.text);
    _validateIp(provider.primaryIpController.text, true);
    _validateIp(provider.backupIpController.text, false);

    if (_errorMessageName != null ||
        _errorMessageUrl != null ||
        _errorMessagePrimaryIp != null ||
        _errorMessageBackupIp != null) {
      return;
    }

    final wasCreating = _creating;
    final err = wasCreating
        ? await provider.createOauthApp(context)
        : await provider.updateOauthApp(context);
    if (!mounted) return;
    if (err == null) {
      setState(() => _creating = false);
      if (!wasCreating) successMessage(context, "Changes saved");
    } else {
      error(context, err);
    }
  }

  // ---- UI helpers ----
  Color get _primary => isDarkMode(context) ? MyntColors.primaryDark : MyntColors.primary;
  Color get _loss => resolveThemeColor(context,
      dark: MyntColors.lossDark, light: MyntColors.loss);
  Color get _textPrimary => resolveThemeColor(context,
      dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
  Color get _textSecondary => resolveThemeColor(context,
      dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
  Color get _divider =>
      resolveThemeColor(context, dark: MyntColors.dividerDark, light: MyntColors.divider);

  Widget _label(String text, {String? suffix}) {
    return Text.rich(TextSpan(
      text: text,
      style: MyntWebTextStyles.bodySmall(context,
          darkColor: MyntColors.textPrimaryDark,
          lightColor: MyntColors.textPrimary,
          fontWeight: MyntFonts.medium),
      children: [
        if (suffix != null)
          TextSpan(text: ' $suffix', style: TextStyle(color: _textSecondary)),
      ],
    ));
  }

  Widget _errorText(String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(message,
          style: MyntWebTextStyles.caption(context, color: _loss)),
    );
  }

  Widget _field({
    required String label,
    String? labelSuffix,
    required TextEditingController controller,
    required String hint,
    required String? errorText,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, suffix: labelSuffix),
        const SizedBox(height: 8),
        CustomTextFormField(
          textCtrl: controller,
          textAlign: TextAlign.start,
          keyboardType: keyboardType ?? TextInputType.text,
          fillColor: resolveThemeColor(context,
              dark: MyntColors.listItemBgDark, light: MyntColors.listItemBg),
          hintText: hint,
          hintStyle: MyntWebTextStyles.para(context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary),
          style: MyntWebTextStyles.para(context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary),
          inputFormate: formatters,
          onChanged: onChanged,
        ),
        _errorText(errorText),
      ],
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onTap,
      {double size = 18}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 32,
            width: 32,
            child: Center(child: Icon(icon, size: size, color: _textPrimary)),
          ),
        ),
      ),
    );
  }

  Widget _appPill(String key, String dname, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? _primary.withValues(alpha: 0.08) : Colors.transparent,
          border: Border.all(color: selected ? _primary : _divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(key,
                style: MyntWebTextStyles.bodySmall(context,
                    color: selected ? _primary : _textPrimary,
                    fontWeight: MyntFonts.semiBold)),
            const SizedBox(height: 2),
            Text(dname,
                style: MyntWebTextStyles.caption(context, color: _textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _newAppButton({required bool active, required VoidCallback? onTap}) {
    final color = onTap == null ? _textSecondary : _primary;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
            color: onTap == null ? _divider : _primary, radius: 8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: active ? _primary.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: color),
              const SizedBox(width: 6),
              Text('New app',
                  style: MyntWebTextStyles.bodySmall(context,
                      color: color, fontWeight: MyntFonts.semiBold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: 200,
      height: 46,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: resolveThemeColor(context,
              dark: MyntColors.secondary, light: MyntColors.primary),
          foregroundColor: MyntColors.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(label,
            style: MyntWebTextStyles.bodySmall(context,
                color: Colors.white, fontWeight: MyntFonts.semiBold)),
      ),
    );
  }

  Widget _emptyState() {
    return CustomPaint(
      painter: _DashedBorderPainter(color: _divider, radius: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primary.withValues(alpha: 0.1),
              ),
              child: Icon(Icons.vpn_key_outlined, size: 22, color: _primary),
            ),
            const SizedBox(height: 12),
            Text('No OAuth apps yet',
                style: MyntWebTextStyles.title(context,
                    color: _textPrimary, fontWeight: MyntFonts.semiBold)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                'Create an app to get a Client Id and Secret Code for OAuth login. You can have up to 6 apps.',
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.para(context, color: _textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            _primaryButton('Create app', _startCreate),
          ],
        ),
      ),
    );
  }

  Widget _createdBanner(String key, VoidCallback onDismiss) {
    final green = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: green.withValues(alpha: 0.1),
        border: Border.all(color: green.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 18, color: green),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(TextSpan(
              style: MyntWebTextStyles.bodySmall(context, color: _textPrimary),
              children: [
                TextSpan(
                    text: '$key is ready. ',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(
                    text:
                        "Use this Client Id and Secret Code in your app's OAuth login. You can view the secret here at any time."),
              ],
            )),
          ),
          InkWell(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 16, color: _textPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final provider = ref.watch(apikeyprovider);
    final app = provider.selectedApp;
    final apps = provider.oauthApps;
    final loaded = provider.oauthLoaded;
    final creating = _creating;
    final isEmpty = loaded && apps.isEmpty && !creating;
    final showApp = app != null && !creating;
    final showForm = creating || showApp;
    final limitReached = loaded && apps.length >= provider.maxApps;
    final canCreate = loaded && apps.isNotEmpty && !limitReached;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          color: resolveThemeColor(context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
        ),
        child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                if (provider.oauthLoading && !loaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                // Your apps
                if (loaded && apps.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your apps',
                          style: MyntWebTextStyles.bodySmall(context,
                              color: _textPrimary,
                              fontWeight: MyntFonts.semiBold)),
                      Text('${apps.length} of ${provider.maxApps} apps',
                          style: MyntWebTextStyles.caption(context,
                              color: _textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < apps.length; i++)
                        _appPill(apps[i].appKey, apps[i].displayName,
                            !creating && i == provider.selectedIdx,
                            () => _selectApp(i)),
                      _newAppButton(
                          active: creating,
                          onTap: canCreate ? _startCreate : null),
                    ],
                  ),
                  if (limitReached) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: resolveThemeColor(context,
                                dark: MyntColors.warningDark,
                                light: MyntColors.warning)
                            .withValues(alpha: 0.15),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: _textPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You have ${provider.maxApps} apps, the maximum. Delete one to create another.',
                              style: MyntWebTextStyles.caption(context,
                                  color: _textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Divider(height: 1, color: _divider),
                  const SizedBox(height: 22),
                ],

                if (isEmpty) _emptyState(),

                if (showApp && provider.createdKey == app.appKey) ...[
                  _createdBanner(
                      app.appKey, () => provider.dismissCreatedBanner()),
                  const SizedBox(height: 22),
                ],

                if (showForm) ...[
                  // Header: Client Id + Delete (view) / New app (create)
                  if (showApp)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Client Id :',
                                  style: MyntWebTextStyles.bodySmall(context,
                                      color: _textPrimary)),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(app.appKey,
                                    overflow: TextOverflow.ellipsis,
                                    style: MyntWebTextStyles.title(context,
                                        color: _textPrimary,
                                        fontWeight: MyntFonts.medium)),
                              ),
                              const SizedBox(width: 6),
                              _iconButton(Icons.copy, 'Copy Client Id',
                                  () => _copyToClipboard(
                                      app.appKey, 'Client Id copied')),
                            ],
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _showDeleteConfirmation(app.appKey),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 16, color: _loss),
                                const SizedBox(width: 6),
                                Text('Delete app',
                                    style: MyntWebTextStyles.bodySmall(context,
                                        color: _loss,
                                        fontWeight: MyntFonts.semiBold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New app',
                            style: MyntWebTextStyles.title(context,
                                color: _textPrimary,
                                fontWeight: MyntFonts.semiBold)),
                        const SizedBox(height: 4),
                        Text.rich(TextSpan(
                          style: MyntWebTextStyles.bodySmall(context,
                              color: _textSecondary),
                          children: [
                            const TextSpan(text: 'This app will get Client Id '),
                            TextSpan(
                                text: provider.nextOauthKey,
                                style: TextStyle(
                                    color: _textPrimary,
                                    fontWeight: FontWeight.w600)),
                            const TextSpan(text: ' when you create it.'),
                          ],
                        )),
                      ],
                    ),
                  const SizedBox(height: 20),

                  _field(
                    label: 'App name',
                    labelSuffix: '(optional)',
                    controller: provider.dnameController,
                    hint: 'e.g. Algo bot',
                    errorText: _errorMessageName,
                    onChanged: _validateName,
                  ),
                  const SizedBox(height: 20),
                  _field(
                    label: 'Redirect URL',
                    controller: provider.urlController,
                    hint: 'https://your-app.com/callback',
                    keyboardType: TextInputType.url,
                    errorText: _errorMessageUrl,
                    onChanged: _validateUrl,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          label: 'Primary IP Address',
                          controller: provider.primaryIpController,
                          hint: 'Primary IP Address',
                          errorText: _errorMessagePrimaryIp,
                          formatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9a-fA-F.:]')),
                          ],
                          onChanged: (v) => _validateIp(v, true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          label: 'Backup IP Address',
                          controller: provider.backupIpController,
                          hint: 'Backup IP Address',
                          errorText: _errorMessageBackupIp,
                          formatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9a-fA-F.:]')),
                          ],
                          onChanged: (v) => _validateIp(v, false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (showApp) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _label('Secret Code'),
                        InkWell(
                          borderRadius: BorderRadius.circular(5),
                          onTap: () => _showRegenerateConfirmation(app.appKey),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text('Regenerate',
                                style: MyntWebTextStyles.para(context,
                                    color: _primary,
                                    fontWeight: MyntFonts.semiBold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.only(left: 14, right: 6),
                      decoration: BoxDecoration(
                        color: resolveThemeColor(context,
                            dark: MyntColors.listItemBgDark,
                            light: MyntColors.listItemBg),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _primary, width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.hideSecret
                                  ? "•" * app.secretCode.length
                                  : app.secretCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MyntWebTextStyles.para(context,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary),
                            ),
                          ),
                          _iconButton(
                              provider.hideSecret
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              provider.hideSecret
                                  ? 'Show secret code'
                                  : 'Hide secret code',
                              provider.toggleSecretVisibility,
                              size: 20),
                          _iconButton(
                              Icons.copy,
                              'Copy secret code',
                              () => _copyToClipboard(
                                  app.secretCode, 'Secret code copied')),
                        ],
                      ),
                    ),
                    if (app.emsg != null && app.emsg!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            "Couldn't load live details: ${app.emsg}",
                            style: MyntWebTextStyles.caption(context,
                                color: _loss)),
                      ),
                    const SizedBox(height: 20),
                    _primaryButton('Update', _submitForm),
                  ] else
                    Row(
                      children: [
                        _primaryButton('Create app', _submitForm),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: apps.isEmpty
                                ? () => setState(() {
                                      _creating = false;
                                      _clearErrors();
                                    })
                                : _cancelCreate,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              side: BorderSide(color: _primary),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text('Cancel',
                                style: MyntWebTextStyles.bodySmall(context,
                                    color: _primary,
                                    fontWeight: MyntFonts.semiBold)),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ],
        ),
      ),
    );
  }
}

/// Dashed rounded-rect border, used by the "New app" button and empty state.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)));
    for (final PathMetric metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

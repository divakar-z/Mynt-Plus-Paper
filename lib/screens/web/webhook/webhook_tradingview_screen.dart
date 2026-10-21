import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/api/web_auth_api.dart';
import 'package:mynt_plus/models/marketwatch_model/search_scrip_model.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/sharedWidget/common_text_fields_web.dart';
import 'package:mynt_plus/sharedWidget/common_search_fields_web.dart';
import 'package:mynt_plus/sharedWidget/custom_text_form_field.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart' as snack;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;

class WebHookTradingViewScreen extends StatefulWidget {
  const WebHookTradingViewScreen({super.key});

  @override
  State<WebHookTradingViewScreen> createState() => _WebHookTradingViewScreenState();
}

class _WebHookTradingViewScreenState
    extends State<WebHookTradingViewScreen> {
  final Preferences _pref = locator<Preferences>();

  // Form state
  bool _isSell = false; // false = BUY, true = SELL
  String _symbolType = 'dyn'; // 'dyn' or 'stat'
  String _productType = 'I'; // 'I' = Intraday, 'C' = Delivery, 'M' = NRML, 'H' = CO, 'B' = BO
  String _orderType = 'MKT'; // 'MKT' or 'LMT'
  String _quantity = '0';
  String _limitPrice = '0';

  // CO-BO state
  bool _isCoverOrder = true; // true = Cover Order (H), false when Bracket is selected
  bool _isBracketOrder = false; // true = Bracket Order (B)
  String _stoploss = '0';
  String _target = '0';

  // JSON visibility – auto-shown when webhook data loads from API
  bool _isGenerated = false;

  // Webhook list state
  List<Map<String, dynamic>> _webhookList = [];
  int? _selectedWebhookIndex;

  // Derived from selected webhook
  Map<String, dynamic>? get _selectedWebhook =>
      _selectedWebhookIndex != null && _selectedWebhookIndex! < _webhookList.length
          ? _webhookList[_selectedWebhookIndex!]
          : null;

  String get _webhookUrl =>
      _selectedWebhook?['webhook_url']?.toString() ?? '';

  bool get _isWebhookActive => _selectedWebhook?['is_active'] == true;

  bool get _isWebhookExpired {
    final expiryStr = _selectedWebhook?['expiry']?.toString();
    if (expiryStr == null || expiryStr.isEmpty) return false;
    try {
      final expiry = DateTime.parse(expiryStr);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return false;
    }
  }

  String get _formattedExpiry {
    final expiryStr = _selectedWebhook?['expiry']?.toString();
    if (expiryStr == null || expiryStr.isEmpty) return '';
    try {
      final expiry = DateTime.parse(expiryStr);
      return DateFormat('dd-MM-yyyy hh:mm a').format(expiry);
    } catch (_) {
      return expiryStr;
    }
  }

  // Tab state: 0 = Param Generator, 1 = Logs
  int _selectedTab = 0;

  // Logs state
  List<Map<String, dynamic>> _logsList = [];
  bool _isLoadingLogs = false;
  DateTime _logsFromDate = DateTime.now();
  DateTime _logsToDate = DateTime.now();
  final ValueNotifier<int?> _hoveredLogRow = ValueNotifier<int?>(null);
  bool _isSheetOpening = false;

  // Search state
  ScripValue? _selectedScrip;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stoplossController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  List<ScripValue> _searchResults = [];
  Timer? _debounceTimer;
  String _lastSearchText = '';

  // The search field's X button only empties the text box; it never calls
  // onClear. Run the clear here when the box goes from text to empty.
  void _onSearchTextChanged() {
    final text = _searchController.text;
    final wasNotEmpty = _lastSearchText.isNotEmpty;
    _lastSearchText = text;
    if (text.isEmpty && wasNotEmpty) {
      _debounceTimer?.cancel();
      _clearSelectedScrip();
      _removeSearchOverlay();
    }
  }

  String get _clientId => _pref.clientId ?? '';
  String get _apiToken => _pref.clientSession ?? '';

  @override
  void initState() {
    super.initState();
    _qtyController.text = _quantity;
    _priceController.text = _limitPrice;
    _stoplossController.text = _stoploss;
    _targetController.text = _target;
    _searchController.addListener(_onSearchTextChanged);
    _fetchWebhookList();
  }

  Future<void> _fetchWebhookList() async {
    final result = await WebAuthApi.listWebhooks(
      clientId: _clientId,
      token: _apiToken,
    );
    if (!mounted) return;
    setState(() {
      if (result != null && result['stat'] == 'Ok' && result['webhooks'] != null) {
        _webhookList = List<Map<String, dynamic>>.from(result['webhooks']);
        // Auto-select the first webhook so the URL field is populated
        _selectedWebhookIndex = _webhookList.isNotEmpty ? 0 : null;
        // Auto-show JSON when webhook data is available
        if (_webhookList.isNotEmpty) _isGenerated = true;
      } else {
        _webhookList = [];
        _selectedWebhookIndex = null;
      }
    });
  }

  Future<void> _toggleWebhookStatus(int webhookId, bool currentlyActive) async {
    final result = currentlyActive
        ? await WebAuthApi.disableWebhook(
            webhookId: webhookId, clientId: _clientId, token: _apiToken)
        : await WebAuthApi.enableWebhook(
            webhookId: webhookId, clientId: _clientId, token: _apiToken);
    if (!mounted) return;
    if (result != null) {
      final message = result['msg'] ?? result['emsg'] ?? '';
      if (result['stat'] == 'Ok') {
        snack.successMessage(context, message.isNotEmpty ? message : (currentlyActive ? 'Webhook disabled' : 'Webhook enabled'));
      } else {
        snack.error(context, message.isNotEmpty ? message : 'Failed to ${currentlyActive ? 'disable' : 'enable'} webhook');
      }
      _fetchWebhookList();
    } else {
      snack.error(context, 'Failed to ${currentlyActive ? 'disable' : 'enable'} webhook');
    }
  }

  @override
  void dispose() {
    _removeSearchOverlay();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _stoplossController.dispose();
    _targetController.dispose();
    _debounceTimer?.cancel();
    _hoveredLogRow.dispose();
    super.dispose();
  }

  // ── Logs API ──

  Future<void> _fetchWebhookLogs() async {
    setState(() => _isLoadingLogs = true);
    final result = await WebAuthApi.webhookLogs(
      clientId: _clientId,
      token: _apiToken,
      fromDate: DateFormat('yyyy-MM-dd').format(_logsFromDate),
      toDate: DateFormat('yyyy-MM-dd').format(_logsToDate),
    );
    if (!mounted) return;
    setState(() {
      _isLoadingLogs = false;
      if (result != null && result['stat'] == 'Ok' && result['logs'] != null) {
        _logsList = List<Map<String, dynamic>>.from(result['logs']);
      } else {
        _logsList = [];
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final bgColor = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final isDark = isDarkMode(context);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _logsFromDate : _logsToDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      builder: (dialogContext, child) => Theme(
        data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
          colorScheme: (isDark
                  ? const ColorScheme.dark()
                  : const ColorScheme.light())
              .copyWith(
            primary: primaryColor,
            onPrimary: Colors.white,
            surface: bgColor,
            onSurface: textColor,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: primaryColor,
            headerForegroundColor: Colors.white,
            dividerColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: primaryColor),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          _logsFromDate = picked;
        } else {
          _logsToDate = picked;
        }
      });
    }
  }

  String _formatLogDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateTimeStr);
      return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTimeStr;
    }
  }

  // Cached colors for the overlay (set when the search field builds)
  Color? _overlayTextColor;
  Color? _overlayBorderColor;

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.length > 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        _searchScrip(query);
      });
    } else {
      _removeSearchOverlay();
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<void> _searchScrip(String query) async {
    if (!mounted) return;
    try {
      final api = locator<ApiExporter>();
      final result = await api.getSearchScrip(searchText: query);
      if (!mounted) return;
      setState(() {
        if (result.stat != 'Not_Ok' && result.values != null) {
          _searchResults = result.values!
              .where((scrip) =>
                  scrip.idx?.toUpperCase() != 'YES' &&
                  scrip.instname?.toUpperCase() != 'UNDIND' &&
                  scrip.instname?.toUpperCase() != 'COM')
              .toList();
        } else {
          _searchResults = [];
        }
      });
      if (_searchResults.isNotEmpty &&
          _overlayTextColor != null &&
          _overlayBorderColor != null) {
        _showSearchOverlay(_overlayTextColor!, _overlayBorderColor!);
      } else {
        _removeSearchOverlay();
      }
    } catch (e) {
      if (!mounted) return;
      _removeSearchOverlay();
      setState(() {
        _searchResults = [];
      });
    }
  }

  void _onScripSelected(ScripValue scrip) {
    setState(() {
      _selectedScrip = scrip;
      _searchController.text = scrip.tsym ?? '';
      _searchResults = [];
      _productType = 'I';
      _resetCOBOState();
    });
  }

  void _clearSelectedScrip() {
    setState(() {
      _selectedScrip = null;
      _searchController.clear();
      _searchResults = [];
      _productType = 'I';
      _resetCOBOState();
    });
  }

  void _resetCOBOState() {
    _isCoverOrder = true;
    _isBracketOrder = false;
    _resetCOBOFields();
  }

  String _buildJsonString() {
    final webhook = _selectedWebhook;
    final clientId = webhook?['clientid']?.toString() ?? _clientId;
    // final webhookName = webhook?['name']?.toString() ?? '';

    String exch;
    String tsym;
    if (_selectedScrip != null) {
      // User selected a scrip via search – use it
      exch = _selectedScrip!.exch ?? '';
      tsym = _selectedScrip!.tsym ?? '';
    } else if (_symbolType == 'dyn') {
      exch = '{{exchange}}';
      tsym = '{{ticker}}';
    } else {
      exch = '';
      tsym = '';
    }

    final prc = _orderType == 'MKT' ? '0' : _limitPrice;
    String prd;
    if (_productType == 'H') {
      prd = 'H'; // Cover Order
    } else if (_productType == 'B') {
      prd = 'B'; // Bracket Order
    } else if (_productType == 'I') {
      prd = 'I';
    } else if (_productType == 'C' ||
        _selectedScrip?.exch == 'NSE' ||
        _selectedScrip?.exch == 'BSE') {
      prd = 'C';
    } else {
      prd = 'M';
    }
    final trantype = _isSell ? 'S' : 'B';

    // Build base JSON map
    final jsonMap = <String, String>{
      'clientid': clientId,
      'exch': exch,
      'tsym': tsym,
      'prc': prc,
      'prd': prd,
      'trantype': trantype,
      'prctyp': _orderType,
      'ret': 'DAY',
      'qty': _quantity,
    };

    // Add CO-BO specific fields
    if (_isCOBO) {
      // Stoploss (blprc) - required for both CO and BO
      jsonMap['blprc'] = _stoploss;

      // Target (bpprc) - only for Bracket Order
      if (_isBracketOrder) {
        jsonMap['bpprc'] = _target;
      }

    }

    return jsonEncode(jsonMap);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    snack.successMessage(context, '$label Copied');
  }

  bool get _isExchangeEquity =>
      _selectedScrip?.exch == 'NSE' || _selectedScrip?.exch == 'BSE';

  Future<bool?> _showRegenerateConfirmDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: resolveThemeColor(
                context,
                dark: MyntColors.dialogDark,
                light: MyntColors.dialog,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row with title and close button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Regenerate Webhook',
                        style: MyntWebTextStyles.title(
                          context,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content area
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Are you sure you want to regenerate the webhook URL? The current URL will be replaced.',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.body(
                          context,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: resolveThemeColor(context,
                                dark: MyntColors.secondary,
                                light: MyntColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Regenerate',
                            style: MyntWebTextStyles.buttonMd(
                              context,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onGenerate() async {
    final name = _clientId;

    final result = await WebAuthApi.createWebhook(
      clientId: _clientId,
      token: _apiToken,
      name: name,
      context: context,
    );

    if (!mounted) return;
    if (result != null) {
      final message = result['msg'] ?? result['emsg'] ?? '';
      if (result['stat'] == 'Ok') {
        snack.successMessage(context, message.isNotEmpty ? message : 'Webhook generated successfully');
        setState(() => _isGenerated = true);
      } else {
        snack.error(context, message.isNotEmpty ? message : 'Failed to generate webhook');
      }
      _fetchWebhookList();
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final bgColor = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor);
    final cardColor = resolveThemeColor(context,
        dark: MyntColors.dashboardCarColor, light: MyntColors.card);
    final inputBg = resolveThemeColor(context,
        dark: MyntColors.inputBgDark, light: MyntColors.listItemBg);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final buyColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final sellColor = resolveThemeColor(context,
        dark: MyntColors.errorDark, light: MyntColors.tertiary);

    final jsonStr = _buildJsonString();
    final prettyJson = _formatJsonPretty(jsonStr);

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 3000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // // ── Header ──
                // Row(
                //   children: [
                //     const SizedBox(width: 14),
                //     Text(
                //       'WebHook Trading View',
                //       style: MyntWebTextStyles.hero(
                //         context,
                //         fontWeight: MyntFonts.bold,
                //         darkColor: MyntColors.textPrimaryDark,
                //         lightColor: MyntColors.textPrimary,
                //       ),
                //     ),
                //   ],
                // ),
                // const SizedBox(height: 32),

                // ── URL Section Card ──
                _buildCard(
                  borderColor: borderColor,
                  cardColor: cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'WebHook URL for TradingView',
                            style: MyntWebTextStyles.title(
                              context,
                              fontWeight: MyntFonts.semiBold,
                              darkColor: MyntColors.textPrimaryDark,
                              lightColor: MyntColors.textPrimary,
                            ),
                          ),
                          // Active / Inactive toggle + Expired badge
                          Row(
                            children: [
                              if (_isWebhookExpired) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: resolveThemeColor(context,
                                            dark: MyntColors.errorDark,
                                            light: MyntColors.tertiary)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: resolveThemeColor(context,
                                              dark: MyntColors.errorDark,
                                              light: MyntColors.tertiary)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'Expired',
                                    style: MyntWebTextStyles.bodySmall(
                                      context,
                                      fontWeight: MyntFonts.semiBold,
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.errorDark,
                                          light: MyntColors.tertiary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Text(
                                _isWebhookActive ? 'Active' : 'Inactive',
                                style: MyntWebTextStyles.bodySmall(
                                  context,
                                  fontWeight: MyntFonts.semiBold,
                                  color: _isWebhookActive
                                      ? resolveThemeColor(context,
                                          dark: MyntColors.profitDark,
                                          light: MyntColors.profit)
                                      : subtitleColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    if (_selectedWebhook == null) return;
                                    final id = _selectedWebhook!['id'] as int? ?? 0;
                                    _toggleWebhookStatus(id, _isWebhookActive);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 40,
                                    height: 22,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: _isWebhookActive
                                          ? resolveThemeColor(context,
                                              dark: MyntColors.successDark,
                                              light: MyntColors.success)
                                          : resolveThemeColor(context,
                                              dark: MyntColors.cardBorderDark,
                                              light: MyntColors.cardBorder),
                                    ),
                                    child: AnimatedAlign(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      alignment: _isWebhookActive
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: inputBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: SelectableText(
                                _webhookUrl.isEmpty
                                    ? 'Click the "Generate" button to create a webhook URL'
                                    : _webhookUrl,
                                style: MyntWebTextStyles.body(
                                  context,
                                  darkColor: _webhookUrl.isEmpty
                                      ? MyntColors.textPrimaryDark
                                            .withValues(alpha: 0.4)
                                      : MyntColors.textPrimaryDark,
                                  lightColor: _webhookUrl.isEmpty
                                      ? MyntColors.textPrimary
                                            .withValues(alpha: 0.4)
                                      : MyntColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildIconButton(
                            icon: Icons.copy_rounded,
                            tooltip: 'Copy URL',
                            onTap: () =>
                                _copyToClipboard(_webhookUrl, 'URL'),
                            color: primaryColor,
                          ),
                          const SizedBox(width: 8),
                          if (_webhookList.isEmpty)
                            TextButton(
                              onPressed: _onGenerate,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 17),
                                backgroundColor: resolveThemeColor(context,
                                    dark: MyntColors.secondary,
                                    light: MyntColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: Text(
                                'Generate',
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.semiBold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else
                            TextButton(
                              onPressed: () async {
                                final confirm =
                                    await _showRegenerateConfirmDialog();
                                if (confirm == true) {
                                  _onGenerate();
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 17),
                                backgroundColor: resolveThemeColor(context,
                                    dark: MyntColors.secondary,
                                    light: MyntColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: Text(
                                'Regenerate',
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.semiBold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_webhookUrl.isNotEmpty) ...[
                         if (_isWebhookExpired)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: resolveThemeColor(context,
                                    dark: MyntColors.errorDark,
                                    light: MyntColors.tertiary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: resolveThemeColor(context,
                                      dark: MyntColors.errorDark,
                                      light: MyntColors.tertiary)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                             child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.errorDark,
                                    light: MyntColors.tertiary),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This webhook URL expired on $_formattedExpiry. Please regenerate a new webhook URL.',
                                  style: MyntWebTextStyles.para(
                                    context,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.errorDark,
                                        light: MyntColors.tertiary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        else
                        Text(
                          'This URL is about to expire tonight. You must create a new webhook URL tomorrow.',
                          style: MyntWebTextStyles.para(
                            context,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (_webhookUrl.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: resolveThemeColor(context,
                                  dark: MyntColors.warningDark,
                                  light: MyntColors.warning)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: resolveThemeColor(context,
                                    dark: MyntColors.warningDark,
                                    light: MyntColors.warning)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.warningDark,
                                  light: MyntColors.warning),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Do not logout while webhooks are active. Logging out will expire the session and your webhooks will stop working.',
                                style: MyntWebTextStyles.para(
                                  context,
                                  color: subtitleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Tab Switcher ──
                _buildTabSwitcher(primaryColor, borderColor, inputBg),
                const SizedBox(height: 20),

                // ── Tab Content ──
                if (_selectedTab == 0)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildOrderParamsCard(
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                          borderColor: borderColor,
                          cardColor: cardColor,
                          inputBg: inputBg,
                          primaryColor: primaryColor,
                          buyColor: buyColor,
                          sellColor: sellColor,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: _buildJsonOutputCard(
                          textColor: textColor,
                          borderColor: borderColor,
                          cardColor: cardColor,
                          inputBg: inputBg,
                          primaryColor: primaryColor,
                          prettyJson: prettyJson,
                          jsonStr: jsonStr,
                        ),
                      ),
                    ],
                  )
                else
                  _buildLogsTab(
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    borderColor: borderColor,
                    cardColor: cardColor,
                    inputBg: inputBg,
                    primaryColor: primaryColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Order Params Generator Card ──
  Widget _buildOrderParamsCard({
    required Color textColor,
    required Color subtitleColor,
    required Color borderColor,
    required Color cardColor,
    required Color inputBg,
    required Color primaryColor,
    required Color buyColor,
    required Color sellColor,
  }) {
    return _buildCard(
      borderColor: borderColor,
      cardColor: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header: title + BUY / SELL in container
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Params Generator',
                style: MyntWebTextStyles.title(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
              ),
              _buildBuySellToggle(buyColor: buyColor, sellColor: sellColor),
            ],
          ),
          const SizedBox(height: 24),

          // ── Row 1: Symbol | Search ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Symbol', subtitleColor),
                    const SizedBox(height: 10),
                    _buildChipGroup(
                      options: const {'dyn': 'Dynamic', 'stat': 'Static'},
                      selected: _symbolType,
                      onSelected: (val) {
                        setState(() {
                          _symbolType = val;
                          _clearSelectedScrip();
                          _productType = 'I';
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Search', subtitleColor),
                    const SizedBox(height: 10),
                    _buildSearchField(inputBg, textColor, borderColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Row 2: Product Type | Quantity ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Product Type', subtitleColor),
                    const SizedBox(height: 10),
                    _buildProductTypeChips(
                        primaryColor: primaryColor),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Quantity', subtitleColor),
                    const SizedBox(height: 10),
                    _buildQuantityInput(
                        inputBg, textColor, borderColor, primaryColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Row 3: Order Type | Price ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Order Type', subtitleColor),
                    const SizedBox(height: 10),
                    _buildChipGroup(
                      options: const {
                        'MKT': 'Market',
                        'LMT': 'Limit'
                      },
                      selected: _orderType,
                      onSelected: (val) =>
                          setState(() => _orderType = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Price', subtitleColor),
                    const SizedBox(height: 10),
                    _buildPriceInput(
                        inputBg, textColor, borderColor),
                  ],
                ),
              ),
            ],
          ),

          // ── CO-BO Section (visible only when CO-BO product type selected) ──
          if (_isCOBO) ...[
            const SizedBox(height: 20),
            _buildCOBOSection(
              textColor: textColor,
              subtitleColor: subtitleColor,
              borderColor: borderColor,
              inputBg: inputBg,
              primaryColor: primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  final LayerLink _searchLayerLink = LayerLink();

  // ── JSON Output Card ──
  Widget _buildJsonOutputCard({
    required Color textColor,
    required Color borderColor,
    required Color cardColor,
    required Color inputBg,
    required Color primaryColor,
    required String prettyJson,
    required String jsonStr,
  }) {
    return _buildCard(
      borderColor: borderColor,
      cardColor: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WebHook Json String',
            style: MyntWebTextStyles.title(
              context,
              fontWeight: MyntFonts.semiBold,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (_isGenerated) ...[
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(
                      left: 16, right: 40, top: 16, bottom: 16),
                  constraints: const BoxConstraints(minHeight: 200),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: SelectableText(
                    prettyJson,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: textColor,
                      height: 1.7,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'Copy JSON',
                    onTap: () => _copyToClipboard(jsonStr, 'JSON'),
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.data_object_rounded,
                      size: 40,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textTertiaryDark,
                          light: MyntColors.textTertiary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No webhook data available',
                      textAlign: TextAlign.center,
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        darkColor: MyntColors.textTertiaryDark,
                        lightColor: MyntColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab Switcher ──
  Widget _buildTabSwitcher(
      Color primaryColor, Color borderColor, Color inputBg) {
    final tabs = ['Param Generator', 'Logs'];
    return Row(
      children: tabs.asMap().entries.map((entry) {
        final index = entry.key;
        final label = entry.value;
        final isActive = _selectedTab == index;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (_selectedTab != index) {
                setState(() => _selectedTab = index);
                if (index == 1 && _logsList.isEmpty && !_isLoadingLogs) {
                  _fetchWebhookLogs();
                }
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? resolveThemeColor(context,
                        dark: Colors.white.withValues(alpha: 0.1),
                        light: Colors.black.withValues(alpha: 0.05))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight:
                      isActive ? MyntFonts.semiBold : MyntFonts.medium,
                ).copyWith(
                  color: isActive
                      ? shadcn.Theme.of(context).colorScheme.foreground
                      : shadcn.Theme.of(context).colorScheme.mutedForeground,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Logs Tab ──
  Widget _buildLogsTab({
    required Color textColor,
    required Color subtitleColor,
    required Color borderColor,
    required Color cardColor,
    required Color inputBg,
    required Color primaryColor,
  }) {
    return _buildCard(
      borderColor: borderColor,
      cardColor: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title left, date pickers + refresh right
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Webhook Logs',
                style: MyntWebTextStyles.title(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
              ),
              const Spacer(),
              // From Date
              _buildDateField(
                label: 'From',
                date: _logsFromDate,
                onTap: () => _pickDate(isFrom: true),
                primaryColor: primaryColor,
                inputBg: inputBg,
                borderColor: borderColor,
              ),
              const SizedBox(width: 12),
              // To Date
              _buildDateField(
                label: 'To',
                date: _logsToDate,
                onTap: () => _pickDate(isFrom: false),
                primaryColor: primaryColor,
                inputBg: inputBg,
                borderColor: borderColor,
              ),
              const SizedBox(width: 12),
              // Refresh button
              IconButton(
                onPressed: _isLoadingLogs ? null : _fetchWebhookLogs,
                icon: _isLoadingLogs
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary),
                        ),
                      )
                    : Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                      ),
                tooltip: 'Refresh',
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Table
          if (_isLoadingLogs)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_logsList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Text(
                  'No logs found for the selected date range',
                  style: MyntWebTextStyles.tableCell(
                    context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            _buildLogsTable(
              textColor: textColor,
              subtitleColor: subtitleColor,
              borderColor: borderColor,
              primaryColor: primaryColor,
            ),
        ],
      ),
    );
  }

  // ── Date Field Widget ──
  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required Color primaryColor,
    required Color inputBg,
    required Color borderColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: MyntWebTextStyles.bodySmall(
            context,
            fontWeight: MyntFonts.medium,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('dd-MM-yyyy').format(date),
                  style: MyntWebTextStyles.body(
                    context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Logs Table (positions-style) ──
  Widget _buildLogsTable({
    required Color textColor,
    required Color subtitleColor,
    required Color borderColor,
    required Color primaryColor,
  }) {
    final headers = ['Time', 'Symbol', 'Exchange', 'Action', 'Qty', 'Price', 'Status'];

    return shadcn.OutlinedContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final columnWidths = <int, shadcn.TableSize>{
            0: shadcn.FixedTableSize(w * 0.18), // Time
            1: shadcn.FixedTableSize(w * 0.18), // Symbol
            2: shadcn.FixedTableSize(w * 0.10), // Exchange
            3: shadcn.FixedTableSize(w * 0.10), // Action
            4: shadcn.FixedTableSize(w * 0.10), // Qty
            5: shadcn.FixedTableSize(w * 0.14), // Price
            6: shadcn.FixedTableSize(w * 0.20), // Status
          };

          return Column(
            children: [
              // Fixed Header
              shadcn.Table(
                columnWidths: columnWidths,
                defaultRowHeight: const shadcn.FixedTableSize(44),
                rows: [
                  shadcn.TableHeader(
                    cells: headers.asMap().entries.map((entry) {
                      final i = entry.key;
                      final h = entry.value;
                      return _buildLogHeaderCell(
                        h,
                        padding: i == 0
                            ? const EdgeInsets.fromLTRB(16, 6, 4, 6)
                            : i == headers.length - 1
                                ? const EdgeInsets.fromLTRB(4, 6, 16, 6)
                                : const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                      );
                    }).toList(),
                  ),
                ],
              ),
              // Scrollable Body
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500),
                child: SingleChildScrollView(
                  child: shadcn.Table(
                    columnWidths: columnWidths,
                    defaultRowHeight: const shadcn.FixedTableSize(50),
                    rows: _logsList.asMap().entries.map((entry) {
                      final index = entry.key;
                      final log = entry.value;

                      final time = _formatLogDateTime(
                          log['executed_at']?.toString());
                      final symbol = log['tsym']?.toString() ?? '-';
                      final exchange = log['exch']?.toString() ?? '-';
                      final action = log['trantype']?.toString() ?? '-';
                      final qty = log['qty']?.toString() ?? '-';
                      final price = log['prc']?.toString() ?? '-';
                      final status = log['order_status']?.toString() ?? '-';
                      final errorMsg = log['error_message']?.toString();
                      final hasError = errorMsg != null &&
                          errorMsg.isNotEmpty &&
                          errorMsg != 'null';

                      final isBuy = action.toUpperCase() == 'B' ||
                          action.toUpperCase() == 'BUY';

                      return shadcn.TableRow(
                        cells: [
                          // Time
                          _buildLogCell(
                            rowIndex: index,
                            onTap: () => _openLogDetailSheet(log),
                            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                            child: Text(
                              time,
                              style: MyntWebTextStyles.tableCell(
                                context,
                                darkColor: MyntColors.textSecondaryDark,
                                lightColor: MyntColors.textSecondary,
                              ),
                            ),
                          ),
                          // Symbol
                          _buildLogCell(
                            rowIndex: index,
                            onTap: () => _openLogDetailSheet(log),
                            child: Text(
                              symbol,
                              style: MyntWebTextStyles.tableCell(
                                context,
                                darkColor: MyntColors.textPrimaryDark,
                                lightColor: MyntColors.textPrimary,
                                fontWeight: MyntFonts.medium,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Exchange
                          _buildLogCell(
                            rowIndex: index,
                            onTap: () => _openLogDetailSheet(log),
                            child: Text(
                              exchange,
                              style: MyntWebTextStyles.tableCell(
                                context,
                                darkColor: MyntColors.textSecondaryDark,
                                lightColor: MyntColors.textSecondary,
                              ),
                            ),
                          ),
                          // Action (Buy/Sell colored)
                          _buildLogCell(
                            rowIndex: index,
                            onTap: () => _openLogDetailSheet(log),
                            child: Text(
                              isBuy ? 'BUY' : (action == '-' ? '-' : 'SELL'),
                              style: MyntWebTextStyles.tableCell(
                                context,
                                fontWeight: MyntFonts.semiBold,
                                color: isBuy
                                    ? resolveThemeColor(context,
                                        dark: MyntColors.profitDark,
                                        light: MyntColors.profit)
                                    : action == '-'
                                        ? null
                                        : resolveThemeColor(context,
                                            dark: MyntColors.lossDark,
                                            light: MyntColors.loss),
                              ),
                            ),
                          ),
                          // Qty
                          _buildLogCell(
                            rowIndex: index,
                            onTap: () => _openLogDetailSheet(log),
                            child: Text(
                              qty,
                              style: MyntWebTextStyles.tableCell(
                                context,
                                darkColor: MyntColors.textPrimaryDark,
                                lightColor: MyntColors.textPrimary,
                              ),
                            ),
                          ),
                          // Price
                          _buildLogCell(
                            rowIndex: index,
                            onTap: () => _openLogDetailSheet(log),
                            child: Text(
                              price,
                              style: MyntWebTextStyles.tableCell(
                                context,
                                darkColor: MyntColors.textPrimaryDark,
                                lightColor: MyntColors.textPrimary,
                              ),
                            ),
                          ),
                          // Status (with error tooltip on hover)
                          _buildLogCell(
                            rowIndex: index,
                            onTap: () => _openLogDetailSheet(log),
                            padding:
                                const EdgeInsets.fromLTRB(4, 8, 16, 8),
                            child: Tooltip(
                                message: hasError ? errorMsg : '',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (status.toLowerCase() == 'ok' ||
                                            status.toLowerCase() == 'success')
                                        ? resolveThemeColor(context,
                                                dark: MyntColors.profitDark,
                                                light: MyntColors.profit)
                                            .withValues(alpha: 0.12)
                                        : (status.toLowerCase() == 'failed' ||
                                                status.toLowerCase() == 'error' ||
                                                status.toLowerCase() == 'rejected')
                                            ? resolveThemeColor(context,
                                                    dark: MyntColors.lossDark,
                                                    light: MyntColors.loss)
                                                .withValues(alpha: 0.12)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: MyntWebTextStyles.bodySmall(
                                      context,
                                      color: (status.toLowerCase() == 'ok' ||
                                              status.toLowerCase() == 'success')
                                          ? resolveThemeColor(context,
                                              dark: MyntColors.profitDark,
                                              light: MyntColors.profit)
                                          : (status.toLowerCase() == 'failed' ||
                                                  status.toLowerCase() == 'error' ||
                                                  status.toLowerCase() == 'rejected')
                                              ? resolveThemeColor(context,
                                                  dark: MyntColors.lossDark,
                                                  light: MyntColors.loss)
                                              : null,
                                      fontWeight: MyntFonts.medium,
                                      darkColor: MyntColors.textPrimaryDark,
                                      lightColor: MyntColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                  ),
                                ),
                              ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Log table header cell (positions pattern) ──
  shadcn.TableCell _buildLogHeaderCell(String label,
      {EdgeInsets padding =
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6)}) {
    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: Container(
        padding: padding,
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: MyntWebTextStyles.tableHeader(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
            fontWeight: MyntFonts.semiBold,
          ),
        ),
      ),
    );
  }

  // ── Log table body cell with hover (positions pattern) ──
  shadcn.TableCell _buildLogCell({
    required Widget child,
    required int rowIndex,
    EdgeInsets padding =
        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    VoidCallback? onTap,
  }) {
    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => _hoveredLogRow.value = rowIndex,
        onExit: (_) => _hoveredLogRow.value = null,
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredLogRow,
          child: child,
          builder: (context, hoveredIndex, cachedChild) {
            final isHovered = hoveredIndex == rowIndex;

            Color? backgroundColor;
            if (isHovered) {
              backgroundColor = resolveThemeColor(context,
                  dark: MyntColors.primaryDark.withValues(alpha: 0.08),
                  light: MyntColors.primary.withValues(alpha: 0.08));
            }

            return GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: padding,
                color: backgroundColor,
                alignment: Alignment.centerLeft,
                child: cachedChild,
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Log Detail Sheet ──

  void _openLogDetailSheet(Map<String, dynamic> log) {
    if (_isSheetOpening) return;
    _isSheetOpening = true;

    shadcn.openSheet(
      context: context,
      builder: (sheetContext) {
        final screenWidth = MediaQuery.of(sheetContext).size.width;
        final sheetWidth = screenWidth < 1300 ? screenWidth * 0.3 : 480.0;
        return Container(
          width: sheetWidth,
          decoration: BoxDecoration(
            color: resolveThemeColor(
              context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor,
            ),
            boxShadow: isDarkMode(context)
                ? MyntShadows.panelRightDark
                : MyntShadows.panelRight,
          ),
          child: _buildLogDetailContent(sheetContext, log),
        );
      },
      position: shadcn.OverlayPosition.end,
      barrierColor: Colors.transparent,
    ).then((_) {
      _isSheetOpening = false;
    });
  }

  Widget _buildLogDetailContent(
      BuildContext sheetContext, Map<String, dynamic> log) {
    final status = log['order_status']?.toString() ?? '-';
    final trantype = log['trantype']?.toString() ?? '-';
    final isBuy =
        trantype.toUpperCase() == 'B' || trantype.toUpperCase() == 'BUY';
    final qty = log['qty']?.toString() ?? '-';
    final price = log['prc']?.toString() ?? '-';
    final prd = log['prd']?.toString() ?? '-';
    final prctyp = log['prctyp']?.toString() ?? '-';
    final orderId = log['noren_order_number']?.toString() ?? '-';
    final exchange = log['exch']?.toString() ?? '-';
    final symbol = log['tsym']?.toString() ?? '-';
    final webhookName = log['webhook_name']?.toString() ?? '-';
    final executedAt = log['executed_at']?.toString() ?? '-';
    final errorMessage = log['error_message']?.toString();

    String productLabel;
    switch (prd) {
      case 'I':
        productLabel = 'Intraday';
        break;
      case 'C':
        productLabel = 'Delivery';
        break;
      case 'M':
        productLabel = 'NRML';
        break;
      case 'H':
        productLabel = 'Cover Order';
        break;
      case 'B':
        productLabel = 'Bracket Order';
        break;
      default:
        productLabel = prd;
    }

    final isSuccess =
        status.toLowerCase() == 'ok' || status.toLowerCase() == 'success';
    final isFailed = status.toLowerCase() == 'failed' ||
        status.toLowerCase() == 'error' ||
        status.toLowerCase() == 'rejected';
    final statusColor = isSuccess
        ? resolveThemeColor(
            context, dark: MyntColors.profitDark, light: MyntColors.profit)
        : isFailed
            ? resolveThemeColor(
                context, dark: MyntColors.lossDark, light: MyntColors.loss)
            : resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary);

    final divider = resolveThemeColor(
        context, dark: MyntColors.dividerDark, light: MyntColors.divider);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: divider, width: 1)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => shadcn.closeSheet(sheetContext),
                child: Icon(Icons.close, size: 20, color: textPrimary),
              ),
              const SizedBox(width: 16),
              Text(
                'Webhook Log Details',
                style: MyntWebTextStyles.title(
                    context, color: textPrimary),
              ),
            ],
          ),
        ),
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    symbol,
                    style: MyntWebTextStyles.title(
                      context,
                      color: textPrimary,
                      fontWeight: MyntFonts.semiBold,
                    ),
                  ),
                  if (webhookName != symbol && webhookName != '-') ...[
                    const SizedBox(height: 4),
                    Text(
                      webhookName,
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _logDetailRowWithColor(
                      'Status', status.toUpperCase(), statusColor),
                  _logDetailRow('Type', isBuy ? 'Buy' : 'Sell'),
                  _logDetailRow('Qty', qty),
                  _logDetailRow('Price', price),
                  _logDetailRow('Product / Type', '$productLabel / $prctyp'),
                  _logDetailRow('Order Id', orderId),
                  _logDetailRow('Exchange', exchange),
                  _logDetailRow(
                      'Date & Time', _formatLogDateTime(executedAt)),
                  if (errorMessage != null &&
                      errorMessage.isNotEmpty &&
                      errorMessage != 'null')
                    _logDetailReasonRow('Reason', errorMessage),
                  // Raw Body for failed logs
                  if (isFailed &&
                      log['raw_body'] != null &&
                      log['raw_body'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Raw Body',
                      style: MyntWebTextStyles.body(
                        context,
                        color: textPrimary,
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: resolveThemeColor(context,
                            dark: MyntColors.inputBgDark,
                            light: MyntColors.listItemBg),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: resolveThemeColor(context,
                              dark: MyntColors.cardBorderDark,
                              light: MyntColors.cardBorder),
                        ),
                      ),
                      child: SelectableText(
                        _formatJsonPretty(log['raw_body'].toString()),
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          darkColor: MyntColors.textSecondaryDark,
                          lightColor: MyntColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _logDetailRow(String title, String value) {
    final divider = resolveThemeColor(
        context, dark: MyntColors.dividerDark, light: MyntColors.divider);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: MyntWebTextStyles.body(
                context,
                color: textPrimary,
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: MyntWebTextStyles.body(
                context,
                color: textPrimary,
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logDetailRowWithColor(String title, String value, Color valueColor) {
    final divider = resolveThemeColor(
        context, dark: MyntColors.dividerDark, light: MyntColors.divider);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: MyntWebTextStyles.body(
                context,
                color: textPrimary,
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: valueColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: MyntWebTextStyles.body(
                  context,
                  color: valueColor,
                  fontWeight: MyntFonts.medium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logDetailReasonRow(String title, String value) {
    final divider = resolveThemeColor(
        context, dark: MyntColors.dividerDark, light: MyntColors.divider);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: MyntWebTextStyles.body(
              context,
              color: textPrimary,
              fontWeight: MyntFonts.medium,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: MyntWebTextStyles.bodySmall(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.lossDark, light: MyntColors.loss),
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pretty-print JSON ──
  String _formatJsonPretty(String json) {
    try {
      final decoded = jsonDecode(json);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return json;
    }
  }

  // ══════════════════════════════════════════
  //  UI Helpers
  // ══════════════════════════════════════════

  Widget _buildFieldLabel(String label, Color color) {
    return Text(
      label,
      style: MyntWebTextStyles.para(
        context,
        fontWeight: MyntFonts.semiBold,
        color: color,
      ),
    );
  }

  Widget _buildCard({
    required Color borderColor,
    required Color cardColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  /// Chip-style segmented button matching Order Preference page pattern.
  /// Each chip takes only the width it needs.
  Widget _buildChipGroup({
    required Map<String, String> options,
    required String selected,
    required ValueChanged<String> onSelected,
    Map<String, Color>? activeColors,
  }) {
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final inputBg = resolveThemeColor(context,
        dark: MyntColors.inputBgDark, light: MyntColors.listItemBg);
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final entries = options.entries.toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((entry) {
        final isSelected = selected == entry.key;
        final chipColor = activeColors?[entry.key] ?? primaryColor;

        return TextButton(
          onPressed: () => onSelected(entry.key),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            minimumSize: const Size(0, 38),
            backgroundColor: isSelected ? inputBg : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(
                color: isSelected ? chipColor : borderColor,
                width: 1,
              ),
            ),
          ),
          child: Text(
            entry.value,
            style: MyntWebTextStyles.body(
              context,
              fontWeight: isSelected ? MyntFonts.semiBold : MyntFonts.regular,
              color: isSelected
                  ? chipColor
                  : resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBuySellToggle({
    required Color buyColor,
    required Color sellColor,
  }) {
    final bgColor = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor);
    final activeColor = !_isSell ? buyColor : sellColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // B button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _isSell = false),
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: buyColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: Text(
                  'B',
                  style: MyntWebTextStyles.para(
                    context,
                    color: Colors.white,
                    fontWeight: MyntFonts.medium,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Toggle switch
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(() => _isSell = !_isSell),
            child: Container(
              width: 43,
              height: 22,
              decoration: BoxDecoration(
                color: bgColor,
                border: Border.all(color: activeColor),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    left: !_isSell ? 2 : 24,
                    top: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // S button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _isSell = true),
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: sellColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: Text(
                  'S',
                  style: MyntWebTextStyles.para(
                    context,
                    color: Colors.white,
                    fontWeight: MyntFonts.medium,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool get _isCOBO => _productType == 'H' || _productType == 'B';

  // ── CO-BO Section ──
  Widget _buildCOBOSection({
    required Color textColor,
    required Color subtitleColor,
    required Color borderColor,
    required Color inputBg,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover / Bracket Toggle (mutually exclusive) ──
          Row(
            children: [
              // Cover - Only SL
              _buildCOBOCheckbox(
                label: 'Cover - Only SL',
                value: _isCoverOrder,
                onChanged: (val) {
                  setState(() {
                    _isCoverOrder = val ?? false;
                    _isBracketOrder = !_isCoverOrder;
                    _productType = _isCoverOrder ? 'H' : 'B';
                    if (_isCoverOrder) {
                      // Clear bracket-only fields
                      _target = '0';
                      _targetController.text = '0';
                    }
                  });
                },
                primaryColor: primaryColor,
                textColor: textColor,
              ),
              const SizedBox(width: 32),
              // Bracket - TGT / SL
              _buildCOBOCheckbox(
                label: 'Bracket - TGT / SL',
                value: _isBracketOrder,
                onChanged: (val) {
                  setState(() {
                    _isBracketOrder = val ?? false;
                    _isCoverOrder = !_isBracketOrder;
                    _productType = _isBracketOrder ? 'B' : 'H';
                  });
                },
                primaryColor: primaryColor,
                textColor: textColor,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Row: Stoploss | Target (BO only) ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Stoploss (in Rs)', subtitleColor),
                    const SizedBox(height: 10),
                    MyntTextField(
                      controller: _stoplossController,
                      placeholder: '0.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (val) => setState(() => _stoploss = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: IgnorePointer(
                  ignoring: !_isBracketOrder,
                  child: Opacity(
                    opacity: _isBracketOrder ? 1.0 : 0.4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Target (in Rs)', subtitleColor),
                        const SizedBox(height: 10),
                        MyntTextField(
                          controller: _targetController,
                          placeholder: '0.00',
                          enabled: _isBracketOrder,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]')),
                          ],
                          onChanged: (val) => setState(() => _target = val),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildCOBOCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required Color primaryColor,
    required Color textColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: BorderSide(
              color: resolveThemeColor(context,
                  dark: MyntColors.cardBorderDark,
                  light: MyntColors.cardBorder),
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: MyntWebTextStyles.body(
            context,
            fontWeight: value ? MyntFonts.semiBold : MyntFonts.regular,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildProductTypeChips({required Color primaryColor}) {
    final options = <String, String>{'I': 'Intraday'};
    if (_symbolType == 'stat' && _selectedScrip != null) {
      if (_isExchangeEquity) {
        options['C'] = 'Delivery';
      } else {
        options['M'] = 'NRML';
      }
    } else {
      options['C'] = 'Delivery';
    }
    
    options['CO-BO'] = 'CO - BO';

    // Map the internal product type to the chip key for selection
    final selectedKey = _isCOBO ? 'CO-BO' : _productType;

    return _buildChipGroup(
      options: options,
      selected: selectedKey,
      onSelected: (val) {
        setState(() {
          if (val == 'CO-BO') {
            // Default to Cover Order when CO-BO is first selected
            _productType = 'H';
            _isCoverOrder = true;
            _isBracketOrder = false;
            _resetCOBOFields();
          } else {
            _productType = val;
            _resetCOBOFields();
          }
        });
      },
    );
  }

  void _resetCOBOFields() {
    _stoploss = '0';
    _target = '0';
    _stoplossController.text = '0';
    _targetController.text = '0';
  }

  Widget _buildQuantityInput(
      Color inputBg, Color textColor, Color borderColor, Color primaryColor) {
    return MyntTextField(
      controller: _qtyController,
      placeholder: '0',
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      leadingWidget: GestureDetector(
        onTap: () {
          int qty = int.tryParse(_qtyController.text) ?? 0;
          if (qty > 0) qty--;
          _qtyController.text = qty.toString();
          setState(() => _quantity = qty.toString());
        },
        child: Icon(
          Icons.remove,
          size: 18,
          color: primaryColor,
        ),
      ),
      trailingWidget: GestureDetector(
        onTap: () {
          int qty = int.tryParse(_qtyController.text) ?? 0;
          qty++;
          _qtyController.text = qty.toString();
          setState(() => _quantity = qty.toString());
        },
        child: Icon(
          Icons.add,
          size: 18,
          color: primaryColor,
        ),
      ),
      onChanged: (val) => setState(() => _quantity = val),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: resolveThemeColor(context,
                    dark: MyntColors.cardBorderDark,
                    light: MyntColors.cardBorder),
              ),
            ),
            child: Icon(icon, size: 18,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary)),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceInput(
      Color inputBg, Color textColor, Color borderColor) {
    final isEnabled = _orderType == 'LMT';
    return IgnorePointer(
      ignoring: !isEnabled,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.4,
        child: MyntTextField(
          controller: _priceController,
          enabled: isEnabled,
          placeholder: isEnabled ? '0' : 'Market Price',
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (val) => setState(() => _limitPrice = val),
        ),
      ),
    );
  }

  OverlayEntry? _searchOverlay;

  void _showSearchOverlay(Color textColor, Color borderColor) {
    _removeSearchOverlay();
    final cardColor = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);

    _searchOverlay = OverlayEntry(
      builder: (context) => _SearchDropdownOverlay(
        link: _searchLayerLink,
        results: _searchResults,
        textColor: textColor,
        borderColor: borderColor,
        cardColor: cardColor,
        onSelected: (scrip) {
          _onScripSelected(scrip);
          _removeSearchOverlay();
        },
        onDismiss: _removeSearchOverlay,
      ),
    );
    Overlay.of(context).insert(_searchOverlay!);
  }

  void _removeSearchOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  Widget _buildSearchField(
      Color inputBg, Color textColor, Color borderColor) {
    // Cache colors so _searchScrip can trigger the overlay
    _overlayTextColor = textColor;
    _overlayBorderColor = borderColor;

    final isEnabled = _symbolType == 'stat';

    return IgnorePointer(
      ignoring: !isEnabled,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.4,
        child: CompositedTransformTarget(
          link: _searchLayerLink,
          child: MyntSearchTextField.withSmartClear(
            controller: _searchController,
            placeholder: 'Search Symbol Name Here..',
            leadingIcon: assets.searchIcon,
            leadingIconHoverEffect: true,
            enabled: isEnabled,
            inputFormatters: [
              UpperCaseTextFormatter(),
              FilteringTextInputFormatter.deny(RegExp('[π£•₹€℅™∆√¶/.,]')),
            ],
            onClear: () {
              _clearSelectedScrip();
              _removeSearchOverlay();
            },
            onChanged: _onSearchChanged,
          ),
        ),
      ),
    );
  }

}

/// Overlay dropdown for search results – renders above all other widgets.
class _SearchDropdownOverlay extends StatelessWidget {
  final LayerLink link;
  final List<ScripValue> results;
  final Color textColor;
  final Color borderColor;
  final Color cardColor;
  final ValueChanged<ScripValue> onSelected;
  final VoidCallback onDismiss;

  const _SearchDropdownOverlay({
    required this.link,
    required this.results,
    required this.textColor,
    required this.borderColor,
    required this.cardColor,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dismiss layer – tap outside to close
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        // Dropdown anchored below the search field
        CompositedTransformFollower(
          link: link,
          offset: const Offset(0, 44),
          showWhenUnlinked: false,
          child: Material(
            elevation: 0,
            color: Colors.transparent,
            child: Container(
              width: 400,
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
                boxShadow: isDarkMode(context)
                    ? MyntShadows.dropdownDark
                    : MyntShadows.dropdown,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final scrip = results[index];
                  return InkWell(
                    onTap: () => onSelected(scrip),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              scrip.tsym ?? '',
                              style: MyntWebTextStyles.bodySmall(
                                context,
                                fontWeight: MyntFonts.medium,
                                color: textColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: resolveThemeColor(context,
                                  dark: MyntColors.borderMutedDark,
                                  light: MyntColors.borderMuted),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              scrip.exch ?? '',
                              style: MyntWebTextStyles.caption(
                                context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textTertiaryDark,
                                    light: MyntColors.textTertiary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

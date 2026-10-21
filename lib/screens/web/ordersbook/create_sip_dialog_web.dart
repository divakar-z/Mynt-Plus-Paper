import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../models/order_book_model/sip_place_order.dart';
import '../../../models/marketwatch_model/search_scrip_new_model.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/res.dart';
import '../../../sharedWidget/common_text_fields_web.dart';
import '../../../sharedWidget/common_search_fields_web.dart';
import '../../../sharedWidget/no_data_found_web.dart';
import '../../../utils/responsive_snackbar.dart';

class CreateSipDialogWeb extends ConsumerStatefulWidget {
  const CreateSipDialogWeb({super.key});

  @override
  ConsumerState<CreateSipDialogWeb> createState() => _CreateSipDialogWebState();
}

class _CreateSipDialogWebState extends ConsumerState<CreateSipDialogWeb> {
  final TextEditingController _sipNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noOfSipsController =
      TextEditingController(text: '');

  DateTime? _startDate;
  String _selectedFrequency = '1'; // Weekly by default

  final List<SipScripItem> _addedScrips = [];
  bool _isLoading = false;
  bool _isSearching = false;
  Timer? _debounceTimer;
  final LayerLink _searchLayerLink = LayerLink();
  final GlobalKey _searchFieldKey = GlobalKey();

  final List<String> _frequencies = [
    'Daily',
    'Weekly',
    'Fortnightly',
    'Monthly'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _sipNameController.dispose();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _noOfSipsController.dispose();
    for (var item in _addedScrips) {
      item.qtyController.dispose();
      item.amountController.dispose();
    }
    super.dispose();
  }

  String _getFrequencyValue(String frequency) {
    switch (frequency) {
      case 'Daily':
        return '0';
      case 'Weekly':
        return '1';
      case 'Fortnightly':
        return '2';
      case 'Monthly':
        return '3';
      default:
        return '1';
    }
  }

  String _getFrequencyLabel(String value) {
    switch (value) {
      case '0':
        return 'Daily';
      case '1':
        return 'Weekly';
      case '2':
        return 'Fortnightly';
      case '3':
        return 'Monthly';
      default:
        return 'Weekly';
    }
  }

  void _showFrequencyPopup(BuildContext btnContext) {
    final btnWidth = (btnContext.findRenderObject() as RenderBox).size.width;
    shadcn.showPopover(
      context: btnContext,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 4),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(btnContext).borderRadiusLg,
      ),
      builder: (popoverContext) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(popoverContext).borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: shadcn.ModalContainer(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: btnWidth - 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _frequencies.map((freq) {
                  final isSelected =
                      _getFrequencyLabel(_selectedFrequency) == freq;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        shadcn.closeOverlay(popoverContext);
                        setState(() {
                          _selectedFrequency = _getFrequencyValue(freq);
                        });
                      },
                      splashColor: resolveThemeColor(
                        context,
                        dark: MyntColors.rippleDark,
                        light: MyntColors.rippleLight,
                      ),
                      highlightColor: resolveThemeColor(
                        context,
                        dark: MyntColors.highlightDark,
                        light: MyntColors.highlightLight,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Text(
                          freq,
                          style: MyntWebTextStyles.body(
                            context,
                            fontWeight: isSelected
                                ? MyntFonts.semiBold
                                : MyntFonts.medium,
                            color: isSelected
                                ? resolveThemeColor(context,
                                    dark: MyntColors.primaryDark,
                                    light: MyntColors.primary)
                                : resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectStartDate() async {
    try {
      final isDark = ref.read(themeProvider).isDarkMode;
      final now = DateTime.now();
      final initialDate =
          _startDate != null && !_startDate!.isBefore(now) ? _startDate! : now;
      final primary = isDark ? MyntColors.primaryDark : MyntColors.primary;
      final bg = isDark ? MyntColors.cardDark : MyntColors.card;
      final text = isDark ? MyntColors.textPrimaryDark : MyntColors.textPrimary;

      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        useRootNavigator: true, // Important for showing in sheet overlay

        builder: (dialogContext, child) => Theme(
          data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme:
                (isDark ? const ColorScheme.dark() : const ColorScheme.light())
                    .copyWith(
              primary: primary,
              onPrimary: Colors.white,
              surface: bg,
              onSurface: text,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: bg,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: primary,
              headerForegroundColor: Colors.white,
              dividerColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primary),
            ),
          ),
          child: child!,
        ),
      );
      if (picked != null && mounted) {
        setState(() {
          _startDate = picked;
        });
      }
    } catch (e) {
    }
  }

  List<ScripNewValue> _searchResults = [];

  String _lastSearchText = '';

  // The search field's X button only empties the text box; it never calls
  // onClear. Run the clear here when the box goes from text to empty.
  void _onSearchTextChanged() {
    final text = _searchController.text;
    final wasNotEmpty = _lastSearchText.isNotEmpty;
    _lastSearchText = text;
    if (text.isEmpty && wasNotEmpty) {
      _debounceTimer?.cancel();
      ref.read(marketWatchProvider).searchClear();
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    if (query.length < 2) {
      ref.read(marketWatchProvider).searchClear();
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Show loading indicator immediately
    setState(() => _isSearching = true);

    // Debounce the actual search by 400ms
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _searchScrips(query);
    });
  }

  Future<void> _searchScrips(String query) async {
    try {
      // Use 'EQ' segment for equity stocks (SIP only supports equity)
      // Pass NSE and BSE exchanges directly to API filter
      await ref.read(marketWatchProvider).fetchSearchScrip(
        searchText: query,
        context: context,
        segment: 'EQ',
        option: false,
        exchanges: ['NSE', 'BSE'],
      );
      // Get results directly after fetch completes
      if (mounted) {
        setState(() {
          _searchResults = ref.read(marketWatchProvider).allSearchScrip ?? [];
        });
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _addScrip(ScripNewValue scrip) {
    // Check if already added
    if (_addedScrips.any((s) => s.scrip.token == scrip.token)) {
      ResponsiveSnackBar.showWarning(context, '${scrip.tsym} is already added');
      return;
    }

    setState(() {
      _addedScrips.add(SipScripItem(
        scrip: scrip,
        investBy: 'Qty',
        qtyController: TextEditingController(text: '1'),
        amountController: TextEditingController(),
      ));
      // Clear search results to close dropdown
      _searchResults = [];
    });

    // Subscribe to WebSocket touchline for LTP
    ref.read(websocketProvider).establishConnection(
          channelInput: '${scrip.exch}|${scrip.token}',
          task: 't',
          context: context,
        );

    // Clear search field and provider
    _searchController.clear();
    ref.read(marketWatchProvider).searchClear();
  }

  void _removeScrip(int index) {
    setState(() {
      _addedScrips[index].qtyController.dispose();
      _addedScrips[index].amountController.dispose();
      _addedScrips.removeAt(index);
    });
  }

  Future<void> _createSip() async {
    // Validation
    if (_sipNameController.text.trim().isEmpty) {
      ResponsiveSnackBar.showWarning(context, 'Please enter SIP name');
      return;
    }
    if (_startDate == null) {
      ResponsiveSnackBar.showWarning(context, 'Please select start date');
      return;
    }
    if (_noOfSipsController.text.isEmpty ||
        int.tryParse(_noOfSipsController.text) == null) {
      ResponsiveSnackBar.showWarning(
          context, 'Please enter valid number of SIPs');
      return;
    }
    if (_addedScrips.isEmpty) {
      ResponsiveSnackBar.showWarning(context, 'Please add at least one stock');
      return;
    }

    // Validate qty/amount values
    for (var item in _addedScrips) {
      final isQtyMode = item.investBy == 'Qty';
      final value = isQtyMode
          ? item.qtyController.text.trim()
          : item.amountController.text.trim();
      if (value.isEmpty) {
        final fieldName = isQtyMode ? 'quantity' : 'amount';
        ResponsiveSnackBar.showWarning(
            context, 'Please enter valid $fieldName for ${item.scrip.tsym}');
        return;
      }
      if (isQtyMode) {
        final qty = int.tryParse(value);
        if (qty == null || qty <= 0) {
          ResponsiveSnackBar.showWarning(
              context, 'Please enter valid quantity for ${item.scrip.tsym}');
          return;
        }
      } else {
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) {
          ResponsiveSnackBar.showWarning(
              context, 'Please enter valid amount for ${item.scrip.tsym}');
          return;
        }
        // Validate amount is at least LTP (need at least 1 share worth)
        final ltp = double.tryParse(
              ref
                  .read(websocketProvider)
                  .getBestLTP(item.scrip.token ?? '', '0'),
            ) ??
            0;
        if (ltp > 0 && amount < ltp) {
          ResponsiveSnackBar.showWarning(context,
              'Amount must be at least LTP (${ltp.toStringAsFixed(2)}) for ${item.scrip.tsym}');
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      final regDate = _sipdateformat(DateTime.now());
      final startDate = _sipdateformat(_startDate!);

      final scrips = _addedScrips.map((item) {
        final isQtyMode = item.investBy == 'Qty';
        return SipScripInput(
          exch: item.scrip.exch ?? 'NSE',
          tsym: item.scrip.tsym ?? '',
          prd: 'C', // CNC for SIP
          token: item.scrip.token ?? '',
          qty: isQtyMode ? item.qtyController.text : '',
          sipType: isQtyMode ? 'qty' : 'prc',
          prc: isQtyMode ? null : item.amountController.text,
        );
      }).toList();

      final sipInput = SipBasketInput(
        regdate: regDate,
        startdate: startDate,
        frequency: _selectedFrequency,
        endperiod: _noOfSipsController.text,
        sipname: _sipNameController.text.trim(),
        scrips: scrips,
      );

      final result =
          await ref.read(orderProvider).placeSipBasketOrder(sipInput, context);

      if (result != null && result.reqStatus == 'OK') {
        if (mounted) {
          Navigator.of(context).pop();
          ResponsiveSnackBar.showSuccess(context, 'SIP created successfully');
        }
      } else {
        if (mounted) {
          ResponsiveSnackBar.showError(
              context, result?.emsg ?? 'Failed to create SIP');
        }
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, 'Failed to create SIP: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _sipdateformat(DateTime date) {
    return DateFormat('ddMMyyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final wsProvider = ref.watch(websocketProvider);

    final showDropdown = _searchController.text.length >= 2;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: resolveThemeColor(context,
              dark: MyntColors.dividerDark, light: MyntColors.divider),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main dialog content (clipped for rounded corners)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                // Header
                _buildHeader(context, theme),

                // Form fields (fixed, non-scrollable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSipNameAndSipsRow(context, theme),
                      const SizedBox(height: 16),
                      _buildDateAndFrequencyRow(context, theme),
                      const SizedBox(height: 16),
                      _buildSearchSection(context, theme),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // Stocks list (scrollable)
                Expanded(
                  child: _buildScripsList(context, theme, wsProvider),
                ),

                // Footer
                _buildFooter(context, theme),
              ],
            ),
          ),

          // Search Results Dropdown Overlay (outside ClipRRect, follows search field)
          if (showDropdown)
            CompositedTransformFollower(
              link: _searchLayerLink,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 4),
              child: Builder(
                builder: (context) {
                  final width = (_searchFieldKey.currentContext
                          ?.findRenderObject() as RenderBox?)
                      ?.size
                      .width;
                  return SizedBox(
                    width: width,
                    child: _buildSearchDropdown(context),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemesProvider theme) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Create SIP',
            style: MyntWebTextStyles.title(
              context,
              fontWeight: MyntFonts.semiBold,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              size: 20,
              color: resolveThemeColor(context,
                  dark: MyntColors.iconSecondaryDark,
                  light: MyntColors.iconSecondary),
            ),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSipNameAndSipsRow(BuildContext context, ThemesProvider theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SIP Name — takes remaining width
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SIP Name',
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary)),
              ),
              const SizedBox(height: 10),
              MyntFormTextField(
                controller: _sipNameController,
                placeholder: 'Enter SIP name',
                height: 40,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Number of SIPs — equal width
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Number of SIPs',
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary)),
              ),
              const SizedBox(height: 10),
              MyntFormTextField(
                controller: _noOfSipsController,
                placeholder: 'e.g. 12',
                height: 40,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateAndFrequencyRow(BuildContext context, ThemesProvider theme) {
    return Row(
      children: [
        // Start Date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start Date',
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary)),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _selectStartDate,
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: resolveThemeColor(context,
                        dark: MyntColors.inputBgDark,
                        light: const Color(0xfff5f5f5)),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isDarkMode(context)
                          ? MyntColors.primaryDark
                          : MyntColors.primary,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _startDate != null
                              ? DateFormat('dd-MM-yyyy').format(_startDate!)
                              : 'Select date',
                          style: MyntWebTextStyles.body(
                            context,
                            fontWeight: MyntFonts.medium,
                            color: _startDate != null
                                ? resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary)
                                : resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                          ),
                        ),
                      ),
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
          ),
        ),
        const SizedBox(width: 16),
        // Frequency
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Frequency',
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary)),
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (btnContext) => GestureDetector(
                  onTap: () => _showFrequencyPopup(btnContext),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.transparent,
                        light: const Color(0xffF1F3F8),
                      ),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.primary,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _getFrequencyLabel(_selectedFrequency),
                            style: MyntWebTextStyles.body(
                              context,
                              darkColor: MyntColors.textPrimaryDark,
                              lightColor: MyntColors.textPrimary,
                              fontWeight: MyntFonts.medium,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary,
                          ),
                          size: 20,
                        ),
                      ],
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

  Widget _buildSearchSection(BuildContext context, ThemesProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Add Stocks ',
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.medium,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary)),
            ),
            if (_addedScrips.isNotEmpty)
              Text(
                '(${_addedScrips.length} stock${_addedScrips.length != 1 ? 's' : ''} added)',
                style: MyntWebTextStyles.para(
                  context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                ),
              ),

            
            
          ],
        ),

        const SizedBox(height: 10),
        // Search Input Field (transform target for dropdown positioning)
        CompositedTransformTarget(
          link: _searchLayerLink,
          child: MyntSearchTextField.withSmartClear(
            key: _searchFieldKey,
            controller: _searchController,
            placeholder: 'Search equity stocks...',
            height: 36,
            leadingIcon: assets.searchIcon,
            leadingIconHoverEffect: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: _onSearchChanged,
            onClear: () {
              _searchController.clear();
              ref.read(marketWatchProvider).searchClear();
              setState(() {
                _searchResults = [];
                _isSearching = false;
              });
            },
          ),
        ),
      ],
    );
  }

  /// Search results dropdown overlay — rendered at top-level Stack
  Widget _buildSearchDropdown(BuildContext context) {
    return Material(
      elevation: 8,
      color: resolveThemeColor(context,
          dark: MyntColors.overlayBgDark, light: MyntColors.overlayBg),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200),
        decoration: BoxDecoration(
          border: Border.all(
            color: resolveThemeColor(context,
                dark: MyntColors.borderMutedDark,
                light: MyntColors.borderMuted),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: _isSearching
              // Loading state
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: resolveThemeColor(context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary),
                      ),
                    ),
                  ),
                )
              : _searchResults.isEmpty
                  // No results state
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              assets.documentIcon,
                              width: 50,
                              height: 50,
                              colorFilter: ColorFilter.mode(
                                resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No Results Found',
                              style: MyntWebTextStyles.body(
                                context,
                                fontWeight: MyntFonts.semiBold,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No stocks match "${_searchController.text}"',
                              style: MyntWebTextStyles.caption(
                                context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  // Results list
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 0,
                        color: shadcn.Theme.of(context).colorScheme.border,
                      ),
                      itemBuilder: (context, index) {
                        final scrip = _searchResults[index];
                        final symbolName = scrip.symbol?.isNotEmpty == true
                            ? scrip.symbol!
                            : (scrip.tsym?.replaceAll('-EQ', '') ?? '');
                        return InkWell(
                          onTap: () => _addScrip(scrip),
                          hoverColor: resolveThemeColor(
                            context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary,
                          ).withValues(alpha: 0.08),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            symbolName
                                                .replaceAll("-EQ", "")
                                                .toUpperCase(),
                                            style: MyntWebTextStyles.body(
                                              context,
                                              fontWeight: MyntFonts.medium,
                                              darkColor:
                                                  MyntColors.textPrimaryDark,
                                              lightColor:
                                                  MyntColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: resolveThemeColor(context,
                                                      dark:
                                                          const Color.fromARGB(
                                                              255, 49, 61, 75),
                                                      light: MyntColors.primary)
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              scrip.exch ?? '',
                                              style: MyntWebTextStyles.caption(
                                                context,
                                                color: resolveThemeColor(
                                                    context,
                                                    dark:
                                                        MyntColors.primaryDark,
                                                    light: MyntColors.primary),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (scrip.cname?.isNotEmpty == true)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                            scrip.cname!,
                                            style: MyntWebTextStyles.para(
                                              context,
                                              fontWeight: MyntFonts.medium,
                                              color: resolveThemeColor(context,
                                                  dark: MyntColors
                                                      .textSecondaryDark,
                                                  light:
                                                      MyntColors.textSecondary),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                    ),
        ),
      ),
    );
  }

  Widget _buildScripsList(BuildContext context, ThemesProvider theme,
      WebSocketProvider wsProvider) {
    if (_addedScrips.isEmpty) {
      return const NoDataFoundWeb(
        title: 'No stocks added',
        subtitle: 'Search and add stocks to your SIP',
        secondaryEnabled: false,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _addedScrips.length,
      separatorBuilder: (context, index) => Divider(
        height: 0,
        color: shadcn.Theme.of(context).colorScheme.border,
      ),
      itemBuilder: (context, index) {
        final item = _addedScrips[index];
        return _buildScripCard(context, theme, wsProvider, item, index);
      },
    );
  }

  Widget _buildScripCard(BuildContext context, ThemesProvider theme,
      WebSocketProvider wsProvider, SipScripItem item, int index) {
    // Get symbol name - use symbol field or parse from tsym, strip any suffix after hyphen
    final rawSymbol = item.scrip.symbol?.isNotEmpty == true
        ? item.scrip.symbol!
        : (item.scrip.tsym ?? '');
    final symbolName =
        rawSymbol.contains('-') ? rawSymbol.split('-').first : rawSymbol;
    final isQtyMode = item.investBy == 'Qty';
    final liveLtp = wsProvider.getBestLTP(item.scrip.token ?? '', '0');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Row(
        children: [
          // Stock name + exchange badge + LTP (takes available space)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        symbolName,
                        style: MyntWebTextStyles.body(
                          context,
                          fontWeight: MyntFonts.medium,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: resolveThemeColor(context,
                                dark: const Color.fromARGB(255, 49, 61, 75),
                                light: MyntColors.primary)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        item.scrip.exch ?? '',
                        style: MyntWebTextStyles.caption(
                          context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.primaryDark,
                              light: MyntColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),
                if (liveLtp != '0' && liveLtp != '0.00') ...[
                  const SizedBox(height: 8),
                  Text(
                    'LTP $liveLtp',
                    style: MyntWebTextStyles.para(
                      context,
                      fontWeight: MyntFonts.medium,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right side controls - fixed width for consistent alignment
          SizedBox(
            width: 200,
            child: Row(
              children: [
                // Switch icon (compact)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        item.investBy = isQtyMode ? 'Amount' : 'Qty';
                      });
                    },
                    borderRadius: BorderRadius.circular(50),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: SvgPicture.asset(
                        assets.switchIcon,
                        width: 16,
                        height: 16,
                        colorFilter: ColorFilter.mode(
                          resolveThemeColor(context,
                              dark: MyntColors.primaryDark,
                              light: MyntColors.primary),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Qty/Amt label (compact, 3-letter)
                SizedBox(
                  width: 28,
                  child: Text(
                    isQtyMode ? 'QTY' : 'AMT',
                    style: MyntWebTextStyles.para(
                      context,
                      fontWeight: MyntFonts.medium,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Input field (takes remaining space)
                Expanded(
                  child: MyntFormTextField(
                    controller:
                        isQtyMode ? item.qtyController : item.amountController,
                    placeholder: isQtyMode ? '1' : '0.00',
                    height: 34,
                    keyboardType: TextInputType.number,
                    inputFormatters: isQtyMode
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                          ],
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 6),
                // Delete button (compact)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _removeScrip(index),
                    borderRadius: BorderRadius.circular(50),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: resolveThemeColor(context,
                            dark: MyntColors.errorDark,
                            light: MyntColors.error),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemesProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: resolveThemeColor(context,
                    dark: MyntColors.textTertiaryDark,
                    light: MyntColors.textTertiary),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 300,
                child: Text(
                  'SIP will be placed at 9:30 AM on due date. If market holiday, order placed on next trading day.',
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
         
          // Create SIP Button
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: _isLoading || _addedScrips.isEmpty ? null : _createSip,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.isDarkMode
                    ? MyntColors.secondary
                    : MyntColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                elevation: 0,
                disabledBackgroundColor: resolveThemeColor(context,
                    dark: MyntColors.borderMutedDark,
                    light: MyntColors.borderMuted),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Create SIP',
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        fontWeight: MyntFonts.semiBold,
                        color: MyntColors.backgroundColor,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class to hold scrip item data
class SipScripItem {
  final ScripNewValue scrip;
  String investBy;
  final TextEditingController qtyController;
  final TextEditingController amountController;

  SipScripItem({
    required this.scrip,
    required this.investBy,
    required this.qtyController,
    required this.amountController,
  });
}

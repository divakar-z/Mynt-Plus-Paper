import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:mynt_plus/provider/ledger_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/common_search_fields_web.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';

import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import 'pledge_history_screen.dart';
import 'unpledge_history_screen.dart';

class PledgeHistoryMainScreen extends StatefulWidget {
  const PledgeHistoryMainScreen({super.key});

  @override
  _PledgeMainScreen createState() => _PledgeMainScreen();
}

class _PledgeMainScreen extends State<PledgeHistoryMainScreen> {
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final _tabItems = [
    {'title': 'Pledge', 'index': 0},
    {'title': 'Unpledge', 'index': 1},
  ];

  @override
  void initState() {
    super.initState();
    // TC_344 — the search field's X button empties the controller without
    // firing onChanged/onClear, so the filter kept the old query. Reset it
    // whenever the field becomes empty (same approach as Positions).
    _searchController.addListener(() {
      if (!mounted) return;
      if (_searchController.text.isEmpty && _searchQuery.isNotEmpty) {
        _onSearchChanged('');
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, WidgetRef ref, _) {
      final theme = ref.watch(themeProvider);
      final ledgerprovider = ref.watch(ledgerProvider);

      return Scaffold(
        backgroundColor: resolveThemeColor(context, dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor),
        body: SafeArea(
          child: MyntLoaderOverlay(
            isLoading: ledgerprovider.pledgehistory,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with back button
                Container(
                  color: resolveThemeColor(context, dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      const CustomBackBtn(),
                      const SizedBox(width: 8),
                      Text(
                        'Pledge History',
                        style: MyntWebTextStyles.title(context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary,
                            fontWeight: MyntFonts.semiBold),
                      ),
                    ],
                  ),
                ),
                // Tabs + Search Row
                _buildTabsAndSearchRow(theme),
                // Divider
                Divider(
                  height: 1,
                  thickness: 0.4,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.dividerDark,
                    light: MyntColors.divider,
                  ),
                ),
                // Content
                Expanded(
                  child: IndexedStack(
                    index: _selectedTabIndex,
                    children: [
                      PledgeHistoryScreen(searchQuery: _searchQuery),
                      UnpledgeHistoryScreen(searchQuery: _searchQuery),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildTabsAndSearchRow(ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Tabs on the left
          ..._tabItems.map((tab) => _buildTabItem(
                tab['title'] as String,
                tab['index'] as int,
                theme,
              )),
          const Spacer(),
          // Search field
          SizedBox(
            width: 260,
            child: MyntSearchTextField.withSmartClear(
              controller: _searchController,
              placeholder: 'Search',
              leadingIcon: assets.searchIcon,
              onChanged: (value) {
                _onSearchChanged(value);
              },
              onClear: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index, ThemesProvider theme) {
    final isActive = _selectedTabIndex == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
            _searchController.clear();
            _searchQuery = '';
          });
        },
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? (theme.isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title,
            style: MyntWebTextStyles.body(
              context,
              fontWeight: isActive ? MyntFonts.semiBold : MyntFonts.medium,
            ).copyWith(
              color: isActive
                  ? shadcn.Theme.of(context).colorScheme.foreground
                  : shadcn.Theme.of(context).colorScheme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

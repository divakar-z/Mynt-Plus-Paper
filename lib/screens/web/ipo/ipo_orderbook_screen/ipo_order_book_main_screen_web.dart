import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import '../../../../provider/iop_provider.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../res/mynt_web_text_styles.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'ipo_order_book_tab/open_orders_table_web.dart';
import 'ipo_order_book_tab/close_orders_table_web.dart';

class IpoOrderbookMainScreen extends ConsumerStatefulWidget {
  const IpoOrderbookMainScreen({super.key});

  @override
  ConsumerState<IpoOrderbookMainScreen> createState() =>
      _IpoOrderbookMainScreenState();
}

class _IpoOrderbookMainScreenState extends ConsumerState<IpoOrderbookMainScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  VoidCallback?
      _tabControllerListener; // Store listener reference for proper cleanup
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    // Store listener reference for proper cleanup
    _tabControllerListener = () {
      if (_tabController.indexIsChanging ||
          _tabController.index != _selectedTabIndex) {
        // Switching Open / Close orders clears the My Bids search
        // (as switching tabs does in Holdings).
        if (_tabController.index != _selectedTabIndex &&
            ref.read(ipoProvide).ipocommonsearchcontroller.text.isNotEmpty) {
          ref.read(ipoProvide).setIpoSearchQuery("");
        }
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    };
    _tabController.addListener(_tabControllerListener!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ipoProvide).getipoorderbookmodel(context, true);
    });
  }

  @override
  void dispose() {
    // Remove listener before disposing to prevent memory leaks
    if (_tabControllerListener != null) {
      _tabController.removeListener(_tabControllerListener!);
      _tabControllerListener = null;
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ipo = ref.watch(ipoProvide);
    final theme = ref.watch(themeProvider);

    // Get filtered orders based on search
    final filteredOpenOrders = _getFilteredOpenOrders(ipo);
    final filteredCloseOrders = _getFilteredCloseOrders(ipo);

    final hasOpenOrders = filteredOpenOrders.isNotEmpty;
    final hasCloseOrders = filteredCloseOrders.isNotEmpty;
    final hasAnyOrders = hasOpenOrders || hasCloseOrders;

    // Show loader while data is being fetched
    if (ipo.myBidsload) {
      return const Center(
        child: MyntLoader(size: MyntLoaderSize.large),
      );
    }

    if (!hasAnyOrders && ipo.ipocommonsearchcontroller.text.isNotEmpty) {
      return const Center(
        child: NoDataFoundWeb(),
      );
    }

    if (!hasAnyOrders) {
      return const Center(
        child: NoDataFoundWeb(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs
        _buildTabs(
            theme, filteredOpenOrders.length, filteredCloseOrders.length),
        const SizedBox(height: 16),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              OpenOrdersTable(filteredOrders: filteredOpenOrders),
              CloseOrdersTable(filteredOrders: filteredCloseOrders),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(ThemesProvider theme, int openCount, int closeCount) {
    final tabs = [
      {'title': 'Open orders', 'count': openCount},
      {'title': 'Close orders', 'count': closeCount}
    ];

    return SizedBox(
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int index = 0; index < tabs.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildTab(
                tabs[index]['title'] as String,
                index,
                theme,
                tabs[index]['count'] as int,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index, ThemesProvider theme, int count) {
    final isSelected = _selectedTabIndex == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (_tabController.index != index) {
            _tabController.animateTo(index);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (theme.isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight:
                      isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                ).copyWith(
                  color: isSelected
                      ? shadcn.Theme.of(context).colorScheme.foreground
                      : shadcn.Theme.of(context).colorScheme.mutedForeground,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Text(
                    '$count',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      fontWeight:
                          isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                    ).copyWith(
                      fontSize: 13,
                      color: isSelected
                          ? shadcn.Theme.of(context).colorScheme.foreground
                          : shadcn.Theme.of(context)
                              .colorScheme
                              .mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> _getFilteredOpenOrders(IPOProvider ipo) {
    final openOrders = ipo.openorder ?? [];

    // If there's a search query, filter the open orders
    if (ipo.ipocommonsearchcontroller.text.isNotEmpty) {
      final searchQuery = ipo.ipocommonsearchcontroller.text.toLowerCase();
      return openOrders.where((order) {
        final companyName = order.companyName?.toLowerCase() ?? '';
        final symbol = order.symbol?.toLowerCase() ?? '';
        return companyName.contains(searchQuery) ||
            symbol.contains(searchQuery);
      }).toList();
    }

    // Otherwise, return all open orders
    return openOrders;
  }

  List<dynamic> _getFilteredCloseOrders(IPOProvider ipo) {
    final closeOrders = ipo.closeorder ?? [];

    // If there's a search query, filter the close orders
    if (ipo.ipocommonsearchcontroller.text.isNotEmpty) {
      final searchQuery = ipo.ipocommonsearchcontroller.text.toLowerCase();
      return closeOrders.where((order) {
        final companyName = order.companyName?.toLowerCase() ?? '';
        final symbol = order.symbol?.toLowerCase() ?? '';
        return companyName.contains(searchQuery) ||
            symbol.contains(searchQuery);
      }).toList();
    }

    // Otherwise, return all close orders
    return closeOrders;
  }
}

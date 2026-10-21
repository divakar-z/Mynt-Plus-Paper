// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:url_launcher/url_launcher.dart';

import '../../../../provider/iop_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../sharedWidget/snack_bar.dart';

class UpcomingIpo extends ConsumerStatefulWidget {
  const UpcomingIpo({super.key});

  @override
  ConsumerState<UpcomingIpo> createState() => _UpcomingIpoState();
}

class _UpcomingIpoState extends ConsumerState<UpcomingIpo> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String? _hoveredRowId;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ipos = ref.watch(ipoProvide);
    final theme = ref.watch(themeProvider);

    // Show loader while data is being fetched
    if (ipos.loading) {
      return const Center(
        child: MyntLoader(size: MyntLoaderSize.large),
      );
    }

    // Get filtered upcoming IPOs based on search
    List<dynamic> filteredUpcomingIPOs = _getFilteredUpcomingIPOs(ipos);

    // Apply sorting
    final sortedUpcomingIPOs = _getSortedUpcomingIPOs(filteredUpcomingIPOs);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Allocation: All columns 25%
        // final nameWidth = width * 0.25;
        // final sizeWidth = width * 0.25;
        // final updatedWidth = width * 0.25;
        // final excWidth = width * 0.25;
        // DRHP link column added: 30 / 18 / 18 / 22 / 12
        final nameWidth = width * 0.30;
        final sizeWidth = width * 0.18;
        final updatedWidth = width * 0.18;
        final excWidth = width * 0.22;
        final drhpWidth = width * 0.12;

        final columnWidths = {
          0: shadcn.FixedTableSize(nameWidth),
          1: shadcn.FixedTableSize(sizeWidth),
          2: shadcn.FixedTableSize(updatedWidth),
          3: shadcn.FixedTableSize(excWidth),
          4: shadcn.FixedTableSize(drhpWidth),
        };

        return shadcn.OutlinedContainer(
          child: Column(
            children: [
              SizedBox(
                height: 50,
                child: shadcn.Table(
                  columnWidths: columnWidths,
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  rows: [
                    shadcn.TableHeader(
                      cells: [
                        _buildHeaderCell("Stock name", 0, theme),
                        _buildHeaderCell("Issue Size", 1, theme),
                        _buildHeaderCell("Last Updated", 2, theme),
                        _buildHeaderCell("Stock Exchanges", 3, theme),
                        // _buildHeaderCell("DRHP", -1, theme),
                        // Link column: no header label (the link itself reads DRHP).
                        _buildHeaderCell("", -1, theme),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredUpcomingIPOs.isEmpty
                    ? const Center(child: NoDataFoundWeb())
                    : SingleChildScrollView(
                        child: shadcn.Table(
                          columnWidths: columnWidths,
                          defaultRowHeight: const shadcn.FixedTableSize(50),
                          rows: sortedUpcomingIPOs.asMap().entries.map((entry) {
                            return _buildShadcnRow(entry.value, entry.key, theme);
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<dynamic> _getFilteredUpcomingIPOs(IPOProvider ipos) {
    final upcomingIPOs = ipos.upcomingModel?.upcoming ?? [];

    // If there's a search query, filter the upcoming IPOs
    if (ipos.ipocommonsearchcontroller.text.isNotEmpty) {
      final searchQuery = ipos.ipocommonsearchcontroller.text.toLowerCase();
      return upcomingIPOs.where((ipo) {
        final companyName = ipo.companyName?.toLowerCase() ?? '';
        final ipoType = ipo.ipoType?.toLowerCase() ?? '';
        return companyName.contains(searchQuery) ||
            ipoType.contains(searchQuery);
      }).toList();
    }

    // Otherwise, return all upcoming IPOs
    return upcomingIPOs;
  }

  List<dynamic> _getSortedUpcomingIPOs(List<dynamic> upcomingIPOs) {
    if (_sortColumnIndex == null) {
      return upcomingIPOs;
    }

    final sorted = List<dynamic>.from(upcomingIPOs);
    sorted.sort((a, b) {
      int comparison = 0;
      switch (_sortColumnIndex) {
        // Name is case-insensitive; Issue Size ("5000.0") and Last Updated
        // ("15-May-2025") were compared as text, so "999" sorted above
        // "1000" and dates sorted by day number.
        case 0: // Company Name
          // final nameA = a.companyName ?? '';
          // final nameB = b.companyName ?? '';
          final nameA = (a.companyName ?? '').toString().trim().toLowerCase();
          final nameB = (b.companyName ?? '').toString().trim().toLowerCase();
          comparison = nameA.compareTo(nameB);
          break;
        case 1: // Issue Size
          // final sizeA = a.issueSize ?? '';
          // final sizeB = b.issueSize ?? '';
          final sizeA = double.tryParse(a.issueSize ?? '') ?? 0.0;
          final sizeB = double.tryParse(b.issueSize ?? '') ?? 0.0;
          comparison = sizeA.compareTo(sizeB);
          break;
        case 2: // Last Updated
          // final updatedA = a.lastUpdated ?? '';
          // final updatedB = b.lastUpdated ?? '';
          final updatedA = _parseUpdatedDate(a.lastUpdated);
          final updatedB = _parseUpdatedDate(b.lastUpdated);
          // Rows with no readable date stay last in both directions.
          if ((updatedA == null) != (updatedB == null)) {
            return updatedA == null ? 1 : -1;
          }
          comparison = (updatedA == null || updatedB == null)
              ? 0
              : updatedA.compareTo(updatedB);
          break;
        case 3: // Stock Exchanges
          final exchangeA = a.stockExchanges ?? '';
          final exchangeB = b.stockExchanges ?? '';
          comparison = exchangeA.compareTo(exchangeB);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
    return sorted;
  }

  // Last Updated comes as "15-May-2025".
  DateTime? _parseUpdatedDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      return DateFormat('dd-MMM-yyyy').parse(s.trim());
    } catch (_) {
      return null;
    }
  }

  void _onSortTable(int columnIndex, bool ascending) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = ascending;
      }
    });
  }

  // Header text style
  // 14px, weight 600, MyntColors for text
  TextStyle _getHeaderStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableHeader(
      context,
      color: color,
      darkColor: color ?? MyntColors.textSecondaryDark,
      lightColor: color ?? MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  Widget _buildSortArrow() {
    return Icon(
      _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
      size: 16,
      color: resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary),
    );
  }

  shadcn.TableCell _buildHeaderCell(
      String text, int sortIndex, ThemesProvider theme,
      {bool alignRight = false, bool centered = false}) {
    Alignment alignment;
    if (centered) {
      alignment = Alignment.center;
    } else {
      alignment = alignRight ? Alignment.centerRight : Alignment.centerLeft;
    }

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
      child: GestureDetector(
        // Whole header cell is tappable, not just the label text.
        behavior: HitTestBehavior.opaque,
        // onTap: sortIndex >= 0
        //     ? () => _onSortTable(sortIndex, !_sortAscending)
        //     : null,
        // A new column always starts ascending; same column again reverses.
        onTap: sortIndex >= 0 ? () => _onSortTable(sortIndex, true) : null,
        child: Container(
          alignment: alignment,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          // decoration: BoxDecoration(
          //   color: theme.isDarkMode
          //       ? Colors.white.withOpacity(0.04)
          //       : Colors.black.withOpacity(0.03),
          // ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sort arrow on the sorted column, as in the Bonds table:
              // before the label when right-aligned, after it otherwise.
              if (alignRight && sortIndex >= 0 && _sortColumnIndex == sortIndex) ...[
                _buildSortArrow(),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: _getHeaderStyle(context),
              ),
              if (!alignRight && sortIndex >= 0 && _sortColumnIndex == sortIndex) ...[
                const SizedBox(width: 4),
                _buildSortArrow(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  shadcn.TableRow _buildShadcnRow(
      dynamic ipo, int index, ThemesProvider theme) {
    final uniqueId = '${ipo.companyName ?? ""}$index';
    final rowIsHovered = _hoveredRowId == uniqueId;
    // Row click opens the DRHP in a new tab (as on mobile); lost in the
    // Jan 2026 table redesign. No link = no action.
    // Only a full http(s) link counts. The API currently sends the same
    // relative path ("/report/...") for every IPO, which is not a real DRHP
    // link, so those rows show "-" until the backend sends full URLs.
    // final String drhpUrl = (ipo.drhp ?? '').toString().trim();
    final String rawDrhp = (ipo.drhp ?? '').toString().trim();
    // final String drhpUrl =
    //     rawDrhp.startsWith('http://') || rawDrhp.startsWith('https://')
    //         ? rawDrhp
    //         : '';
    // User wants the DRHP link on every row: a relative "/report/..." path
    // is Chittorgarh's DRHP/RHP list page, so open it on that site.
    final String drhpUrl = rawDrhp.isEmpty
        ? ''
        : rawDrhp.startsWith('http://') || rawDrhp.startsWith('https://')
            ? rawDrhp
            : rawDrhp.startsWith('/')
                ? 'https://www.chittorgarh.com$rawDrhp'
                : 'https://$rawDrhp';
    final VoidCallback? onTap =
        drhpUrl.isNotEmpty ? () => _onDRHPTap(drhpUrl) : null;

    final cellTextStyle = MyntWebTextStyles.tableCell(
      context,
      fontWeight: MyntFonts.medium,
      color: resolveThemeColor(context,
          dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
    );

    return shadcn.TableRow(
      cells: [
        // Name
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          onTap: onTap,
          child: Text(
            ipo.companyName ?? '',
            style: cellTextStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Issue Size
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          onTap: onTap,
          child: Text(
            ipo.issueSize ?? '',
            style: cellTextStyle,
          ),
        ),
        // Last Updated
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          onTap: onTap,
          child: Text(
            ipo.lastUpdated ?? '',
            style: cellTextStyle,
          ),
        ),
        // Stock Exchanges
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          onTap: onTap,
          child: Text(
            ipo.stockExchanges ?? '',
            style: cellTextStyle,
          ),
        ),
        // DRHP link (blue); '-' when the API sends no link
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          onTap: onTap,
          child: drhpUrl.isNotEmpty
              ? Text(
                  'DRHP',
                  style: MyntWebTextStyles.tableCell(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    color: resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary),
                  ),
                )
              : Text(
                  '-',
                  style: MyntWebTextStyles.tableCell(
                    context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _onDRHPTap(String url) async {
    // Callers pass full http(s) links only (see _buildShadcnRow).
    final String finalUrl = url;
    // if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
    //   finalUrl = 'https://$finalUrl';
    // }
    try {
      final opened =
          await launchUrl(Uri.parse(finalUrl), webOnlyWindowName: '_blank');
      if (!opened && mounted) {
        warningMessage(context, 'Could not open DRHP');
      }
    } catch (e) {
      debugPrint("Error launching DRHP URL: $e");
      if (mounted) warningMessage(context, 'Could not open DRHP');
    }
  }

  shadcn.TableCell _buildShadcnCell({
    required Widget child,
    required String uniqueId,
    required bool rowIsHovered,
    required ThemesProvider theme,
    VoidCallback? onTap,
    bool alignRight = false,
    bool centered = false,
  }) {
    Alignment alignment;
    if (centered) {
      alignment = Alignment.center;
    } else {
      alignment = alignRight ? Alignment.centerRight : Alignment.centerLeft;
    }

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
        // cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredRowId = uniqueId),
        onExit: (_) => setState(() => _hoveredRowId = null),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            color: rowIsHovered
                ? resolveThemeColor(context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary,
                  ).withValues(alpha: 0.08)
                : Colors.transparent,
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            width: double.infinity,
            height: double.infinity,
            child: Align(
              alignment: alignment,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

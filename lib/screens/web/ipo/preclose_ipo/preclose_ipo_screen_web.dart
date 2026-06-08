// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/models/ipo_model/ipo_pre_close_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../../provider/iop_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../Mobile/ipo/main_sme_list/single_page.dart';

class ClosedIPOScreen extends ConsumerStatefulWidget {
  const ClosedIPOScreen({super.key});

  @override
  ConsumerState<ClosedIPOScreen> createState() => _ClosedIPOScreenState();
}

class _ClosedIPOScreenState extends ConsumerState<ClosedIPOScreen> {
  late List<Msg> ipoList;
  String? _hoveredRowId;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    ipoList = ref.read(ipoProvide).ipoPreClose!.msg;
    ref.read(ipoProvide).sortpreCloseIPOListByDate(ipoList);
  }

  @override
  Widget build(BuildContext context) {
    final preClose = ref.watch(ipoProvide);
    final theme = ref.watch(themeProvider);

    if (preClose.ipoPreClose == null || preClose.ipoPreClose!.msg.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildClosedTable(theme, preClose);
  }

  Widget _buildClosedTable(ThemesProvider theme, IPOProvider preClose) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final nameWidth = width * 0.35;
        final dateWidth = width * 0.25;
        final priceWidth = width * 0.15;
        final minWidth = width * 0.25;

        final columnWidths = {
          0: shadcn.FixedTableSize(nameWidth),
          1: shadcn.FixedTableSize(dateWidth),
          2: shadcn.FixedTableSize(priceWidth),
          3: shadcn.FixedTableSize(minWidth),
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
                        _buildHeaderCell("Stock name",
                            padding: const EdgeInsets.only(
                                left: 15.0,
                                right: 12.0,
                                top: 12.0,
                                bottom: 12.0)),
                        _buildHeaderCell("IPO date"),
                        _buildHeaderCell("Price range", alignRight: true),
                        _buildHeaderCell("Min. amount",
                            alignRight: true,
                            padding: const EdgeInsets.only(
                                left: 12.0,
                                right: 24.0,
                                top: 12.0,
                                bottom: 12.0)),
                      ],
                    ),
                  ],
                ),
              ),
              shadcn.Table(
                columnWidths: columnWidths,
                defaultRowHeight: const shadcn.FixedTableSize(60),
                rows: ipoList.asMap().entries.map((entry) {
                  return _buildRow(entry.value, entry.key, theme, preClose);
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  shadcn.TableCell _buildHeaderCell(String text,
      {bool alignRight = false, EdgeInsets? padding}) {
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
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12.0),
        child: Text(
          text,
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

  shadcn.TableRow _buildRow(
      Msg ipo, int index, ThemesProvider theme, IPOProvider preClose) {
    final uniqueId = 'closed_${ipo.id ?? ""}_$index';
    final rowIsHovered = _hoveredRowId == uniqueId;

    return shadcn.TableRow(
      cells: [
        _buildNameCell(ipo, uniqueId, rowIsHovered, theme, preClose, index),
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          onTap: () => _onIPOTap(context, ipo, preClose, index),
          child: Text(
            _formatIPODate(ipo),
            style: MyntWebTextStyles.bodyMedium(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        ),
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          alignRight: true,
          onTap: () => _onIPOTap(context, ipo, preClose, index),
          child: Text(
            _formatPriceRange(ipo),
            style: MyntWebTextStyles.bodyMedium(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          alignRight: true,
          padding: const EdgeInsets.only(
              left: 8.0, right: 24.0, top: 8.0, bottom: 8.0),
          onTap: () => _onIPOTap(context, ipo, preClose, index),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatMinAmount(ipo),
                style: MyntWebTextStyles.bodyMedium(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                  fontWeight: MyntFonts.medium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (ipo.minBidQu != null && ipo.minBidQu! > 0) ...[
                const SizedBox(height: 1),
                Text(
                  "${ipo.minBidQu} Qty",
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary),
                    fontWeight: MyntFonts.medium,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  shadcn.TableCell _buildNameCell(Msg ipo, String uniqueId, bool rowIsHovered,
      ThemesProvider theme, IPOProvider preClose, int index) {
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
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredRowId = uniqueId),
        onExit: (_) => setState(() => _hoveredRowId = null),
        child: GestureDetector(
          onTap: () => _onIPOTap(context, ipo, preClose, index),
          child: Container(
            color: rowIsHovered
                ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary)
                    .withOpacity(theme.isDarkMode ? 0.06 : 0.10)
                : Colors.transparent,
            padding: const EdgeInsets.only(
                left: 15.0, right: 8.0, top: 8.0, bottom: 8.0),
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _toTitleCase(ipo.companyName ?? ipo.name ?? ""),
                  style: MyntWebTextStyles.bodyMedium(
                    context,
                    fontWeight: MyntFonts.medium,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      ipo.ipoType ?? "IPO",
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Closed",
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                    if (ipo.totalsub != null &&
                        ipo.totalsub!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        "${ipo.totalsub}x sub",
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary),
                          fontWeight: MyntFonts.medium,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  shadcn.TableCell _buildShadcnCell({
    required Widget child,
    required String uniqueId,
    required bool rowIsHovered,
    required ThemesProvider theme,
    VoidCallback? onTap,
    bool alignRight = false,
    EdgeInsets? padding,
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
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredRowId = uniqueId),
        onExit: (_) => setState(() => _hoveredRowId = null),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            color: rowIsHovered
                ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary)
                    .withOpacity(theme.isDarkMode ? 0.06 : 0.10)
                : Colors.transparent,
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            width: double.infinity,
            height: double.infinity,
            child: Align(
              alignment:
                  alignRight ? Alignment.centerRight : Alignment.centerLeft,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  String _toTitleCase(String input) {
    return input
        .toLowerCase()
        .split(' ')
        .map((word) =>
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  String _formatIPODate(Msg ipo) {
    try {
      final startStr = ipo.iPOStartDate;
      final endStr = ipo.iPOEndDate;

      if (startStr == null ||
          startStr.isEmpty ||
          endStr == null ||
          endStr.isEmpty) {
        return "-";
      }

      DateTime? startDate;
      DateTime? endDate;

      try {
        startDate = DateFormat("MMM dd, yyyy").parse(startStr);
      } catch (_) {
        try {
          startDate = DateFormat("dd-MM-yyyy").parse(startStr);
        } catch (_) {}
      }

      try {
        endDate = DateFormat("EEE, dd MMM yyyy HH:mm:ss").parse(endStr);
      } catch (_) {
        try {
          endDate = DateFormat("MMM dd, yyyy").parse(endStr);
        } catch (_) {}
      }

      if (startDate == null || endDate == null) return "-";

      String startDayStr = _getOrdinalSuffix(startDate.day);
      String endDayStr = _getOrdinalSuffix(endDate.day);
      String startMonthYear = DateFormat('MMM yyyy').format(startDate);
      String endMonthYear = DateFormat('MMM yyyy').format(endDate);

      bool isSameDay = startDate.year == endDate.year &&
          startDate.month == endDate.month &&
          startDate.day == endDate.day;

      if (isSameDay) {
        return "$startDayStr $startMonthYear";
      } else if (startMonthYear == endMonthYear) {
        return "$startDayStr - $endDayStr $endMonthYear";
      } else {
        return "$startDayStr $startMonthYear - $endDayStr $endMonthYear";
      }
    } catch (_) {
      return "-";
    }
  }

  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return "${day}th";
    switch (day % 10) {
      case 1:
        return "${day}st";
      case 2:
        return "${day}nd";
      case 3:
        return "${day}rd";
      default:
        return "${day}th";
    }
  }

  String _formatPriceRange(Msg ipo) {
    final range = ipo.priceRange;
    if (range == null || range.isEmpty) return "-";
    final parts = range.split('-').map((s) => s.trim()).toList();
    if (parts.length == 2) {
      return "₹${parts[0]} - ₹${parts[1]}";
    }
    return "₹$range";
  }

  String _formatMinAmount(Msg ipo) {
    final minPrice = ipo.minPrice;
    final minQty = ipo.minBidQu;
    if (minPrice == null || minQty == null || minPrice <= 0 || minQty <= 0) {
      return "-";
    }
    final amount = minPrice * minQty;
    return "₹${convertCurrencyINRStandard(amount)}";
  }

  Future<void> _onIPOTap(BuildContext context, Msg ipo, IPOProvider preClose,
      int index) async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      await preClose.getIpoSinglePage(ipoName: "${ipo.companyName}");

      if (!context.mounted) return;

      shadcn.openSheet(
        context: context,
        position: shadcn.OverlayPosition.end,
        barrierColor: Colors.transparent,
        builder: (sheetContext) {
          return Container(
            width: 480,
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.backgroundColorDark,
                  light: MyntColors.backgroundColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: MainSmeSinglePage(
              pricerange: "₹${ipo.priceRange ?? ''}",
              mininv: "₹${convertCurrencyINRStandard(
                mininv(
                  (ipo.minPrice ?? 0).toDouble(),
                  (ipo.minBidQu ?? 0).toInt(),
                ).toInt(),
              )}",
              enddate: convertClosedIpoDates(
                ipo.iPOEndDate ?? '',
                "MMM dd, yyyy",
                "EEE, dd MMM yyyy HH:mm:ss",
              ),
              startdate: convertClosedIpoDates(
                ipo.iPOStartDate ?? '',
                "MMM dd, yyyy",
                "dd-MM-yyyy",
              ),
              ipotype: "${ipo.ipoType}",
              ipodetails: "",
            ),
          );
        },
      );
    } finally {
      _isNavigating = false;
    }
  }
}

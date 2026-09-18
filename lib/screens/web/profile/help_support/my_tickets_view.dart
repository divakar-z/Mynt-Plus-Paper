import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../../models/support_ticket_model/support_ticket.dart';
import '../../../../provider/thems.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/res.dart';
import '../../../../res/responsive_extensions.dart';
import '../../../../sharedWidget/common_buttons_web.dart';
import '../../../../sharedWidget/common_search_fields_web.dart';
import '../../../../sharedWidget/no_data_found_web.dart';
import 'support_skeleton.dart';
import 'support_status_badge.dart';

/// The client's own tickets: status filters, search, and the list.
///
/// Built on the same components Positions and Holdings use — the chip tabs from
/// `position_screen_web`, `MyntSearchTextField.withSmartClear`, and
/// `shadcn.Table` — so this reads as part of the app rather than a one-off.
///
/// Fed from `GET /api/client.php/tickets` via [SupportTicketProvider].
class MyTicketsView extends ConsumerStatefulWidget {
  const MyTicketsView({
    super.key,
    required this.borderColor,
    required this.primaryColor,
    this.tickets = const [],
    this.isLoading = false,
    this.errorMessage,
    this.hasMore = false,
    this.total = 0,
    this.onRetry,
    this.onOpenTicket,
    this.onLoadMore,
    this.isLoadingMore = false,
  });

  final Color borderColor;
  final Color primaryColor;
  final List<SupportTicket> tickets;
  final bool isLoading;

  /// Set when the fetch failed. Kept separate from an empty list, because
  /// "we couldn't load these" and "you have none" are different things and
  /// showing the second for the first is a lie.
  final String? errorMessage;

  /// True when the server holds more tickets than this page carries.
  final bool hasMore;
  final int total;

  final VoidCallback? onRetry;

  /// Opens one ticket. The row is passed back so the detail header can show a
  /// subject and status straight away instead of a spinner over an empty panel.
  final void Function(SupportTicket ticket)? onOpenTicket;

  final VoidCallback? onLoadMore;
  final bool isLoadingMore;

  @override
  ConsumerState<MyTicketsView> createState() => _MyTicketsViewState();
}

/// The chips, in the order they are shown. `null` is "All".
///
/// A fixed list rather than one derived from the data, so the row reads the
/// same for every client and keeps a sensible order — a client with no closed
/// tickets still sees a Closed chip, empty, instead of a tab row that changes
/// shape per account. Matches the mobile app's five.
const List<SupportStatusBucket?> _kStatusChips = [
  null,
  SupportStatusBucket.open,
  SupportStatusBucket.inProgress,
  SupportStatusBucket.resolved,
  SupportStatusBucket.closed,
];

class _MyTicketsViewState extends ConsumerState<MyTicketsView> {
  final TextEditingController _search = TextEditingController();
  /// The selected bucket, or null for "All".
  SupportStatusBucket? _filter;
  String _query = '';

  /// Category filter behind the funnel icon. Null means all categories.
  ///
  /// A ValueNotifier rather than plain state because the menu lives in an
  /// overlay: `setState` here does not rebuild it, so the tapped row would not
  /// highlight until the popover was reopened. Same reason Positions uses one.
  final ValueNotifier<String?> _topicFilter = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _topicFilter.addListener(_onCategoryChanged);
    // The query follows the controller rather than `onChanged`.
    //
    // The field's own clear button calls `controller.clear()`, and a
    // programmatic clear does not fire `onChanged` — so the box emptied while
    // the query it had been filtering on stayed behind, and the table went on
    // reporting "nothing matches" against text no longer on screen.
    _search.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_query == _search.text) return;
    setState(() => _query = _search.text);
  }

  void _onCategoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _topicFilter.removeListener(_onCategoryChanged);
    _topicFilter.dispose();
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  /// Applies the active bucket and the search box.
  ///
  /// Filtering client-side is right while the whole list arrives in one call.
  /// If the list is ever paginated this has to move server-side, or a search
  /// will only ever find matches on the page already loaded.
  List<SupportTicket> get _visible {
    final query = _query.trim().toLowerCase();
    return widget.tickets.where((ticket) {
      if (!_matchesFilter(ticket, _filter)) return false;
      if (_topicFilter.value != null && ticket.topic != _topicFilter.value) {
        return false;
      }
      if (query.isEmpty) return true;
      return ticket.number.toLowerCase().contains(query) ||
          ticket.subject.toLowerCase().contains(query);
    }).toList();
  }

  bool _matchesFilter(SupportTicket ticket, SupportStatusBucket? filter) =>
      filter == null ||
      SupportStatusBucketX.fromStatus(ticket.status) == filter;

  /// The count on a chip.
  ///
  /// Counts what is loaded, not the server's total — with paging on, "All"
  /// reads 50 while the desk holds more. Only reachable past 50 tickets, and
  /// the honest fix is a server-side count per bucket rather than arithmetic
  /// here on a partial list.
  int _countFor(SupportStatusBucket? filter) => filter == null
      ? widget.tickets.length
      : widget.tickets.where((t) => _matchesFilter(t, filter)).length;

  /// Every distinct topic present, for the funnel menu — same reasoning.
  // ignore: unused_element
  List<String> get _topicOptions {
    final seen = <String>[];
    for (final ticket in widget.tickets) {
      final topic = ticket.topic;
      if (topic != null && topic.isNotEmpty && !seen.contains(topic)) {
        seen.add(topic);
      }
    }
    return seen;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final rows = _visible;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tabsAndActionBar(theme),
          const SizedBox(height: 12),
          // `shadcn.OutlinedContainer` is what draws the frame on the Orders
          // and Positions tables — not a hand-rolled Border.all.
          //
          // Expanded twice over: once so the table fills the panel rather than
          // hugging its rows, and again inside so the body takes whatever the
          // header leaves. Without the inner one the empty state sits jammed
          // under the header instead of centred in the space.
          Expanded(
            child: shadcn.OutlinedContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _tableHeader(),
                  Expanded(
                    child: widget.isLoading
                        ? _loadingRows()
                        : widget.errorMessage != null
                            ? Center(child: _errorState())
                            : rows.isEmpty
                                ? Center(child: _emptyState())
                                : ListView.builder(
                                itemCount: rows.length,
                                itemExtent: 42,
                                itemBuilder: (context, index) =>
                                    _tableRow(rows[index]),
                              ),
                  ),
                ],
              ),
            ),
          ),
          // Only when it matters. The search and filters above run over the
          // rows in hand, so a client with more tickets than one page needs
          // telling — otherwise a search that finds nothing looks like an
          // answer rather than a partial one.
          if (widget.hasMore) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Showing ${widget.tickets.length} of ${widget.total}.',
                  style: MyntWebTextStyles.caption(
                    context,
                    fontWeight: MyntFonts.regular,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                // Paging matters more than it looks: search and the filters run
                // over the rows in hand, so anything not loaded is invisible to
                // them.
                MyntTextButton(
                  label: widget.isLoadingMore ? 'Loading…' : 'Load more',
                  onPressed: widget.isLoadingMore ? null : widget.onLoadMore,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- Tabs and actions ----------------------------------------------------

  /// Same shape as `position_screen_web._buildTabsAndActionBar`: chip tabs on
  /// the left, search pushed to the right.
  Widget _tabsAndActionBar(ThemesProvider theme) {
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: _kStatusChips
              .map((filter) => _chipTab(theme, filter))
              .toList(),
        ),
        const Spacer(),
        SizedBox(
          width: context.responsiveValue<double>(
            mobile: 140,
            smallTablet: 180,
            tablet: 220,
            desktop: 300,
            largeDesktop: 350,
            widescreen: 400,
          ),
          child: MyntSearchTextField.withSmartClear(
            controller: _search,
            placeholder: context.isMobile ? 'Search' : 'Search tickets',
            leadingIcon: assets.searchIcon,
            // Both, deliberately. `onChanged` covers typing; the controller
            // listener in initState covers the clear button, which calls
            // `controller.clear()` and never fires `onChanged`. The guard in
            // `_onSearchChanged` stops the two double-setting the same value.
            onChanged: (_) => _onSearchChanged(),
            onClear: _search.clear,
          ),
        ),
        // Topic filter retired: every client ticket is raised under General,
        // so the menu only ever offered one topic and filtering by it could
        // not narrow anything. Kept below for when topics are offered again.
        // SizedBox(
        //     width: context.responsive<double>(mobile: 6, tablet: 8, desktop: 12)),
        // _filterButton(),
      ],
    );
  }

  /// Category filter, same funnel button Positions and Holdings use.
  ///
  /// Status is not offered here — the All / Open / Closed chips already own
  /// that, and having two controls set the same thing invites them to disagree.
  // ignore: unused_element
  Widget _filterButton() {
    final buttonSize =
        context.responsive<double>(mobile: 32, tablet: 36, desktop: 40);
    final iconSize =
        context.responsive<double>(mobile: 16, tablet: 18, desktop: 20);

    return Builder(
      builder: (buttonContext) => Tooltip(
        message: 'Filter by category',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _showFilterPopup(buttonContext),
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SvgPicture.asset(
                  assets.searchFilter,
                  width: iconSize,
                  colorFilter: ColorFilter.mode(
                    // Tinted while a category is active, so the button itself
                    // shows a filter is on — otherwise rows go missing with no
                    // visible reason why.
                    _topicFilter.value != null
                        ? resolveThemeColor(context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary)
                        : resolveThemeColor(context,
                            dark: MyntColors.iconDark, light: MyntColors.icon),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showFilterPopup(BuildContext context) {
    shadcn.showPopover(
      context: context,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 8),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          borderRadius: shadcn.Theme.of(context).borderRadiusLg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: shadcn.ModalContainer(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            // Wider than the Positions menu: these labels are full topic
            // names, not four-letter product codes.
            width: 210,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _filterMenuItem(null, 'All topics'),
                // Only topics actually present, so the menu never offers a
                // filter that would empty the table.
                ..._topicOptions.map((t) => _filterMenuItem(t, t)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _filterMenuItem(String? value, String label) {
    return ValueListenableBuilder<String?>(
      valueListenable: _topicFilter,
      builder: (context, current, _) {
        final isSelected = current == value;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _topicFilter.value = value;
              shadcn.closeOverlay(context);
            },
            splashColor: resolveThemeColor(context,
                dark: MyntColors.rippleDark, light: MyntColors.rippleLight),
            highlightColor: resolveThemeColor(context,
                dark: MyntColors.highlightDark,
                light: MyntColors.highlightLight),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isSelected
                    ? resolveThemeColor(
                        context,
                        dark: MyntColors.primaryDark.withOpacity(0.12),
                        light: const Color(0xFFE8F0FE),
                      )
                    : Colors.transparent,
              ),
              child: Text(
                label,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight:
                      isSelected ? MyntFonts.semiBold : MyntFonts.medium,
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
      },
    );
  }

  /// The app's chip tab: filled when active, no border, count superscripted.
  /// Lifted from Positions so the two screens do not drift.
  Widget _chipTab(ThemesProvider theme, SupportStatusBucket? filter) {
    final isSelected = _filter == filter;
    final count = _countFor(filter);
    final colorScheme = shadcn.Theme.of(context).colorScheme;
    final tone =
        isSelected ? colorScheme.foreground : colorScheme.mutedForeground;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (mounted && _filter != filter) setState(() => _filter = filter);
        },
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (theme.isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                filter?.label ?? 'All',
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight:
                      isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                ).copyWith(color: tone),
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
                      fontSize: context.responsive<double>(
                        mobile: 10,
                        tablet: 11,
                        desktop: 12,
                      ),
                      color: tone,
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

  // --- Table ---------------------------------------------------------------

  /// Proportional rather than fixed: this table has no numeric columns needing
  /// a set width, and the panel it sits in is resizable.
  static const Map<int, shadcn.TableSize> _columnWidths = {
    0: shadcn.FlexTableSize(flex: 2), // Ticket
    1: shadcn.FlexTableSize(flex: 5), // Issue summary
    2: shadcn.FlexTableSize(flex: 3), // Category
    3: shadcn.FlexTableSize(flex: 2), // Status
    4: shadcn.FlexTableSize(flex: 2), // Created
    5: shadcn.FlexTableSize(flex: 2), // Last updated
  };

  static const shadcn.TableCellTheme _borderlessCell = shadcn.TableCellTheme(
    border: shadcn.WidgetStatePropertyAll(
      shadcn.Border(
        top: shadcn.BorderSide.none,
        bottom: shadcn.BorderSide.none,
        left: shadcn.BorderSide.none,
        right: shadcn.BorderSide.none,
      ),
    ),
  );

  /// Column padding, shared by the header and the rows so they stay aligned.
  ///
  /// The outer columns carry the 16px page gutter and the inner ones sit tight
  /// at 6px — same rule as `executed_orders_screen`.
  EdgeInsets _cellPadding(int columnIndex) {
    if (columnIndex == 0) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 6);
    }
    if (columnIndex == _columnWidths.length - 1) {
      return const EdgeInsets.fromLTRB(4, 6, 16, 6);
    }
    return const EdgeInsets.symmetric(horizontal: 6, vertical: 6);
  }

  Widget _tableHeader() {
    shadcn.TableCell cell(String label, int index) => shadcn.TableCell(
          theme: _borderlessCell,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: _cellPadding(index),
            alignment: Alignment.centerLeft,
            // The shaded band is what separates the header from the rows on
            // every other table in the app — not a bottom rule.
            decoration: BoxDecoration(
              color: resolveThemeColor(
                context,
                dark: MyntColors.cardDark,
                light: MyntColors.listItemBg,
              ),
            ),
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

    return shadcn.Table(
      columnWidths: _columnWidths,
      defaultRowHeight: const shadcn.FixedTableSize(40),
      rows: [
        shadcn.TableHeader(
          // Sentence case, as everywhere else in the app. The agent console
          // uppercases its headers; nothing on this side does.
          cells: [
            cell('Ticket', 0),
            cell('Issue summary', 1),
            cell('Category', 2),
            cell('Status', 3),
            cell('Created', 4),
            cell('Last updated', 5),
          ],
        ),
      ],
    );
  }

  Widget _tableRow(SupportTicket ticket) {
    final row = _tableRowBody(ticket);
    if (onOpenTicketOf == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onOpenTicketOf!(ticket),
        // Opaque, or a tap that lands on the padding between cells falls
        // through and the row only responds where there happens to be text.
        behavior: HitTestBehavior.opaque,
        child: row,
      ),
    );
  }

  void Function(SupportTicket)? get onOpenTicketOf => widget.onOpenTicket;

  Widget _tableRowBody(SupportTicket ticket) {
    shadcn.TableCell cell(Widget child, int index) => shadcn.TableCell(
          theme: _borderlessCell,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: _cellPadding(index),
            alignment: Alignment.centerLeft,
            child: child,
          ),
        );

    Widget text(String value, {bool secondary = true}) => Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MyntWebTextStyles.tableCell(
            context,
            fontWeight: secondary ? MyntFonts.regular : MyntFonts.medium,
            darkColor: secondary
                ? MyntColors.textSecondaryDark
                : MyntColors.textPrimaryDark,
            lightColor:
                secondary ? MyntColors.textSecondary : MyntColors.textPrimary,
          ),
        );

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: widget.borderColor.withOpacity(0.5)),
        ),
      ),
      child: shadcn.Table(
        columnWidths: _columnWidths,
        defaultRowHeight: const shadcn.FixedTableSize(42),
        rows: [
          shadcn.TableRow(
            cells: [
              cell(
                Text(
                  '#${ticket.number}',
                  style: MyntWebTextStyles.tableCell(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    color: widget.primaryColor,
                  ),
                ),
                0,
              ),
              cell(text(ticket.subject, secondary: false), 1),
              cell(text(ticket.topic ?? '—'), 2),
              cell(_statusPill(ticket), 3),
              cell(text(_formatDate(ticket.created)), 4),
              cell(text(_formatDate(ticket.updated)), 5),
            ],
          ),
        ],
      ),
    );
  }

  /// The status, shown as given.
  ///
  /// Deliberately one neutral tone rather than colour-coded. Colour would mean
  /// deciding which statuses are good and which are bad, and status names are
  /// admin-editable strings the API tells us nothing about — a new one added in
  /// the admin panel would silently take whatever colour the fallback gives it.
  /// Restoring colour needs a state field from the backend, not a longer map.
  /// Placeholder rows, shaped like the real ones.
  ///
  /// A spinner in the middle of an empty table throws away what we already
  /// know — six columns, 42px rows — and then reflows the whole thing when the
  /// data lands. These hold the layout still.
  ///
  /// Eight rows: enough to fill the panel at its usual height without
  /// pretending to know how many tickets are actually coming.
  Widget _loadingRows() {
    return SupportSkeletonGroup(
      child: ListView.builder(
        itemCount: 8,
        itemExtent: 42,
        // Nothing here responds to a tap, and letting it scroll would let
        // someone fling a list of placeholders around.
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) => _skeletonRow(),
      ),
    );
  }

  Widget _skeletonRow() {
    shadcn.TableCell cell(Widget child, int index) => shadcn.TableCell(
          theme: _borderlessCell,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: _cellPadding(index),
            alignment: Alignment.centerLeft,
            child: child,
          ),
        );

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: widget.borderColor.withOpacity(0.5)),
        ),
      ),
      child: shadcn.Table(
        columnWidths: _columnWidths,
        defaultRowHeight: const shadcn.FixedTableSize(42),
        rows: [
          shadcn.TableRow(
            cells: [
              cell(const SupportSkeleton(width: 56, height: 11), 0),
              // Widest block for the widest column, so the shape reads as this
              // table rather than as a generic loading strip.
              cell(const SupportSkeleton(width: double.infinity, height: 11), 1),
              cell(const SupportSkeleton(width: 72, height: 11), 2),
              cell(const SupportSkeleton(width: 58, height: 18, radius: 6), 3),
              cell(const SupportSkeleton(width: 68, height: 11), 4),
              cell(const SupportSkeleton(width: 68, height: 11), 5),
            ],
          ),
        ],
      ),
    );
  }

  /// The status, to the support badge spec.
  ///
  /// Dense: the table row is 42px, and the badge shares it with the row's own
  /// vertical padding.
  Widget _statusPill(SupportTicket ticket) =>
      SupportStatusBadge(ticket.status, dense: true);

  /// `21 Aug 2026`, matching how the rest of the app renders report dates.
  String _formatDate(DateTime? value) =>
      value == null ? '—' : DateFormat('dd MMM yyyy').format(value);

  // --- Empty ---------------------------------------------------------------

  /// Distinguishes "you have no tickets" from "your search matched nothing" —
  /// telling someone who just searched that they have never raised a ticket is
  /// simply wrong, and hides the fact that clearing the box would bring rows
  /// back.
  /// The fetch failed. Deliberately not the empty state: telling someone with
  /// twenty tickets that they have none, because a request timed out, is worse
  /// than saying nothing.
  Widget _errorState() {
    return NoDataFoundWeb(
      title: "Couldn't load your tickets",
      subtitle: widget.errorMessage,
      assetIcon: assets.documentIcon,
      iconSize: 120,
      primaryEnabled: widget.onRetry != null,
      primaryLabel: 'Retry',
      onPrimary: widget.onRetry,
      secondaryEnabled: false,
    );
  }

  Widget _emptyState() {
    final query = _query.trim();
    final searching = query.isNotEmpty;
    // An empty chip is ordinary now that the five are fixed rather than built
    // from the data — a client with nothing closed still gets a Closed tab. So
    // "you have no tickets" has to be reserved for clients who genuinely have
    // none, or it tells someone with a full list that their list is empty.
    final filtered = !searching && _filter != null && widget.tickets.isNotEmpty;

    // Same shape as Positions: name what came up empty in the subtitle, rather
    // than leaving the client to work out whether they have no tickets, picked
    // a tab with nothing under it, or simply mistyped.
    return NoDataFoundWeb(
      title: searching || filtered ? 'No Tickets Found' : 'No Tickets',
      subtitle: searching
          ? 'No tickets match your search "$query".'
          : filtered
              ? 'You have no ${_filter!.label.toLowerCase()} tickets.'
              : "You haven't raised any tickets yet.",
      assetIcon: assets.documentIcon,
      iconSize: 120,
      primaryEnabled: false,
      secondaryEnabled: false,
    );
  }
}

/// Where in the app the client hit the problem.
///
/// This exists because the auto-captured route is not trustworthy. The client
/// raises the ticket from wherever the entry point lives — today the dashboard
/// — which is rarely where the thing broke. Left to the captured route, every
/// ticket would claim to have happened on the dashboard, and the one field
/// that tells an agent where to look would be noise.
///
/// So the client says. The captured route still travels alongside it, for the
/// case where the two disagree and someone wants to know what the app thought.
///
/// [apiValue] is the stable contract. [label] is prose and will be reworded —
/// never send it.
enum SupportTicketArea {
  orders('orders', 'Orders'),
  holdings('holdings', 'Holdings'),
  positions('positions', 'Positions'),
  funds('funds', 'Funds & Payments'),
  watchlist('watchlist', 'Watchlist'),
  charts('charts', 'Charts'),
  mutualFunds('mutual_funds', 'Mutual Funds'),
  ipoBonds('ipo_bonds', 'IPO & Bonds'),
  reports('reports', 'Reports & Statements'),
  profile('profile', 'Profile & KYC'),
  elsewhere('elsewhere', 'Somewhere else');

  const SupportTicketArea(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Best guess from the route the client raised the ticket from, so the
  /// picker opens on the likely answer instead of empty.
  ///
  /// Only a starting point — the client can always change it, which is the
  /// whole reason the field exists.
  static SupportTicketArea? fromRoute(String route) {
    final r = route.toLowerCase();
    for (final area in values) {
      if (area == elsewhere) continue;
      if (r.contains(area.apiValue.split('_').first)) return area;
    }
    return null;
  }
}

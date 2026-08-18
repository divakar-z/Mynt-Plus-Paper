/// Display string for the Closing-Auction-Session indicative price (feed `ic`).
/// Returns the rupee-formatted value only when [ic] is a real positive price;
/// otherwise an em dash (no auction / not eligible / not sent).
String casIndicativeDisplay(String? ic) {
  if (ic == null) return '—';
  final s = ic.trim();
  if (s.isEmpty || s == 'null') return '—';
  final v = double.tryParse(s);
  if (v == null || v <= 0) return '—';
  return '$s';
}

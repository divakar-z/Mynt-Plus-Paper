/// Buildup classification (price vs OI, day-over-day) used across the
/// dashboard. Wire values come from `category` on `/fno-buildup` and
/// `/most-active?by=oi_change` rows.
///
/// DISTINCT from the legacy `BuildupBucket` enum used by the old OI-Data
/// screens: the new API uses `long_covering` (not `long_unwinding`) and adds
/// an explicit `na` bucket for symbols with no prior-day reference.
enum BuildupCategory {
  longBuildup('long_buildup', 'Long Buildup'),
  shortBuildup('short_buildup', 'Short Buildup'),
  shortCovering('short_covering', 'Short Covering'),
  longCovering('long_covering', 'Long Covering'),
  na('na', 'NA');

  final String wire;
  final String label;
  const BuildupCategory(this.wire, this.label);

  static BuildupCategory fromWire(String? value) {
    for (final c in BuildupCategory.values) {
      if (c.wire == value) return c;
    }
    return BuildupCategory.na;
  }

  /// bullish = long_buildup + short_covering (price expected to rise).
  bool get isBullish =>
      this == BuildupCategory.longBuildup ||
      this == BuildupCategory.shortCovering;

  /// bearish = short_buildup + long_covering (price expected to fall).
  bool get isBearish =>
      this == BuildupCategory.shortBuildup ||
      this == BuildupCategory.longCovering;
}

/// Per-stock price direction from `/advance-decline?index=...` stock rows.
enum Direction {
  up('up'),
  down('down'),
  flat('flat');

  final String wire;
  const Direction(this.wire);

  static Direction fromWire(String? value) {
    for (final d in Direction.values) {
      if (d.wire == value) return d;
    }
    return Direction.flat;
  }
}

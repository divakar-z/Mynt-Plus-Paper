/// The four asset classes a journal note can belong to.
///
/// A note is keyed on `(client, note_date, segment_group)` — one note per day
/// per asset class. A trader who traded F&O and commodity on the same day has
/// two notes, and will not see the F&O note on the commodity tab. That is
/// intentional: each note's P&L snapshot then matches the numbers shown on the
/// tab it was written from.
enum SegmentGroup {
  equity('equity', 'Equity', 'NSE_CASH,BSE_CASH'),
  fno('fno', 'FNO', 'NSE_FNO,BSE_FNO'),
  commodity('commodity', 'Commodity', 'MCX,NCDEX,NSE_COM,BSE_COM'),
  currency('currency', 'Currency', 'CD_NSE,CD_BSE,CD_MCX,CD_USE');

  const SegmentGroup(this.wire, this.tabLabel, this.cocdScope);

  /// Value sent as `segment_group`. The backend does not derive this from the
  /// COCD codes — a COCD list is a query filter, not a classification.
  final String wire;

  /// The label [LDProvider.selectedSegment] holds for this group.
  final String tabLabel;

  /// The COCD CSV `getcalenderpnldata` passes to the journal endpoint for this
  /// group, mirrored from [LedgerApi.getcalenderpnldata]. Recorded on the
  /// snapshot as `cocd_scope` so the stored P&L says which universe it covers.
  /// Unknown codes are rejected with `400 BAD_PNL`, so these must stay in step
  /// with the ledger API if its segment codes ever change.
  final String cocdScope;

  /// Maps a P&L Summary tab label to its group.
  ///
  /// Returns null for anything unrecognised. Deliberately unlike
  /// [LedgerApi.getcalenderpnldata], whose ternary chain treats Currency as the
  /// `else` branch and so silently maps any unknown label to currency codes.
  ///
  /// Not to be confused with `LDProvider._calSegCode`, which maps the same four
  /// tabs to `eq`/`fno`/`comm`/`curr` for the charges API. Different vocabulary,
  /// different endpoint — do not cross the two.
  static SegmentGroup? fromTabLabel(String label) => switch (label) {
        'Equity' => SegmentGroup.equity,
        'FNO' => SegmentGroup.fno,
        'Commodity' => SegmentGroup.commodity,
        'Currency' => SegmentGroup.currency,
        _ => null,
      };

  /// Parses the `segment_group` value returned on a note.
  static SegmentGroup? fromWire(String? wire) => switch (wire) {
        'equity' => SegmentGroup.equity,
        'fno' => SegmentGroup.fno,
        'commodity' => SegmentGroup.commodity,
        'currency' => SegmentGroup.currency,
        _ => null,
      };

  /// Commodity reads its day rows from `getJournalDiary3`, which returns a
  /// different response shape (`dateWise`) to the other three (`journal[]`).
  /// The P&L snapshot has to be sourced accordingly — see `NotePnlSnapshot`.
  bool get usesJournalDiary3 => this == SegmentGroup.commodity;
}

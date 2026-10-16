/// Shared geometry for the option-chain ladder, matching the app's existing
/// market-watch option chain: `CALLS (flex 6) | STRIKE (150px) | PUTS (flex 6)`
/// with 56px virtualized rows and two stacked sub-columns per side.
const double kChainRowH = 56.0;
const double kStrikeColWidth = 150.0;
const double kChainHeaderTopH = 34.0;
const double kChainSubHeaderH = 52.0;
const int kCallPutFlex = 6;

/// Height of the mirrored OI bar drawn under each strike number.
const double kOiBarH = 5.0;

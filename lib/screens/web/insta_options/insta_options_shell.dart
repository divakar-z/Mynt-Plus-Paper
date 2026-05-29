import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';
import 'package:mynt_plus/screens/web/insta_options/screens/buildup_screen.dart';
import 'package:mynt_plus/screens/web/insta_options/screens/chain_screen.dart';
import 'package:mynt_plus/screens/web/insta_options/screens/index_contributors_screen.dart';
import 'package:mynt_plus/screens/web/insta_options/screens/markets_dashboard_screen.dart';
import 'package:mynt_plus/screens/web/insta_options/screens/oi_stats_screen.dart';
import 'package:mynt_plus/screens/web/insta_options/screens/pcr_screen.dart';
import 'package:mynt_plus/screens/web/insta_options/screens/per_strike_screen.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/basket_chip.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/placeholder_screen.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/side_rail.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/streaming_dot.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/symbol_expiry_bar.dart';

/// Root widget for the InstaOptions Analytics module. Lives inside
/// `CustomizableSplitHomeScreen` as the right-panel for
/// `ScreenTypeParam.instaOptions`.
///
/// Owns the active sub-screen state and switches between the 9 sub-views via
/// an internal side-rail. There is no per-sub-screen GoRoute; deep-linking is
/// a Phase-10 follow-up.
class InstaOptionsShell extends ConsumerStatefulWidget {
  const InstaOptionsShell({super.key});

  @override
  ConsumerState<InstaOptionsShell> createState() => _InstaOptionsShellState();
}

class _InstaOptionsShellState extends ConsumerState<InstaOptionsShell> {
  InstaSubScreen _active = InstaSubScreen.markets;

  void _onSelect(InstaSubScreen sub) {
    if (sub == _active) return;
    setState(() => _active = sub);
  }

  Widget _buildActiveSubScreen() {
    switch (_active) {
      case InstaSubScreen.markets:
        return MarketsDashboardScreen(
          onOpenChain: () => _onSelect(InstaSubScreen.chain),
        );
      case InstaSubScreen.contributors:
        return const IndexContributorsScreen();
      case InstaSubScreen.chain:
        return const ChainScreen();
      case InstaSubScreen.oiStats:
        return const OiStatsScreen();
      case InstaSubScreen.trending:
        return const InstaPlaceholderScreen(
          title: 'Trending OI',
          phaseLabel: 'Phase 6',
          icon: Icons.trending_up,
        );
      case InstaSubScreen.pcr:
        return const PcrScreen();
      case InstaSubScreen.strike:
        return const PerStrikeScreen();
      case InstaSubScreen.buildup:
        return const BuildupScreen();
      case InstaSubScreen.findStrategy:
        return const InstaPlaceholderScreen(
          title: 'Find Strategy',
          phaseLabel: 'Phase 9',
          icon: Icons.search,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final markets = _active == InstaSubScreen.markets;
    final contributors = _active == InstaSubScreen.contributors;
    return Container(
      color: tokens.bgPrimary,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InstaSideRail(active: _active, onSelect: _onSelect),
              Expanded(
                child: Column(
                  children: [
                    SymbolExpiryBar(
                      streamingStatus: StreamingStatus.disconnected,
                      streamingTooltip:
                          'OI Data WebSocket not connected yet — Phase 2',
                      disableSymbol: markets || contributors,
                      disableExpiry: markets || contributors,
                    ),
                    Expanded(child: _buildActiveSubScreen()),
                  ],
                ),
              ),
            ],
          ),
          const BasketChip(),
        ],
      ),
    );
  }
}

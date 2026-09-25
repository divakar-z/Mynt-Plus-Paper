import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/strategy_scan_result.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_strategy_scan_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/strategy_result_card.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';

/// Find Strategy screen (README §10.9). Backend-driven strategy scanner with
/// direction + min reward filters; results render as cards with leg tables.
class FindStrategyScreen extends ConsumerStatefulWidget {
  const FindStrategyScreen({super.key});

  @override
  ConsumerState<FindStrategyScreen> createState() => _FindStrategyScreenState();
}

class _FindStrategyScreenState extends ConsumerState<FindStrategyScreen> {
  late final TextEditingController _rewardCtl;

  @override
  void initState() {
    super.initState();
    final initial = ref
        .read(instaOptionsStrategyScanProvider)
        .minReward
        .toStringAsFixed(0);
    _rewardCtl = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _rewardCtl.dispose();
    super.dispose();
  }

  void _onAddToBasket(StrategyScanResult r) {
    ResponsiveSnackBar.showSuccess(
      context,
      'Queued ${r.legs.length}-leg ${r.templateName} — order placement lands in Phase ι.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final selection = ref.watch(instaOptionsSelectionProvider).selection;
    final provider = ref.watch(instaOptionsStrategyScanProvider);

    return Container(
      color: tokens.bgPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(
            provider: provider,
            rewardCtl: _rewardCtl,
            disabled: selection.expiry.isEmpty,
            tokens: tokens,
          ),
          Expanded(
            child: _Results(
              provider: provider,
              onAddToBasket: _onAddToBasket,
              tokens: tokens,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final InstaOptionsStrategyScanProvider provider;
  final TextEditingController rewardCtl;
  final bool disabled;
  final InstaOptionsTokens tokens;

  const _FilterBar({
    required this.provider,
    required this.rewardCtl,
    required this.disabled,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: tokens.bgSecondary,
          border: Border.all(color: tokens.border, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: _LabelledDirection(
                value: provider.direction,
                onChange: provider.setDirection,
                tokens: tokens,
              ),
            ),
            SizedBox(
              width: 100,
              child: _LabelledRewardType(
                value: provider.minRewardType,
                onChange: provider.setMinRewardType,
                tokens: tokens,
              ),
            ),
            SizedBox(
              width: 160,
              child: _LabelledMinReward(
                controller: rewardCtl,
                onChange: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null) provider.setMinReward(parsed);
                },
                symbol: provider.minRewardType.symbol,
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: disabled || provider.loading
                  ? null
                  : provider.runScan,
              icon: const Icon(Icons.search, size: 16),
              label: Text(provider.loading ? 'Scanning…' : 'Run scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                disabledBackgroundColor: tokens.border,
                disabledForegroundColor: tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelledDirection extends StatelessWidget {
  final StrategyDirection value;
  final ValueChanged<StrategyDirection> onChange;
  final InstaOptionsTokens tokens;

  const _LabelledDirection({
    required this.value,
    required this.onChange,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Direction',
          style: MyntWebTextStyles.caption(
            context,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: tokens.bgTertiary,
            border: Border.all(color: tokens.border, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.centerLeft,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<StrategyDirection>(
              isDense: true,
              isExpanded: true,
              value: value,
              dropdownColor: tokens.bgSecondary,
              icon: Icon(
                Icons.expand_more,
                color: tokens.textSecondary,
                size: 18,
              ),
              items: StrategyDirection.values
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.wire)))
                  .toList(growable: false),
              onChanged: (v) {
                if (v != null) onChange(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _LabelledRewardType extends StatelessWidget {
  final StrategyMinRewardType value;
  final ValueChanged<StrategyMinRewardType> onChange;
  final InstaOptionsTokens tokens;

  const _LabelledRewardType({
    required this.value,
    required this.onChange,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Unit',
          style: MyntWebTextStyles.caption(
            context,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        SegmentedButton<StrategyMinRewardType>(
          segments: const [
            ButtonSegment(value: StrategyMinRewardType.inr, label: Text('₹')),
            ButtonSegment(value: StrategyMinRewardType.pct, label: Text('%')),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChange(s.first),
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            foregroundColor: tokens.textSecondary,
            selectedForegroundColor: tokens.textPrimary,
            selectedBackgroundColor: tokens.bgTertiary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 36),
          ),
        ),
      ],
    );
  }
}

class _LabelledMinReward extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChange;
  final String symbol;
  final InstaOptionsTokens tokens;

  const _LabelledMinReward({
    required this.controller,
    required this.onChange,
    required this.symbol,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Min reward',
          style: MyntWebTextStyles.caption(
            context,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextField(
            controller: controller,
            onChanged: onChange,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: MyntWebTextStyles.body(context, color: tokens.textPrimary),
            decoration: InputDecoration(
              prefixText: '$symbol  ',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: tokens.bgTertiary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: tokens.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: tokens.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: tokens.accent, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  final InstaOptionsStrategyScanProvider provider;
  final ValueChanged<StrategyScanResult> onAddToBasket;
  final InstaOptionsTokens tokens;

  const _Results({
    required this.provider,
    required this.onAddToBasket,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.loading && provider.results.isEmpty) {
      return Center(child: CircularProgressIndicator(color: tokens.accent));
    }
    if (provider.error != null && provider.results.isEmpty) {
      return _Banner(
        icon: Icons.error_outline,
        title: 'Scan failed',
        body: provider.error!,
        tokens: tokens,
      );
    }
    if (!provider.hasRun) {
      return _Banner(
        icon: Icons.tune,
        title: 'Choose filters and tap Run scan',
        body: 'Pick a direction, set a minimum reward, then we will fetch ranked strategies from the OI Data backend.',
        tokens: tokens,
      );
    }
    if (provider.results.isEmpty) {
      return _Banner(
        icon: Icons.search_off,
        title: 'No strategies match these filters',
        body: 'Try lowering the minimum reward or switching direction.',
        tokens: tokens,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: provider.results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = provider.results[i];
        return StrategyResultCard(
          result: r,
          onAddToBasket: () => onAddToBasket(r),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final InstaOptionsTokens tokens;

  const _Banner({
    required this.icon,
    required this.title,
    required this.body,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: tokens.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: MyntWebTextStyles.head(context, color: tokens.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: MyntWebTextStyles.body(
                context,
                color: tokens.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

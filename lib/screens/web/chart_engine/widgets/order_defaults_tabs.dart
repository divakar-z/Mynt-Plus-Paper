import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/refined_controls.dart';

// Body widgets for the three previously-stub tabs of the Order Defaults
// popover (SL/TP, Quantity, Product). All three read/write the
// `orderDefaultsProvider` and persist via the Notifier's debounced timer.
//
// The popover host already wraps these in a SingleChildScrollView, so each
// tab body is a plain Column.

// ─── SL / TP ─────────────────────────────────────────────────────────────────

class SlTpDefaultsTab extends ConsumerWidget {
  // `paneIndex` is unused today — kept on the API surface so the host
  // signature matches the other tabs (and so a future per-pane override
  // doesn't break callers).
  final int paneIndex;
  const SlTpDefaultsTab(this.paneIndex, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(orderDefaultsProvider);
    final n = ref.read(orderDefaultsProvider.notifier);

    final triggerUnitHint = switch (d.slTrigger) {
      'percent' => 'Percent below entry',
      'ticks' => 'Ticks below entry',
      _ => 'Points below entry',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefinedRow(
          label: 'Auto Stop Loss',
          description: 'Adds a stop-loss leg to every order',
          control: RefinedSwitch(
            value: d.autoStopLoss,
            onChanged: n.setAutoStopLoss,
          ),
          onTap: () => n.setAutoStopLoss(!d.autoStopLoss),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'SL Type',
          description: 'Limit fires at price, Market fires immediately',
          control: RefinedSegmented<String>(
            width: 160,
            value: d.slType,
            onChanged: n.setSlType,
            options: const [
              RefinedSegmentOption(value: 'SL_LMT', label: 'SL Limit'),
              RefinedSegmentOption(value: 'SL_MKT', label: 'SL Market'),
            ],
          ),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'SL Trigger',
          description: 'How the trigger distance is measured',
          control: RefinedSegmented<String>(
            width: 200,
            value: d.slTrigger,
            onChanged: n.setSlTrigger,
            options: const [
              RefinedSegmentOption(value: 'points', label: 'Points'),
              RefinedSegmentOption(value: 'percent', label: 'Percent'),
              RefinedSegmentOption(value: 'ticks', label: 'Ticks'),
            ],
          ),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Trigger value',
          description: triggerUnitHint,
          control: _DoubleStepper(
            value: d.slTriggerValue,
            min: 0,
            max: 100000,
            step: d.slTrigger == 'percent' ? 0.5 : 1.0,
            decimals: d.slTrigger == 'percent' ? 1 : 0,
            onChanged: n.setSlTriggerValue,
          ),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Trailing SL',
          description: 'SL moves by X for every Y move in LTP',
          control: RefinedSwitch(
            value: d.trailingSL,
            onChanged: n.setTrailingSL,
          ),
          onTap: () => n.setTrailingSL(!d.trailingSL),
        ),
        if (d.trailingSL) ...[
          const RefinedDivider(),
          RefinedRow(
            label: 'SL moves by',
            description: 'X — how far the SL shifts on each step',
            control: _DoubleStepper(
              value: d.trailingMove,
              min: 0.1,
              max: 1000,
              step: 0.5,
              decimals: 1,
              onChanged: n.setTrailingMove,
            ),
          ),
          const RefinedDivider(),
          RefinedRow(
            label: 'For every move of',
            description: 'Y — LTP distance that triggers each shift',
            control: _DoubleStepper(
              value: d.trailingFor,
              min: 0.1,
              max: 1000,
              step: 0.5,
              decimals: 1,
              onChanged: n.setTrailingFor,
            ),
          ),
        ],
        const RefinedDivider(),
        RefinedRow(
          label: 'Auto Take Profit',
          description: 'Adds a take-profit leg to every order',
          control: RefinedSwitch(
            value: d.autoTakeProfit,
            onChanged: n.setAutoTakeProfit,
          ),
          onTap: () => n.setAutoTakeProfit(!d.autoTakeProfit),
        ),
        if (d.autoTakeProfit) ...[
          const RefinedDivider(),
          RefinedRow(
            label: 'TP Type',
            description: 'Limit fires at price, Market fires immediately',
            control: RefinedSegmented<String>(
              width: 160,
              value: d.tpType,
              onChanged: n.setTpType,
              options: const [
                RefinedSegmentOption(value: 'TP_LMT', label: 'TP Limit'),
                RefinedSegmentOption(value: 'TP_MKT', label: 'TP Market'),
              ],
            ),
          ),
        ],
        const RefinedDivider(),
        RefinedRow(
          label: 'TP Trigger',
          description: 'Points above entry',
          control: _DoubleStepper(
            value: d.tpTriggerValue,
            min: 0,
            max: 100000,
            step: 1.0,
            decimals: 0,
            onChanged: n.setTpTriggerValue,
          ),
        ),
      ],
    );
  }
}

// ─── Trade Quantity ──────────────────────────────────────────────────────────

class TradeQtyDefaultsTab extends ConsumerWidget {
  final int paneIndex;
  const TradeQtyDefaultsTab(this.paneIndex, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(orderDefaultsProvider);
    final n = ref.read(orderDefaultsProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefinedRow(
          label: 'Equity',
          description: 'Default quantity for stocks',
          control: RefinedStepper(
            value: d.equityDefaultQty,
            min: 1,
            max: 1 << 30,
            onChanged: n.setEquityDefaultQty,
          ),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Futures',
          description: 'Number of lots',
          control: RefinedStepper(
            value: d.futuresDefaultQty,
            min: 1,
            max: 9999,
            onChanged: n.setFuturesDefaultQty,
          ),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Options',
          description: 'Number of lots',
          control: RefinedStepper(
            value: d.optionsDefaultQty,
            min: 1,
            max: 9999,
            onChanged: n.setOptionsDefaultQty,
          ),
        ),
      ],
    );
  }
}

// ─── Product Type ────────────────────────────────────────────────────────────

class ProductTypeDefaultsTab extends ConsumerWidget {
  final int paneIndex;
  const ProductTypeDefaultsTab(this.paneIndex, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(orderDefaultsProvider);
    final n = ref.read(orderDefaultsProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefinedRow(
          label: 'Equity',
          description: 'Delivery holds overnight; Intraday squares off EOD',
          control: RefinedSegmented<String>(
            width: 170,
            value: d.equityProduct,
            onChanged: n.setEquityProduct,
            options: const [
              RefinedSegmentOption(value: 'C', label: 'Delivery'),
              RefinedSegmentOption(value: 'I', label: 'Intraday'),
            ],
          ),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Futures',
          description: 'Normal carries forward; Intraday squares off EOD',
          control: RefinedSegmented<String>(
            width: 170,
            value: d.futuresProduct,
            onChanged: n.setFuturesProduct,
            options: const [
              RefinedSegmentOption(value: 'M', label: 'Normal'),
              RefinedSegmentOption(value: 'I', label: 'Intraday'),
            ],
          ),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Options',
          description: 'Normal carries forward; Intraday squares off EOD',
          control: RefinedSegmented<String>(
            width: 170,
            value: d.optionsProduct,
            onChanged: n.setOptionsProduct,
            options: const [
              RefinedSegmentOption(value: 'M', label: 'Normal'),
              RefinedSegmentOption(value: 'I', label: 'Intraday'),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Private helpers ─────────────────────────────────────────────────────────

/// 36px bordered numeric stepper for `double` values. Mirrors `RefinedStepper`
/// (ints) and the `_ParamStepper` in chart_engine_shell_screen.dart for floats,
/// so the look matches the rest of the chart-engine settings surface.
class _DoubleStepper extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final int decimals;
  final ValueChanged<double> onChanged;
  const _DoubleStepper({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = double.infinity,
    this.step = 1.0,
    this.decimals = 0,
  });

  double _clamp(double v) {
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }

  double _normalize(double v) {
    // Round to step precision to avoid float drift (0.1 + 0.1 + … = 0.30000004).
    final stepInv = 1 / step;
    return (v * stepInv).round() / stepInv;
  }

  String _format(double v) {
    if (decimals == 0) return v.round().toString();
    final fixed = v.toStringAsFixed(decimals);
    if (fixed.endsWith('.0')) return fixed.substring(0, fixed.length - 2);
    return fixed;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2030) : const Color(0xFFF8FAFC);
    final stroke =
        isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);
    final iconColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Container(
      width: 124,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: stroke, width: 1),
      ),
      child: Row(
        children: [
          _DoubleStepperButton(
            icon: Icons.remove,
            color: iconColor,
            onTap: () => onChanged(_normalize(_clamp(value - step))),
          ),
          Expanded(
            child: Center(
              child: Text(
                _format(value),
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold),
              ),
            ),
          ),
          _DoubleStepperButton(
            icon: Icons.add,
            color: iconColor,
            onTap: () => onChanged(_normalize(_clamp(value + step))),
          ),
        ],
      ),
    );
  }
}

class _DoubleStepperButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _DoubleStepperButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

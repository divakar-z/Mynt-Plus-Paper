import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// Entry price cell of the legs table. The ⇆ icon inside the box switches the
/// leg to the market price ("Market") and, clicked again, back to the typed price.
class EntryPriceTableInput extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final bool market;
  final VoidCallback? onToggleMarket;
  final String? marketTip;

  const EntryPriceTableInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.market = false,
    this.onToggleMarket,
    this.marketTip,
  });

  @override
  State<EntryPriceTableInput> createState() => _EntryPriceTableInputState();
}

class _EntryPriceTableInputState extends State<EntryPriceTableInput> {
  late TextEditingController _controller;
  double _lastEmittedValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(2));
    _lastEmittedValue = widget.value;
  }

  @override
  void didUpdateWidget(EntryPriceTableInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only update text if the incoming value is different from what we last emitted.
    // This allows the user to type freely without the text resetting (re-formatting) on every keystroke
    // when the parent rebuilds.
    if ((widget.value - _lastEmittedValue).abs() > 0.001) {
       // Check if the current text content already represents the new value (e.g. "10." vs 10.0)
       final currentParsed = double.tryParse(_controller.text);
       if (currentParsed != widget.value) {
         _controller.text = widget.value.toStringAsFixed(2);
       }
       _lastEmittedValue = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = MyntWebTextStyles.bodySmall(
      context,
      darkColor: MyntColors.textPrimaryDark,
      lightColor: MyntColors.textBlack,
      fontWeight: MyntFonts.medium,
    ).copyWith(fontSize: 12);
    final primary = resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary);
    final muted = resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Container(
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: resolveThemeColor(context, dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder)),
      ),
      child: Row(children: [
        Expanded(
          child: widget.market
              ? Center(child: Text('Market', style: textStyle.copyWith(color: primary)))
              : TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: textStyle,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '0.00',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                  ),
                  onChanged: (val) {
                    final price = double.tryParse(val);
                    if (price != null) {
                      _lastEmittedValue = price;
                      widget.onChanged(price);
                    }
                  },
                ),
        ),
        if (widget.onToggleMarket != null)
          Tooltip(
            message: widget.marketTip ?? '',
            child: InkWell(
              onTap: widget.onToggleMarket,
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 22,
                height: 26,
                child: Icon(Icons.swap_horiz, size: 15, color: widget.market ? primary : muted),
              ),
            ),
          ),
      ]),
    );
  }
}

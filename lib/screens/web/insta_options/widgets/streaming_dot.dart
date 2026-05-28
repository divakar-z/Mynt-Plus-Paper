import 'package:flutter/material.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Connection status indicator for the OI Data backend.
enum StreamingStatus {
  connected,
  reconnecting,
  disconnected,
}

class StreamingDot extends StatelessWidget {
  final StreamingStatus status;
  final String? tooltip;

  const StreamingDot({
    super.key,
    required this.status,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final color = switch (status) {
      StreamingStatus.connected => tokens.profit,
      StreamingStatus.reconnecting => tokens.warning,
      StreamingStatus.disconnected => tokens.loss,
    };
    final dot = SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: status == StreamingStatus.connected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
    if (tooltip == null) return dot;
    return Tooltip(message: tooltip!, child: dot);
  }
}

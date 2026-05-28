import 'package:flutter/material.dart';
import 'package:mynt_plus/api/insta_options/insta_options_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/health_status.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Phase-1 landing for InstaOptions Analytics. Runs a one-shot `/health` call
/// against the OI Data backend so the shell smoke-tests end-to-end wiring.
/// Full Markets Dashboard layout lands in Phase 7.
class MarketsPlaceholderScreen extends StatefulWidget {
  const MarketsPlaceholderScreen({super.key});

  @override
  State<MarketsPlaceholderScreen> createState() =>
      _MarketsPlaceholderScreenState();
}

class _MarketsPlaceholderScreenState extends State<MarketsPlaceholderScreen> {
  InstaOptionsHealth? _health;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _probeHealth();
  }

  Future<void> _probeHealth() async {
    final api = locator<InstaOptionsApi>();
    try {
      final h = await api.getHealth();
      if (!mounted) return;
      setState(() {
        _health = h;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _health = null;
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    return Container(
      color: tokens.bgPrimary,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 560),
          decoration: BoxDecoration(
            color: tokens.bgSecondary,
            border: Border.all(color: tokens.border, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'InstaOptions Analytics',
                style: MyntWebTextStyles.hero(
                  context,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Phase 1 — plumbing ready. Markets Dashboard lands in Phase 7.',
                style: MyntWebTextStyles.body(
                  context,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 1,
                color: tokens.border,
              ),
              const SizedBox(height: 16),
              Text(
                'OI Data backend',
                style: MyntWebTextStyles.head(
                  context,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Probing /health…',
                      style: MyntWebTextStyles.body(
                        context,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                )
              else if (_error != null)
                _BackendOffline(error: _error!, tokens: tokens, onRetry: () {
                  setState(() => _loading = true);
                  _probeHealth();
                })
              else if (_health != null)
                _BackendOnline(health: _health!, tokens: tokens, onRetry: () {
                  setState(() => _loading = true);
                  _probeHealth();
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackendOnline extends StatelessWidget {
  final InstaOptionsHealth health;
  final InstaOptionsTokens tokens;
  final VoidCallback onRetry;

  const _BackendOnline({
    required this.health,
    required this.tokens,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusRow(
          label: 'Status',
          value: health.status,
          color: tokens.profit,
          tokens: tokens,
        ),
        _StatusRow(
          label: 'WS connected',
          value: health.wsConnected ? 'true' : 'false',
          color: health.wsConnected ? tokens.profit : tokens.loss,
          tokens: tokens,
        ),
        _StatusRow(
          label: 'NFO tokens',
          value: health.nfoTokens.toString(),
          tokens: tokens,
        ),
        _StatusRow(
          label: 'BFO tokens',
          value: health.bfoTokens.toString(),
          tokens: tokens,
        ),
        _StatusRow(
          label: 'Subscribed',
          value: health.subscribedCount.toString(),
          tokens: tokens,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _BackendOffline extends StatelessWidget {
  final String error;
  final InstaOptionsTokens tokens;
  final VoidCallback onRetry;

  const _BackendOffline({
    required this.error,
    required this.tokens,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.loss.withValues(alpha: 0.1),
        border: Border.all(color: tokens.loss, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off, color: tokens.loss, size: 20),
              const SizedBox(width: 8),
              Text(
                'Backend unreachable',
                style: MyntWebTextStyles.body(
                  context,
                  color: tokens.loss,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: MyntWebTextStyles.caption(
              context,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Expected when the OI Data backend at the default '
            '192.168.5.61:8000 is not reachable from this network. '
            'The shell is still functional; per-screen widgets will surface '
            'their own errors when phases 2–9 land.',
            style: MyntWebTextStyles.caption(
              context,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final InstaOptionsTokens tokens;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.tokens,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: MyntWebTextStyles.body(
                context,
                color: tokens.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: MyntWebTextStyles.body(
              context,
              color: color ?? tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'scanners_detail_pane.dart';
import 'scanners_list_pane.dart';

class ScannersSubPage extends ConsumerStatefulWidget {
  const ScannersSubPage({super.key});

  @override
  ConsumerState<ScannersSubPage> createState() => _ScannersSubPageState();
}

class _ScannersSubPageState extends ConsumerState<ScannersSubPage> {
  String? _selectedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(scannerShellProvider).pendingScannerCode;
      if (pending != null) {
        setState(() => _selectedCode = pending);
        ref.read(scannerShellProvider.notifier).consumePendingScannerCode();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scannerShellProvider, (prev, next) {
      if (next.pendingScannerCode != null &&
          next.pendingScannerCode != _selectedCode) {
        setState(() => _selectedCode = next.pendingScannerCode);
        ref.read(scannerShellProvider.notifier).consumePendingScannerCode();
      }
    });

    if (_selectedCode == null) {
      return ScannersListPane(
        onSelect: (c) => setState(() => _selectedCode = c),
      );
    }
    return ScannersDetailPane(
      code: _selectedCode!,
      onBack: () => setState(() => _selectedCode = null),
    );
  }
}

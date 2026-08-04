import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/supabase_config.dart';
import 'app_update_providers.dart';

/// Dispara comprobación de actualizaciones al iniciar y al volver a primer plano.
class AppUpdateGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkIfReady());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkIfReady();
    }
  }

  void _checkIfReady() {
    if (!SupabaseConfig.isConfigured) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(appUpdateProvider.notifier).check();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

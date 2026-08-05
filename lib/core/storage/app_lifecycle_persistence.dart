import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';

/// Asegura que SQLite vuelque cambios al pausar o cerrar la app.
class AppLifecyclePersistence extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecyclePersistence({super.key, required this.child});

  @override
  ConsumerState<AppLifecyclePersistence> createState() =>
      _AppLifecyclePersistenceState();
}

class _AppLifecyclePersistenceState extends ConsumerState<AppLifecyclePersistence>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _checkpointDatabase();
    }
  }

  Future<void> _checkpointDatabase() async {
    try {
      final db = ref.read(databaseProvider);
      await db.customStatement('PRAGMA wal_checkpoint(FULL);');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';

/// Número de operaciones de sync pendientes en cola local.
final pendingSyncQueueCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final pending = await (db.select(db.cloudSyncQueue)
        ..where((q) => q.processed.equals(false)))
      .get();
  return pending.length;
});

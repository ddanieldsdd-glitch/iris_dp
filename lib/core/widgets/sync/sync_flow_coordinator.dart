import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/sync_engine.dart';
import '../../sync/sync_plan_applier.dart';
import '../../utils/error_log.dart';
import 'sync_conflict_resolution_sheet.dart';

/// Orquesta el flujo de sync manual: motor de datos + UI de revisión.
abstract final class SyncFlowCoordinator {
  SyncFlowCoordinator._();

  static Future<SyncResult> runWithConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final engine = ref.read(syncEngineProvider);
    final SyncManualStart start;
    try {
      start = await engine.prepareManualSync();
    } catch (e, st) {
      // Lo que se pudo aplicar ya está aplicado; el detalle queda en el log.
      await ErrorLog.record(e, st, context: 'Sincronizar');
      final detail = e is SyncApplyException ? e.error : e;
      return SyncResult(message: 'No se pudo sincronizar todo: $detail');
    }

    if (start.isSkipped) {
      return SyncResult.skipped(start.skipReason!);
    }
    if (start.isComplete) {
      return start.result!;
    }

    final plan = start.plan!;
    final workspaceId = start.workspaceId!;

    if (!context.mounted) {
      return SyncResult.skipped('Cancelado');
    }

    SyncResult? appliedResult;
    final applied = await SyncConflictResolutionSheet.show(
      context,
      plan: plan,
      onApply: (confirmed) async {
        appliedResult = await engine.applyConfirmedPlan(confirmed, workspaceId);
      },
    );

    if (applied != true) {
      return engine.cancelManualSyncReview(plan);
    }

    final base = appliedResult ??
        const SyncResult(
          pushed: 0,
          pulled: 0,
          deleted: 0,
        );
    return engine.finalizeManualSync(base, workspaceId);
  }
}

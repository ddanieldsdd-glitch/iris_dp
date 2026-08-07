import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/cloud_session.dart';
import '../database/database_provider.dart';
import 'media_hydrate_service.dart';
import 'media_sync_providers.dart';
import 'media_upload_queue.dart';
import 'project_content_sync_service.dart';
import 'project_sync_service.dart';
import 'sync_conflict_resolution_sheet.dart';
import 'sync_plan.dart';
import 'sync_plan_applier.dart';
import 'sync_plan_builder.dart';
import '../templates/user_settings_sync_service.dart';

/// Orquestador de sincronización cloud ↔ cache local.
class SyncEngine {
  final Ref _ref;

  SyncEngine(this._ref);

  ProjectSyncService? get _projects {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) return null;
    return ProjectSyncService(_ref.read(databaseProvider), client);
  }

  MediaUploadQueue? get _uploadQueue => _ref.read(mediaUploadQueueProvider);

  MediaHydrateService? get _hydrate => _ref.read(mediaHydrateServiceProvider);

  SupabaseClient? get _client => _ref.read(supabaseClientProvider);

  /// Analiza diferencias sin aplicar cambios.
  Future<SyncPlan?> analyze() async {
    final client = _client;
    if (client == null) return null;

    final workspaceId = await CloudSessionStore.workspaceId();
    if (workspaceId == null) return null;

    final db = _ref.read(databaseProvider);
    return SyncPlanBuilder(db, client).build(workspaceId);
  }

  /// Sync con confirmación del usuario si hay diferencias.
  Future<SyncResult> syncWithConfirmation(BuildContext context) async {
    final client = _client;
    if (client == null) {
      return SyncResult.skipped('Modo local');
    }

    final workspaceId = await CloudSessionStore.workspaceId();
    if (workspaceId == null) {
      return SyncResult.skipped('Sin workspace');
    }

    final db = _ref.read(databaseProvider);
    final plan = await SyncPlanBuilder(db, client).build(workspaceId);

    if (plan.isEmpty) {
      _ref.read(pendingSyncPlanProvider.notifier).state = null;
      return _finishSync(workspaceId, pushed: 0, pulled: 0, deleted: 0);
    }

    if (!context.mounted) {
      return SyncResult.skipped('Cancelado');
    }

    SyncResult? result;
    final applied = await SyncConflictResolutionSheet.show(
      context,
      plan: plan,
      onApply: (confirmed) async {
        final counts = await _applyPlan(confirmed, workspaceId);
        result = await _finishSync(
          workspaceId,
          pushed: counts.pushed,
          pulled: counts.pulled,
          deleted: counts.deleted,
        );
      },
    );

    if (applied != true) {
      _ref.read(pendingSyncPlanProvider.notifier).state = plan;
      return SyncResult.skipped('Revisión pendiente');
    }

    final remaining = await SyncPlanBuilder(db, client).build(workspaceId);
    if (remaining.isEmpty || _isSpuriousContentDrift(remaining)) {
      _ref.read(pendingSyncPlanProvider.notifier).state = null;
      final base = result ??
          const SyncResult(
            pushed: 0,
            pulled: 0,
            deleted: 0,
          );
      return SyncResult(
        pushed: base.pushed,
        pulled: base.pulled,
        deleted: base.deleted,
        invitationsAccepted: base.invitationsAccepted,
            mediaUploaded: base.mediaUploaded,
            mediaDownloaded: base.mediaDownloaded,
            bytesSaved: base.bytesSaved,
        message: _successMessage(base),
      );
    }

    _ref.read(pendingSyncPlanProvider.notifier).state = remaining;
    return SyncResult(
      pushed: result?.pushed ?? 0,
      pulled: result?.pulled ?? 0,
      deleted: result?.deleted ?? 0,
      invitationsAccepted: result?.invitationsAccepted ?? 0,
      mediaUploaded: result?.mediaUploaded ?? 0,
      mediaDownloaded: result?.mediaDownloaded ?? 0,
      bytesSaved: result?.bytesSaved ?? 0,
      message:
          'Aplicado, pero quedan ${remaining.items.length} diferencias. Revisa de nuevo.',
      pendingReview: true,
    );
  }

  /// Solo quedan ítems de contenido con mismos conteos (hash distinto por rutas locales).
  bool _isSpuriousContentDrift(SyncPlan plan) {
    if (plan.items.isEmpty) return true;
    return plan.items.every((item) {
      if (!item.isContentSync) return false;
      final local = item.localContentSummary;
      final cloud = item.cloudContentSummary;
      return local != null && cloud != null && local == cloud;
    });
  }

  String _successMessage(SyncResult result) {
    final parts = <String>['Sincronizado correctamente'];
    if (result.pushed + result.pulled + result.deleted > 0) {
      parts.add('↑${result.pushed} ↓${result.pulled}');
    }
    if (result.mediaUploaded + result.mediaDownloaded > 0) {
      parts.add('↑${result.mediaUploaded} ↓${result.mediaDownloaded} img');
    }
    if (result.bytesSaved > 0) {
      parts.add('${(result.bytesSaved / 1024 / 1024).toStringAsFixed(1)} MB ahorrados');
    }
    return parts.join(' · ');
  }

  /// Sync al arrancar: no aplica si hay diferencias; deja banner pendiente.
  Future<SyncResult> syncOnStartup() async {
    final client = _client;
    if (client == null) {
      return SyncResult.skipped('Modo local');
    }

    final workspaceId = await CloudSessionStore.workspaceId();
    if (workspaceId == null) {
      return SyncResult.skipped('Sin workspace');
    }

    final db = _ref.read(databaseProvider);
    final plan = await SyncPlanBuilder(db, client).build(workspaceId);

    if (plan.isEmpty) {
      _ref.read(pendingSyncPlanProvider.notifier).state = null;
      return _finishSync(workspaceId, pushed: 0, pulled: 0, deleted: 0);
    }

    _ref.read(pendingSyncPlanProvider.notifier).state = plan;
    return SyncResult(
      message: 'Hay ${plan.items.length} cambios pendientes de revisar',
      pendingReview: true,
    );
  }

  /// Aplica el plan con las elecciones por defecto (p. ej. migración inicial).
  Future<SyncResult> syncApplyDefaults() async {
    final client = _client;
    if (client == null) {
      return SyncResult.skipped('Modo local');
    }

    final workspaceId = await CloudSessionStore.workspaceId();
    if (workspaceId == null) {
      return SyncResult.skipped('Sin workspace');
    }

    final db = _ref.read(databaseProvider);
    final plan = await SyncPlanBuilder(db, client).build(workspaceId);

    if (plan.isEmpty) {
      return _finishSync(workspaceId, pushed: 0, pulled: 0, deleted: 0);
    }

    final counts = await _applyPlan(plan, workspaceId);
    _ref.read(pendingSyncPlanProvider.notifier).state = null;
    return _finishSync(
      workspaceId,
      pushed: counts.pushed,
      pulled: counts.pulled,
      deleted: counts.deleted,
    );
  }

  Future<({int pushed, int pulled, int deleted})> _applyPlan(
    SyncPlan plan,
    String workspaceId,
  ) async {
    final client = _client!;
    final db = _ref.read(databaseProvider);
    final projects = _projects!;

    await projects.processPendingDeletions();
    final counts = await SyncPlanApplier(db, client).apply(plan, workspaceId);
    await CloudSyncQueueService(db, client).processPending();
    return counts;
  }

  Future<SyncResult> _finishSync(
    String workspaceId, {
    required int pushed,
    required int pulled,
    required int deleted,
  }) async {
    final inviteService = ProjectInviteService(_client!);
    final accepted = await inviteService.acceptPendingInvitations();

    var mediaUploaded = 0;
    var mediaDownloaded = 0;
    var bytesSaved = 0;

    final uploadQueue = _uploadQueue;
    final hydrate = _hydrate;
    if (uploadQueue != null && hydrate != null) {
      final db = _ref.read(databaseProvider);
      final allProjects = await db.watchProjects().first;
      for (final p in allProjects) {
        if (p.cloudId == null) continue;
        mediaUploaded += await uploadQueue.scanAndEnqueueProject(p.id);
        mediaDownloaded += await hydrate.hydrateProject(p.id, p.cloudId!);
      }
      await uploadQueue.startWorker();
      bytesSaved = uploadQueue.bytesSavedSession;
    }

    final client = _client;
    if (client != null && client.auth.currentUser != null) {
      try {
        await UserSettingsSyncService.sync(
          db: _ref.read(databaseProvider),
          client: client,
        );
      } catch (_) {
        // Plantillas locales siguen disponibles sin nube.
      }
    }

    await CloudSessionStore.setLastSyncAt(DateTime.now());

    return SyncResult(
      pushed: pushed,
      pulled: pulled,
      deleted: deleted,
      invitationsAccepted: accepted,
      mediaUploaded: mediaUploaded,
      mediaDownloaded: mediaDownloaded,
      bytesSaved: bytesSaved,
    );
  }

  /// Alias de [syncApplyDefaults] para compatibilidad.
  Future<SyncResult> syncAll() => syncApplyDefaults();
}

class SyncResult {
  final int pushed;
  final int pulled;
  final int deleted;
  final int invitationsAccepted;
  final int mediaUploaded;
  final int mediaDownloaded;
  final int bytesSaved;
  final String? message;
  final bool pendingReview;

  const SyncResult({
    this.pushed = 0,
    this.pulled = 0,
    this.deleted = 0,
    this.invitationsAccepted = 0,
    this.mediaUploaded = 0,
    this.mediaDownloaded = 0,
    this.bytesSaved = 0,
    this.message,
    this.pendingReview = false,
  });

  /// Compatibilidad con código que usaba [mediaSynced].
  int get mediaSynced => mediaUploaded + mediaDownloaded;

  factory SyncResult.skipped(String reason) =>
      SyncResult(message: reason);

  bool get ok => message == null || pendingReview;
}

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine(ref));

final pendingSyncPlanProvider = StateProvider<SyncPlan?>((ref) => null);

final syncStatusProvider = FutureProvider<SyncResult>((ref) async {
  return ref.read(syncEngineProvider).syncOnStartup();
});

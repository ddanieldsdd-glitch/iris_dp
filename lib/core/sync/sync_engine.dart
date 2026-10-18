import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/cloud_session.dart';
import '../database/database_provider.dart';
import 'content_merge_service.dart';
import 'device_label.dart';
import 'media_hydrate_service.dart';
import 'media_sync_providers.dart';
import 'media_upload_queue.dart';
import 'primary_reference_repair.dart';
import 'project_content_sync_service.dart';
import 'project_sync_service.dart';
import 'sync_plan.dart';
import 'sync_plan_applier.dart';
import 'sync_plan_builder.dart';
import '../templates/user_settings_sync_service.dart';
import '../utils/error_log.dart';

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

  /// Sync manual: aplica sin hoja lo que solo cambió en un lado y devuelve
  /// para revisar lo que hay que decidir.
  Future<SyncManualStart> prepareManualSync() async {
    final client = _client;
    if (client == null) {
      return SyncManualStart.skipped('Modo local');
    }

    final workspaceId = await CloudSessionStore.workspaceId();
    if (workspaceId == null) {
      return SyncManualStart.skipped('Sin workspace');
    }

    // Si ya hay una pasada en marcha (p. ej. la de cada minuto), se espera y
    // se hace otra completa: el botón siempre deja todo mirado.
    await _settled(_inFlight);
    final result = await syncSilently();
    final pending = _ref.read(pendingSyncPlanProvider);
    if (pending != null && !pending.isEmpty) {
      return SyncManualStart.needsReview(pending, workspaceId);
    }
    return SyncManualStart.complete(result);
  }

  /// Aplica el plan confirmado por el usuario.
  Future<SyncResult> applyConfirmedPlan(
    SyncPlan plan,
    String workspaceId,
  ) async {
    // No se cruza con una pasada automática.
    await _settled(_inFlight);
    final done = Completer<SyncResult>();
    _inFlight = done.future;
    try {
      final counts = await _applyPlan(plan, workspaceId);
      return await _finishSync(
        workspaceId,
        pushed: counts.pushed,
        pulled: counts.pulled,
        deleted: counts.deleted,
      );
    } on SyncApplyException catch (e) {
      // Lo que sí se aplicó necesita sus medios: si no, un proyecto
      // descargado se queda sin imágenes. Después se enseña el error.
      await _finishSync(
        workspaceId,
        pushed: e.pushed,
        pulled: e.pulled,
        deleted: e.deleted,
      );
      rethrow;
    } finally {
      _inFlight = null;
      done.complete(const SyncResult());
    }
  }

  /// Tras aplicar cambios, re-analiza y actualiza el estado pendiente.
  Future<SyncResult> finalizeManualSync(
    SyncResult baseResult,
    String workspaceId,
  ) async {
    final client = _client;
    if (client == null) return baseResult;

    // Lo que la revisión dejó por aplicar solo se aplica ya; queda lo que
    // sigue pendiente de decidir.
    await syncSilently(allMedia: false);
    final remaining =
        _ref.read(pendingSyncPlanProvider) ?? const SyncPlan(items: []);
    if (remaining.isEmpty || _isSpuriousContentDrift(remaining)) {
      _ref.read(pendingSyncPlanProvider.notifier).state = null;
      return SyncResult(
        pushed: baseResult.pushed,
        pulled: baseResult.pulled,
        deleted: baseResult.deleted,
        invitationsAccepted: baseResult.invitationsAccepted,
        mediaUploaded: baseResult.mediaUploaded,
        mediaDownloaded: baseResult.mediaDownloaded,
        bytesSaved: baseResult.bytesSaved,
        message: _successMessage(baseResult),
      );
    }

    _ref.read(pendingSyncPlanProvider.notifier).state = remaining;
    return SyncResult(
      pushed: baseResult.pushed,
      pulled: baseResult.pulled,
      deleted: baseResult.deleted,
      invitationsAccepted: baseResult.invitationsAccepted,
      mediaUploaded: baseResult.mediaUploaded,
      mediaDownloaded: baseResult.mediaDownloaded,
      bytesSaved: baseResult.bytesSaved,
      message:
          'Aplicado, pero quedan ${remaining.items.length} diferencias. Revisa de nuevo.',
      pendingReview: true,
    );
  }

  /// Usuario canceló la revisión: deja el plan pendiente.
  SyncResult cancelManualSyncReview(SyncPlan plan) {
    _ref.read(pendingSyncPlanProvider.notifier).state = plan;
    return SyncResult.skipped('Revisión pendiente');
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

  /// Pasada en marcha: los disparadores (al volver, cada minuto, tras editar,
  /// el botón) no se pisan entre sí.
  Future<SyncResult>? _inFlight;

  /// Alguien pidió sincronizar mientras había una pasada: se hace otra al
  /// terminar, para no perder lo editado entretanto.
  bool _again = false;

  /// Proyectos bajados hace poco: el otro equipo sube sus imágenes después
  /// del contenido, así que se vuelven a mirar un rato aunque no cambien.
  final Map<String, DateTime> _recentPulls = {};

  /// El aviso de imágenes desactivadas va al log una vez por sesión.
  static bool _warnedMediaOff = false;
  static const _mediaFollowUp = Duration(minutes: 10);

  static Future<void> _settled(Future<void>? f) async {
    if (f == null) return;
    try {
      await f;
    } catch (_) {}
  }

  /// Sync al arrancar (y al reconectar o cambiar de versión).
  Future<SyncResult> syncOnStartup() => syncSilently();

  /// Sincroniza sin preguntar lo que solo cambió en un lado; lo que hay que
  /// decidir queda en [pendingSyncPlanProvider] para la hoja.
  ///
  /// [allMedia] mira los medios de todos los proyectos; si no, solo los de
  /// los proyectos que han cambiado en esta pasada o se bajaron hace poco
  /// (la pasada de cada minuto).
  Future<SyncResult> syncSilently({bool allMedia = true}) {
    final running = _inFlight;
    if (running != null) {
      _again = true;
      return running;
    }
    final run = _runSilently(allMedia: allMedia);
    _inFlight = run;
    run.whenComplete(() {
      _inFlight = null;
      if (!_again) return;
      _again = false;
      unawaited(syncSilently(allMedia: false).then(
        (_) {},
        onError: (Object e, StackTrace st) =>
            ErrorLog.record(e, st, context: 'Sincronización automática'),
      ));
    }).ignore();
    return run;
  }

  Future<SyncResult> _runSilently({required bool allMedia}) async {
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

    // Cambiado aquí y en la nube: se mezcla elemento a elemento. Sin base
    // para mezclar queda para revisarlo.
    final merged = <SyncPlanItem>[];
    for (final item in plan.items) {
      if (item.action != SyncPlanAction.contentConflict) continue;
      final id = item.localProjectId;
      final cloudId = item.cloudId;
      if (id == null || cloudId == null) continue;
      try {
        final outcome =
            await ContentMergeService(db, client).mergeAndSync(id, cloudId);
        if (outcome == null) continue;
        merged.add(item);
        if (outcome.discarded > 0) {
          _ref.read(mergeDiscardsProvider.notifier).state += outcome.discarded;
          _ref.read(mergeNoticeProvider.notifier).state = MergeNotice(
            projectName: item.localProject?.name ?? item.title,
            discarded: outcome.discarded,
            mine: outcome.mine,
          );
        }
      } catch (e, st) {
        await ErrorLog.record(e, st, context: 'Mezclar ${item.title}');
      }
    }

    final review = [
      for (final item in plan.reviewItems)
        if (!merged.contains(item)) item,
    ];
    for (final item in [...review, ...merged]) {
      item.choice = SyncResolutionChoice.skip;
    }
    final applied = [
      for (final item in plan.items)
        if (item.appliesSilently) item,
    ];

    var counts = (pushed: 0, pulled: 0, deleted: 0);
    Object? failure;
    StackTrace? failureStack;
    if (applied.isNotEmpty) {
      try {
        counts = await _applyPlan(plan, workspaceId);
      } on SyncApplyException catch (e, st) {
        // Lo que sí se aplicó necesita sus medios: se termina la pasada y
        // después se enseña el error.
        counts = (pushed: e.pushed, pulled: e.pulled, deleted: e.deleted);
        failure = e;
        failureStack = st;
      }
    }

    counts = (
      pushed: counts.pushed + merged.length,
      pulled: counts.pulled + merged.length,
      deleted: counts.deleted,
    );
    final touched = [...applied, ...merged];

    final now = DateTime.now();
    for (final item in touched) {
      final cloudId = item.cloudId;
      if (cloudId == null) continue;
      if (item.action == SyncPlanAction.contentConflict ||
          item.action == SyncPlanAction.pullContentCloud ||
          item.action == SyncPlanAction.importFromCloud ||
          item.action == SyncPlanAction.updateLocalFromCloud) {
        _recentPulls[cloudId] = now;
      }
    }
    _recentPulls.removeWhere((_, at) => now.difference(at) > _mediaFollowUp);

    Set<int>? mediaProjects;
    if (!allMedia) {
      final touchedLocal = {
        for (final item in touched)
          if (item.localProjectId != null) item.localProjectId!,
      };
      final touchedCloud = {
        for (final item in touched)
          if (item.cloudId != null) item.cloudId!,
        ..._recentPulls.keys,
      };
      final locals = await db.select(db.projects).get();
      mediaProjects = {
        for (final p in locals)
          if (touchedLocal.contains(p.id) ||
              (p.cloudId != null && touchedCloud.contains(p.cloudId)))
            p.id,
      };
    }

    _ref.read(pendingSyncPlanProvider.notifier).state = review.isEmpty
        ? null
        : SyncPlan(
            items: [
              for (final item in review)
                item.copyWith(choice: item.defaultChoice),
            ],
          );

    final result = await _finishSync(
      workspaceId,
      pushed: counts.pushed,
      pulled: counts.pulled,
      deleted: counts.deleted,
      mediaProjects: mediaProjects,
    );
    await _refreshLastCloudEdit(client);
    if (failure != null) {
      Error.throwWithStackTrace(failure, failureStack!);
    }
    if (review.isEmpty) return result;
    return SyncResult(
      pushed: result.pushed,
      pulled: result.pulled,
      deleted: result.deleted,
      invitationsAccepted: result.invitationsAccepted,
      mediaUploaded: result.mediaUploaded,
      mediaDownloaded: result.mediaDownloaded,
      bytesSaved: result.bytesSaved,
      message: review.length == 1
          ? 'Hay 1 cambio que revisar'
          : 'Hay ${review.length} cambios que revisar',
      pendingReview: true,
    );
  }

  /// Para el indicador: cuándo y en qué equipo se subió lo último.
  Future<void> _refreshLastCloudEdit(SupabaseClient client) async {
    final db = _ref.read(databaseProvider);
    final ids = [
      for (final p in await db.select(db.projects).get())
        if (p.cloudId != null) p.cloudId!,
    ];
    if (ids.isEmpty) return;
    Future<List<Map<String, dynamic>>> latest(String columns) => client
        .from('cloud_project_snapshots')
        .select(columns)
        .inFilter('project_id', ids)
        .order('updated_at', ascending: false)
        .limit(1);
    try {
      List<Map<String, dynamic>> rows;
      try {
        rows = await latest(
          hasDeviceColumn ? 'updated_at, updated_device' : 'updated_at',
        );
      } on PostgrestException catch (e) {
        if (!hasDeviceColumn || !isMissingDeviceColumn(e)) rethrow;
        hasDeviceColumn = false;
        rows = await latest('updated_at');
      }
      if (rows.isEmpty) return;
      final at = DateTime.tryParse(rows.first['updated_at'] as String? ?? '');
      if (at == null) return;
      _ref.read(lastCloudEditProvider.notifier).state = CloudEdit(
        at: at.toLocal(),
        device: rows.first['updated_device'] as String?,
      );
    } catch (_) {
      // Solo es el indicador: la sincronización ya está hecha.
    }
  }

  /// Sube enseguida lo editado aquí (unos segundos después de dejar de
  /// editar), sin mirar la nube entera. Si la nube cambió entretanto no sube:
  /// la próxima pasada lo resuelve.
  Future<void> pushPendingEdits() async {
    final client = _client;
    if (client == null) return;
    if (_inFlight != null) {
      _again = true;
      return;
    }
    final run = _pushPendingEdits(client);
    _inFlight = run.then(
      (_) => const SyncResult(),
      onError: (Object _) => const SyncResult(),
    );
    try {
      await run;
    } finally {
      _inFlight = null;
      if (_again) {
        _again = false;
        unawaited(syncSilently(allMedia: false).then(
          (_) {},
          onError: (Object e, StackTrace st) =>
              ErrorLog.record(e, st, context: 'Sincronización automática'),
        ));
      }
    }
  }

  Future<void> _pushPendingEdits(SupabaseClient client) async {
    final db = _ref.read(databaseProvider);
    final pending = await (db.select(db.cloudSyncQueue)
          ..where((q) => q.processed.equals(false)))
        .get();
    if (pending.isEmpty) return;
    await CloudSyncQueueService(db, client).processPending();

    // Las imágenes nuevas de esos proyectos salen ya, sin esperar a la
    // siguiente pasada completa.
    final uploadQueue = _uploadQueue;
    if (uploadQueue == null) return;
    final ids = {for (final q in pending) int.tryParse(q.localEntityId)};
    for (final id in ids) {
      if (id == null) continue;
      try {
        await uploadQueue.scanAndEnqueueProject(id);
      } catch (e, st) {
        await ErrorLog.record(e, st, context: 'Subir medios del proyecto $id');
      }
    }
    unawaited(uploadQueue.startWorker());
  }

  /// Aplica sin preguntar lo que solo cambió en un lado (p. ej. migración
  /// inicial). Los conflictos quedan pendientes de revisar.
  Future<SyncResult> syncApplyDefaults() => syncSilently();

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
    Set<int>? mediaProjects,
  }) async {
    // Pasada ligera ([mediaProjects] dado): solo los proyectos que tocan; las
    // invitaciones y plantillas se miran en las completas.
    final light = mediaProjects != null;
    final accepted = light
        ? 0
        : await ProjectInviteService(_client!).acceptPendingInvitations();

    var mediaUploaded = 0;
    var mediaDownloaded = 0;
    var bytesSaved = 0;

    final db = _ref.read(databaseProvider);
    final allProjects = [
      for (final p in await db.watchProjects().first)
        if (mediaProjects == null || mediaProjects.contains(p.id)) p,
    ];
    // Solo local y sin red: no depende de que la descarga llegue al final.
    for (final p in allProjects) {
      try {
        await repairDuplicatePrimaryReferences(db, p.id);
      } catch (e, st) {
        await ErrorLog.record(e, st, context: 'Reparar referencias ${p.name}');
      }
    }

    final uploadQueue = _uploadQueue;
    final hydrate = _hydrate;
    if (uploadQueue != null && hydrate != null) {
      for (final p in allProjects) {
        if (p.cloudId == null) continue;
        // Primero bajar y después poner en cola: lo recién bajado queda
        // anotado como subido y no vuelve a la nube. Un proyecto que falle
        // no deja sin medios a los demás.
        try {
          mediaDownloaded += await hydrate.hydrateProject(p.id, p.cloudId!);
        } catch (e, st) {
          await ErrorLog.record(e, st, context: 'Bajar medios ${p.name}');
        }
        try {
          mediaUploaded += await uploadQueue.scanAndEnqueueProject(p.id);
        } catch (e, st) {
          await ErrorLog.record(e, st, context: 'Subir medios ${p.name}');
        }
      }
      // Las imágenes siguen subiendo en segundo plano.
      unawaited(uploadQueue.startWorker());
      bytesSaved = uploadQueue.bytesSavedSession;
    } else if (!_warnedMediaOff) {
      // Sin esto las imágenes ni bajan ni suben y no queda rastro.
      _warnedMediaOff = true;
      await ErrorLog.record(
        StateError(
          'Imágenes desactivadas: esta versión se compiló sin '
          'CLOUDINARY_CLOUD_NAME / CLOUDINARY_UPLOAD_PRESET '
          '(usar scripts/run_cloud.sh o los --dart-define).',
        ),
        null,
        context: 'Sincronizar',
      );
    }

    final client = _client;
    if (!light && client != null && client.auth.currentUser != null) {
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

/// Resultado de preparar un sync manual (sin UI).
class SyncManualStart {
  final SyncPlan? plan;
  final String? workspaceId;
  final SyncResult? result;
  final String? skipReason;

  const SyncManualStart._({
    this.plan,
    this.workspaceId,
    this.result,
    this.skipReason,
  });

  factory SyncManualStart.skipped(String reason) =>
      SyncManualStart._(skipReason: reason);

  factory SyncManualStart.complete(SyncResult result) =>
      SyncManualStart._(result: result);

  factory SyncManualStart.needsReview(SyncPlan plan, String workspaceId) =>
      SyncManualStart._(plan: plan, workspaceId: workspaceId);

  bool get isSkipped => skipReason != null;
  bool get isComplete => result != null;
  bool get needsReview => plan != null && workspaceId != null;
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

/// Ediciones que la mezcla descartó en esta sesión (están en el historial
/// de conflictos).
final mergeDiscardsProvider = StateProvider<int>((ref) => 0);

/// Aviso de la última mezcla que descartó algo (lo enseña [AutoSyncScheduler]).
class MergeNotice {
  final String projectName;
  final int discarded;
  final int mine;

  const MergeNotice({
    required this.projectName,
    required this.discarded,
    required this.mine,
  });

  String get message {
    String n(int count, String one, String many) =>
        count == 1 ? '1 $one' : '$count $many';
    final what = mine > 0
        ? n(mine, 'cambio tuyo se descartó', 'cambios tuyos se descartaron')
        : n(discarded, 'cambio del otro equipo se descartó',
            'cambios del otro equipo se descartaron');
    return '$projectName se mezcló con el otro equipo · $what';
  }
}

final mergeNoticeProvider = StateProvider<MergeNotice?>((ref) => null);

/// La última subida a la nube que se ha visto (ver [CloudEdit]).
final lastCloudEditProvider = StateProvider<CloudEdit?>((ref) => null);

final syncStatusProvider = FutureProvider<SyncResult>((ref) async {
  return ref.read(syncEngineProvider).syncOnStartup();
});

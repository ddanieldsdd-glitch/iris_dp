import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import 'floor_plan_scope.dart';

/// Lo que dejó una restauración: lo que no se pudo devolver tal cual.
class PlanRestoreResult {
  /// Planos que entretanto se asignaron a otra planta: se quedan como están.
  final List<String> keptShots;

  /// Sets cuya localización ya no existe: vuelven sueltos.
  final List<String> orphanSets;

  const PlanRestoreResult({
    this.keptShots = const [],
    this.orphanSets = const [],
  });

  /// Aviso para el usuario, o nulo si todo volvió igual.
  String? get notice {
    final parts = [
      if (keptShots.isNotEmpty)
        '${_count(keptShots.length, 'plano', 'planos')} ya tenía'
            '${keptShots.length == 1 ? '' : 'n'} otra planta y se '
            'queda${keptShots.length == 1 ? '' : 'n'} como está'
            '${keptShots.length == 1 ? '' : 'n'} '
            '(${keptShots.join(', ')})',
      if (orphanSets.isNotEmpty)
        '${orphanSets.map((s) => '«$s»').join(', ')} vuelve'
            '${orphanSets.length == 1 ? '' : 'n'} sin localización',
    ];
    return parts.isEmpty ? null : '${parts.join('. ')}.';
  }
}

/// Qué perdería un borrado, para avisar antes de hacerlo.
class PlanDeletionImpact {
  final int sets;
  final int setups;

  /// Planos que se quedan sin planta: «2A», «2B»…
  final List<String> shots;

  const PlanDeletionImpact({
    this.sets = 0,
    this.setups = 0,
    this.shots = const [],
  });

  /// «2 sets, 3 esquemas de luz. 3 planos perderán su planta: 2A, 2B, 4C.»
  String describe() {
    final what = [
      if (sets > 0) _count(sets, 'set', 'sets'),
      if (setups > 0) _count(setups, 'esquema de luz', 'esquemas de luz'),
    ];
    final lines = [
      if (what.isNotEmpty) 'Se borran también ${what.join(' y ')}.',
      if (shots.isNotEmpty)
        '${_count(shots.length, 'plano perderá', 'planos perderán')} su '
            'planta (set, luz, cámaras y actores): ${_shortList(shots)}.',
      'Podrás recuperarlo desde la Papelera de plantas.',
    ];
    return lines.join(' ');
  }
}

String _shotLabel(Scene? scene, Shot shot) => scene == null
    ? 'Plano ${shot.number}'
    : 'Esc ${scene.number} · Plano ${shot.number}';

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

String _shortList(List<String> items) => items.length <= 6
    ? items.join(', ')
    : '${items.take(6).join(', ')} y ${items.length - 6} más';

/// Borra y vacía plantas guardando una foto en la papelera, y las devuelve.
///
/// Lo borrado se guarda entero (filas, plantas, cámaras de los planos y los
/// enlaces que se rompen) y al restaurar vuelve con los mismos ids si están
/// libres; si no, con ids nuevos y los enlaces rehechos.
class PlanTrashService {
  final AppDatabase db;

  PlanTrashService(this.db);

  /// Lo que hay en la papelera más tiempo que esto se borra de verdad.
  static const keepFor = Duration(days: 30);

  static const kindSite = 'site';
  static const kindSet = 'set';
  static const kindLightSetup = 'light_setup';
  static const kindPlanContents = 'plan_contents';

  // ─── Leer ──────────────────────────────────────────────────────────────

  Stream<List<PlanTrashEntry>> watch(int projectId) =>
      (db.select(db.planTrash)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
          .watch();

  /// Borra de verdad lo que lleva más de [keepFor] en la papelera.
  Future<void> purgeExpired(int projectId, {DateTime? now}) async {
    final limit = (now ?? DateTime.now()).subtract(keepFor);
    await (db.delete(db.planTrash)..where(
          (t) =>
              t.projectId.equals(projectId) &
              t.deletedAt.isSmallerThanValue(limit),
        ))
        .go();
  }

  Future<void> purge(int trashId) =>
      (db.delete(db.planTrash)..where((t) => t.id.equals(trashId))).go();

  Future<void> emptyTrash(int projectId) => (db.delete(
    db.planTrash,
  )..where((t) => t.projectId.equals(projectId))).go();

  // ─── Avisos ────────────────────────────────────────────────────────────

  Future<PlanDeletionImpact> impactOfSite(int siteId) async {
    final site = await db.getSiteById(siteId);
    if (site == null) return const PlanDeletionImpact();
    final scope = await _Scope.load(db, site.projectId);
    final setIds = scope.setIdsOfSite(siteId);
    final setupIds = scope.setupIdsOf(siteId: siteId, setIds: setIds);
    return PlanDeletionImpact(
      sets: setIds.length,
      setups: setupIds.length,
      shots: scope.shotLabels(scope.shotsOnSite(siteId, setIds)),
    );
  }

  Future<PlanDeletionImpact> impactOfSet(int setId) async {
    final set = await db.getLocationById(setId);
    if (set == null) return const PlanDeletionImpact();
    final scope = await _Scope.load(db, set.projectId);
    return PlanDeletionImpact(
      setups: scope.setupIdsOf(setIds: {setId}).length,
      shots: scope.shotLabels(scope.shotsOnSets({setId})),
    );
  }

  // ─── Borrar ────────────────────────────────────────────────────────────

  /// Borra la localización con todos sus sets y esquemas. Sus escenas y
  /// planos se quedan sin planta. Devuelve la entrada de la papelera.
  Future<int?> deleteSite(int siteId) async {
    final site = await db.getSiteById(siteId);
    if (site == null) return null;
    final scope = await _Scope.load(db, site.projectId);
    final setIds = scope.setIdsOfSite(siteId);
    final setupIds = scope.setupIdsOf(siteId: siteId, setIds: setIds);
    final fullShots = scope.shotsOnSite(siteId, setIds);
    final payload = await _snapshot(
      scope,
      siteIds: {siteId},
      setIds: setIds,
      setupIds: setupIds,
      fullShotIds: fullShots,
    );
    final impact = PlanDeletionImpact(
      sets: setIds.length,
      setups: setupIds.length,
      shots: scope.shotLabels(fullShots),
    );
    late int trashId;
    await db.transaction(() async {
      trashId = await _addEntry(
        site.projectId,
        kind: kindSite,
        label: 'Localización «${site.name}»',
        detail: _detail(impact),
        payload: payload,
      );
      await _apply(payload);
    });
    await db.touchProjectContent(site.projectId);
    return trashId;
  }

  /// Borra el set con sus esquemas de luz. Los planos que se rodaban en él
  /// pierden la planta: set, esquema, cámaras y actores.
  Future<int?> deleteSet(int setId) async {
    final set = await db.getLocationById(setId);
    if (set == null) return null;
    final scope = await _Scope.load(db, set.projectId);
    final setupIds = scope.setupIdsOf(setIds: {setId});
    final fullShots = scope.shotsOnSets({setId});
    final payload = await _snapshot(
      scope,
      setIds: {setId},
      setupIds: setupIds,
      fullShotIds: fullShots,
    );
    final impact = PlanDeletionImpact(
      setups: setupIds.length,
      shots: scope.shotLabels(fullShots),
    );
    late int trashId;
    await db.transaction(() async {
      trashId = await _addEntry(
        set.projectId,
        kind: kindSet,
        label: 'Set «${set.locationName}»',
        detail: _detail(impact),
        payload: payload,
      );
      await _apply(payload);
    });
    await db.touchProjectContent(set.projectId);
    return trashId;
  }

  /// Borra el esquema de luz. Los planos que lo usaban se quedan sin luz,
  /// con sus cámaras.
  Future<int?> deleteLightSetup(int setupId) async {
    final setup = await db.getLightSetupById(setupId);
    if (setup == null) return null;
    final scope = await _Scope.load(db, setup.projectId);
    final payload = await _snapshot(scope, setupIds: {setupId});
    late int trashId;
    await db.transaction(() async {
      trashId = await _addEntry(
        setup.projectId,
        kind: kindLightSetup,
        label: 'Esquema «${setup.name}»',
        detail: null,
        payload: payload,
      );
      await _apply(payload);
    });
    await db.touchProjectContent(setup.projectId);
    return trashId;
  }

  /// Vacía la planta para empezarla de cero; conserva el nombre, los planos
  /// asignados y la zona del set. Nulo si ya estaba vacía.
  Future<int?> clearPlan(FloorPlanScope scope, int id) async {
    final target = await _PlanTarget.load(db, scope, id);
    if (target == null || await target.isEmpty(db)) return null;
    final elements = scope == FloorPlanScope.shot
        ? await (db.select(
            db.cameraPlanElements,
          )..where((e) => e.shotId.equals(id))).get()
        : const <CameraPlanElement>[];
    final points = await _pathPointsOf(elements.map((e) => e.id).toSet());
    final drawing = await _drawingOf(target.projectId, scope, id);
    final images = await _imagesWhere(target.projectId, {
      '${scope.name}/$id',
    });
    final payload = <String, dynamic>{
      'v': 1,
      'plan': {
        'scope': scope.name,
        'id': id,
        'json': target.json,
        'overrides': target.overrides,
      },
      'elements': [for (final e in elements) e.toJson()],
      'pathPoints': [for (final p in points) p.toJson()],
      'drawings': [if (drawing != null) drawing.toJson()],
      'images': [for (final i in images) i.toJson()],
    };
    late int trashId;
    await db.transaction(() async {
      trashId = await _addEntry(
        target.projectId,
        kind: kindPlanContents,
        label: 'Planta de ${target.label}',
        detail: 'Vaciada',
        payload: payload,
      );
      await _applyClear(scope, id, payload);
    });
    await db.touchProjectContent(target.projectId);
    return trashId;
  }

  // ─── Restaurar ─────────────────────────────────────────────────────────

  Future<PlanRestoreResult> restore(int trashId) async {
    final entry = await (db.select(
      db.planTrash,
    )..where((t) => t.id.equals(trashId))).getSingleOrNull();
    if (entry == null) return const PlanRestoreResult();
    final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
    late PlanRestoreResult result;
    await db.transaction(() async {
      result = entry.kind == kindPlanContents
          ? await _restorePlan(payload)
          : await _restoreRows(payload);
      await purge(trashId);
    });
    await db.touchProjectContent(entry.projectId);
    return result;
  }

  // ─── Por dentro ────────────────────────────────────────────────────────

  String? _detail(PlanDeletionImpact impact) {
    final parts = [
      if (impact.sets > 0) _count(impact.sets, 'set', 'sets'),
      if (impact.setups > 0) _count(impact.setups, 'esquema', 'esquemas'),
      if (impact.shots.isNotEmpty)
        '${_count(impact.shots.length, 'plano', 'planos')} sin planta',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<int> _addEntry(
    int projectId, {
    required String kind,
    required String label,
    required String? detail,
    required Map<String, dynamic> payload,
  }) => db
      .into(db.planTrash)
      .insert(
        PlanTrashCompanion.insert(
          projectId: projectId,
          kind: kind,
          label: label,
          detail: Value(detail),
          payloadJson: jsonEncode(payload),
        ),
      );

  Future<List<CameraPathPoint>> _pathPointsOf(Set<int> elementIds) async {
    if (elementIds.isEmpty) return const [];
    return (db.select(
      db.cameraPathPoints,
    )..where((p) => p.elementId.isIn(elementIds))).get();
  }

  Future<ProjectAnnotationDocument?> _drawingOf(
    int projectId,
    FloorPlanScope scope,
    int id,
  ) =>
      (db.select(db.projectAnnotationDocuments)..where(
            (d) =>
                d.projectId.equals(projectId) &
                d.targetType.equals(_drawingType(scope)) &
                d.targetId.equals('$id'),
          ))
          .getSingleOrNull();

  static String _drawingType(FloorPlanScope scope) => switch (scope) {
    FloorPlanScope.site => 'camera_plan_site',
    FloorPlanScope.set => 'camera_plan_set',
    FloorPlanScope.lightSetup => 'camera_plan_light_setup',
    FloorPlanScope.shot => 'camera_plan_shot',
  };

  /// Foto de lo que se va a borrar y de los enlaces que se rompen.
  Future<Map<String, dynamic>> _snapshot(
    _Scope scope, {
    Set<int> siteIds = const {},
    Set<int> setIds = const {},
    Set<int> setupIds = const {},
    Set<int> fullShotIds = const {},
  }) async {
    final elements = fullShotIds.isEmpty
        ? const <CameraPlanElement>[]
        : await (db.select(
            db.cameraPlanElements,
          )..where((e) => e.shotId.isIn(fullShotIds))).get();
    final points = await _pathPointsOf(elements.map((e) => e.id).toSet());
    final locationImages = setIds.isEmpty
        ? const <LocationImage>[]
        : await (db.select(
            db.locationImages,
          )..where((i) => i.locationId.isIn(setIds))).get();
    final siteImages = siteIds.isEmpty
        ? const <SiteImage>[]
        : await (db.select(
            db.siteImages,
          )..where((i) => i.siteId.isIn(siteIds))).get();

    final drawingKeys = {
      for (final id in siteIds) 'camera_plan_site/$id',
      for (final id in setIds) 'camera_plan_set/$id',
      for (final id in setupIds) 'camera_plan_light_setup/$id',
      for (final id in fullShotIds) 'camera_plan_shot/$id',
    };
    final drawings = (await (db.select(
      db.projectAnnotationDocuments,
    )..where((d) => d.projectId.equals(scope.projectId))).get()).where(
      (d) => drawingKeys.contains('${d.targetType}/${d.targetId}'),
    );

    final imageKeys = {
      for (final id in siteIds) 'site/$id',
      for (final id in setIds) 'set/$id',
      for (final id in setupIds) 'lightSetup/$id',
      for (final id in fullShotIds) 'shot/$id',
    };
    final images = await _imagesWhere(scope.projectId, imageKeys);

    final bibleLinks = setupIds.isEmpty
        ? const <LightingSetup>[]
        : await (db.select(
            db.lightingSetups,
          )..where((l) => l.planSetupId.isIn(setupIds))).get();

    return {
      'v': 1,
      'sites': [
        for (final s in scope.sites)
          if (siteIds.contains(s.id)) s.toJson(),
      ],
      'sets': [
        for (final s in scope.sets)
          if (setIds.contains(s.id)) s.toJson(),
      ],
      'setups': [
        for (final s in scope.setups)
          if (setupIds.contains(s.id)) s.toJson(),
      ],
      'locationImages': [for (final i in locationImages) i.toJson()],
      'siteImages': [for (final i in siteImages) i.toJson()],
      'elements': [for (final e in elements) e.toJson()],
      'pathPoints': [for (final p in points) p.toJson()],
      'drawings': [for (final d in drawings) d.toJson()],
      'images': [for (final i in images) i.toJson()],
      // Enlaces que se rompen, con lo que valían.
      'scenes': [
        for (final s in scope.scenes)
          if (setIds.contains(s.locationId) ||
              siteIds.contains(s.locationSiteId))
            {
              'id': s.id,
              if (setIds.contains(s.locationId)) 'set': s.locationId,
              if (siteIds.contains(s.locationSiteId)) 'site': s.locationSiteId,
            },
      ],
      'shots': [
        for (final s in scope.shots)
          if (fullShotIds.contains(s.id) ||
              setupIds.contains(s.lightSetupId) ||
              setIds.contains(s.locationBasePlanId))
            {
              'id': s.id,
              'label': scope.shotLabel(s),
              'full': fullShotIds.contains(s.id),
              if (setIds.contains(s.locationBasePlanId) ||
                  fullShotIds.contains(s.id))
                'set': s.locationBasePlanId,
              if (setupIds.contains(s.lightSetupId) ||
                  fullShotIds.contains(s.id))
                'setup': s.lightSetupId,
              if (fullShotIds.contains(s.id))
                'overrides': s.lightOverridesJson,
            },
      ],
      'bible': [
        for (final l in bibleLinks) {'id': l.id, 'setup': l.planSetupId},
      ],
      // Zonas que el set ocupaba en el plano de su localización.
    };
  }

  /// Hace el borrado que describe [payload].
  Future<void> _apply(Map<String, dynamic> payload) async {
    final siteIds = _ids(payload['sites']);
    final setIds = _ids(payload['sets']);
    final setupIds = _ids(payload['setups']);
    final elementIds = _ids(payload['elements']);

    for (final row in _maps(payload['scenes'])) {
      await (db.update(
        db.scenes,
      )..where((s) => s.id.equals(row['id'] as int))).write(
        ScenesCompanion(
          locationId: row.containsKey('set')
              ? const Value(null)
              : const Value.absent(),
          locationSiteId: row.containsKey('site')
              ? const Value(null)
              : const Value.absent(),
        ),
      );
    }
    for (final row in _maps(payload['shots'])) {
      await (db.update(
        db.shots,
      )..where((s) => s.id.equals(row['id'] as int))).write(
        ShotsCompanion(
          locationBasePlanId: row.containsKey('set')
              ? const Value(null)
              : const Value.absent(),
          lightSetupId: row.containsKey('setup')
              ? const Value(null)
              : const Value.absent(),
          lightOverridesJson: row['full'] == true
              ? const Value(null)
              : const Value.absent(),
        ),
      );
    }
    for (final row in _maps(payload['bible'])) {
      await (db.update(db.lightingSetups)
            ..where((l) => l.id.equals(row['id'] as int)))
          .write(const LightingSetupsCompanion(planSetupId: Value(null)));
    }
    if (elementIds.isNotEmpty) {
      await (db.delete(
        db.cameraPathPoints,
      )..where((p) => p.elementId.isIn(elementIds))).go();
      await (db.delete(
        db.cameraPlanElements,
      )..where((e) => e.id.isIn(elementIds))).go();
    }
    final drawingIds = _ids(payload['drawings']);
    if (drawingIds.isNotEmpty) {
      await (db.delete(
        db.projectAnnotationDocuments,
      )..where((d) => d.id.isIn(drawingIds))).go();
    }
    final imageIds = _ids(payload['images']);
    if (imageIds.isNotEmpty) {
      await (db.delete(
        db.planImages,
      )..where((i) => i.id.isIn(imageIds))).go();
    }
    if (setIds.isNotEmpty) {
      await (db.delete(
        db.locationImages,
      )..where((i) => i.locationId.isIn(setIds))).go();
    }
    if (siteIds.isNotEmpty) {
      await (db.delete(
        db.siteImages,
      )..where((i) => i.siteId.isIn(siteIds))).go();
    }
    if (setupIds.isNotEmpty) {
      await (db.delete(
        db.lightSetups,
      )..where((s) => s.id.isIn(setupIds))).go();
    }
    if (setIds.isNotEmpty) {
      await (db.delete(
        db.locationBasePlans,
      )..where((s) => s.id.isIn(setIds))).go();
    }
    if (siteIds.isNotEmpty) {
      await (db.delete(
        db.locationSites,
      )..where((s) => s.id.isIn(siteIds))).go();
    }
  }

  Future<void> _applyClear(
    FloorPlanScope scope,
    int id,
    Map<String, dynamic> payload,
  ) async {
    switch (scope) {
      case FloorPlanScope.site:
        await (db.update(db.locationSites)..where((s) => s.id.equals(id)))
            .write(const LocationSitesCompanion(floorPlanJson: Value(null)));
      case FloorPlanScope.set:
        await (db.update(db.locationBasePlans)..where((s) => s.id.equals(id)))
            .write(
              const LocationBasePlansCompanion(floorPlanJson: Value(null)),
            );
      case FloorPlanScope.lightSetup:
        await (db.update(db.lightSetups)..where((s) => s.id.equals(id)))
            .write(const LightSetupsCompanion(planJson: Value(null)));
      case FloorPlanScope.shot:
        await (db.update(db.shots)..where((s) => s.id.equals(id))).write(
          const ShotsCompanion(lightOverridesJson: Value(null)),
        );
    }
    final elementIds = _ids(payload['elements']);
    if (elementIds.isNotEmpty) {
      await (db.delete(
        db.cameraPathPoints,
      )..where((p) => p.elementId.isIn(elementIds))).go();
      await (db.delete(
        db.cameraPlanElements,
      )..where((e) => e.id.isIn(elementIds))).go();
    }
    final drawingIds = _ids(payload['drawings']);
    if (drawingIds.isNotEmpty) {
      await (db.delete(
        db.projectAnnotationDocuments,
      )..where((d) => d.id.isIn(drawingIds))).go();
    }
    final imageIds = _ids(payload['images']);
    if (imageIds.isNotEmpty) {
      await (db.delete(
        db.planImages,
      )..where((i) => i.id.isIn(imageIds))).go();
    }
  }

  /// Devuelve una planta vaciada. Si entretanto se empezó de nuevo, lo
  /// nuevo va antes a la papelera: no se pierde nada.
  Future<PlanRestoreResult> _restorePlan(Map<String, dynamic> payload) async {
    final plan = Map<String, dynamic>.from(payload['plan'] as Map);
    final scope = FloorPlanScope.values.byName(plan['scope'] as String);
    final id = plan['id'] as int;
    final target = await _PlanTarget.load(db, scope, id);
    if (target == null) return const PlanRestoreResult();
    if (!await target.isEmpty(db)) await clearPlan(scope, id);

    final json = plan['json'] as String?;
    switch (scope) {
      case FloorPlanScope.site:
        await (db.update(db.locationSites)..where((s) => s.id.equals(id)))
            .write(LocationSitesCompanion(floorPlanJson: Value(json)));
      case FloorPlanScope.set:
        await (db.update(db.locationBasePlans)..where((s) => s.id.equals(id)))
            .write(LocationBasePlansCompanion(floorPlanJson: Value(json)));
      case FloorPlanScope.lightSetup:
        await (db.update(db.lightSetups)..where((s) => s.id.equals(id)))
            .write(LightSetupsCompanion(planJson: Value(json)));
      case FloorPlanScope.shot:
        await (db.update(db.shots)..where((s) => s.id.equals(id))).write(
          ShotsCompanion(
            lightOverridesJson: Value(plan['overrides'] as String?),
          ),
        );
    }
    final ids = _IdMaps();
    await _insertElements(payload, ids, liveShots: {id});
    await _insertDrawings(payload, ids);
    await _insertImages(payload, ids, liveShots: {id});
    return const PlanRestoreResult();
  }

  /// Devuelve lo borrado de una localización, un set o un esquema.
  Future<PlanRestoreResult> _restoreRows(Map<String, dynamic> payload) async {
    final ids = _IdMaps();
    final orphanSets = <String>[];
    final keptShots = <String>[];

    for (final json in _maps(payload['sites'])) {
      final row = LocationSite.fromJson(json);
      final existing = await _siteByUid(row.uid);
      if (existing != null) {
        ids.sites[row.id] = existing.id;
        continue;
      }
      final free = await db.getSiteById(row.id) == null;
      ids.sites[row.id] = free
          ? await db.into(db.locationSites).insert(row)
          : await db
                .into(db.locationSites)
                .insert(row.toCompanion(false).copyWith(id: const Value.absent()));
    }

    for (final json in _maps(payload['sets'])) {
      var row = LocationBasePlan.fromJson(json);
      final existing = await _setByUid(row.uid);
      if (existing != null) {
        ids.sets[row.id] = existing.id;
        continue;
      }
      if (row.siteId != null) {
        final siteId = await ids.site(db, row.siteId!);
        if (siteId == null) orphanSets.add(row.locationName);
        row = row.copyWith(
          siteId: Value(siteId),
          sitePlacementJson: Value(siteId == null ? null : row.sitePlacementJson),
        );
      }
      final free = await db.getLocationById(row.id) == null;
      ids.sets[row.id] = free
          ? await db.into(db.locationBasePlans).insert(row)
          : await db
                .into(db.locationBasePlans)
                .insert(row.toCompanion(false).copyWith(id: const Value.absent()));
    }

    for (final json in _maps(payload['setups'])) {
      var row = LightSetup.fromJson(json);
      final existing = await _setupByUid(row.uid);
      if (existing != null) {
        ids.setups[row.id] = existing.id;
        continue;
      }
      row = row.copyWith(
        locationSiteId: Value(
          row.locationSiteId == null
              ? null
              : await ids.site(db, row.locationSiteId!),
        ),
        locationBasePlanId: Value(
          row.locationBasePlanId == null
              ? null
              : await ids.set(db, row.locationBasePlanId!),
        ),
      );
      final free = await db.getLightSetupById(row.id) == null;
      ids.setups[row.id] = free
          ? await db.into(db.lightSetups).insert(row)
          : await db
                .into(db.lightSetups)
                .insert(row.toCompanion(false).copyWith(id: const Value.absent()));
    }

    for (final json in _maps(payload['locationImages'])) {
      final row = LocationImage.fromJson(json);
      final setId = await ids.set(db, row.locationId);
      if (setId == null) continue;
      await db
          .into(db.locationImages)
          .insert(
            row
                .toCompanion(false)
                .copyWith(id: const Value.absent(), locationId: Value(setId)),
          );
    }
    for (final json in _maps(payload['siteImages'])) {
      final row = SiteImage.fromJson(json);
      final siteId = await ids.site(db, row.siteId);
      if (siteId == null) continue;
      await db
          .into(db.siteImages)
          .insert(
            row
                .toCompanion(false)
                .copyWith(id: const Value.absent(), siteId: Value(siteId)),
          );
    }

    for (final row in _maps(payload['scenes'])) {
      final scene = await (db.select(
        db.scenes,
      )..where((s) => s.id.equals(row['id'] as int))).getSingleOrNull();
      if (scene == null) continue;
      final setId = row['set'] == null
          ? null
          : await ids.set(db, row['set'] as int);
      final siteId = row['site'] == null
          ? null
          : await ids.site(db, row['site'] as int);
      await (db.update(db.scenes)..where((s) => s.id.equals(scene.id))).write(
        ScenesCompanion(
          locationId: setId != null && scene.locationId == null
              ? Value(setId)
              : const Value.absent(),
          locationSiteId: siteId != null && scene.locationSiteId == null
              ? Value(siteId)
              : const Value.absent(),
        ),
      );
    }

    // Planos: solo se devuelven los que siguen sin planta.
    final liveShots = <int>{};
    for (final row in _maps(payload['shots'])) {
      final shot = await (db.select(
        db.shots,
      )..where((s) => s.id.equals(row['id'] as int))).getSingleOrNull();
      if (shot == null) continue;
      final full = row['full'] == true;
      final hasElements =
          full &&
          await (db.select(db.cameraPlanElements)
                    ..where((e) => e.shotId.equals(shot.id))
                    ..limit(1))
                  .getSingleOrNull() !=
              null;
      final moved =
          (row.containsKey('set') && shot.locationBasePlanId != null) ||
          (row.containsKey('setup') && shot.lightSetupId != null) ||
          hasElements;
      if (moved) {
        keptShots.add(row['label'] as String? ?? '${shot.number}');
        continue;
      }
      if (full) liveShots.add(shot.id);
      final setId = row['set'] == null
          ? null
          : await ids.set(db, row['set'] as int);
      final setupId = row['setup'] == null
          ? null
          : await ids.setup(db, row['setup'] as int);
      await (db.update(db.shots)..where((s) => s.id.equals(shot.id))).write(
        ShotsCompanion(
          locationBasePlanId: setId != null
              ? Value(setId)
              : const Value.absent(),
          lightSetupId: setupId != null ? Value(setupId) : const Value.absent(),
          lightOverridesJson: full && row['overrides'] != null
              ? Value(row['overrides'] as String)
              : const Value.absent(),
        ),
      );
    }

    for (final row in _maps(payload['bible'])) {
      final setupId = await ids.setup(db, row['setup'] as int);
      if (setupId == null) continue;
      await (db.update(db.lightingSetups)..where(
            (l) => l.id.equals(row['id'] as int) & l.planSetupId.isNull(),
          ))
          .write(LightingSetupsCompanion(planSetupId: Value(setupId)));
    }

    await _insertElements(payload, ids, liveShots: liveShots);
    await _insertDrawings(payload, ids, liveShots: liveShots);
    await _insertImages(payload, ids, liveShots: liveShots);
    return PlanRestoreResult(keptShots: keptShots, orphanSets: orphanSets);
  }

  Future<void> _insertElements(
    Map<String, dynamic> payload,
    _IdMaps ids, {
    required Set<int> liveShots,
  }) async {
    final elementIds = <int, int>{};
    for (final json in _maps(payload['elements'])) {
      final row = CameraPlanElement.fromJson(json);
      if (!liveShots.contains(row.shotId)) continue;
      final free =
          await (db.select(
            db.cameraPlanElements,
          )..where((e) => e.id.equals(row.id))).getSingleOrNull() ==
          null;
      elementIds[row.id] = free
          ? await db.into(db.cameraPlanElements).insert(row)
          : await db
                .into(db.cameraPlanElements)
                .insert(row.toCompanion(false).copyWith(id: const Value.absent()));
    }
    for (final json in _maps(payload['pathPoints'])) {
      final row = CameraPathPoint.fromJson(json);
      final elementId = elementIds[row.elementId];
      if (elementId == null) continue;
      await db
          .into(db.cameraPathPoints)
          .insert(
            row
                .toCompanion(false)
                .copyWith(id: const Value.absent(), elementId: Value(elementId)),
          );
    }
  }

  Future<void> _insertDrawings(
    Map<String, dynamic> payload,
    _IdMaps ids, {
    Set<int>? liveShots,
  }) async {
    for (final json in _maps(payload['drawings'])) {
      final row = ProjectAnnotationDocument.fromJson(json);
      final oldId = int.tryParse(row.targetId);
      if (oldId == null) continue;
      final newId = switch (row.targetType) {
        'camera_plan_site' => await ids.site(db, oldId),
        'camera_plan_set' => await ids.set(db, oldId),
        'camera_plan_light_setup' => await ids.setup(db, oldId),
        'camera_plan_shot' =>
          liveShots == null || liveShots.contains(oldId) ? oldId : null,
        _ => null,
      };
      if (newId == null) continue;
      await db
          .into(db.projectAnnotationDocuments)
          .insert(
            row
                .toCompanion(false)
                .copyWith(id: const Value.absent(), targetId: Value('$newId')),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  /// Imágenes de la planta en las capas `tipo/id` de [keys].
  Future<List<PlanImage>> _imagesWhere(int projectId, Set<String> keys) async {
    if (keys.isEmpty) return const [];
    final rows = await (db.select(
      db.planImages,
    )..where((i) => i.projectId.equals(projectId))).get();
    return [
      for (final r in rows)
        if (keys.contains('${r.targetType}/${r.targetId}')) r,
    ];
  }

  Future<void> _insertImages(
    Map<String, dynamic> payload,
    _IdMaps ids, {
    required Set<int> liveShots,
  }) async {
    for (final json in _maps(payload['images'])) {
      final row = PlanImage.fromJson(json);
      final targetId = switch (row.targetType) {
        'site' => await ids.site(db, row.targetId),
        'set' => await ids.set(db, row.targetId),
        'lightSetup' => await ids.setup(db, row.targetId),
        'shot' => liveShots.contains(row.targetId) ? row.targetId : null,
        _ => null,
      };
      if (targetId == null) continue;
      final free = await (db.select(
        db.planImages,
      )..where((i) => i.id.equals(row.id))).getSingleOrNull() == null;
      final fixed = row.copyWith(targetId: targetId);
      if (free) {
        await db.into(db.planImages).insert(fixed);
      } else {
        await db
            .into(db.planImages)
            .insert(fixed.toCompanion(false).copyWith(id: const Value.absent()));
      }
    }
  }

  Future<LocationSite?> _siteByUid(String? uid) async => uid == null
      ? null
      : (db.select(db.locationSites)
              ..where((s) => s.uid.equals(uid))
              ..limit(1))
            .getSingleOrNull();

  Future<LocationBasePlan?> _setByUid(String? uid) async => uid == null
      ? null
      : (db.select(db.locationBasePlans)
              ..where((s) => s.uid.equals(uid))
              ..limit(1))
            .getSingleOrNull();

  Future<LightSetup?> _setupByUid(String? uid) async => uid == null
      ? null
      : (db.select(db.lightSetups)
              ..where((s) => s.uid.equals(uid))
              ..limit(1))
            .getSingleOrNull();

  static List<Map<String, dynamic>> _maps(Object? list) => [
    for (final row in list as List? ?? const [])
      Map<String, dynamic>.from(row as Map),
  ];

  static Set<int> _ids(Object? list) => {
    for (final row in _maps(list)) row['id'] as int,
  };
}

/// Ids viejos → ids con los que han vuelto. Lo que no se borró sigue con el
/// suyo si aún existe.
class _IdMaps {
  final sites = <int, int>{};
  final sets = <int, int>{};
  final setups = <int, int>{};

  Future<int?> site(AppDatabase db, int id) async =>
      sites[id] ?? (await db.getSiteById(id))?.id;

  Future<int?> set(AppDatabase db, int id) async =>
      sets[id] ?? (await db.getLocationById(id))?.id;

  Future<int?> setup(AppDatabase db, int id) async =>
      setups[id] ?? (await db.getLightSetupById(id))?.id;
}

/// Todo lo del proyecto que hace falta para saber qué arrastra un borrado.
class _Scope {
  final int projectId;
  final List<LocationSite> sites;
  final List<LocationBasePlan> sets;
  final List<LightSetup> setups;
  final List<Scene> scenes;
  final List<Shot> shots;
  final Map<int, Scene> sceneById;

  _Scope(
    this.projectId,
    this.sites,
    this.sets,
    this.setups,
    this.scenes,
    this.shots,
  ) : sceneById = {for (final s in scenes) s.id: s};

  static Future<_Scope> load(AppDatabase db, int projectId) async => _Scope(
    projectId,
    await (db.select(
      db.locationSites,
    )..where((s) => s.projectId.equals(projectId))).get(),
    await (db.select(
      db.locationBasePlans,
    )..where((s) => s.projectId.equals(projectId))).get(),
    await db.getLightSetupsForProject(projectId),
    await (db.select(
      db.scenes,
    )..where((s) => s.projectId.equals(projectId))).get(),
    await db.getShotsForProject(projectId),
  );

  Set<int> setIdsOfSite(int siteId) => {
    for (final s in sets)
      if (s.siteId == siteId) s.id,
  };

  Set<int> setupIdsOf({int? siteId, Set<int> setIds = const {}}) => {
    for (final s in setups)
      if ((siteId != null && s.locationSiteId == siteId) ||
          setIds.contains(s.locationBasePlanId))
        s.id,
  };

  /// El set donde se rueda el plano: el suyo o el de su escena.
  int? effectiveSet(Shot shot) =>
      shot.locationBasePlanId ?? sceneById[shot.sceneId]?.locationId;

  Set<int> shotsOnSets(Set<int> setIds) => {
    for (final s in shots)
      if (setIds.contains(effectiveSet(s))) s.id,
  };

  /// Planos de la localización: los de sus sets y los que solo usan su
  /// plano maestro.
  Set<int> shotsOnSite(int siteId, Set<int> setIds) => {
    for (final s in shots)
      if (setIds.contains(effectiveSet(s)) ||
          (effectiveSet(s) == null &&
              sceneById[s.sceneId]?.locationSiteId == siteId))
        s.id,
  };

  /// «Esc 2 · Plano 3», como en el resto de la planta.
  String shotLabel(Shot shot) => _shotLabel(sceneById[shot.sceneId], shot);

  List<String> shotLabels(Set<int> ids) => [
    for (final s in shots)
      if (ids.contains(s.id)) shotLabel(s),
  ];
}

/// La planta que se vacía: su JSON y su nombre.
class _PlanTarget {
  final int projectId;
  final String label;
  final String? json;
  final String? overrides;
  final FloorPlanScope scope;
  final int id;

  _PlanTarget(
    this.projectId,
    this.label,
    this.json,
    this.scope,
    this.id, {
    this.overrides,
  });

  static Future<_PlanTarget?> load(
    AppDatabase db,
    FloorPlanScope scope,
    int id,
  ) async {
    switch (scope) {
      case FloorPlanScope.site:
        final s = await db.getSiteById(id);
        return s == null
            ? null
            : _PlanTarget(s.projectId, '«${s.name}»', s.floorPlanJson, scope, id);
      case FloorPlanScope.set:
        final s = await db.getLocationById(id);
        return s == null
            ? null
            : _PlanTarget(
                s.projectId,
                '«${s.locationName}»',
                s.floorPlanJson,
                scope,
                id,
              );
      case FloorPlanScope.lightSetup:
        final s = await db.getLightSetupById(id);
        return s == null
            ? null
            : _PlanTarget(s.projectId, '«${s.name}»', s.planJson, scope, id);
      case FloorPlanScope.shot:
        final s = await (db.select(
          db.shots,
        )..where((s) => s.id.equals(id))).getSingleOrNull();
        if (s == null) return null;
        final scene = await (db.select(
          db.scenes,
        )..where((c) => c.id.equals(s.sceneId))).getSingleOrNull();
        return _PlanTarget(
          s.projectId,
          _shotLabel(scene, s),
          null,
          scope,
          id,
          overrides: s.lightOverridesJson,
        );
    }
  }

  Future<bool> isEmpty(AppDatabase db) async {
    if (json != null && json!.trim().isNotEmpty) return false;
    if (overrides != null && overrides!.trim().isNotEmpty) return false;
    if (scope == FloorPlanScope.shot) {
      final any = await (db.select(db.cameraPlanElements)
            ..where((e) => e.shotId.equals(id))
            ..limit(1))
          .getSingleOrNull();
      if (any != null) return false;
    }
    final drawing =
        await (db.select(db.projectAnnotationDocuments)..where(
              (d) =>
                  d.projectId.equals(projectId) &
                  d.targetType.equals(PlanTrashService._drawingType(scope)) &
                  d.targetId.equals('$id'),
            ))
            .getSingleOrNull();
    if (drawing != null) return false;
    final image = await (db.select(db.planImages)
          ..where(
            (i) =>
                i.projectId.equals(projectId) &
                i.targetType.equals(scope.name) &
                i.targetId.equals(id),
          )
          ..limit(1))
        .getSingleOrNull();
    return image == null;
  }
}

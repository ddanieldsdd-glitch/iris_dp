import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../utils/media_storage.dart';
import '../utils/scene_color.dart';
import '../utils/scene_format.dart';
import 'seed_data.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  ProjectGroups, Projects, Scenes, Shots,
  ShotReferences, CameraPlanElements, CameraPathPoints, LocationSites,
  LocationBasePlans,
  LocationImages,
  SiteImages,
  Cameras, Lenses, Lights, ProjectEquipment,
  LookBibles, ProjectAnnotatedPdfs,
  VisualBibles, VisualBibleColorBlocks, VisualBibleLocationRefs, MoodboardImages,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedEquipmentCatalog();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(projects, projects.scriptFilePath);
            await m.addColumn(projects, projects.scriptFileName);
            await m.addColumn(scenes, scenes.sourceStartIndex);
          }
          if (from < 3) {
            await m.addColumn(scenes, scenes.locationId);
            await m.addColumn(locationBasePlans, locationBasePlans.description);
            await m.createTable(locationImages);
          }
          if (from < 4) {
            await m.createTable(locationSites);
            await m.addColumn(locationBasePlans, locationBasePlans.siteId);
          }
          if (from < 5) {
            await m.addColumn(scenes, scenes.locationSiteId);
            await _wrapOrphanSetsInSites();
            await _backfillSceneLocationSites();
          }
          if (from < 6) {
            await m.createTable(siteImages);
          }
          if (from < 7) {
            await _ensureDefaultSetsForAllSites();
          }
          if (from < 8) {
            await m.addColumn(locationSites, locationSites.floorPlanJson);
            await m.addColumn(locationBasePlans, locationBasePlans.floorPlanJson);
          }
          if (from < 9) {
            await m.createTable(cameras);
            await m.createTable(lenses);
            await m.createTable(lights);
            await m.createTable(projectEquipment);
            await _seedEquipmentCatalog();
          }
          if (from < 10) {
            await m.addColumn(locationSites, locationSites.scanPath);
            await m.addColumn(locationSites, locationSites.scanSource);
            await m.addColumn(locationSites, locationSites.scanMetadataJson);
            await m.addColumn(locationBasePlans, locationBasePlans.scanPath);
            await m.addColumn(locationBasePlans, locationBasePlans.scanSource);
            await m.addColumn(
              locationBasePlans,
              locationBasePlans.scanMetadataJson,
            );
          }
          if (from < 11) {
            await m.addColumn(
              cameraPlanElements,
              cameraPlanElements.externalMappingJson,
            );
          }
          if (from < 12) {
            await m.createTable(lookBibles);
            await m.createTable(projectAnnotatedPdfs);
          }
          if (from < 13) {
            await m.createTable(visualBibles);
            await m.createTable(visualBibleColorBlocks);
            await m.createTable(visualBibleLocationRefs);
            await m.createTable(moodboardImages);
            await _migrateLookBiblesToVisualBibles();
          }
        },
      );

  Future<void> _seedEquipmentCatalog() async {
    final existing = await select(cameras).get();
    if (existing.isNotEmpty) return;

    for (final c in kSeedCameras) {
      await into(cameras).insert(CamerasCompanion.insert(
        brand: c.brand,
        model: c.model,
        sensorWidthMm: c.sensorW,
        sensorHeightMm: c.sensorH,
      ));
    }
    for (final l in kSeedLenses) {
      await into(lenses).insert(LensesCompanion.insert(
        brand: l.brand,
        model: l.model,
        focalLength: l.focalLength,
        focalMin: Value(l.focalMin),
        focalMax: Value(l.focalMax),
        minTStop: l.minTStop,
        formatCoverage: l.formatCoverage,
      ));
    }
    for (final light in kSeedLights) {
      await into(lights).insert(LightsCompanion.insert(
        brand: light.brand,
        model: light.model,
        lightType: light.type,
        powerW: light.powerW,
        colorTempMin: light.cMin,
        colorTempMax: light.cMax,
        isLukaCompatible: Value(light.luka),
        lukaFixtureId: Value(light.lukaFixtureId),
      ));
    }
  }

  /// Cada localización debe tener al menos un set (mismo nombre que el sitio).
  Future<void> _ensureDefaultSetsForAllSites() async {
    final sites = await select(locationSites).get();
    for (final site in sites) {
      await ensureDefaultSetForSite(projectId: site.projectId, site: site);
    }
  }

  Future<void> _wrapOrphanSetsInSites() async {
    final orphanSets = await (select(locationBasePlans)
          ..where((l) => l.siteId.isNull()))
        .get();
    for (final set in orphanSets) {
      final sites = await (select(locationSites)
            ..where((s) => s.projectId.equals(set.projectId)))
          .get();
      final siteId = await insertSite(LocationSitesCompanion.insert(
        projectId: set.projectId,
        name: set.locationName,
        description: Value(set.description),
        notes: Value(set.notes),
        sortOrder: Value(sites.length),
      ));
      await updateLocation(set.copyWith(siteId: Value(siteId)));
    }
  }

  Future<void> _backfillSceneLocationSites() async {
    final sceneList = await select(scenes).get();
    for (final scene in sceneList) {
      if (scene.locationSiteId != null) continue;
      int? siteId;
      if (scene.locationId != null) {
        final set = await getLocationById(scene.locationId!);
        siteId = set?.siteId;
      }
      if (siteId == null && scene.locationPureName.isNotEmpty) {
        final site = await findSiteByName(
          scene.projectId,
          scene.locationPureName,
        );
        siteId = site?.id;
      }
      if (siteId != null) {
        await update(scenes).replace(
          scene.copyWith(locationSiteId: Value(siteId)),
        );
      }
    }
  }

  // ── Grupos ─────────────────────────────────────
  Future<List<ProjectGroup>> getAllGroups() =>
      (select(projectGroups)..orderBy([(g) => OrderingTerm.asc(g.sortOrder)])).get();

  Stream<List<ProjectGroup>> watchAllGroups() =>
      (select(projectGroups)..orderBy([(g) => OrderingTerm.asc(g.sortOrder)])).watch();

  Future<int> insertGroup(ProjectGroupsCompanion g) => into(projectGroups).insert(g);
  Future<bool> updateGroup(ProjectGroup g) => update(projectGroups).replace(g);
  Future<int> deleteGroup(int id) =>
      (delete(projectGroups)..where((g) => g.id.equals(id))).go();

  // ── Proyectos ─────────────────────────────────
  Stream<List<Project>> watchProjects() =>
      (select(projects)..orderBy([(p) => OrderingTerm.asc(p.sortOrder)])).watch();

  Stream<List<Project>> watchProjectsByGroup(int? groupId) {
    return (select(projects)
      ..where((p) => groupId == null ? p.groupId.isNull() : p.groupId.equals(groupId))
      ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .watch();
  }

  Future<int> insertProject(ProjectsCompanion project) => into(projects).insert(project);
  Future<bool> updateProject(Project project) => update(projects).replace(project);
  Future<int> deleteProject(int id) async {
    await deleteProjectFully(id);
    return 1;
  }

  /// Elimina proyecto, datos relacionados y archivos en disco.
  Future<void> deleteProjectFully(int id) async {
    await transaction(() async {
      final projectShots = await (select(shots)
            ..where((s) => s.projectId.equals(id)))
          .get();
      for (final shot in projectShots) {
        await (delete(shotReferences)..where((r) => r.shotId.equals(shot.id)))
            .go();
      }
      await (delete(shots)..where((s) => s.projectId.equals(id))).go();
      await (delete(scenes)..where((s) => s.projectId.equals(id))).go();
      await (delete(projectEquipment)..where((e) => e.projectId.equals(id)))
          .go();

      final sets = await (select(locationBasePlans)
            ..where((l) => l.projectId.equals(id)))
          .get();
      for (final set in sets) {
        await (delete(locationImages)..where((i) => i.locationId.equals(set.id)))
            .go();
      }
      await (delete(locationBasePlans)..where((l) => l.projectId.equals(id))).go();

      final sites = await (select(locationSites)
            ..where((s) => s.projectId.equals(id)))
          .get();
      for (final site in sites) {
        await (delete(siteImages)..where((i) => i.siteId.equals(site.id))).go();
      }
      await (delete(locationSites)..where((s) => s.projectId.equals(id))).go();
      await (delete(projects)..where((p) => p.id.equals(id))).go();
    });
    await MediaStorage.deleteProjectDirectory(id);
  }

  Future<Project?> getProject(int id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  // Duplicar proyecto: copia escenas, planos, localizaciones e imágenes.
  Future<int> duplicateProject(int sourceId) async {
    final source = await getProject(sourceId);
    if (source == null) return -1;

    final newId = await insertProject(ProjectsCompanion.insert(
      name: '${source.name} (copia)',
      director: Value(source.director),
      description: Value(source.description),
      clientName: Value(source.clientName),
      status: Value(source.status),
      iconCode: Value(source.iconCode),
      groupId: Value(source.groupId),
      scriptFileName: Value(source.scriptFileName),
    ));

    if (source.scriptFilePath != null) {
      final scriptPath = await MediaStorage.duplicateScriptFile(
        sourceProjectId: sourceId,
        destProjectId: newId,
        sourcePath: source.scriptFilePath,
      );
      if (scriptPath != null) {
        final created = (await getProject(newId))!;
        await updateProject(created.copyWith(
          scriptFilePath: Value(scriptPath),
          scriptFileName: Value(source.scriptFileName),
        ));
      }
    }

    final siteIdMap = <int, int>{};
    final sourceSites = await (select(locationSites)
          ..where((s) => s.projectId.equals(sourceId)))
        .get();
    for (final site in sourceSites) {
      final newSiteId = await insertSite(LocationSitesCompanion.insert(
        projectId: newId,
        name: site.name,
        description: Value(site.description),
        notes: Value(site.notes),
        floorPlanJson: Value(site.floorPlanJson),
        scanPath: Value(site.scanPath),
        scanSource: Value(site.scanSource),
        scanMetadataJson: Value(site.scanMetadataJson),
        sortOrder: Value(site.sortOrder),
      ));
      siteIdMap[site.id] = newSiteId;

      final siteImagesList = await (select(siteImages)
            ..where((i) => i.siteId.equals(site.id)))
          .get();
      for (final img in siteImagesList) {
        final newPath = await MediaStorage.duplicateImageFile(
          destProjectId: newId,
          sourcePath: img.imagePath,
          subfolder: 'sites/$newSiteId',
          prefix: 'img',
        );
        if (newPath != null) {
          await insertSiteImage(SiteImagesCompanion.insert(
            siteId: newSiteId,
            imagePath: newPath,
            caption: Value(img.caption),
            kind: Value(img.kind),
            timeOfDay: Value(img.timeOfDay),
            sortOrder: Value(img.sortOrder),
          ));
        }
      }
    }

    final setIdMap = <int, int>{};
    final sourceSets = await (select(locationBasePlans)
          ..where((l) => l.projectId.equals(sourceId)))
        .get();
    for (final set in sourceSets) {
      final newSiteId = set.siteId != null ? siteIdMap[set.siteId!] : null;
      final newSetId = await insertLocation(LocationBasePlansCompanion.insert(
        projectId: newId,
        siteId: Value(newSiteId),
        locationName: set.locationName,
        description: Value(set.description),
        imagePath: Value(set.imagePath),
        color: Value(set.color),
        notes: Value(set.notes),
        model3dPath: Value(set.model3dPath),
        floorPlanJson: Value(set.floorPlanJson),
        scanPath: Value(set.scanPath),
        scanSource: Value(set.scanSource),
        scanMetadataJson: Value(set.scanMetadataJson),
        sortOrder: Value(set.sortOrder),
      ));
      setIdMap[set.id] = newSetId;

      final locImages = await (select(locationImages)
            ..where((i) => i.locationId.equals(set.id)))
          .get();
      for (final img in locImages) {
        final newPath = await MediaStorage.duplicateImageFile(
          destProjectId: newId,
          sourcePath: img.imagePath,
          subfolder: 'locations/$newSetId',
          prefix: 'img',
        );
        if (newPath != null) {
          await insertLocationImage(LocationImagesCompanion.insert(
            locationId: newSetId,
            imagePath: newPath,
            caption: Value(img.caption),
            kind: Value(img.kind),
            timeOfDay: Value(img.timeOfDay),
            sortOrder: Value(img.sortOrder),
          ));
        }
      }
    }

    final sceneIdMap = <int, int>{};
    final sourceScenes = await (select(scenes)
          ..where((s) => s.projectId.equals(sourceId)))
        .get();

    for (final scene in sourceScenes) {
      final newSceneId = await into(scenes).insert(ScenesCompanion.insert(
        projectId: newId,
        number: scene.number,
        name: scene.name,
        locationCanonical: scene.locationCanonical,
        locationPureName: scene.locationPureName,
        intExt: Value(scene.intExt),
        dayNight: Value(scene.dayNight),
        locationColor: Value(scene.locationColor),
        description: Value(scene.description),
        sourceStartIndex: Value(scene.sourceStartIndex),
        locationId: Value(
          scene.locationId != null ? setIdMap[scene.locationId!] : null,
        ),
        locationSiteId: Value(
          scene.locationSiteId != null ? siteIdMap[scene.locationSiteId!] : null,
        ),
        sortOrder: Value(scene.sortOrder),
      ));
      sceneIdMap[scene.id] = newSceneId;

      final sourceShots = await (select(shots)
            ..where((s) => s.sceneId.equals(scene.id)))
          .get();

      for (final shot in sourceShots) {
        String? refPath;
        if (shot.referenceImagePath != null) {
          refPath = await MediaStorage.duplicateImageFile(
            destProjectId: newId,
            sourcePath: shot.referenceImagePath!,
            subfolder: 'references',
            prefix: 'shot',
          );
        }

        final newShotId = await into(shots).insert(ShotsCompanion.insert(
          sceneId: newSceneId,
          projectId: newId,
          number: shot.number,
          framing: Value(shot.framing),
          lens: Value(shot.lens),
          angle: Value(shot.angle),
          movement: Value(shot.movement),
          fStop: Value(shot.fStop),
          action: Value(shot.action),
          notes: Value(shot.notes),
          notesHighlight: Value(shot.notesHighlight),
          referenceImagePath: Value(refPath ?? shot.referenceImagePath),
          sortOrder: Value(shot.sortOrder),
        ));

        await _copyCameraPlanElements(sourceShotId: shot.id, destShotId: newShotId);
      }
    }
    return newId;
  }

  Future<void> _copyCameraPlanElements({
    required int sourceShotId,
    required int destShotId,
  }) async {
    final sourceElements = await getCameraPlanElementsForShot(sourceShotId);
    for (final el in sourceElements) {
      final pathRows = await getPathPointsForElement(el.id);
      final newElId = await insertCameraPlanElement(
        CameraPlanElementsCompanion.insert(
          shotId: destShotId,
          type: el.type,
          x: Value(el.x),
          y: Value(el.y),
          rotation: Value(el.rotation),
          label: Value(el.label),
          color: Value(el.color),
          cameraStabilization: Value(el.cameraStabilization),
          cameraLens: Value(el.cameraLens),
          cameraLetter: Value(el.cameraLetter),
          cameraNumber: Value(el.cameraNumber),
          lightType: Value(el.lightType),
          lukaCompatible: Value(el.lukaCompatible),
          lukaFixtureId: Value(el.lukaFixtureId),
          externalMappingJson: Value(el.externalMappingJson),
          sortOrder: Value(el.sortOrder),
        ),
      );
      await replacePathPoints(
        newElId,
        pathRows.map((p) => (x: p.x, y: p.y)).toList(),
      );
    }
  }

  // ── Escenas ───────────────────────────────────
  Stream<List<Scene>> watchScenesForProject(int projectId) =>
      (select(scenes)
        ..where((s) => s.projectId.equals(projectId))
        ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .watch();

  Future<int> insertScene(ScenesCompanion scene) => into(scenes).insert(scene);
  Future<bool> updateScene(Scene scene) => update(scenes).replace(scene);
  Future<int> deleteScene(int id) =>
      (delete(scenes)..where((s) => s.id.equals(id))).go();

  /// Reemplaza todas las escenas del proyecto (y sus planos) en el orden indicado.
  Future<void> replaceScenesForProject(
    int projectId,
    List<ScenesCompanion> newScenes,
  ) async {
    await transaction(() async {
      await (delete(shots)..where((s) => s.projectId.equals(projectId))).go();
      await (delete(scenes)..where((s) => s.projectId.equals(projectId))).go();
      for (final scene in newScenes) {
        await into(scenes).insert(scene);
      }
    });
  }

  /// Sincroniza escenas desde el espacio de trabajo preservando planos cuando es posible.
  Future<void> syncScenesFromWorkspace(
    int projectId,
    List<({
      String intExt,
      String dayNight,
      String location,
      String shootSet,
      String locationSite,
      String? description,
      String? locationColor,
      int? sourceStartIndex,
    })> items,
  ) async {
    await transaction(() async {
      final existing = await (select(scenes)
            ..where((s) => s.projectId.equals(projectId)))
          .get();

      final matchedIds = <int>{};

      for (var i = 0; i < items.length; i++) {
        final order = i + 1;
        final s = items[i];
        final siteName = s.locationSite.trim().isEmpty
            ? s.shootSet.trim()
            : s.locationSite.trim();
        final site =
            await ensureSite(projectId: projectId, siteName: siteName);
        await ensureSiteAndSet(
          projectId: projectId,
          siteName: siteName,
          setName: s.shootSet.trim(),
          colorHex: s.locationColor,
        );
        final siteId = site.id;

        Scene? match;
        if (s.sourceStartIndex != null) {
          for (final candidate in existing) {
            if (candidate.sourceStartIndex == s.sourceStartIndex) {
              match = candidate;
              break;
            }
          }
        }
        if (match == null) {
          for (final candidate in existing) {
            if (matchedIds.contains(candidate.id)) continue;
            if (candidate.number == order || candidate.sortOrder == order) {
              match = candidate;
              break;
            }
          }
        }

        final name = formatSceneDefaultName(
          intExt: s.intExt,
          dayNight: s.dayNight,
          location: s.location,
        );
        final canonical = '${s.intExt}. ${s.location} - ${s.dayNight}';

        if (match != null) {
          matchedIds.add(match.id);
          await update(scenes).replace(match.copyWith(
            number: order,
            name: name,
            locationCanonical: canonical,
            locationPureName: s.shootSet.trim(),
            locationSiteId: Value(siteId),
            intExt: s.intExt,
            dayNight: s.dayNight,
            locationColor: Value(s.locationColor),
            description: Value(s.description),
            sourceStartIndex: Value(s.sourceStartIndex),
            sortOrder: order,
          ));
        } else {
          await into(scenes).insert(ScenesCompanion.insert(
            projectId: projectId,
            number: order,
            name: name,
            locationCanonical: canonical,
            locationPureName: s.shootSet.trim(),
            locationSiteId: Value(siteId),
            intExt: Value(s.intExt),
            dayNight: Value(s.dayNight),
            locationColor: Value(s.locationColor),
            description: Value(s.description),
            sourceStartIndex: Value(s.sourceStartIndex),
            sortOrder: Value(order),
          ));
        }
      }

      for (final old in existing) {
        if (matchedIds.contains(old.id)) continue;
        await (delete(shots)..where((sh) => sh.sceneId.equals(old.id))).go();
        await (delete(scenes)..where((sc) => sc.id.equals(old.id))).go();
      }

      await linkScenesToLocations(projectId);
    });
  }

  /// Escenas que se eliminarían al sincronizar y tienen planos.
  Future<List<Scene>> findScenesWithShotsToRemoveOnSync(
    int projectId,
    List<int?> sourceStartIndices,
    int newCount,
  ) async {
    final existing = await (select(scenes)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .get();

    final keepIds = <int>{};

    for (var i = 0; i < newCount; i++) {
      final order = i + 1;
      final sourceIndex = i < sourceStartIndices.length
          ? sourceStartIndices[i]
          : null;

      Scene? match;
      if (sourceIndex != null) {
        match = existing
            .where((e) => e.sourceStartIndex == sourceIndex)
            .firstOrNull;
      }
      match ??= existing
          .where((e) => !keepIds.contains(e.id) && e.sortOrder == order)
          .firstOrNull;
      if (match != null) keepIds.add(match.id);
    }

    final toRemove =
        existing.where((e) => !keepIds.contains(e.id)).toList(growable: false);
    if (toRemove.isEmpty) return [];

    final result = <Scene>[];
    for (final scene in toRemove) {
      final shotCount = await (select(shots)
            ..where((s) => s.sceneId.equals(scene.id)))
          .get();
      if (shotCount.isNotEmpty) result.add(scene);
    }
    return result;
  }

  // Localizaciones únicas de un proyecto (para dropdown)
  Future<List<String>> getUniqueLocations(int projectId) async {
    final allScenes = await (select(scenes)
      ..where((s) => s.projectId.equals(projectId))).get();
    final locs = allScenes.map((s) => s.locationPureName).toSet().toList();
    locs.sort();
    return locs;
  }

  // ── Planos ────────────────────────────────────
  Stream<List<Shot>> watchShotsForScene(int sceneId) =>
      (select(shots)
        ..where((s) => s.sceneId.equals(sceneId))
        ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .watch();

  Future<List<Shot>> getShotsForProject(int projectId) =>
      (select(shots)
        ..where((s) => s.projectId.equals(projectId))
        ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)])).get();

  Stream<List<Shot>> watchShotsForProject(int projectId) =>
      (select(shots)
        ..where((s) => s.projectId.equals(projectId))
        ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)])).watch();

  Future<int> insertShot(ShotsCompanion shot) => into(shots).insert(shot);
  Future<bool> updateShot(Shot shot) => update(shots).replace(shot);
  Future<int> deleteShot(int id) async {
    final elements = await getCameraPlanElementsForShot(id);
    for (final el in elements) {
      await deleteCameraPlanElement(el.id);
    }
    return (delete(shots)..where((s) => s.id.equals(id))).go();
  }

  Future<int> countShotsWithCameraPlan(int projectId) async {
    final projectShots = await getShotsForProject(projectId);
    if (projectShots.isEmpty) return 0;
    final shotIds = projectShots.map((s) => s.id).toList();
    final elements = await (select(cameraPlanElements)
          ..where((e) => e.shotId.isIn(shotIds)))
        .get();
    return elements.map((e) => e.shotId).toSet().length;
  }

  // ── Localizaciones (contenedores) ───────────
  Stream<List<LocationSite>> watchSitesForProject(int projectId) =>
      (select(locationSites)
        ..where((s) => s.projectId.equals(projectId))
        ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .watch();

  Future<LocationSite?> getSiteById(int id) =>
      (select(locationSites)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> insertSite(LocationSitesCompanion site) =>
      into(locationSites).insert(site);

  Future<bool> updateSite(LocationSite site) =>
      update(locationSites).replace(site);

  Future<void> deleteSite(int id) async {
    await transaction(() async {
      await (update(locationBasePlans)..where((l) => l.siteId.equals(id))).write(
        const LocationBasePlansCompanion(siteId: Value(null)),
      );
      await (delete(locationSites)..where((s) => s.id.equals(id))).go();
    });
  }

  Stream<List<LocationBasePlan>> watchSetsForSite(int siteId) =>
      (select(locationBasePlans)
        ..where((l) => l.siteId.equals(siteId))
        ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
          .watch();

  Future<int> countSetsForSite(int siteId) async {
    final rows = await (select(locationBasePlans)
          ..where((l) => l.siteId.equals(siteId)))
        .get();
    return rows.length;
  }

  Future<LocationSite?> findSiteByName(int projectId, String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;
    final sites = await (select(locationSites)
          ..where((s) => s.projectId.equals(projectId)))
        .get();
    for (final site in sites) {
      if (site.name.trim().toLowerCase() == key) return site;
    }
    return null;
  }

  Future<LocationBasePlan?> findSetInSite(int siteId, String setName) async {
    final key = setName.trim().toLowerCase();
    if (key.isEmpty) return null;
    final sets = await (select(locationBasePlans)
          ..where((l) => l.siteId.equals(siteId)))
        .get();
    for (final set in sets) {
      if (set.locationName.trim().toLowerCase() == key) return set;
    }
    return null;
  }

  /// Garantiza que exista la localización contenedora.
  Future<LocationSite> ensureSite({
    required int projectId,
    required String siteName,
  }) async {
    final siteKey = siteName.trim();
    if (siteKey.isEmpty) {
      throw ArgumentError('siteName es obligatorio');
    }

    var site = await findSiteByName(projectId, siteKey);
    if (site == null) {
      final sites = await (select(locationSites)
            ..where((s) => s.projectId.equals(projectId)))
          .get();
      final siteId = await insertSite(LocationSitesCompanion.insert(
        projectId: projectId,
        name: siteKey,
        sortOrder: Value(sites.length),
      ));
      site = (await getSiteById(siteId))!;
    }

    await ensureDefaultSetForSite(projectId: projectId, site: site);
    return site;
  }

  /// Garantiza el set base de una localización (mismo nombre que el sitio).
  Future<LocationBasePlan> ensureDefaultSetForSite({
    required int projectId,
    required LocationSite site,
  }) async {
    var set = await findSetInSite(site.id, site.name);
    if (set != null) return set;

    final sets = await (select(locationBasePlans)
          ..where((l) => l.siteId.equals(site.id)))
        .get();

    // Si ya hay sets pero ninguno coincide con el nombre del sitio, reutiliza el primero.
    if (sets.isNotEmpty) {
      return sets.first;
    }

    final setId = await insertLocation(LocationBasePlansCompanion.insert(
      projectId: projectId,
      siteId: Value(site.id),
      locationName: site.name,
      color: Value(defaultSceneColorForIndex(0)),
      sortOrder: const Value(0),
    ));
    return (await getLocationById(setId))!;
  }

  /// Garantiza localización + set; crea lo que falte.
  Future<({LocationSite site, LocationBasePlan set})> ensureSiteAndSet({
    required int projectId,
    required String siteName,
    required String setName,
    String? colorHex,
  }) async {
    final siteKey = siteName.trim();
    final setKey = setName.trim();
    if (siteKey.isEmpty || setKey.isEmpty) {
      throw ArgumentError('siteName y setName son obligatorios');
    }

    final site = await ensureSite(projectId: projectId, siteName: siteKey);

    var set = await findSetInSite(site.id, setKey);
    if (set == null) {
      final sets = await (select(locationBasePlans)
            ..where((l) => l.siteId.equals(site.id)))
          .get();
      final setId = await insertLocation(LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(site.id),
        locationName: setKey,
        color: Value(colorHex ?? defaultSceneColorForIndex(sets.length)),
        sortOrder: Value(sets.length),
      ));
      set = (await getLocationById(setId))!;
    } else if (colorHex != null && set.color != colorHex) {
      await updateLocation(set.copyWith(color: colorHex));
      set = (await getLocationById(set.id))!;
    }

    return (site: site, set: set);
  }

  /// Crea localización con un set inicial del mismo nombre (caso simple).
  Future<({LocationSite site, LocationBasePlan set})> createLocationWithDefaultSet(
    int projectId,
    String name, {
    String? colorHex,
  }) =>
      ensureSiteAndSet(
        projectId: projectId,
        siteName: name,
        setName: name,
        colorHex: colorHex,
      );

  /// Convierte un set suelto en localización con varios sets (crea contenedor).
  Future<LocationSite> enableMultiSetForLocation(int setId) async {
    final set = await getLocationById(setId);
    if (set == null) throw StateError('Set no encontrado');
    if (set.siteId != null) {
      final site = await getSiteById(set.siteId!);
      if (site != null) return site;
    }

    final sites = await (select(locationSites)
          ..where((s) => s.projectId.equals(set.projectId)))
        .get();

    final siteId = await insertSite(LocationSitesCompanion.insert(
      projectId: set.projectId,
      name: set.locationName,
      description: Value(set.description),
      notes: Value(set.notes),
      sortOrder: Value(sites.length),
    ));

    await updateLocation(set.copyWith(siteId: Value(siteId)));
    return (await getSiteById(siteId))!;
  }

  Future<int> insertSetUnderSite({
    required int projectId,
    required int siteId,
    required String name,
    String? color,
    int? sortOrder,
  }) async {
    final sets = await (select(locationBasePlans)
          ..where((l) => l.siteId.equals(siteId)))
        .get();
    return insertLocation(LocationBasePlansCompanion.insert(
      projectId: projectId,
      siteId: Value(siteId),
      locationName: name,
      color: Value(color ?? defaultSceneColorForIndex(sets.length)),
      sortOrder: Value(sortOrder ?? sets.length),
    ));
  }

  // ── Sets de rodaje ────────────────────────────
  Stream<List<LocationBasePlan>> watchLocationsForProject(int projectId) =>
      (select(locationBasePlans)
        ..where((l) => l.projectId.equals(projectId))
        ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
          .watch();

  Future<LocationBasePlan?> getLocationById(int id) =>
      (select(locationBasePlans)..where((l) => l.id.equals(id)))
          .getSingleOrNull();

  Future<Map<int, LocationBasePlan>> getLocationsMapForProject(int projectId) async {
    final list = await (select(locationBasePlans)
          ..where((l) => l.projectId.equals(projectId)))
        .get();
    return {for (final l in list) l.id: l};
  }

  Future<int> insertLocation(LocationBasePlansCompanion loc) =>
      into(locationBasePlans).insert(loc);

  Future<bool> updateLocation(LocationBasePlan loc) =>
      update(locationBasePlans).replace(loc);

  Future<void> deleteLocation(int id) async {
    await transaction(() async {
      await (update(scenes)..where((s) => s.locationId.equals(id))).write(
        const ScenesCompanion(locationId: Value(null)),
      );
      await (delete(locationImages)..where((i) => i.locationId.equals(id))).go();
      await (delete(locationBasePlans)..where((l) => l.id.equals(id))).go();
    });
  }

  Future<int> deleteLocationAndUnlink(int projectId, String locationName) async {
    final loc = await (select(locationBasePlans)
          ..where((l) =>
              l.projectId.equals(projectId) &
              l.locationName.equals(locationName)))
        .getSingleOrNull();
    if (loc == null) return 0;
    await deleteLocation(loc.id);
    return 1;
  }

  /// Crea localizaciones y sets a partir de escenas.
  Future<int> syncLocationsFromScenes(int projectId) async {
    final sceneList = await (select(scenes)
          ..where((s) => s.projectId.equals(projectId)))
        .get();

    final grouped = <String, ({String siteName, Set<String> setNames})>{};

    for (final scene in sceneList) {
      final setName = scene.locationPureName.trim();
      if (setName.isEmpty) continue;

      final siteName = scene.locationSiteId != null
          ? (await getSiteById(scene.locationSiteId!))?.name ?? setName
          : setName;
      final key = siteName.trim().toLowerCase();
      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = (siteName: siteName.trim(), setNames: {setName});
      } else {
        grouped[key] = (
          siteName: existing.siteName,
          setNames: {...existing.setNames, setName},
        );
      }
    }

    var created = 0;
    for (final entry in grouped.values) {
      final existingSite = await findSiteByName(projectId, entry.siteName);
      final setsBefore = existingSite != null
          ? await countSetsForSite(existingSite.id)
          : 0;

      final site =
          await ensureSite(projectId: projectId, siteName: entry.siteName);
      final setsAfter = await countSetsForSite(site.id);
      created += setsAfter - setsBefore;

      final normalizedSite = entry.siteName.trim().toLowerCase();
      for (final setName in entry.setNames) {
        if (setName.trim().toLowerCase() == normalizedSite) continue;
        final existingSet = await findSetInSite(site.id, setName);
        if (existingSet != null) continue;
        await ensureSiteAndSet(
          projectId: projectId,
          siteName: entry.siteName,
          setName: setName,
          colorHex: defaultSceneColorForIndex(setsAfter + created),
        );
        created++;
      }
    }

    await linkScenesToLocations(projectId);
    return created;
  }

  /// Vincula escenas a sets por localización + nombre de set.
  Future<int> linkScenesToLocations(int projectId) async {
    final sceneList = await (select(scenes)
          ..where((s) => s.projectId.equals(projectId)))
        .get();
    final sets = await (select(locationBasePlans)
          ..where((l) => l.projectId.equals(projectId)))
        .get();
    final setsBySiteAndName = <String, int>{};
    for (final set in sets) {
      if (set.siteId == null) continue;
      final key =
          '${set.siteId}|${set.locationName.trim().toLowerCase()}';
      setsBySiteAndName[key] = set.id;
    }

    var linked = 0;
    for (final scene in sceneList) {
      final setKey = scene.locationPureName.trim().toLowerCase();

      int? siteId = scene.locationSiteId;
      if (siteId == null && setKey.isNotEmpty) {
        final site = await findSiteByName(projectId, scene.locationPureName.trim());
        siteId = site?.id;
      }
      if (siteId == null) continue;

      int? setId;
      if (setKey.isNotEmpty) {
        setId = setsBySiteAndName['$siteId|$setKey'];
      }
      if (setId == null) {
        final site = await getSiteById(siteId);
        if (site != null) {
          setId = setsBySiteAndName[
              '$siteId|${site.name.trim().toLowerCase()}'];
        }
      }

      if (scene.locationSiteId == siteId && scene.locationId == setId) {
        continue;
      }

      await update(scenes).replace(scene.copyWith(
        locationSiteId: Value(siteId),
        locationId: Value(setId),
      ));
      linked++;
    }
    return linked;
  }

  /// Quita overrides de color en escenas vinculadas para heredar el set.
  Future<int> applyLocationColorToLinkedScenes(int locationId) async {
    final affected = await (select(scenes)
          ..where((s) => s.locationId.equals(locationId)))
        .get();
    for (final scene in affected) {
      await update(scenes).replace(
        scene.copyWith(locationColor: const Value(null)),
      );
    }
    return affected.length;
  }

  /// Quita overrides de escenas de una localización contenedora.
  Future<int> clearSceneColorOverridesForSite(int siteId) async {
    final affected = await (select(scenes)
          ..where((s) => s.locationSiteId.equals(siteId)))
        .get();
    for (final scene in affected) {
      await update(scenes).replace(
        scene.copyWith(locationColor: const Value(null)),
      );
    }
    return affected.length;
  }

  /// Color solo en una escena.
  Future<void> applySceneColorOverride(int sceneId, String? colorHex) async {
    final scene = await (select(scenes)..where((s) => s.id.equals(sceneId)))
        .getSingleOrNull();
    if (scene == null) return;
    await update(scenes).replace(
      scene.copyWith(locationColor: Value(persistSceneColor(colorHex))),
    );
  }

  /// Color en un set; limpia overrides de sus escenas.
  Future<void> applySetColorHex(int setId, String colorHex) async {
    final set = await getLocationById(setId);
    if (set == null) return;
    final hex = sceneColorForPicker(colorHex);
    await updateLocation(set.copyWith(color: hex));
    await applyLocationColorToLinkedScenes(setId);
  }

  /// Color base en localización: variantes en todos los sets.
  Future<void> applySiteColorFromBase(int siteId, String baseColorHex) async {
    final base = locationBaseColor(sceneDisplayColor(baseColorHex));
    final siteSets = await (select(locationBasePlans)
          ..where((l) => l.siteId.equals(siteId))
          ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
        .get();
    final count = siteSets.length;
    for (var i = 0; i < count; i++) {
      final variant = setVariantColor(base, i, count);
      await updateLocation(
        siteSets[i].copyWith(color: hexFromColor(variant)),
      );
    }
    await clearSceneColorOverridesForSite(siteId);
  }

  /// Actualiza o crea set por nombre y aplica su color.
  Future<void> upsertSetColor(
    int projectId,
    String siteName,
    String setName,
    String colorHex,
  ) async {
    final result = await ensureSiteAndSet(
      projectId: projectId,
      siteName: siteName.trim().isEmpty ? setName : siteName,
      setName: setName,
      colorHex: colorHex,
    );
    await linkScenesToLocations(projectId);
    await applyLocationColorToLinkedScenes(result.set.id);
  }

  Future<void> syncSetColorsFromWorkspace(
    int projectId,
    Map<String, String> colorsBySetKey,
    Map<String, String> siteBySetKey,
  ) async {
    for (final entry in colorsBySetKey.entries) {
      final siteName = siteBySetKey[entry.key] ?? entry.key;
      await upsertSetColor(projectId, siteName, entry.key, entry.value);
    }
  }

  Stream<List<Scene>> watchScenesForSite(int siteId) =>
      (select(scenes)
        ..where((s) => s.locationSiteId.equals(siteId))
        ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .watch();

  Future<int> countScenesForSite(int siteId) async {
    final rows = await (select(scenes)
          ..where((s) => s.locationSiteId.equals(siteId)))
        .get();
    return rows.length;
  }

  Stream<List<Scene>> watchScenesForLocation(int locationId) =>
      (select(scenes)
        ..where((s) => s.locationId.equals(locationId))
        ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .watch();

  Future<int> countScenesForLocation(int locationId) async {
    final rows = await (select(scenes)
          ..where((s) => s.locationId.equals(locationId)))
        .get();
    return rows.length;
  }

  /// Mueve una escena a otro set dentro de la misma localización.
  Future<void> moveSceneToSet({
    required Scene scene,
    required LocationBasePlan targetSet,
  }) async {
    if (targetSet.siteId == null) {
      throw ArgumentError('El set destino debe pertenecer a una localización');
    }
    await update(scenes).replace(
      scene.copyWith(
        locationId: Value(targetSet.id),
        locationSiteId: Value(targetSet.siteId),
        locationPureName: targetSet.locationName,
        locationColor: const Value(null),
      ),
    );
  }

  // ── Imágenes de localización ──────────────────
  Stream<List<LocationImage>> watchImagesForLocation(int locationId) =>
      (select(locationImages)
        ..where((i) => i.locationId.equals(locationId))
        ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .watch();

  Future<int> insertLocationImage(LocationImagesCompanion image) =>
      into(locationImages).insert(image);

  Future<int> deleteLocationImage(int id) =>
      (delete(locationImages)..where((i) => i.id.equals(id))).go();

  // ── Imágenes de localización (sitio) ──────────
  Stream<List<SiteImage>> watchImagesForSite(int siteId) =>
      (select(siteImages)
        ..where((i) => i.siteId.equals(siteId))
        ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .watch();

  Future<int> insertSiteImage(SiteImagesCompanion image) =>
      into(siteImages).insert(image);

  Future<int> deleteSiteImage(int id) =>
      (delete(siteImages)..where((i) => i.id.equals(id))).go();

  // ── Planta de cámara ─────────────────────────
  Future<List<CameraPlanElement>> getCameraPlanElementsForShot(int shotId) =>
      (select(cameraPlanElements)
            ..where((e) => e.shotId.equals(shotId))
            ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
          .get();

  Stream<List<CameraPlanElement>> watchCameraPlanElementsForShot(int shotId) =>
      (select(cameraPlanElements)
            ..where((e) => e.shotId.equals(shotId))
            ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
          .watch();

  Future<List<CameraPathPoint>> getPathPointsForElement(int elementId) =>
      (select(cameraPathPoints)
            ..where((p) => p.elementId.equals(elementId))
            ..orderBy([(p) => OrderingTerm.asc(p.pointNumber)]))
          .get();

  Future<int> insertCameraPlanElement(CameraPlanElementsCompanion row) =>
      into(cameraPlanElements).insert(row);

  Future<bool> updateCameraPlanElement(CameraPlanElement row) =>
      update(cameraPlanElements).replace(row);

  Future<void> replacePathPoints(
    int elementId,
    List<({double x, double y})> points,
  ) async {
    await (delete(cameraPathPoints)
          ..where((p) => p.elementId.equals(elementId)))
        .go();
    for (var i = 0; i < points.length; i++) {
      await into(cameraPathPoints).insert(CameraPathPointsCompanion.insert(
        elementId: elementId,
        pointNumber: i + 1,
        x: points[i].x,
        y: points[i].y,
      ));
    }
  }

  Future<int> deleteCameraPlanElement(int id) async {
    await (delete(cameraPathPoints)..where((p) => p.elementId.equals(id))).go();
    return (delete(cameraPlanElements)..where((e) => e.id.equals(id))).go();
  }

  Future<List<Shot>> getShotsForScene(int sceneId) =>
      (select(shots)
            ..where((s) => s.sceneId.equals(sceneId))
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .get();

  Future<void> saveFloorPlanToSet(int setId, String json) async {
    final set = await getLocationById(setId);
    if (set == null) return;
    await updateLocation(set.copyWith(floorPlanJson: Value(json)));
  }

  Future<void> saveFloorPlanToSite(int siteId, String json) async {
    final site = await getSiteById(siteId);
    if (site == null) return;
    await updateSite(site.copyWith(floorPlanJson: Value(json)));
  }

  Future<bool> shotHasCameraPlan(int shotId) async {
    final rows = await getCameraPlanElementsForShot(shotId);
    return rows.isNotEmpty;
  }

  // ── Catálogo de equipo ────────────────────────
  Stream<List<Camera>> watchAllCameras() =>
      (select(cameras)..orderBy([(c) => OrderingTerm.asc(c.brand)])).watch();

  Stream<List<Lense>> watchAllLenses() =>
      (select(lenses)..orderBy([(l) => OrderingTerm.asc(l.brand)])).watch();

  Stream<List<Light>> watchAllLights() =>
      (select(lights)..orderBy([(l) => OrderingTerm.asc(l.brand)])).watch();

  Stream<List<ProjectEquipmentData>> watchProjectEquipment(int projectId) =>
      (select(projectEquipment)
            ..where((e) => e.projectId.equals(projectId)))
          .watch();

  Future<bool> isEquipmentAssigned({
    required int projectId,
    required String equipmentType,
    required int equipmentId,
  }) async {
    final row = await (select(projectEquipment)
          ..where((e) =>
              e.projectId.equals(projectId) &
              e.equipmentType.equals(equipmentType) &
              e.equipmentId.equals(equipmentId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<int> assignEquipmentToProject({
    required int projectId,
    required String equipmentType,
    required int equipmentId,
    String source = 'rental',
  }) async {
    if (await isEquipmentAssigned(
      projectId: projectId,
      equipmentType: equipmentType,
      equipmentId: equipmentId,
    )) {
      return 0;
    }
    return into(projectEquipment).insert(ProjectEquipmentCompanion.insert(
      projectId: projectId,
      equipmentType: equipmentType,
      equipmentId: equipmentId,
      source: Value(source),
    ));
  }

  Future<int> unassignProjectEquipment(int assignmentId) =>
      (delete(projectEquipment)..where((e) => e.id.equals(assignmentId))).go();

  // ── Referencias de plano ──────────────────────
  Stream<List<ShotReference>> watchReferencesForShot(int shotId) =>
      (select(shotReferences)
            ..where((r) => r.shotId.equals(shotId))
            ..orderBy([(r) => OrderingTerm.asc(r.sortOrder)]))
          .watch();

  Future<int> insertShotReference(ShotReferencesCompanion ref) =>
      into(shotReferences).insert(ref);

  Future<int> deleteShotReference(int id) =>
      (delete(shotReferences)..where((r) => r.id.equals(id))).go();

  Future<Shot?> getShotById(int id) =>
      (select(shots)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<Shot?> getShotBySceneAndNumber(int sceneId, int number) =>
      (select(shots)
            ..where((s) => s.sceneId.equals(sceneId) & s.number.equals(number)))
          .getSingleOrNull();

  Future<Scene?> getSceneById(int id) =>
      (select(scenes)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<List<Shot>> getShotsWithReferencesForProject(int projectId) =>
      (select(shots)
            ..where((s) =>
                s.projectId.equals(projectId) &
                s.referenceImagePath.isNotNull())
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .get();

  /// Miniaturas para la cabecera del hub: moodboard (localizaciones) + storyboard.
  Future<({List<String> moodboard, List<String> storyboard})>
      getProjectHubVisuals(
    int projectId, {
    int moodLimit = 16,
    int storyLimit = 16,
  }) async {
    final moodPaths = <String>[];
    final storyPaths = <String>[];

    final moodboardRows = await (select(moodboardImages)
          ..where((m) => m.projectId.equals(projectId))
          ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]))
        .get();
    for (final row in moodboardRows) {
      if (_isExistingImage(row.imagePath)) {
        moodPaths.add(row.imagePath);
      }
    }

    final sites = await (select(locationSites)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .get();

    for (final site in sites) {
      final images = await (select(siteImages)
            ..where((i) => i.siteId.equals(site.id))
            ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .get();
      for (final image in images) {
        if (_isExistingImage(image.imagePath)) {
          moodPaths.add(image.imagePath);
        }
      }
    }

    final sets = await (select(locationBasePlans)
          ..where((l) => l.projectId.equals(projectId))
          ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
        .get();

    for (final set in sets) {
      if (set.imagePath != null && _isExistingImage(set.imagePath!)) {
        moodPaths.add(set.imagePath!);
      }
      final images = await (select(locationImages)
            ..where((i) => i.locationId.equals(set.id))
            ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .get();
      for (final image in images) {
        if (_isExistingImage(image.imagePath)) {
          moodPaths.add(image.imagePath);
        }
      }
    }

    final projectShots = await (select(shots)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .get();

    for (final shot in projectShots) {
      final path = shot.referenceImagePath;
      if (path != null && _isExistingImage(path)) {
        storyPaths.add(path);
      }
    }

    return (
      moodboard: moodPaths.take(moodLimit).toList(),
      storyboard: storyPaths.take(storyLimit).toList(),
    );
  }

  bool _isExistingImage(String path) =>
      path.isNotEmpty && File(path).existsSync();

  // ── Look Bible ───────────────────────────────────────────────────────────

  Stream<LookBible?> watchLookBibleForProject(int projectId) =>
      (select(lookBibles)..where((l) => l.projectId.equals(projectId)))
          .watchSingleOrNull();

  Future<LookBible?> getLookBibleForProject(int projectId) =>
      (select(lookBibles)..where((l) => l.projectId.equals(projectId)))
          .getSingleOrNull();

  Future<int> upsertLookBible(LookBiblesCompanion row) async {
    final existing = await getLookBibleForProject(row.projectId.value);
    if (existing == null) {
      return into(lookBibles).insert(row);
    }
    await (update(lookBibles)..where((l) => l.id.equals(existing.id))).write(
      row.copyWith(
        id: Value(existing.id),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return existing.id;
  }

  // ── Biblia Visual ─────────────────────────────────────────────────────────

  Stream<VisualBible?> watchVisualBibleForProject(int projectId) =>
      (select(visualBibles)..where((v) => v.projectId.equals(projectId)))
          .watchSingleOrNull();

  Future<VisualBible?> getVisualBibleForProject(int projectId) =>
      (select(visualBibles)..where((v) => v.projectId.equals(projectId)))
          .getSingleOrNull();

  Future<VisualBible> ensureVisualBibleForProject(int projectId) async {
    final existing = await getVisualBibleForProject(projectId);
    if (existing != null) return existing;
    final id = await into(visualBibles).insert(
      VisualBiblesCompanion.insert(projectId: projectId),
    );
    return (await (select(visualBibles)..where((v) => v.id.equals(id))).getSingle())!;
  }

  Future<int> upsertVisualBible(VisualBiblesCompanion row) async {
    final existing = await getVisualBibleForProject(row.projectId.value);
    if (existing == null) {
      return into(visualBibles).insert(row);
    }
    await (update(visualBibles)..where((v) => v.id.equals(existing.id))).write(
      row.copyWith(
        id: Value(existing.id),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return existing.id;
  }

  Stream<List<VisualBibleColorBlock>> watchColorBlocksForBible(int bibleId) =>
      (select(visualBibleColorBlocks)
            ..where((b) => b.bibleId.equals(bibleId))
            ..orderBy([(b) => OrderingTerm.asc(b.sortOrder)]))
          .watch();

  Future<int> insertColorBlock(VisualBibleColorBlocksCompanion row) =>
      into(visualBibleColorBlocks).insert(row);

  Future<void> updateColorBlock(VisualBibleColorBlock row) =>
      update(visualBibleColorBlocks).replace(row);

  Future<void> deleteColorBlock(int id) =>
      (delete(visualBibleColorBlocks)..where((b) => b.id.equals(id))).go();

  Stream<List<VisualBibleLocationRef>> watchLocationRefsForBible(int bibleId) =>
      (select(visualBibleLocationRefs)
            ..where((r) => r.bibleId.equals(bibleId))
            ..orderBy([(r) => OrderingTerm.asc(r.locationName)]))
          .watch();

  Future<VisualBibleLocationRef?> getLocationRef(
    int bibleId,
    String locationName,
  ) =>
      (select(visualBibleLocationRefs)
            ..where((r) =>
                r.bibleId.equals(bibleId) &
                r.locationName.equals(locationName)))
          .getSingleOrNull();

  Future<void> upsertLocationRef(VisualBibleLocationRefsCompanion row) async {
    final existing = await getLocationRef(
      row.bibleId.value,
      row.locationName.value,
    );
    if (existing == null) {
      await into(visualBibleLocationRefs).insert(row);
    } else {
      await (update(visualBibleLocationRefs)
            ..where((r) => r.id.equals(existing.id)))
          .write(row.copyWith(id: Value(existing.id)));
    }
  }

  Stream<List<MoodboardImage>> watchMoodboardImages(
    int projectId, {
    String? category,
  }) {
    final query = select(moodboardImages)
      ..where((m) {
        final base = m.projectId.equals(projectId);
        if (category != null) {
          return base & m.category.equals(category);
        }
        return base;
      })
      ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]);
    return query.watch();
  }

  Future<int> insertMoodboardImage(MoodboardImagesCompanion row) async {
    if (!row.sortOrder.present) {
      final maxOrder = await _maxMoodboardSortOrder(row.projectId.value);
      return into(moodboardImages).insert(
        row.copyWith(sortOrder: Value(maxOrder + 1)),
      );
    }
    return into(moodboardImages).insert(row);
  }

  Future<int> _maxMoodboardSortOrder(int projectId) async {
    final rows = await (select(moodboardImages)
          ..where((m) => m.projectId.equals(projectId)))
        .get();
    if (rows.isEmpty) return 0;
    return rows.map((r) => r.sortOrder).reduce((a, b) => a > b ? a : b);
  }

  Future<void> updateMoodboardImage(MoodboardImage row) =>
      update(moodboardImages).replace(row);

  Future<void> deleteMoodboardImage(int id) =>
      (delete(moodboardImages)..where((m) => m.id.equals(id))).go();

  Future<void> reorderMoodboardImage(int id, int newSortOrder) async {
    final row = await (select(moodboardImages)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await update(moodboardImages).replace(row.copyWith(sortOrder: newSortOrder));
  }

  Future<void> _migrateLookBiblesToVisualBibles() async {
    final legacy = await select(lookBibles).get();
    for (final lb in legacy) {
      final existing = await getVisualBibleForProject(lb.projectId);
      if (existing != null) continue;

      final bibleId = await into(visualBibles).insert(
        VisualBiblesCompanion.insert(
          projectId: lb.projectId,
          visualConcept: Value(lb.visualConcept),
          narrativeReferences: Value(lb.filmReferences),
          lightingPhilosophy: Value(lb.lightingPhilosophy),
          contrastStyle: Value(lb.contrastStyle),
          creativeLutName: Value(lb.lutName),
          updatedAt: Value(lb.updatedAt),
        ),
      );

      if (lb.colorPalette != null && lb.colorPalette!.trim().isNotEmpty) {
        await insertColorBlock(
          VisualBibleColorBlocksCompanion.insert(
            bibleId: bibleId,
            blockName: 'Paleta global',
            dominantColors: lb.colorPalette!,
          ),
        );
      }

      final acts = [
        ('Acto I', lb.actOneNotes),
        ('Acto II', lb.actTwoNotes),
        ('Acto III', lb.actThreeNotes),
      ];
      var order = 0;
      for (final (name, notes) in acts) {
        if (notes == null || notes.trim().isEmpty) continue;
        await insertColorBlock(
          VisualBibleColorBlocksCompanion.insert(
            bibleId: bibleId,
            blockName: name,
            emotionalIntent: Value(notes),
            dominantColors: '[]',
            sortOrder: Value(order++),
          ),
        );
      }

      if (lb.moodboardImages != null && lb.moodboardImages!.trim().isNotEmpty) {
        try {
          final paths = (jsonDecode(lb.moodboardImages!) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
          var mbOrder = 0;
          for (final path in paths) {
            if (!_isExistingImage(path)) continue;
            await insertMoodboardImage(
              MoodboardImagesCompanion.insert(
                projectId: lb.projectId,
                bibleId: Value(bibleId),
                imagePath: path,
                sortOrder: Value(mbOrder++),
              ),
            );
          }
        } catch (_) {}
      }
    }
  }

  // ── PDFs anotados (GoodNotes) ────────────────────────────────────────────

  Stream<List<ProjectAnnotatedPdf>> watchAnnotatedPdfsForProject(
    int projectId, {
    String? moduleType,
  }) {
    final query = select(projectAnnotatedPdfs)
      ..where((p) {
        if (moduleType != null) {
          return p.projectId.equals(projectId) &
              p.moduleType.equals(moduleType);
        }
        return p.projectId.equals(projectId);
      })
      ..orderBy([(p) => OrderingTerm.desc(p.importedAt)]);
    return query.watch();
  }

  Future<int> insertAnnotatedPdf(ProjectAnnotatedPdfsCompanion row) =>
      into(projectAnnotatedPdfs).insert(row);

  Future<int> deleteAnnotatedPdf(int id) =>
      (delete(projectAnnotatedPdfs)..where((p) => p.id.equals(id))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'iris_dp.db'));
    return NativeDatabase.createInBackground(file);
  });
}

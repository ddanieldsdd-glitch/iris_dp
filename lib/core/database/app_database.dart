import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import '../storage/app_storage_config.dart';
import '../utils/media_storage.dart';
import '../utils/scene_color.dart';
import '../utils/scene_format.dart';
import '../../shared/visual_bible/bible_section_fields.dart';
import '../../shared/visual_bible/moodboard_association.dart';
import '../../shared/visual_bible/bible_layout.dart' as bible_layout;
import '../../shared/visual_bible/bible_section_ids.dart';
import '../../shared/visual_bible/narrative_card_kind.dart';
import '../../shared/visual_bible/sensor_mode_cascade.dart';
import '../../features/visual_bible/v2/migration/freeform_v2_blocks_codec.dart';
import '../templates/user_template_models.dart';
import 'seed_data.dart';
import '../../shared/equipment/catalog_importer.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ProjectGroups,
    Projects,
    Scenes,
    Shots,
    ShootDocuments,
    ShootDocumentBlocks,
    ShotReferences,
    CameraPlanElements,
    CameraPathPoints,
    LocationSites,
    LocationBasePlans,
    LocationImages,
    SiteImages,
    Cameras,
    Lenses,
    Lights,
    ProjectEquipment,
    LookBibles,
    ProjectAnnotatedPdfs,
    ProjectAnnotationDocuments,
    VisualBibles,
    VisualBibleColorBlocks,
    VisualBibleLocationRefs,
    VisualBibleNarrativeCards,
    MoodboardGroups,
    MoodboardImages,
    BibleSectionGroups,
    BibleSectionDefinitions,
    UserTemplates,
    ExposureBlocks,
    LightingSetups,
    CameraTests,
    VisualBibleVersions,
    BibleComments,
    CatalogSyncMeta,
    BibleSectionEvidence,
    LukaSyncMeta,
    OpticsLabSamples,
    CloudSyncQueue,
    PendingMediaUploads,
    VisualBibleDocuments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 40;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await importEmbeddedCatalog(this);
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
      if (from < 14) {
        await m.addColumn(cameras, cameras.dynamicRangeStops);
        await m.addColumn(cameras, cameras.colorScience);
        await m.addColumn(cameras, cameras.nativeIso);
        await m.addColumn(cameras, cameras.logFormats);
        await m.addColumn(visualBibles, visualBibles.primaryCameraId);
        await m.addColumn(visualBibles, visualBibles.recordingFormat);
        await m.addColumn(visualBibles, visualBibles.codec);
        await m.addColumn(visualBibles, visualBibles.resolutionNotes);
        await m.addColumn(visualBibles, visualBibles.frameRateNotes);
        await m.addColumn(visualBibles, visualBibles.nativeIso);
        await m.addColumn(visualBibles, visualBibles.defaultTStop);
        await m.addColumn(visualBibles, visualBibles.ndNotes);
        await m.addColumn(visualBibles, visualBibles.deliveryColorSpace);
        await m.addColumn(visualBibles, visualBibles.captureResolution);
        await m.addColumn(visualBibles, visualBibles.deliveryResolution);
        await m.addColumn(visualBibles, visualBibles.workflowPipeline);
        await m.addColumn(visualBibles, visualBibles.diffusionNotes);
        await m.addColumn(visualBibles, visualBibles.sensorShadowBehavior);
        await m.addColumn(visualBibles, visualBibles.colorScienceNotes);
        await m.addColumn(visualBibles, visualBibles.lowLightNotes);
        await m.addColumn(visualBibles, visualBibles.opticCharacterNotes);
        await m.addColumn(visualBibles, visualBibles.filtrationNotes);
        await m.addColumn(visualBibles, visualBibles.cameraMovementsJson);
        await m.addColumn(visualBibles, visualBibles.actVisualNotes);
        await m.addColumn(visualBibles, visualBibles.cameraNarrativeIntent);
        await m.addColumn(visualBibles, visualBibles.opticsNarrativeIntent);
        await m.addColumn(visualBibles, visualBibles.exposureNarrativeIntent);
        await m.addColumn(visualBibles, visualBibles.lightingNarrativeIntent);
        await m.addColumn(visualBibles, visualBibles.colorNarrativeIntent);
        await m.addColumn(visualBibles, visualBibles.formatNarrativeIntent);
        await m.addColumn(visualBibles, visualBibles.textureNarrativeIntent);
        await m.addColumn(visualBibles, visualBibles.conceptNarrativeIntent);
        await m.addColumn(
          visualBibleLocationRefs,
          visualBibleLocationRefs.solarOrientation,
        );
        await m.addColumn(
          visualBibleLocationRefs,
          visualBibleLocationRefs.availableLightHours,
        );
        await m.addColumn(
          visualBibleLocationRefs,
          visualBibleLocationRefs.existingPracticals,
        );
        await m.addColumn(
          visualBibleLocationRefs,
          visualBibleLocationRefs.estimatedColorTempKelvin,
        );
        await m.createTable(exposureBlocks);
        await m.createTable(lightingSetups);
        await m.createTable(cameraTests);
        await m.createTable(visualBibleVersions);
        await m.createTable(bibleComments);
      }
      if (from < 15) {
        await m.addColumn(cameras, cameras.mountType);
        await m.addColumn(cameras, cameras.sensorModesJson);
        await m.addColumn(cameras, cameras.recordingResolutionsJson);
        await m.addColumn(cameras, cameras.weightKg);
        await m.addColumn(cameras, cameras.powerDrawW);
        await m.addColumn(cameras, cameras.heroImagePath);
        await m.addColumn(cameras, cameras.manufacturerUrl);
        await m.addColumn(cameras, cameras.externalId);
        await m.addColumn(cameras, cameras.catalogVersion);
        await m.addColumn(cameras, cameras.isCustom);
        await m.addColumn(lenses, lenses.mountType);
        await m.addColumn(lenses, lenses.imageCircleMm);
        await m.addColumn(lenses, lenses.isAnamorphic);
        await m.addColumn(lenses, lenses.squeezeRatio);
        await m.addColumn(lenses, lenses.closeFocusM);
        await m.addColumn(lenses, lenses.frontDiameterMm);
        await m.addColumn(lenses, lenses.lensType);
        await m.addColumn(lenses, lenses.heroImagePath);
        await m.addColumn(lenses, lenses.externalId);
        await m.addColumn(lenses, lenses.catalogVersion);
        await m.addColumn(lenses, lenses.isCustom);
        await m.addColumn(lights, lights.beamAngleDeg);
        await m.addColumn(lights, lights.cri);
        await m.addColumn(lights, lights.tlci);
        await m.addColumn(lights, lights.dimmingType);
        await m.addColumn(lights, lights.modifierCompatibilityJson);
        await m.addColumn(lights, lights.heroImagePath);
        await m.addColumn(lights, lights.externalId);
        await m.addColumn(lights, lights.catalogVersion);
        await m.addColumn(lights, lights.isCustom);
        await m.addColumn(visualBibles, visualBibles.opticsConfigJson);
        await m.createTable(catalogSyncMeta);
        await m.createTable(bibleSectionEvidence);
        await _importEmbeddedCatalogIfNeeded();
      }
      if (from < 16) {
        await m.addColumn(cameras, cameras.series);
        await m.addColumn(cameras, cameras.vintage);
        await m.addColumn(cameras, cameras.rentalTagsJson);
        await m.addColumn(cameras, cameras.lukaCompatible);
        await m.addColumn(cameras, cameras.lukaProfileJson);
        await m.addColumn(lenses, lenses.series);
        await m.addColumn(lenses, lenses.vintage);
        await m.addColumn(lenses, lenses.rentalTagsJson);
        await m.addColumn(lenses, lenses.lukaCompatible);
        await m.addColumn(lenses, lenses.lukaProfileJson);
        await m.addColumn(lights, lights.series);
        await m.addColumn(lights, lights.vintage);
        await m.addColumn(lights, lights.rentalTagsJson);
        await m.addColumn(lights, lights.lukaProfileJson);
        await m.createTable(lukaSyncMeta);
        await _importEmbeddedCatalogIfNeeded();
      }
      if (from < 17) {
        await m.addColumn(scenes, scenes.charactersJson);
      }
      if (from < 18) {
        await m.addColumn(visualBibles, visualBibles.tone);
        await m.addColumn(visualBibles, visualBibles.creativeIntention);
        await m.addColumn(visualBibles, visualBibles.stagingApproach);
        await m.addColumn(visualBibles, visualBibles.pointOfView);
        await m.addColumn(visualBibles, visualBibles.directionNarrativeIntent);
        await m.addColumn(visualBibles, visualBibles.depthOfFieldNotes);
        await m.addColumn(
          visualBibleLocationRefs,
          visualBibleLocationRefs.stagingNote,
        );
      }
      if (from < 19) {
        await customStatement(
          "UPDATE moodboard_images SET source = 'manual' "
          "WHERE source = 'ai_generated'",
        );
        await customStatement(
          "UPDATE shot_references SET source = 'manual' "
          "WHERE source = 'ai_generated'",
        );
      }
      if (from < 20) {
        await m.createTable(opticsLabSamples);
      }
      if (from < 21) {
        await m.addColumn(projectEquipment, projectEquipment.sortOrder);
      }
      if (from < 22) {
        await m.addColumn(moodboardImages, moodboardImages.assignedSections);
      }
      if (from < 23) {
        await m.createTable(moodboardGroups);
        await m.addColumn(moodboardImages, moodboardImages.groupId);
      }
      if (from < 24) {
        await _migrateEvidenceToMoodboard();
      }
      if (from < 25) {
        await m.createTable(bibleSectionGroups);
        await m.createTable(bibleSectionDefinitions);
        await _seedBibleSectionDefinitionsForExistingBibles();
      }
      if (from < 26) {
        await m.addColumn(
          visualBibleLocationRefs,
          visualBibleLocationRefs.locationSiteId,
        );
        await m.addColumn(
          visualBibleLocationRefs,
          visualBibleLocationRefs.locationBasePlanId,
        );
        await m.addColumn(
          moodboardImages,
          moodboardImages.linkedLocationBasePlanId,
        );
        await _backfillLocationForeignKeys();
      }
      if (from < 27) {
        await customStatement(
          "UPDATE bible_section_definitions SET label = 'Dirección' "
          "WHERE id = 'direction'",
        );
        await _seedBibleSectionFieldsJson();
      }
      if (from < 28) {
        await m.addColumn(projects, projects.cloudId);
        await m.addColumn(projects, projects.syncUpdatedAt);
        await m.createTable(cloudSyncQueue);
      }
      if (from < 29) {
        await m.addColumn(projects, projects.characterColorsJson);
      }
      if (from < 30) {
        await m.createTable(shootDocuments);
        await m.createTable(shootDocumentBlocks);
        await m.addColumn(shots, shots.charactersJson);
        await m.addColumn(shots, shots.durationSeconds);
        await m.addColumn(shots, shots.scriptAnchorIndex);
      }
      if (from < 31) {
        await m.addColumn(projects, projects.contentSyncUpdatedAt);
      }
      if (from < 32) {
        await m.createTable(userTemplates);
      }
      if (from < 33) {
        await m.createTable(pendingMediaUploads);
      }
      if (from < 34) {
        await m.createTable(visualBibleDocuments);
      }
      if (from < 35) {
        await m.addColumn(visualBibles, visualBibles.structureInitialized);
        await customStatement(
          'UPDATE visual_bibles SET structure_initialized = 1 '
          'WHERE id IN (SELECT DISTINCT bible_id FROM bible_section_groups)',
        );
      }
      if (from < 36) {
        await m.createTable(projectAnnotationDocuments);
      }
      if (from < 37) {
        await m.addColumn(visualBibles, visualBibles.engineVersion);
      }
      if (from < 38) {
        await m.addColumn(lightingSetups, lightingSetups.locationBasePlanId);
        await m.addColumn(lightingSetups, lightingSetups.locationSiteId);
      }
      if (from < 39) {
        await m.addColumn(moodboardImages, moodboardImages.metaJson);
      }
      if (from < 40) {
        await m.addColumn(moodboardImages, moodboardImages.assignedCardIds);
        await m.createTable(visualBibleNarrativeCards);
      }
    },
  );

  Future<void> _seedEquipmentCatalog() async {
    final existing = await select(cameras).get();
    if (existing.isNotEmpty) return;

    for (final c in kSeedCameras) {
      await into(cameras).insert(
        CamerasCompanion.insert(
          brand: c.brand,
          model: c.model,
          sensorWidthMm: c.sensorW,
          sensorHeightMm: c.sensorH,
        ),
      );
    }
    for (final l in kSeedLenses) {
      await into(lenses).insert(
        LensesCompanion.insert(
          brand: l.brand,
          model: l.model,
          focalLength: l.focalLength,
          focalMin: Value(l.focalMin),
          focalMax: Value(l.focalMax),
          minTStop: l.minTStop,
          formatCoverage: l.formatCoverage,
        ),
      );
    }
    for (final light in kSeedLights) {
      await into(lights).insert(
        LightsCompanion.insert(
          brand: light.brand,
          model: light.model,
          lightType: light.type,
          powerW: light.powerW,
          colorTempMin: light.cMin,
          colorTempMax: light.cMax,
          isLukaCompatible: Value(light.luka),
          lukaFixtureId: Value(light.lukaFixtureId),
        ),
      );
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
    final orphanSets = await (select(
      locationBasePlans,
    )..where((l) => l.siteId.isNull())).get();
    for (final set in orphanSets) {
      final sites = await (select(
        locationSites,
      )..where((s) => s.projectId.equals(set.projectId))).get();
      final siteId = await insertSite(
        LocationSitesCompanion.insert(
          projectId: set.projectId,
          name: set.locationName,
          description: Value(set.description),
          notes: Value(set.notes),
          sortOrder: Value(sites.length),
        ),
      );
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
        await update(
          scenes,
        ).replace(scene.copyWith(locationSiteId: Value(siteId)));
      }
    }
  }

  // ── Grupos ─────────────────────────────────────
  Future<List<ProjectGroup>> getAllGroups() => (select(
    projectGroups,
  )..orderBy([(g) => OrderingTerm.asc(g.sortOrder)])).get();

  Stream<List<ProjectGroup>> watchAllGroups() => (select(
    projectGroups,
  )..orderBy([(g) => OrderingTerm.asc(g.sortOrder)])).watch();

  Future<int> insertGroup(ProjectGroupsCompanion g) =>
      into(projectGroups).insert(g);
  Future<bool> updateGroup(ProjectGroup g) => update(projectGroups).replace(g);
  Future<int> deleteGroup(int id) =>
      (delete(projectGroups)..where((g) => g.id.equals(id))).go();

  // ── Proyectos ─────────────────────────────────
  Stream<List<Project>> watchProjects() => (select(
    projects,
  )..orderBy([(p) => OrderingTerm.asc(p.sortOrder)])).watch();

  Stream<List<Project>> watchProjectsByGroup(int? groupId) {
    return (select(projects)
          ..where(
            (p) => groupId == null
                ? p.groupId.isNull()
                : p.groupId.equals(groupId),
          )
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .watch();
  }

  Future<int> insertProject(ProjectsCompanion project) =>
      into(projects).insert(project);
  Future<bool> updateProject(Project project) =>
      update(projects).replace(project);
  Future<int> deleteProject(int id) async {
    await deleteProjectFully(id);
    return 1;
  }

  /// Elimina proyecto, datos relacionados y archivos en disco.
  Future<void> deleteProjectFully(int id) async {
    await transaction(() async {
      final projectShots = await (select(
        shots,
      )..where((s) => s.projectId.equals(id))).get();
      for (final shot in projectShots) {
        await (delete(
          shotReferences,
        )..where((r) => r.shotId.equals(shot.id))).go();
      }
      await (delete(shots)..where((s) => s.projectId.equals(id))).go();
      await (delete(scenes)..where((s) => s.projectId.equals(id))).go();
      await (delete(
        projectEquipment,
      )..where((e) => e.projectId.equals(id))).go();

      final sets = await (select(
        locationBasePlans,
      )..where((l) => l.projectId.equals(id))).get();
      for (final set in sets) {
        await (delete(
          locationImages,
        )..where((i) => i.locationId.equals(set.id))).go();
      }
      await (delete(
        locationBasePlans,
      )..where((l) => l.projectId.equals(id))).go();

      final sites = await (select(
        locationSites,
      )..where((s) => s.projectId.equals(id))).get();
      for (final site in sites) {
        await (delete(siteImages)..where((i) => i.siteId.equals(site.id))).go();
      }
      await (delete(locationSites)..where((s) => s.projectId.equals(id))).go();

      final shootDocs = await (select(
        shootDocuments,
      )..where((d) => d.projectId.equals(id))).get();
      for (final doc in shootDocs) {
        await (delete(
          shootDocumentBlocks,
        )..where((b) => b.documentId.equals(doc.id))).go();
      }
      await (delete(shootDocuments)..where((d) => d.projectId.equals(id))).go();

      await (delete(projects)..where((p) => p.id.equals(id))).go();
    });
    await MediaStorage.deleteProjectDirectory(id);
  }

  /// Elimina todo el contenido del proyecto pero conserva la fila Projects.
  Future<void> deleteProjectContentOnly(int id) async {
    await transaction(() async {
      final vbs = await (select(
        visualBibles,
      )..where((v) => v.projectId.equals(id))).get();
      await (delete(
        visualBibleDocuments,
      )..where((d) => d.projectId.equals(id))).go();
      for (final vb in vbs) {
        await (delete(
          bibleComments,
        )..where((c) => c.bibleId.equals(vb.id))).go();
        await (delete(
          bibleSectionDefinitions,
        )..where((s) => s.bibleId.equals(vb.id))).go();
        await (delete(
          bibleSectionGroups,
        )..where((g) => g.bibleId.equals(vb.id))).go();
        await (delete(
          bibleSectionEvidence,
        )..where((e) => e.bibleId.equals(vb.id))).go();
        await (delete(
          exposureBlocks,
        )..where((e) => e.bibleId.equals(vb.id))).go();
        await (delete(
          lightingSetups,
        )..where((l) => l.bibleId.equals(vb.id))).go();
        await (delete(cameraTests)..where((c) => c.bibleId.equals(vb.id))).go();
        await (delete(
          visualBibleLocationRefs,
        )..where((r) => r.bibleId.equals(vb.id))).go();
        await (delete(
          visualBibleColorBlocks,
        )..where((b) => b.bibleId.equals(vb.id))).go();
        await (delete(
          visualBibleVersions,
        )..where((v) => v.bibleId.equals(vb.id))).go();
      }
      await (delete(visualBibles)..where((v) => v.projectId.equals(id))).go();
      await (delete(lookBibles)..where((l) => l.projectId.equals(id))).go();
      await (delete(
        moodboardImages,
      )..where((m) => m.projectId.equals(id))).go();
      await (delete(
        moodboardGroups,
      )..where((g) => g.projectId.equals(id))).go();
      await (delete(
        opticsLabSamples,
      )..where((o) => o.projectId.equals(id))).go();
      await (delete(
        projectAnnotatedPdfs,
      )..where((p) => p.projectId.equals(id))).go();
      await (delete(
        projectAnnotationDocuments,
      )..where((a) => a.projectId.equals(id))).go();

      final projectShots = await (select(
        shots,
      )..where((s) => s.projectId.equals(id))).get();
      for (final shot in projectShots) {
        final elements = await getCameraPlanElementsForShot(shot.id);
        for (final el in elements) {
          await deleteCameraPlanElement(el.id);
        }
        await (delete(
          shotReferences,
        )..where((r) => r.shotId.equals(shot.id))).go();
      }
      await (delete(shots)..where((s) => s.projectId.equals(id))).go();
      await (delete(scenes)..where((s) => s.projectId.equals(id))).go();
      await (delete(
        projectEquipment,
      )..where((e) => e.projectId.equals(id))).go();

      final shootDocs = await (select(
        shootDocuments,
      )..where((d) => d.projectId.equals(id))).get();
      for (final doc in shootDocs) {
        await (delete(
          shootDocumentBlocks,
        )..where((b) => b.documentId.equals(doc.id))).go();
      }
      await (delete(shootDocuments)..where((d) => d.projectId.equals(id))).go();

      final sets = await (select(
        locationBasePlans,
      )..where((l) => l.projectId.equals(id))).get();
      for (final set in sets) {
        await (delete(
          locationImages,
        )..where((i) => i.locationId.equals(set.id))).go();
      }
      await (delete(
        locationBasePlans,
      )..where((l) => l.projectId.equals(id))).go();

      final sites = await (select(
        locationSites,
      )..where((s) => s.projectId.equals(id))).get();
      for (final site in sites) {
        await (delete(siteImages)..where((i) => i.siteId.equals(site.id))).go();
      }
      await (delete(locationSites)..where((s) => s.projectId.equals(id))).go();
    });
  }

  /// Marca el contenido del proyecto como modificado (sync cloud).
  Future<void> touchProjectContent(int projectId) async {
    await (update(projects)..where((p) => p.id.equals(projectId))).write(
      ProjectsCompanion(
        contentSyncUpdatedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    final project = await getProject(projectId);
    if (project?.cloudId != null) {
      final pending =
          await (select(cloudSyncQueue)..where(
                (q) =>
                    q.entityType.equals('project_content') &
                    q.localEntityId.equals('$projectId') &
                    q.processed.equals(false),
              ))
              .get();
      if (pending.isEmpty) {
        await into(cloudSyncQueue).insert(
          CloudSyncQueueCompanion.insert(
            entityType: 'project_content',
            localEntityId: '$projectId',
            operation: 'upsert',
            payloadJson: Value('{"cloudId":"${project!.cloudId}"}'),
          ),
        );
      }
    }
  }

  Future<Project?> getProject(int id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  // Duplicar proyecto: copia escenas, planos, localizaciones e imágenes.
  Future<int> duplicateProject(int sourceId) async {
    final source = await getProject(sourceId);
    if (source == null) return -1;

    final newId = await insertProject(
      ProjectsCompanion.insert(
        name: '${source.name} (copia)',
        director: Value(source.director),
        description: Value(source.description),
        clientName: Value(source.clientName),
        status: Value(source.status),
        iconCode: Value(source.iconCode),
        groupId: Value(source.groupId),
        scriptFileName: Value(source.scriptFileName),
      ),
    );

    if (source.scriptFilePath != null) {
      final scriptPath = await MediaStorage.duplicateScriptFile(
        sourceProjectId: sourceId,
        destProjectId: newId,
        sourcePath: source.scriptFilePath,
      );
      if (scriptPath != null) {
        final created = (await getProject(newId))!;
        await updateProject(
          created.copyWith(
            scriptFilePath: Value(scriptPath),
            scriptFileName: Value(source.scriptFileName),
          ),
        );
      }
    }

    final siteIdMap = <int, int>{};
    final sourceSites = await (select(
      locationSites,
    )..where((s) => s.projectId.equals(sourceId))).get();
    for (final site in sourceSites) {
      final newSiteId = await insertSite(
        LocationSitesCompanion.insert(
          projectId: newId,
          name: site.name,
          description: Value(site.description),
          notes: Value(site.notes),
          floorPlanJson: Value(site.floorPlanJson),
          scanPath: Value(site.scanPath),
          scanSource: Value(site.scanSource),
          scanMetadataJson: Value(site.scanMetadataJson),
          sortOrder: Value(site.sortOrder),
        ),
      );
      siteIdMap[site.id] = newSiteId;

      final siteImagesList = await (select(
        siteImages,
      )..where((i) => i.siteId.equals(site.id))).get();
      for (final img in siteImagesList) {
        final newPath = await MediaStorage.duplicateImageFile(
          destProjectId: newId,
          sourcePath: img.imagePath,
          subfolder: 'sites/$newSiteId',
          prefix: 'img',
        );
        if (newPath != null) {
          await insertSiteImage(
            SiteImagesCompanion.insert(
              siteId: newSiteId,
              imagePath: newPath,
              caption: Value(img.caption),
              kind: Value(img.kind),
              timeOfDay: Value(img.timeOfDay),
              sortOrder: Value(img.sortOrder),
            ),
          );
        }
      }
    }

    final setIdMap = <int, int>{};
    final sourceSets = await (select(
      locationBasePlans,
    )..where((l) => l.projectId.equals(sourceId))).get();
    for (final set in sourceSets) {
      final newSiteId = set.siteId != null ? siteIdMap[set.siteId!] : null;
      final newSetId = await insertLocation(
        LocationBasePlansCompanion.insert(
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
        ),
      );
      setIdMap[set.id] = newSetId;

      final locImages = await (select(
        locationImages,
      )..where((i) => i.locationId.equals(set.id))).get();
      for (final img in locImages) {
        final newPath = await MediaStorage.duplicateImageFile(
          destProjectId: newId,
          sourcePath: img.imagePath,
          subfolder: 'locations/$newSetId',
          prefix: 'img',
        );
        if (newPath != null) {
          await insertLocationImage(
            LocationImagesCompanion.insert(
              locationId: newSetId,
              imagePath: newPath,
              caption: Value(img.caption),
              kind: Value(img.kind),
              timeOfDay: Value(img.timeOfDay),
              sortOrder: Value(img.sortOrder),
            ),
          );
        }
      }
    }

    final sceneIdMap = <int, int>{};
    final sourceScenes = await (select(
      scenes,
    )..where((s) => s.projectId.equals(sourceId))).get();

    for (final scene in sourceScenes) {
      final newSceneId = await into(scenes).insert(
        ScenesCompanion.insert(
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
            scene.locationSiteId != null
                ? siteIdMap[scene.locationSiteId!]
                : null,
          ),
          sortOrder: Value(scene.sortOrder),
        ),
      );
      sceneIdMap[scene.id] = newSceneId;

      final sourceShots = await (select(
        shots,
      )..where((s) => s.sceneId.equals(scene.id))).get();

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

        final newShotId = await into(shots).insert(
          ShotsCompanion.insert(
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
          ),
        );

        await _copyCameraPlanElements(
          sourceShotId: shot.id,
          destShotId: newShotId,
        );
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

  Future<int> insertScene(ScenesCompanion scene) async {
    final id = await into(scenes).insert(scene);
    await touchProjectContent(scene.projectId.value);
    return id;
  }

  Future<bool> updateScene(Scene scene) async {
    final ok = await update(scenes).replace(scene);
    await touchProjectContent(scene.projectId);
    return ok;
  }

  Future<int> deleteScene(int id) async {
    final scene = await (select(
      scenes,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    final count = await (delete(scenes)..where((s) => s.id.equals(id))).go();
    if (scene != null) await touchProjectContent(scene.projectId);
    return count;
  }

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
    await touchProjectContent(projectId);
  }

  /// Sincroniza escenas desde el espacio de trabajo preservando planos cuando es posible.
  Future<void> syncScenesFromWorkspace(
    int projectId,
    List<
      ({
        String intExt,
        String dayNight,
        String location,
        String shootSet,
        String locationSite,
        String? name,
        String? description,
        String? locationColor,
        String? charactersJson,
        int? sourceStartIndex,
      })
    >
    items,
  ) async {
    await transaction(() async {
      final existing = await (select(
        scenes,
      )..where((s) => s.projectId.equals(projectId))).get();

      final matchedIds = <int>{};

      for (var i = 0; i < items.length; i++) {
        final order = i + 1;
        final s = items[i];
        final siteName = s.locationSite.trim().isEmpty
            ? s.shootSet.trim()
            : s.locationSite.trim();
        final site = await ensureSite(projectId: projectId, siteName: siteName);
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

        final name = s.name != null && s.name!.trim().isNotEmpty
            ? s.name!.trim()
            : formatSceneDefaultName(
                intExt: s.intExt,
                dayNight: s.dayNight,
                location: s.location,
              );
        final canonical = '${s.intExt}. ${s.location} - ${s.dayNight}';

        if (match != null) {
          matchedIds.add(match.id);
          await update(scenes).replace(
            match.copyWith(
              number: order,
              name: name,
              locationCanonical: canonical,
              locationPureName: s.shootSet.trim(),
              locationSiteId: Value(siteId),
              intExt: s.intExt,
              dayNight: s.dayNight,
              locationColor: Value(s.locationColor),
              charactersJson: Value(s.charactersJson),
              description: Value(s.description),
              sourceStartIndex: Value(s.sourceStartIndex),
              sortOrder: order,
            ),
          );
        } else {
          await into(scenes).insert(
            ScenesCompanion.insert(
              projectId: projectId,
              number: order,
              name: name,
              locationCanonical: canonical,
              locationPureName: s.shootSet.trim(),
              locationSiteId: Value(siteId),
              intExt: Value(s.intExt),
              dayNight: Value(s.dayNight),
              locationColor: Value(s.locationColor),
              charactersJson: Value(s.charactersJson),
              description: Value(s.description),
              sourceStartIndex: Value(s.sourceStartIndex),
              sortOrder: Value(order),
            ),
          );
        }
      }

      for (final old in existing) {
        if (matchedIds.contains(old.id)) continue;
        await (delete(shots)..where((sh) => sh.sceneId.equals(old.id))).go();
        await (delete(scenes)..where((sc) => sc.id.equals(old.id))).go();
      }

      await linkScenesToLocations(projectId);
    });
    await touchProjectContent(projectId);
  }

  /// Escenas que se eliminarían al sincronizar y tienen planos.
  Future<List<Scene>> findScenesWithShotsToRemoveOnSync(
    int projectId,
    List<int?> sourceStartIndices,
    int newCount,
  ) async {
    final existing =
        await (select(scenes)
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

    final toRemove = existing
        .where((e) => !keepIds.contains(e.id))
        .toList(growable: false);
    if (toRemove.isEmpty) return [];

    final result = <Scene>[];
    for (final scene in toRemove) {
      final shotCount = await (select(
        shots,
      )..where((s) => s.sceneId.equals(scene.id))).get();
      if (shotCount.isNotEmpty) result.add(scene);
    }
    return result;
  }

  // Localizaciones únicas de un proyecto (para dropdown)
  Future<List<String>> getUniqueLocations(int projectId) async {
    final allScenes = await (select(
      scenes,
    )..where((s) => s.projectId.equals(projectId))).get();
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
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .get();

  Stream<List<Shot>> watchShotsForProject(int projectId) =>
      (select(shots)
            ..where((s) => s.projectId.equals(projectId))
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .watch();

  Future<int> insertShot(ShotsCompanion shot) async {
    final id = await into(shots).insert(shot);
    await touchProjectContent(shot.projectId.value);
    return id;
  }

  Future<bool> updateShot(Shot shot) async {
    final ok = await update(shots).replace(shot);
    await touchProjectContent(shot.projectId);
    return ok;
  }

  Future<int> deleteShot(int id) async {
    final shot = await (select(
      shots,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    final elements = await getCameraPlanElementsForShot(id);
    for (final el in elements) {
      await deleteCameraPlanElement(el.id);
    }
    final count = await (delete(shots)..where((s) => s.id.equals(id))).go();
    if (shot != null) await touchProjectContent(shot.projectId);
    return count;
  }

  Future<int> countShotsWithCameraPlan(int projectId) async {
    final projectShots = await getShotsForProject(projectId);
    if (projectShots.isEmpty) return 0;
    final shotIds = projectShots.map((s) => s.id).toList();
    final elements = await (select(
      cameraPlanElements,
    )..where((e) => e.shotId.isIn(shotIds))).get();
    return elements.map((e) => e.shotId).toSet().length;
  }

  // ── Documentos de rodaje ───────────────────────
  Stream<List<ShootDocument>> watchShootDocumentsForProject(int projectId) =>
      (select(shootDocuments)
            ..where((d) => d.projectId.equals(projectId))
            ..orderBy([
              (d) => OrderingTerm.desc(d.isPrimaryOnSet),
              (d) => OrderingTerm.desc(d.updatedAt),
            ]))
          .watch();

  Future<ShootDocument?> getShootDocument(int id) =>
      (select(shootDocuments)..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<int> insertShootDocument(ShootDocumentsCompanion doc) async {
    final id = await into(shootDocuments).insert(doc);
    await touchProjectContent(doc.projectId.value);
    return id;
  }

  Future<bool> updateShootDocument(ShootDocument doc) async {
    final ok = await update(shootDocuments).replace(doc);
    await touchProjectContent(doc.projectId);
    return ok;
  }

  Future<int> deleteShootDocument(int id) async {
    final doc = await getShootDocument(id);
    await (delete(
      shootDocumentBlocks,
    )..where((b) => b.documentId.equals(id))).go();
    final count = await (delete(
      shootDocuments,
    )..where((d) => d.id.equals(id))).go();
    if (doc != null) await touchProjectContent(doc.projectId);
    return count;
  }

  Future<void> setPrimaryShootDocument(int projectId, int documentId) async {
    await transaction(() async {
      await (update(shootDocuments)
            ..where((d) => d.projectId.equals(projectId)))
          .write(const ShootDocumentsCompanion(isPrimaryOnSet: Value(false)));
      await (update(shootDocuments)..where((d) => d.id.equals(documentId)))
          .write(const ShootDocumentsCompanion(isPrimaryOnSet: Value(true)));
    });
    await touchProjectContent(projectId);
  }

  Stream<List<ShootDocumentBlock>> watchBlocksForShootDocument(
    int documentId,
  ) =>
      (select(shootDocumentBlocks)
            ..where((b) => b.documentId.equals(documentId))
            ..orderBy([(b) => OrderingTerm.asc(b.sortOrder)]))
          .watch();

  Future<List<ShootDocumentBlock>> getBlocksForShootDocument(int documentId) =>
      (select(shootDocumentBlocks)
            ..where((b) => b.documentId.equals(documentId))
            ..orderBy([(b) => OrderingTerm.asc(b.sortOrder)]))
          .get();

  Future<int> insertShootDocumentBlock(
    ShootDocumentBlocksCompanion block,
  ) async {
    final id = await into(shootDocumentBlocks).insert(block);
    final doc = await getShootDocument(block.documentId.value);
    if (doc != null) await touchProjectContent(doc.projectId);
    return id;
  }

  Future<bool> updateShootDocumentBlock(ShootDocumentBlock block) async {
    final ok = await update(shootDocumentBlocks).replace(block);
    final doc = await getShootDocument(block.documentId);
    if (doc != null) await touchProjectContent(doc.projectId);
    return ok;
  }

  Future<int> deleteShootDocumentBlock(int id) async {
    final block = await (select(
      shootDocumentBlocks,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    final count = await (delete(
      shootDocumentBlocks,
    )..where((b) => b.id.equals(id))).go();
    if (block != null) {
      final doc = await getShootDocument(block.documentId);
      if (doc != null) await touchProjectContent(doc.projectId);
    }
    return count;
  }

  Future<void> reorderShootDocumentBlocks(
    int documentId,
    List<int> blockIdsInOrder,
  ) async {
    await transaction(() async {
      for (var i = 0; i < blockIdsInOrder.length; i++) {
        await (update(shootDocumentBlocks)..where(
              (b) =>
                  b.id.equals(blockIdsInOrder[i]) &
                  b.documentId.equals(documentId),
            ))
            .write(ShootDocumentBlocksCompanion(sortOrder: Value(i)));
      }
    });
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
      await (update(locationBasePlans)..where((l) => l.siteId.equals(id)))
          .write(const LocationBasePlansCompanion(siteId: Value(null)));
      await (delete(locationSites)..where((s) => s.id.equals(id))).go();
    });
  }

  Stream<List<LocationBasePlan>> watchSetsForSite(int siteId) =>
      (select(locationBasePlans)
            ..where((l) => l.siteId.equals(siteId))
            ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
          .watch();

  Future<int> countSetsForSite(int siteId) async {
    final rows = await (select(
      locationBasePlans,
    )..where((l) => l.siteId.equals(siteId))).get();
    return rows.length;
  }

  Future<LocationSite?> findSiteByName(int projectId, String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;
    final sites = await (select(
      locationSites,
    )..where((s) => s.projectId.equals(projectId))).get();
    for (final site in sites) {
      if (site.name.trim().toLowerCase() == key) return site;
    }
    return null;
  }

  Future<LocationBasePlan?> findSetInSite(int siteId, String setName) async {
    final key = setName.trim().toLowerCase();
    if (key.isEmpty) return null;
    final sets = await (select(
      locationBasePlans,
    )..where((l) => l.siteId.equals(siteId))).get();
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
      final sites = await (select(
        locationSites,
      )..where((s) => s.projectId.equals(projectId))).get();
      final siteId = await insertSite(
        LocationSitesCompanion.insert(
          projectId: projectId,
          name: siteKey,
          sortOrder: Value(sites.length),
        ),
      );
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

    final sets = await (select(
      locationBasePlans,
    )..where((l) => l.siteId.equals(site.id))).get();

    // Si ya hay sets pero ninguno coincide con el nombre del sitio, reutiliza el primero.
    if (sets.isNotEmpty) {
      return sets.first;
    }

    final baseHex = await _siteBaseHexForSite(projectId: projectId, site: site);
    final setId = await insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(site.id),
        locationName: site.name,
        color: Value(baseHex),
        sortOrder: const Value(0),
      ),
    );
    return (await getLocationById(setId))!;
  }

  Future<int> _siteIndexForSite({
    required int projectId,
    required LocationSite site,
  }) async {
    final sites =
        await (select(locationSites)
              ..where((s) => s.projectId.equals(projectId))
              ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
            .get();
    final idx = sites.indexWhere((s) => s.id == site.id);
    return idx >= 0 ? idx : sites.length;
  }

  Future<String> _siteBaseHexForSite({
    required int projectId,
    required LocationSite site,
  }) async {
    final sites =
        await (select(locationSites)
              ..where((s) => s.projectId.equals(projectId))
              ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
            .get();
    final idx = sites.indexWhere((s) => s.id == site.id);
    return siteBaseHexForIndex(idx >= 0 ? idx : sites.length);
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
      final sets = await (select(
        locationBasePlans,
      )..where((l) => l.siteId.equals(site.id))).get();
      final setCount = sets.length + 1;
      final siteIndex = await _siteIndexForSite(
        projectId: projectId,
        site: site,
      );
      final defaultHex = defaultSetHexForSite(
        siteIndex: siteIndex,
        setIndex: sets.length,
        totalSets: setCount,
        explicitHex: colorHex,
      );
      final setId = await insertLocation(
        LocationBasePlansCompanion.insert(
          projectId: projectId,
          siteId: Value(site.id),
          locationName: setKey,
          color: Value(defaultHex),
          sortOrder: Value(sets.length),
        ),
      );
      set = (await getLocationById(setId))!;
    } else if (colorHex != null && set.color != colorHex) {
      await updateLocation(set.copyWith(color: colorHex));
      set = (await getLocationById(set.id))!;
    }

    return (site: site, set: set);
  }

  /// Crea localización con un set inicial del mismo nombre (caso simple).
  Future<({LocationSite site, LocationBasePlan set})>
  createLocationWithDefaultSet(
    int projectId,
    String name, {
    String? colorHex,
  }) => ensureSiteAndSet(
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

    final sites = await (select(
      locationSites,
    )..where((s) => s.projectId.equals(set.projectId))).get();

    final siteId = await insertSite(
      LocationSitesCompanion.insert(
        projectId: set.projectId,
        name: set.locationName,
        description: Value(set.description),
        notes: Value(set.notes),
        sortOrder: Value(sites.length),
      ),
    );

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
    final site = await getSiteById(siteId);
    if (site == null) throw StateError('Localización no encontrada');

    final sets = await (select(
      locationBasePlans,
    )..where((l) => l.siteId.equals(siteId))).get();
    final siteIndex = await _siteIndexForSite(projectId: projectId, site: site);
    final defaultHex = defaultSetHexForSite(
      siteIndex: siteIndex,
      setIndex: sets.length,
      totalSets: sets.length + 1,
      explicitHex: color,
    );

    return insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: name,
        color: Value(defaultHex),
        sortOrder: Value(sortOrder ?? sets.length),
      ),
    );
  }

  // ── Sets de rodaje ────────────────────────────
  Stream<List<LocationBasePlan>> watchLocationsForProject(int projectId) =>
      (select(locationBasePlans)
            ..where((l) => l.projectId.equals(projectId))
            ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
          .watch();

  Future<LocationBasePlan?> getLocationById(int id) => (select(
    locationBasePlans,
  )..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<Map<int, LocationBasePlan>> getLocationsMapForProject(
    int projectId,
  ) async {
    final list = await (select(
      locationBasePlans,
    )..where((l) => l.projectId.equals(projectId))).get();
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
      await (delete(
        locationImages,
      )..where((i) => i.locationId.equals(id))).go();
      await (delete(locationBasePlans)..where((l) => l.id.equals(id))).go();
    });
  }

  Future<int> deleteLocationAndUnlink(
    int projectId,
    String locationName,
  ) async {
    final loc =
        await (select(locationBasePlans)..where(
              (l) =>
                  l.projectId.equals(projectId) &
                  l.locationName.equals(locationName),
            ))
            .getSingleOrNull();
    if (loc == null) return 0;
    await deleteLocation(loc.id);
    return 1;
  }

  /// Crea localizaciones y sets a partir de escenas.
  Future<int> syncLocationsFromScenes(int projectId) async {
    final sceneList = await (select(
      scenes,
    )..where((s) => s.projectId.equals(projectId))).get();

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
    final siteOrder = <String>[];
    for (final entry in grouped.values) {
      final key = entry.siteName.trim().toLowerCase();
      if (!siteOrder.contains(key)) siteOrder.add(key);
    }

    for (final entry in grouped.values) {
      final existingSite = await findSiteByName(projectId, entry.siteName);
      final setsBefore = existingSite != null
          ? await countSetsForSite(existingSite.id)
          : 0;

      final site = await ensureSite(
        projectId: projectId,
        siteName: entry.siteName,
      );
      final setsAfter = await countSetsForSite(site.id);
      created += setsAfter - setsBefore;

      final normalizedSite = entry.siteName.trim().toLowerCase();
      final siteIdx = siteOrder.indexOf(normalizedSite);
      final siteSets =
          await (select(locationBasePlans)
                ..where((l) => l.siteId.equals(site.id))
                ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
              .get();
      var setIndex = siteSets.length;

      for (final setName in entry.setNames) {
        if (setName.trim().toLowerCase() == normalizedSite) continue;
        final existingSet = await findSetInSite(site.id, setName);
        if (existingSet != null) continue;
        final totalSets = setIndex + 1;
        await ensureSiteAndSet(
          projectId: projectId,
          siteName: entry.siteName,
          setName: setName,
          colorHex: defaultSetHexForSite(
            siteIndex: siteIdx >= 0 ? siteIdx : siteOrder.length,
            setIndex: setIndex,
            totalSets: totalSets,
          ),
        );
        setIndex++;
        created++;
      }
    }

    await linkScenesToLocations(projectId);
    return created;
  }

  /// Vincula escenas a sets por localización + nombre de set.
  Future<int> linkScenesToLocations(int projectId) async {
    final sceneList = await (select(
      scenes,
    )..where((s) => s.projectId.equals(projectId))).get();
    final sets = await (select(
      locationBasePlans,
    )..where((l) => l.projectId.equals(projectId))).get();
    final setsBySiteAndName = <String, int>{};
    for (final set in sets) {
      if (set.siteId == null) continue;
      final key = '${set.siteId}|${set.locationName.trim().toLowerCase()}';
      setsBySiteAndName[key] = set.id;
    }

    var linked = 0;
    for (final scene in sceneList) {
      final setKey = scene.locationPureName.trim().toLowerCase();

      int? siteId = scene.locationSiteId;
      if (siteId == null && setKey.isNotEmpty) {
        final site = await findSiteByName(
          projectId,
          scene.locationPureName.trim(),
        );
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
          setId =
              setsBySiteAndName['$siteId|${site.name.trim().toLowerCase()}'];
        }
      }

      if (scene.locationSiteId == siteId && scene.locationId == setId) {
        continue;
      }

      await update(scenes).replace(
        scene.copyWith(locationSiteId: Value(siteId), locationId: Value(setId)),
      );
      linked++;
    }
    return linked;
  }

  /// Quita overrides de color en escenas vinculadas para heredar el set.
  Future<int> applyLocationColorToLinkedScenes(int locationId) async {
    final affected = await (select(
      scenes,
    )..where((s) => s.locationId.equals(locationId))).get();
    for (final scene in affected) {
      await update(
        scenes,
      ).replace(scene.copyWith(locationColor: const Value(null)));
    }
    return affected.length;
  }

  /// Quita overrides de escenas de una localización contenedora.
  Future<int> clearSceneColorOverridesForSite(int siteId) async {
    final affected = await (select(
      scenes,
    )..where((s) => s.locationSiteId.equals(siteId))).get();
    for (final scene in affected) {
      await update(
        scenes,
      ).replace(scene.copyWith(locationColor: const Value(null)));
    }
    return affected.length;
  }

  /// Color solo en una escena.
  Future<void> applySceneColorOverride(int sceneId, String? colorHex) async {
    final scene = await (select(
      scenes,
    )..where((s) => s.id.equals(sceneId))).getSingleOrNull();
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
    final siteSets =
        await (select(locationBasePlans)
              ..where((l) => l.siteId.equals(siteId))
              ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
            .get();
    final variants = setVariantHexesForSiteBase(baseColorHex, siteSets.length);
    for (var i = 0; i < siteSets.length; i++) {
      await updateLocation(siteSets[i].copyWith(color: variants[i]));
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
      final compositeKey = entry.key;
      final pipe = compositeKey.indexOf('|');
      final setName = pipe >= 0
          ? compositeKey.substring(pipe + 1)
          : compositeKey;
      final siteName =
          siteBySetKey[compositeKey] ??
          (pipe >= 0 ? compositeKey.substring(0, pipe) : compositeKey);
      await upsertSetColor(projectId, siteName, setName, entry.value);
    }
  }

  Stream<List<Scene>> watchScenesForSite(int siteId) =>
      (select(scenes)
            ..where((s) => s.locationSiteId.equals(siteId))
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .watch();

  Future<int> countScenesForSite(int siteId) async {
    final rows = await (select(
      scenes,
    )..where((s) => s.locationSiteId.equals(siteId))).get();
    return rows.length;
  }

  Stream<List<Scene>> watchScenesForLocation(int locationId) =>
      (select(scenes)
            ..where((s) => s.locationId.equals(locationId))
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .watch();

  Future<int> countScenesForLocation(int locationId) async {
    final rows = await (select(
      scenes,
    )..where((s) => s.locationId.equals(locationId))).get();
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
    await (delete(
      cameraPathPoints,
    )..where((p) => p.elementId.equals(elementId))).go();
    for (var i = 0; i < points.length; i++) {
      await into(cameraPathPoints).insert(
        CameraPathPointsCompanion.insert(
          elementId: elementId,
          pointNumber: i + 1,
          x: points[i].x,
          y: points[i].y,
        ),
      );
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
            ..where((e) => e.projectId.equals(projectId))
            ..orderBy([
              (e) => OrderingTerm.asc(e.sortOrder),
              (e) => OrderingTerm.asc(e.id),
            ]))
          .watch();

  Future<List<ProjectEquipmentData>> getProjectEquipment(int projectId) =>
      (select(projectEquipment)
            ..where((e) => e.projectId.equals(projectId))
            ..orderBy([
              (e) => OrderingTerm.asc(e.sortOrder),
              (e) => OrderingTerm.asc(e.id),
            ]))
          .get();

  Future<bool> isEquipmentAssigned({
    required int projectId,
    required String equipmentType,
    required int equipmentId,
  }) async {
    final row =
        await (select(projectEquipment)..where(
              (e) =>
                  e.projectId.equals(projectId) &
                  e.equipmentType.equals(equipmentType) &
                  e.equipmentId.equals(equipmentId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<int> assignEquipmentToProject({
    required int projectId,
    required String equipmentType,
    required int equipmentId,
    String source = 'rental',
    String status = 'available',
    String? notes,
    int sortOrder = 0,
  }) async {
    if (await isEquipmentAssigned(
      projectId: projectId,
      equipmentType: equipmentType,
      equipmentId: equipmentId,
    )) {
      return 0;
    }
    return into(projectEquipment).insert(
      ProjectEquipmentCompanion.insert(
        projectId: projectId,
        equipmentType: equipmentType,
        equipmentId: equipmentId,
        source: Value(source),
        status: Value(status),
        notes: Value(notes),
        sortOrder: Value(sortOrder),
      ),
    );
  }

  Future<bool> updateProjectEquipmentAssignment({
    required int assignmentId,
    String? source,
    String? status,
    String? notes,
    int? sortOrder,
  }) async {
    final row = await (select(
      projectEquipment,
    )..where((e) => e.id.equals(assignmentId))).getSingleOrNull();
    if (row == null) return false;
    return update(projectEquipment).replace(
      row.copyWith(
        source: source ?? row.source,
        status: status ?? row.status,
        notes: Value(notes ?? row.notes),
        sortOrder: sortOrder ?? row.sortOrder,
      ),
    );
  }

  Future<void> clearProjectEquipment(int projectId) async {
    await (delete(
      projectEquipment,
    )..where((e) => e.projectId.equals(projectId))).go();
  }

  Future<int> unassignProjectEquipment(int assignmentId) =>
      (delete(projectEquipment)..where((e) => e.id.equals(assignmentId))).go();

  Future<Camera?> getCameraById(int id) =>
      (select(cameras)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<Lense?> getLensById(int id) =>
      (select(lenses)..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<Light?> getLightById(int id) =>
      (select(lights)..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<Camera?> getCameraByExternalId(String externalId) => (select(
    cameras,
  )..where((c) => c.externalId.equals(externalId))).getSingleOrNull();

  Future<Lense?> getLensByExternalId(String externalId) => (select(
    lenses,
  )..where((l) => l.externalId.equals(externalId))).getSingleOrNull();

  Future<Light?> getLightByExternalId(String externalId) => (select(
    lights,
  )..where((l) => l.externalId.equals(externalId))).getSingleOrNull();

  Future<Camera?> getCameraByBrandModel(String brand, String model) =>
      (select(cameras)
            ..where((c) => c.brand.equals(brand) & c.model.equals(model)))
          .getSingleOrNull();

  Future<Lense?> getLensByBrandModel(String brand, String model) =>
      (select(lenses)
            ..where((l) => l.brand.equals(brand) & l.model.equals(model)))
          .getSingleOrNull();

  Future<Light?> getLightByBrandModel(String brand, String model) =>
      (select(lights)
            ..where((l) => l.brand.equals(brand) & l.model.equals(model)))
          .getSingleOrNull();

  Future<List<Camera>> getAllCameras() =>
      (select(cameras)..orderBy([(c) => OrderingTerm.asc(c.brand)])).get();

  Future<List<Lense>> getAllLenses() =>
      (select(lenses)..orderBy([(l) => OrderingTerm.asc(l.brand)])).get();

  Future<List<Light>> getAllLights() =>
      (select(lights)..orderBy([(l) => OrderingTerm.asc(l.brand)])).get();

  Future<List<Camera>> getCustomCameras() =>
      (select(cameras)..where((c) => c.isCustom.equals(true))).get();

  Future<List<Lense>> getCustomLenses() =>
      (select(lenses)..where((l) => l.isCustom.equals(true))).get();

  Future<List<Light>> getCustomLights() =>
      (select(lights)..where((l) => l.isCustom.equals(true))).get();

  Future<int> insertCamera(CamerasCompanion row) => into(cameras).insert(row);

  Future<bool> updateCamera(Camera row) => update(cameras).replace(row);

  Future<int> deleteCamera(int id) =>
      (delete(cameras)..where((c) => c.id.equals(id))).go();

  Future<int> insertLens(LensesCompanion row) => into(lenses).insert(row);

  Future<bool> updateLens(Lense row) => update(lenses).replace(row);

  Future<int> deleteLens(int id) =>
      (delete(lenses)..where((l) => l.id.equals(id))).go();

  Future<int> insertLight(LightsCompanion row) => into(lights).insert(row);

  Future<bool> updateLight(Light row) => update(lights).replace(row);

  Future<int> deleteLight(int id) =>
      (delete(lights)..where((l) => l.id.equals(id))).go();

  Future<CatalogSyncMetaData?> getCatalogSyncMeta() =>
      select(catalogSyncMeta).getSingleOrNull();

  Future<void> upsertCatalogSyncMeta(CatalogSyncMetaCompanion row) async {
    final existing = await getCatalogSyncMeta();
    if (existing == null) {
      await into(catalogSyncMeta).insert(row);
    } else {
      await (update(catalogSyncMeta)..where((m) => m.id.equals(existing.id)))
          .write(row.copyWith(id: Value(existing.id)));
    }
  }

  Future<LukaSyncMetaData?> getLukaSyncMeta() =>
      select(lukaSyncMeta).getSingleOrNull();

  Future<void> upsertLukaSyncMeta(LukaSyncMetaCompanion row) async {
    final existing = await getLukaSyncMeta();
    if (existing == null) {
      await into(lukaSyncMeta).insert(row);
    } else {
      await (update(lukaSyncMeta)..where((m) => m.id.equals(existing.id)))
          .write(row.copyWith(id: Value(existing.id)));
    }
  }

  Stream<List<BibleSectionEvidenceData>> watchEvidenceForBible(
    int bibleId, {
    String? sectionId,
    String? targetType,
    int? targetId,
  }) {
    final query = select(bibleSectionEvidence)
      ..where((e) {
        var expr = e.bibleId.equals(bibleId);
        if (sectionId != null) expr = expr & e.sectionId.equals(sectionId);
        if (targetType != null) expr = expr & e.targetType.equals(targetType);
        if (targetId != null) expr = expr & e.targetId.equals(targetId);
        return expr;
      })
      ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]);
    return query.watch();
  }

  Future<int> insertBibleEvidence(BibleSectionEvidenceCompanion row) =>
      into(bibleSectionEvidence).insert(row);

  Future<void> deleteBibleEvidence(int id) =>
      (delete(bibleSectionEvidence)..where((e) => e.id.equals(id))).go();

  Future<void> updateBibleEvidenceCaption(int id, String caption) =>
      (update(bibleSectionEvidence)..where((e) => e.id.equals(id))).write(
        BibleSectionEvidenceCompanion(caption: Value(caption)),
      );

  Future<void> _importEmbeddedCatalogIfNeeded() async {
    await importEmbeddedCatalog(this, force: true);
  }

  /// Resuelve cámara principal del proyecto: Biblia > ProjectEquipment > null.
  Future<Camera?> resolveProjectCamera(int projectId) async {
    final bible = await getVisualBibleForProject(projectId);
    if (bible?.primaryCameraId != null) {
      return getCameraById(bible!.primaryCameraId!);
    }
    final firstId = await _firstAssignedEquipmentId(projectId, 'camera');
    if (firstId == null) return null;
    return getCameraById(firstId);
  }

  /// Resuelve lente principal del proyecto: Biblia > ProjectEquipment > null.
  Future<Lense?> resolveProjectLens(int projectId) async {
    final bible = await getVisualBibleForProject(projectId);
    if (bible?.primaryLensId != null) {
      return getLensById(bible!.primaryLensId!);
    }
    final firstId = await _firstAssignedEquipmentId(projectId, 'lens');
    if (firstId == null) return null;
    return getLensById(firstId);
  }

  /// Tras asignar equipo, promueve a principal en Biblia solo si aún no hay uno.
  /// Si ya hay varias asignadas sin principal (legacy), promueve la **primera**
  /// en orden de proyecto — nunca la recién añadida si no es la primera.
  Future<void> maybePromotePrimaryOnEquipmentAssign({
    required int projectId,
    required String equipmentType,
    required int equipmentId,
  }) async {
    final bible = await getVisualBibleForProject(projectId);
    switch (equipmentType) {
      case 'camera':
        if (bible?.primaryCameraId == null) {
          final firstId =
              await _firstAssignedEquipmentId(projectId, 'camera') ??
                  equipmentId;
          await syncBiblePrimaryCamera(projectId, firstId);
        }
        break;
      case 'lens':
        if (bible?.primaryLensId == null) {
          final firstId =
              await _firstAssignedEquipmentId(projectId, 'lens') ?? equipmentId;
          await syncBiblePrimaryLens(projectId, firstId);
        }
        break;
    }
  }

  /// Tras desasignar: si era A-CAM/A-LENS, reasigna la siguiente o limpia primary.
  Future<void> maybeReconcilePrimaryOnEquipmentUnassign({
    required int projectId,
    required String equipmentType,
    required int equipmentId,
  }) async {
    final bible = await getVisualBibleForProject(projectId);
    if (bible == null) return;
    switch (equipmentType) {
      case 'camera':
        if (bible.primaryCameraId != equipmentId) return;
        final next = await _firstAssignedEquipmentId(projectId, 'camera');
        if (next != null) {
          await syncBiblePrimaryCamera(projectId, next);
        } else {
          await (update(visualBibles)..where((v) => v.id.equals(bible.id)))
              .write(
            const VisualBiblesCompanion(
              primaryCameraId: Value(null),
            ),
          );
        }
      case 'lens':
        if (bible.primaryLensId != equipmentId) return;
        final next = await _firstAssignedEquipmentId(projectId, 'lens');
        if (next != null) {
          await syncBiblePrimaryLens(projectId, next);
        } else {
          await (update(visualBibles)..where((v) => v.id.equals(bible.id)))
              .write(
            const VisualBiblesCompanion(
              primaryLensId: Value(null),
            ),
          );
        }
    }
  }

  Future<int?> _firstAssignedEquipmentId(
    int projectId,
    String equipmentType,
  ) async {
    final assigned =
        await (select(projectEquipment)..where(
              (e) =>
                  e.projectId.equals(projectId) &
                  e.equipmentType.equals(equipmentType),
            )
            ..orderBy([
              (e) => OrderingTerm.asc(e.sortOrder),
              (e) => OrderingTerm.asc(e.id),
            ]))
            .get();
    if (assigned.isEmpty) return null;
    return assigned.first.equipmentId;
  }

  Future<void> syncBiblePrimaryCamera(int projectId, int cameraId) async {
    final bible = await ensureVisualBibleForProject(projectId);
    final cam = await getCameraById(cameraId);
    await (update(visualBibles)..where((v) => v.id.equals(bible.id))).write(
      VisualBiblesCompanion(
        primaryCameraId: Value(cameraId),
        nativeIso: Value(cam?.nativeIso),
        colorScienceNotes: Value(cam?.colorScience),
      ),
    );
    if (!await isEquipmentAssigned(
      projectId: projectId,
      equipmentType: 'camera',
      equipmentId: cameraId,
    )) {
      await assignEquipmentToProject(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: cameraId,
      );
    }
    if (cam != null) {
      await _reconcileFormatSensorModeForCamera(projectId, cam);
    }
  }

  /// Cascada A-CAM → Format: si `sensorModeName` no está en la cámara, re-resuelve.
  Future<void> _reconcileFormatSensorModeForCamera(
    int projectId,
    Camera cam,
  ) async {
    final bible = await getVisualBibleForProject(projectId);
    if (bible == null) return;
    final def = await (select(bibleSectionDefinitions)
          ..where((d) => d.bibleId.equals(bible.id))
          ..where((d) => d.id.equals(BibleSectionId.format)))
        .getSingleOrNull();
    if (def == null) return;

    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    var blob = <String, dynamic>{};
    final raw = values['formatData'];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          blob = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final patch = SensorModeCascade.reconcileFormatBlob(
      formatBlob: blob,
      sensorModesJson: cam.sensorModesJson,
      fallbackWidthMm: cam.sensorWidthMm,
      fallbackHeightMm: cam.sensorHeightMm,
    );
    if (patch == null) return;

    await patchFormatDataBlob(projectId, patch);
  }

  Future<void> patchFormatDataBlob(
    int projectId,
    Map<String, dynamic> patch,
  ) async {
    final bible = await getVisualBibleForProject(projectId);
    if (bible == null) return;
    final def = await (select(bibleSectionDefinitions)
          ..where((d) => d.bibleId.equals(bible.id))
          ..where((d) => d.id.equals(BibleSectionId.format)))
        .getSingleOrNull();
    if (def == null) return;

    final fields = BibleSectionFieldsConfig.parse(
      def.contentJson,
      BibleSectionId.format,
    );
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    var blob = <String, dynamic>{};
    final raw = values['formatData'];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) blob = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    blob.addAll(patch);
    values['formatData'] = jsonEncode(blob);

    await upsertBibleSectionDefinition(
      def.copyWith(
        contentJson: Value(
          BibleSectionFieldsConfig.encode(fields, values: values),
        ),
      ),
    );
  }

  Future<void> syncBiblePrimaryLens(int projectId, int lensId) async {
    final bible = await ensureVisualBibleForProject(projectId);
    await (update(visualBibles)..where((v) => v.id.equals(bible.id))).write(
      VisualBiblesCompanion(primaryLensId: Value(lensId)),
    );
    if (!await isEquipmentAssigned(
      projectId: projectId,
      equipmentType: 'lens',
      equipmentId: lensId,
    )) {
      await assignEquipmentToProject(
        projectId: projectId,
        equipmentType: 'lens',
        equipmentId: lensId,
      );
    }
  }

  Future<void> saveOpticsConfigToBible({
    required int projectId,
    int? cameraId,
    int? lensId,
    String? tStop,
    required String configJson,
  }) async {
    final bible = await ensureVisualBibleForProject(projectId);
    await (update(visualBibles)..where((v) => v.id.equals(bible.id))).write(
      VisualBiblesCompanion(
        primaryCameraId: Value(cameraId),
        primaryLensId: Value(lensId),
        defaultTStop: Value(tStop),
        opticsConfigJson: Value(configJson),
      ),
    );
    if (cameraId != null) {
      await syncBiblePrimaryCamera(projectId, cameraId);
    }
    if (lensId != null) {
      await syncBiblePrimaryLens(projectId, lensId);
    }
  }

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
            ..where(
              (s) =>
                  s.projectId.equals(projectId) &
                  s.referenceImagePath.isNotNull(),
            )
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

    final moodboardRows =
        await (select(moodboardImages)
              ..where((m) => m.projectId.equals(projectId))
              ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]))
            .get();
    for (final row in moodboardRows) {
      if (_isExistingImage(row.imagePath)) {
        moodPaths.add(row.imagePath);
      }
    }

    final sites =
        await (select(locationSites)
              ..where((s) => s.projectId.equals(projectId))
              ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
            .get();

    for (final site in sites) {
      final images =
          await (select(siteImages)
                ..where((i) => i.siteId.equals(site.id))
                ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
              .get();
      for (final image in images) {
        if (_isExistingImage(image.imagePath)) {
          moodPaths.add(image.imagePath);
        }
      }
    }

    final sets =
        await (select(locationBasePlans)
              ..where((l) => l.projectId.equals(projectId))
              ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
            .get();

    for (final set in sets) {
      if (set.imagePath != null && _isExistingImage(set.imagePath!)) {
        moodPaths.add(set.imagePath!);
      }
      final images =
          await (select(locationImages)
                ..where((i) => i.locationId.equals(set.id))
                ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
              .get();
      for (final image in images) {
        if (_isExistingImage(image.imagePath)) {
          moodPaths.add(image.imagePath);
        }
      }
    }

    final projectShots =
        await (select(shots)
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

  /// Conteos ligeros para la tarjeta de proyecto en inicio.
  Future<
    ({
      VisualBible? bible,
      int sceneCount,
      int planCount,
      int moodboardCount,
      int locationCount,
    })
  >
  fetchProjectSummaryCounts(int projectId) async {
    final bible = await getVisualBibleForProject(projectId);
    final sceneCount =
        await (select(scenes)..where((s) => s.projectId.equals(projectId)))
            .get()
            .then((rows) => rows.length);
    final planCount = await countShotsWithCameraPlan(projectId);
    final moodboardCount =
        await (select(moodboardImages)
              ..where((m) => m.projectId.equals(projectId)))
            .get()
            .then((rows) => rows.length);
    final locationCount =
        await (select(locationSites)
              ..where((s) => s.projectId.equals(projectId)))
            .get()
            .then((rows) => rows.length);
    return (
      bible: bible,
      sceneCount: sceneCount,
      planCount: planCount,
      moodboardCount: moodboardCount,
      locationCount: locationCount,
    );
  }

  // ── Look Bible ───────────────────────────────────────────────────────────

  Stream<LookBible?> watchLookBibleForProject(int projectId) => (select(
    lookBibles,
  )..where((l) => l.projectId.equals(projectId))).watchSingleOrNull();

  Future<LookBible?> getLookBibleForProject(int projectId) => (select(
    lookBibles,
  )..where((l) => l.projectId.equals(projectId))).getSingleOrNull();

  Future<int> upsertLookBible(LookBiblesCompanion row) async {
    final existing = await getLookBibleForProject(row.projectId.value);
    if (existing == null) {
      return into(lookBibles).insert(row);
    }
    await (update(lookBibles)..where((l) => l.id.equals(existing.id))).write(
      row.copyWith(id: Value(existing.id), updatedAt: Value(DateTime.now())),
    );
    return existing.id;
  }

  // ── Biblia Visual ─────────────────────────────────────────────────────────

  Stream<VisualBible?> watchVisualBibleForProject(int projectId) => (select(
    visualBibles,
  )..where((v) => v.projectId.equals(projectId))).watchSingleOrNull();

  Future<VisualBible?> getVisualBibleForProject(int projectId) => (select(
    visualBibles,
  )..where((v) => v.projectId.equals(projectId))).getSingleOrNull();

  Future<VisualBible> ensureVisualBibleForProject(int projectId) async {
    final existing = await getVisualBibleForProject(projectId);
    if (existing != null) return existing;
    final id = await into(visualBibles).insert(
      VisualBiblesCompanion.insert(
        projectId: projectId,
        structureInitialized: const Value(false),
        engineVersion: const Value('legacy'),
      ),
    );
    return (await (select(
      visualBibles,
    )..where((v) => v.id.equals(id))).getSingle());
  }

  /// Confirma una Biblia vacía sin sembrar las pantallas IRIS (legacy).
  Future<void> initializeEmptyBible(int bibleId) =>
      (update(visualBibles)..where((v) => v.id.equals(bibleId))).write(
        VisualBiblesCompanion(
          structureInitialized: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Borra grupos/pantallas y vuelve al onboarding inicial (contenido técnico intacto).
  Future<void> resetBibleStructureToEmpty(int bibleId) async {
    await transaction(() async {
      await (delete(
        bibleSectionDefinitions,
      )..where((d) => d.bibleId.equals(bibleId))).go();
      await (delete(
        bibleSectionGroups,
      )..where((g) => g.bibleId.equals(bibleId))).go();
      await (update(visualBibles)..where((v) => v.id.equals(bibleId))).write(
        VisualBiblesCompanion(
          structureInitialized: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> promoteEngineToV2(int bibleId) async {
    await (update(visualBibles)..where((v) => v.id.equals(bibleId))).write(
      VisualBiblesCompanion(
        engineVersion: const Value('v2'),
        structureInitialized: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> clearV2Documents(int bibleId) async {
    await (delete(
      visualBibleDocuments,
    )..where((t) => t.bibleId.equals(bibleId))).go();
  }

  Future<void> _markBibleStructureInitialized(int bibleId) =>
      initializeEmptyBible(bibleId);

  /// Aplica una plantilla de estructura de biblia (grupos + secciones).
  Future<void> applyBibleLayoutTemplate(
    int bibleId,
    BibleLayoutTemplatePayload layout,
  ) async {
    await transaction(() async {
      await (delete(
        bibleSectionDefinitions,
      )..where((d) => d.bibleId.equals(bibleId))).go();
      await (delete(
        bibleSectionGroups,
      )..where((g) => g.bibleId.equals(bibleId))).go();

      for (final group in layout.groups) {
        await into(bibleSectionGroups).insert(
          BibleSectionGroupsCompanion.insert(
            id: group.id,
            bibleId: bibleId,
            label: group.label,
            sortOrder: Value(group.sortOrder),
            isBuiltIn: Value(group.isBuiltIn),
          ),
        );
      }

      for (final section in layout.sections) {
        await into(bibleSectionDefinitions).insert(
          BibleSectionDefinitionsCompanion.insert(
            id: section.id,
            bibleId: bibleId,
            groupId: section.groupId,
            label: section.label,
            iconKey: Value(section.iconKey),
            sortOrder: Value(section.sortOrder),
            isBuiltIn: Value(section.isBuiltIn),
            isHidden: Value(section.isHidden),
            template: Value(section.template),
            contentJson: Value(section.contentJson),
          ),
        );
      }
      await _markBibleStructureInitialized(bibleId);
    });
  }

  /// Restaura la estructura built-in de la biblia (plantilla IRIS base).
  Future<void> resetBibleSectionLayoutToBuiltin(int bibleId) async {
    await transaction(() async {
      await (delete(
        bibleSectionDefinitions,
      )..where((d) => d.bibleId.equals(bibleId))).go();
      await (delete(
        bibleSectionGroups,
      )..where((g) => g.bibleId.equals(bibleId))).go();
    });
    await _seedBibleSectionLayout(bibleId);
    await _markBibleStructureInitialized(bibleId);
  }

  Future<void> setBibleSectionHidden({
    required int bibleId,
    required String sectionId,
    required bool hidden,
  }) async {
    final def =
        await (select(
              bibleSectionDefinitions,
            )..where((d) => d.bibleId.equals(bibleId) & d.id.equals(sectionId)))
            .getSingleOrNull();
    if (def == null) return;
    await upsertBibleSectionDefinition(def.copyWith(isHidden: hidden));
  }

  Future<void> deleteCustomBibleSection({
    required int bibleId,
    required String sectionId,
  }) async {
    await (delete(bibleSectionDefinitions)..where(
          (d) =>
              d.bibleId.equals(bibleId) &
              d.id.equals(sectionId) &
              d.isBuiltIn.equals(false),
        ))
        .go();
  }

  Stream<List<UserTemplate>> watchUserTemplates(String type) =>
      (select(userTemplates)
            ..where((t) => t.type.equals(type))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<UserTemplate?> getUserTemplate(String id) =>
      (select(userTemplates)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> upsertVisualBible(VisualBiblesCompanion row) async {
    final existing = await getVisualBibleForProject(row.projectId.value);
    if (existing == null) {
      return into(visualBibles).insert(row);
    }
    await (update(visualBibles)..where((v) => v.id.equals(existing.id))).write(
      row.copyWith(id: Value(existing.id), updatedAt: Value(DateTime.now())),
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

  Stream<List<VisualBibleNarrativeCard>> watchNarrativeCardsForSection(
    int bibleId,
    String sectionId, {
    String? kind,
  }) {
    final query = select(visualBibleNarrativeCards)
      ..where((c) {
        final base =
            c.bibleId.equals(bibleId) & c.sectionId.equals(sectionId);
        if (kind != null) return base & c.kind.equals(kind);
        return base;
      })
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]);
    return query.watch();
  }

  Future<VisualBibleNarrativeCard?> getNarrativeCard(int id) =>
      (select(visualBibleNarrativeCards)..where((c) => c.id.equals(id)))
          .getSingleOrNull();

  Future<VisualBibleNarrativeCard?> getNarrativeCardForLocationLight(
    int bibleId,
    int locationBasePlanId,
  ) =>
      (select(visualBibleNarrativeCards)
            ..where(
              (c) =>
                  c.bibleId.equals(bibleId) &
                  c.sectionId.equals(BibleSectionId.lighting) &
                  c.kind.equals(NarrativeCardKind.locationLight) &
                  c.locationBasePlanId.equals(locationBasePlanId),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<int> insertNarrativeCard(VisualBibleNarrativeCardsCompanion row) =>
      into(visualBibleNarrativeCards).insert(row);

  Future<void> updateNarrativeCard(VisualBibleNarrativeCard row) =>
      update(visualBibleNarrativeCards).replace(row);

  Future<void> deleteNarrativeCard(int id) async {
    final images = await select(moodboardImages).get();
    for (final img in images) {
      final ids = MoodboardAssociation.decodeCardIds(img.assignedCardIds);
      if (!ids.contains(id)) continue;
      ids.remove(id);
      await (update(moodboardImages)..where((m) => m.id.equals(img.id))).write(
        MoodboardImagesCompanion(
          assignedCardIds: Value(
            ids.isEmpty ? null : jsonEncode(ids),
          ),
        ),
      );
    }
    await (delete(visualBibleNarrativeCards)..where((c) => c.id.equals(id)))
        .go();
  }

  Stream<List<MoodboardImage>> watchMoodboardImagesForCard(
    int projectId,
    int cardId,
  ) {
    return watchMoodboardImages(projectId).map((rows) {
      return rows
          .where(
            (row) => MoodboardAssociation.decodeCardIds(row.assignedCardIds)
                .contains(cardId),
          )
          .toList();
    });
  }

  Future<void> assignMoodboardImageToCard({
    required int imageId,
    required int cardId,
    String? sectionId,
  }) async {
    final row = await (select(moodboardImages)
          ..where((m) => m.id.equals(imageId)))
        .getSingleOrNull();
    if (row == null) return;
    final cardIds = MoodboardAssociation.decodeCardIds(row.assignedCardIds);
    if (!cardIds.contains(cardId)) cardIds.add(cardId);
    final sections = MoodboardAssociation.decodeSections(row.assignedSections);
    if (sectionId != null && !sections.contains(sectionId)) {
      sections.add(sectionId);
    }
    await (update(moodboardImages)..where((m) => m.id.equals(imageId))).write(
      MoodboardImagesCompanion(
        assignedCardIds: Value(jsonEncode(cardIds)),
        assignedSections: Value(
          sections.isEmpty ? row.assignedSections : jsonEncode(sections),
        ),
      ),
    );
  }

  Future<void> unassignMoodboardImageFromCard({
    required int imageId,
    required int cardId,
  }) async {
    final row = await (select(moodboardImages)
          ..where((m) => m.id.equals(imageId)))
        .getSingleOrNull();
    if (row == null) return;
    final cardIds = MoodboardAssociation.decodeCardIds(row.assignedCardIds);
    cardIds.remove(cardId);
    await (update(moodboardImages)..where((m) => m.id.equals(imageId))).write(
      MoodboardImagesCompanion(
        assignedCardIds: Value(
          cardIds.isEmpty ? null : jsonEncode(cardIds),
        ),
      ),
    );
  }

  Stream<List<VisualBibleLocationRef>> watchLocationRefsForBible(int bibleId) =>
      (select(visualBibleLocationRefs)
            ..where((r) => r.bibleId.equals(bibleId))
            ..orderBy([(r) => OrderingTerm.asc(r.locationName)]))
          .watch();

  Future<VisualBibleLocationRef?> getLocationRef(
    int bibleId,
    String locationName,
  ) =>
      (select(visualBibleLocationRefs)..where(
            (r) =>
                r.bibleId.equals(bibleId) & r.locationName.equals(locationName),
          ))
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

  /// Imágenes del moodboard visibles en una sección (asignación explícita o categoría).
  Stream<List<MoodboardImage>> watchMoodboardImagesForSection(
    int projectId,
    String sectionId,
  ) {
    return watchMoodboardImages(projectId).map((rows) {
      return rows
          .where(
            (row) => MoodboardAssociation.visibleInSection(
              category: row.category,
              assignedSections: MoodboardAssociation.decodeSections(
                row.assignedSections,
              ),
              sectionId: sectionId,
            ),
          )
          .toList();
    });
  }

  /// Imágenes del moodboard vinculadas a un set/localización.
  Stream<List<MoodboardImage>> watchMoodboardImagesForLocation(
    int projectId,
    String locationName, {
    int? locationBasePlanId,
  }) {
    return watchMoodboardImages(projectId).map((rows) {
      return rows
          .where(
            (row) => MoodboardAssociation.visibleInLocation(
              linkedLocationName: row.linkedLocationName,
              linkedLocationBasePlanId: row.linkedLocationBasePlanId,
              locationName: locationName,
              locationBasePlanId: locationBasePlanId,
            ),
          )
          .toList();
    });
  }

  Stream<List<MoodboardGroup>> watchMoodboardGroups(
    int projectId, {
    String? category,
  }) {
    final query = select(moodboardGroups)
      ..where((g) {
        final base = g.projectId.equals(projectId);
        if (category != null) {
          return base & g.category.equals(category);
        }
        return base;
      })
      ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]);
    return query.watch();
  }

  Future<int> insertMoodboardGroup(MoodboardGroupsCompanion row) async {
    if (!row.sortOrder.present) {
      final max = await _maxMoodboardGroupSortOrder(
        row.projectId.value,
        row.category.value,
      );
      return into(
        moodboardGroups,
      ).insert(row.copyWith(sortOrder: Value(max + 1)));
    }
    return into(moodboardGroups).insert(row);
  }

  Future<int> _maxMoodboardGroupSortOrder(
    int projectId,
    String category,
  ) async {
    final rows =
        await (select(moodboardGroups)..where(
              (g) =>
                  g.projectId.equals(projectId) & g.category.equals(category),
            ))
            .get();
    if (rows.isEmpty) return 0;
    return rows.map((r) => r.sortOrder).reduce((a, b) => a > b ? a : b);
  }

  Future<void> updateMoodboardGroup(MoodboardGroup row) =>
      update(moodboardGroups).replace(row);

  Future<void> deleteMoodboardGroup(int id) async {
    await (update(moodboardImages)..where((m) => m.groupId.equals(id))).write(
      const MoodboardImagesCompanion(groupId: Value(null)),
    );
    await (delete(moodboardGroups)..where((g) => g.id.equals(id))).go();
  }

  Stream<List<BibleSectionGroup>> watchBibleSectionGroups(int bibleId) =>
      (select(bibleSectionGroups)
            ..where((g) => g.bibleId.equals(bibleId))
            ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
          .watch();

  Stream<List<BibleSectionDefinition>> watchBibleSectionDefinitions(
    int bibleId,
  ) =>
      (select(bibleSectionDefinitions)
            ..where((d) => d.bibleId.equals(bibleId))
            ..orderBy([(d) => OrderingTerm.asc(d.sortOrder)]))
          .watch();

  Future<void> ensureBibleSectionLayout(int bibleId) async {
    final existing = await (select(
      bibleSectionGroups,
    )..where((g) => g.bibleId.equals(bibleId))).get();
    if (existing.isNotEmpty) return;
    await _seedBibleSectionLayout(bibleId);
    await _markBibleStructureInitialized(bibleId);
  }

  /// Añade una pantalla built-in sin aplicar la estructura IRIS completa.
  Future<void> addBuiltinBibleSection({
    required int bibleId,
    required String sectionId,
  }) async {
    String? groupId;
    for (final entry in bible_layout.BibleLayoutGroup.sectionsByGroup.entries) {
      if (entry.value.contains(sectionId)) {
        groupId = entry.key;
        break;
      }
    }
    final targetGroupId = groupId;
    if (targetGroupId == null) {
      throw ArgumentError.value(sectionId, 'sectionId', 'Pantalla desconocida');
    }

    await transaction(() async {
      final groups = await (select(
        bibleSectionGroups,
      )..where((g) => g.bibleId.equals(bibleId))).get();
      final existingGroup = groups
          .where((g) => g.id == targetGroupId)
          .firstOrNull;
      if (existingGroup == null) {
        await into(bibleSectionGroups).insert(
          BibleSectionGroupsCompanion.insert(
            id: targetGroupId,
            bibleId: bibleId,
            label: bible_layout.BibleLayoutGroup.label(targetGroupId),
            sortOrder: Value(
              bible_layout.BibleLayoutGroup.orderedGroups.indexOf(
                targetGroupId,
              ),
            ),
            isBuiltIn: const Value(true),
          ),
        );
      }

      final existing =
          await (select(bibleSectionDefinitions)..where(
                (d) => d.bibleId.equals(bibleId) & d.id.equals(sectionId),
              ))
              .getSingleOrNull();
      if (existing == null) {
        final siblings =
            await (select(bibleSectionDefinitions)..where(
                  (d) =>
                      d.bibleId.equals(bibleId) &
                      d.groupId.equals(targetGroupId),
                ))
                .get();
        await into(bibleSectionDefinitions).insert(
          BibleSectionDefinitionsCompanion.insert(
            id: sectionId,
            bibleId: bibleId,
            groupId: targetGroupId,
            label: BibleSectionId.label(sectionId),
            iconKey: Value(_sectionIconKey(sectionId)),
            sortOrder: Value(siblings.length),
            isBuiltIn: const Value(true),
            template: Value(_sectionTemplate(sectionId)),
            contentJson: Value(
              BibleSectionFieldsConfig.encode(
                BibleSectionFieldsConfig.defaultsFor(sectionId),
              ),
            ),
          ),
        );
      } else if (existing.isHidden) {
        await upsertBibleSectionDefinition(existing.copyWith(isHidden: false));
      }
      await _markBibleStructureInitialized(bibleId);
    });
  }

  Future<void> _seedBibleSectionLayout(int bibleId) async {
    var groupOrder = 0;
    for (final groupId in bible_layout.BibleLayoutGroup.orderedGroups) {
      await into(bibleSectionGroups).insert(
        BibleSectionGroupsCompanion.insert(
          id: groupId,
          bibleId: bibleId,
          label: bible_layout.BibleLayoutGroup.label(groupId),
          sortOrder: Value(groupOrder++),
          isBuiltIn: const Value(true),
        ),
      );
      final sectionIds =
          bible_layout.BibleLayoutGroup.sectionsByGroup[groupId] ?? [];
      for (var i = 0; i < sectionIds.length; i++) {
        final sectionId = sectionIds[i];
        await into(bibleSectionDefinitions).insert(
          BibleSectionDefinitionsCompanion.insert(
            id: sectionId,
            bibleId: bibleId,
            groupId: groupId,
            label: BibleSectionId.label(sectionId),
            iconKey: Value(_sectionIconKey(sectionId)),
            sortOrder: Value(i),
            isBuiltIn: const Value(true),
            template: Value(_sectionTemplate(sectionId)),
            contentJson: Value(
              BibleSectionFieldsConfig.encode(
                BibleSectionFieldsConfig.defaultsFor(sectionId),
              ),
            ),
          ),
        );
      }
    }
  }

  static String _sectionIconKey(String sectionId) => switch (sectionId) {
    BibleSectionId.direction => 'theater',
    BibleSectionId.concept => 'auto_stories',
    BibleSectionId.camera => 'videocam',
    BibleSectionId.optics => 'camera',
    BibleSectionId.exposure => 'exposure',
    BibleSectionId.lighting => 'wb_sunny',
    BibleSectionId.colorImage => 'palette',
    BibleSectionId.format => 'aspect_ratio',
    BibleSectionId.texture => 'grain',
    BibleSectionId.location => 'location_on',
    BibleSectionId.cameraTests => 'science',
    BibleSectionId.workflow => 'account_tree',
    BibleSectionId.moodboard => 'photo_library',
    _ => 'article',
  };

  static String _sectionTemplate(String sectionId) => switch (sectionId) {
    BibleSectionId.location => 'locations',
    BibleSectionId.cameraTests => 'tests',
    BibleSectionId.moodboard => 'moodboard',
    BibleSectionId.workflow => 'standard',
    BibleSectionId.colorImage => 'blocks_color',
    BibleSectionId.exposure => 'blocks_exposure',
    BibleSectionId.lighting => 'blocks_lighting',
    _ => 'standard',
  };

  Future<void> upsertBibleSectionGroup(BibleSectionGroup row) =>
      into(bibleSectionGroups).insertOnConflictUpdate(row);

  Future<void> upsertBibleSectionDefinition(BibleSectionDefinition row) =>
      into(bibleSectionDefinitions).insertOnConflictUpdate(row);

  Future<String> insertCustomBibleSection({
    required int bibleId,
    required String groupId,
    required String label,
    String template = 'freeform',
    String? contentJson,
  }) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final defs =
        await (select(bibleSectionDefinitions)..where(
              (d) => d.bibleId.equals(bibleId) & d.groupId.equals(groupId),
            ))
            .get();
    final maxOrder = defs.isEmpty
        ? 0
        : defs.map((d) => d.sortOrder).reduce((a, b) => a > b ? a : b);
    await into(bibleSectionDefinitions).insert(
      BibleSectionDefinitionsCompanion.insert(
        id: id,
        bibleId: bibleId,
        groupId: groupId,
        label: label,
        sortOrder: Value(maxOrder + 1),
        isBuiltIn: const Value(false),
        template: Value(template),
        contentJson: Value(
          contentJson ??
              FreeformV2BlocksCodec.starterContentJson(label),
        ),
      ),
    );
    await _markBibleStructureInitialized(bibleId);
    return id;
  }

  Future<void> _seedBibleSectionDefinitionsForExistingBibles() async {
    final bibles = await select(visualBibles).get();
    for (final bible in bibles) {
      await ensureBibleSectionLayout(bible.id);
    }
  }

  Future<void> _seedBibleSectionFieldsJson() async {
    final defs = await select(bibleSectionDefinitions).get();
    for (final def in defs) {
      if (def.contentJson != null && def.contentJson!.isNotEmpty) continue;
      if (!def.isBuiltIn) continue;
      await upsertBibleSectionDefinition(
        def.copyWith(
          contentJson: Value(
            BibleSectionFieldsConfig.encode(
              BibleSectionFieldsConfig.defaultsFor(def.id),
            ),
          ),
        ),
      );
    }
  }

  Future<void> saveBibleSectionFields(
    int bibleId,
    String sectionId,
    List<BibleSectionField> fields,
  ) async {
    final def =
        await (select(
              bibleSectionDefinitions,
            )..where((d) => d.bibleId.equals(bibleId) & d.id.equals(sectionId)))
            .getSingleOrNull();
    if (def == null) return;
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    await upsertBibleSectionDefinition(
      def.copyWith(
        contentJson: Value(
          BibleSectionFieldsConfig.encode(fields, values: values),
        ),
      ),
    );
  }

  Future<void> reorderBibleSectionsInGroup(
    int bibleId,
    String groupId,
    List<String> orderedSectionIds,
  ) async {
    for (var i = 0; i < orderedSectionIds.length; i++) {
      final sectionId = orderedSectionIds[i];
      final def =
          await (select(bibleSectionDefinitions)..where(
                (d) =>
                    d.bibleId.equals(bibleId) &
                    d.groupId.equals(groupId) &
                    d.id.equals(sectionId),
              ))
              .getSingleOrNull();
      if (def == null) continue;
      await upsertBibleSectionDefinition(def.copyWith(sortOrder: i));
    }
  }

  Future<void> _migrateEvidenceToMoodboard() async {
    final evidenceRows = await select(bibleSectionEvidence).get();
    for (final ev in evidenceRows) {
      final bible = await (select(
        visualBibles,
      )..where((v) => v.id.equals(ev.bibleId))).getSingleOrNull();
      if (bible == null) continue;
      final sectionsJson = jsonEncode([ev.sectionId]);
      final existing =
          await (select(moodboardImages)..where(
                (m) =>
                    m.projectId.equals(bible.projectId) &
                    m.imagePath.equals(ev.imagePath),
              ))
              .getSingleOrNull();
      if (existing != null) {
        final merged = MoodboardAssociation.decodeSections(
          existing.assignedSections,
        );
        if (!merged.contains(ev.sectionId)) {
          merged.add(ev.sectionId);
        }
        await (update(
          moodboardImages,
        )..where((m) => m.id.equals(existing.id))).write(
          MoodboardImagesCompanion(
            assignedSections: Value(jsonEncode(merged)),
            caption: ev.caption != null && ev.caption!.isNotEmpty
                ? Value(ev.caption)
                : const Value.absent(),
          ),
        );
        continue;
      }
      await insertMoodboardImage(
        MoodboardImagesCompanion.insert(
          projectId: bible.projectId,
          bibleId: Value(bible.id),
          imagePath: ev.imagePath,
          source: const Value('evidence_migration'),
          caption: Value(ev.caption),
          assignedSections: Value(sectionsJson),
        ),
      );
    }
  }

  Future<void> _backfillLocationForeignKeys() async {
    final plans = await select(locationBasePlans).get();
    final planByName = {for (final p in plans) p.locationName: p};
    final refs = await select(visualBibleLocationRefs).get();
    for (final ref in refs) {
      final plan = planByName[ref.locationName];
      if (plan == null) continue;
      await (update(
        visualBibleLocationRefs,
      )..where((r) => r.id.equals(ref.id))).write(
        VisualBibleLocationRefsCompanion(
          locationBasePlanId: Value(plan.id),
          locationSiteId: Value(plan.siteId),
        ),
      );
    }
    final moodRows = await select(moodboardImages).get();
    for (final row in moodRows) {
      if (row.linkedLocationName == null) continue;
      final plan = planByName[row.linkedLocationName!];
      if (plan == null) continue;
      await (update(moodboardImages)..where((m) => m.id.equals(row.id))).write(
        MoodboardImagesCompanion(linkedLocationBasePlanId: Value(plan.id)),
      );
    }
  }

  Future<int> insertMoodboardImage(MoodboardImagesCompanion row) async {
    if (!row.sortOrder.present) {
      final maxOrder = await _maxMoodboardSortOrder(row.projectId.value);
      return into(
        moodboardImages,
      ).insert(row.copyWith(sortOrder: Value(maxOrder + 1)));
    }
    return into(moodboardImages).insert(row);
  }

  Future<int> _maxMoodboardSortOrder(int projectId) async {
    final rows = await (select(
      moodboardImages,
    )..where((m) => m.projectId.equals(projectId))).get();
    if (rows.isEmpty) return 0;
    return rows.map((r) => r.sortOrder).reduce((a, b) => a > b ? a : b);
  }

  Future<void> updateMoodboardImage(MoodboardImage row) =>
      update(moodboardImages).replace(row);

  Future<void> saveMoodboardImageMeta(
    int imageId,
    Map<String, dynamic>? metaJson,
  ) async {
    await (update(moodboardImages)..where((m) => m.id.equals(imageId))).write(
      MoodboardImagesCompanion(
        metaJson: metaJson == null ? const Value(null) : Value(jsonEncode(metaJson)),
      ),
    );
  }

  Future<Map<String, dynamic>?> getMoodboardImageMeta(int imageId) async {
    final row = await (select(moodboardImages)
          ..where((m) => m.id.equals(imageId)))
        .getSingleOrNull();
    final raw = row?.metaJson;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> deleteMoodboardImage(int id) =>
      (delete(moodboardImages)..where((m) => m.id.equals(id))).go();

  static const opticsLabMaxSamples = 10;

  Stream<List<OpticsLabSample>> watchOpticsLabSamples(int projectId) {
    return (select(opticsLabSamples)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .watch();
  }

  Future<int> countOpticsLabSamples(int projectId) async {
    final rows = await (select(
      opticsLabSamples,
    )..where((s) => s.projectId.equals(projectId))).get();
    return rows.length;
  }

  Future<int> insertOpticsLabSample(OpticsLabSamplesCompanion row) async {
    if (!row.sortOrder.present) {
      final maxOrder = await _maxOpticsLabSampleSortOrder(row.projectId.value);
      return into(
        opticsLabSamples,
      ).insert(row.copyWith(sortOrder: Value(maxOrder + 1)));
    }
    return into(opticsLabSamples).insert(row);
  }

  Future<int> _maxOpticsLabSampleSortOrder(int projectId) async {
    final rows = await (select(
      opticsLabSamples,
    )..where((s) => s.projectId.equals(projectId))).get();
    if (rows.isEmpty) return 0;
    return rows.map((r) => r.sortOrder).reduce((a, b) => a > b ? a : b);
  }

  Future<void> deleteOpticsLabSample(int id) async {
    await (delete(opticsLabSamples)..where((s) => s.id.equals(id))).go();
  }

  Future<OpticsLabSample?> getOpticsLabSampleById(int id) {
    return (select(
      opticsLabSamples,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Future<void> reorderMoodboardImage(int id, int newSortOrder) async {
    final row = await (select(
      moodboardImages,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await update(
      moodboardImages,
    ).replace(row.copyWith(sortOrder: newSortOrder));
  }

  // ── Exposure blocks ───────────────────────────────────────────────────────

  Stream<List<ExposureBlock>> watchExposureBlocksForBible(int bibleId) =>
      (select(exposureBlocks)
            ..where((b) => b.bibleId.equals(bibleId))
            ..orderBy([(b) => OrderingTerm.asc(b.sortOrder)]))
          .watch();

  Future<int> insertExposureBlock(ExposureBlocksCompanion row) =>
      into(exposureBlocks).insert(row);

  Future<void> updateExposureBlock(ExposureBlock row) =>
      update(exposureBlocks).replace(row);

  Future<void> deleteExposureBlock(int id) =>
      (delete(exposureBlocks)..where((b) => b.id.equals(id))).go();

  // ── Lighting setups ───────────────────────────────────────────────────────

  Stream<List<LightingSetup>> watchLightingSetupsForBible(int bibleId) =>
      (select(lightingSetups)
            ..where((s) => s.bibleId.equals(bibleId))
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .watch();

  Future<int> insertLightingSetup(LightingSetupsCompanion row) =>
      into(lightingSetups).insert(row);

  Future<void> updateLightingSetup(LightingSetup row) =>
      update(lightingSetups).replace(row);

  Future<void> deleteLightingSetup(int id) =>
      (delete(lightingSetups)..where((s) => s.id.equals(id))).go();

  // ── Camera tests ──────────────────────────────────────────────────────────

  Stream<List<CameraTest>> watchCameraTestsForBible(int bibleId) =>
      (select(cameraTests)
            ..where((t) => t.bibleId.equals(bibleId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<int> insertCameraTest(CameraTestsCompanion row) =>
      into(cameraTests).insert(row);

  Future<void> updateCameraTest(CameraTest row) =>
      update(cameraTests).replace(row);

  Future<void> deleteCameraTest(int id) =>
      (delete(cameraTests)..where((t) => t.id.equals(id))).go();

  // ── Bible versions ────────────────────────────────────────────────────────

  Stream<List<VisualBibleVersion>> watchBibleVersions(int bibleId) =>
      (select(visualBibleVersions)
            ..where((v) => v.bibleId.equals(bibleId))
            ..orderBy([(v) => OrderingTerm.desc(v.createdAt)]))
          .watch();

  Future<int> insertBibleVersion(VisualBibleVersionsCompanion row) =>
      into(visualBibleVersions).insert(row);

  // ── Bible comments ────────────────────────────────────────────────────────

  Stream<List<BibleComment>> watchBibleComments(
    int bibleId, {
    String? targetType,
    int? targetId,
  }) {
    final query = select(bibleComments)
      ..where((c) {
        var expr = c.bibleId.equals(bibleId);
        if (targetType != null) {
          expr = expr & c.targetType.equals(targetType);
        }
        if (targetId != null) {
          expr = expr & c.targetId.equals(targetId);
        }
        return expr;
      })
      ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]);
    return query.watch();
  }

  Future<int> insertBibleComment(BibleCommentsCompanion row) =>
      into(bibleComments).insert(row);

  Future<void> deleteBibleComment(int id) =>
      (delete(bibleComments)..where((c) => c.id.equals(id))).go();

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

  // ── Capas vectoriales de anotación ───────────────────────────────────────

  Future<ProjectAnnotationDocument?> getProjectAnnotationDocument({
    required int projectId,
    required String targetType,
    required String targetId,
  }) =>
      (select(projectAnnotationDocuments)..where(
            (a) =>
                a.projectId.equals(projectId) &
                a.targetType.equals(targetType) &
                a.targetId.equals(targetId),
          ))
          .getSingleOrNull();

  Stream<ProjectAnnotationDocument?> watchProjectAnnotationDocument({
    required int projectId,
    required String targetType,
    required String targetId,
  }) =>
      (select(projectAnnotationDocuments)..where(
            (a) =>
                a.projectId.equals(projectId) &
                a.targetType.equals(targetType) &
                a.targetId.equals(targetId),
          ))
          .watchSingleOrNull();

  Future<void> saveProjectAnnotationDocument({
    required int projectId,
    required String targetType,
    required String targetId,
    required String documentJson,
    required int documentSchemaVersion,
  }) async {
    final existing = await getProjectAnnotationDocument(
      projectId: projectId,
      targetType: targetType,
      targetId: targetId,
    );
    if (existing == null) {
      await into(projectAnnotationDocuments).insert(
        ProjectAnnotationDocumentsCompanion.insert(
          projectId: projectId,
          targetType: targetType,
          targetId: targetId,
          documentJson: documentJson,
          documentSchemaVersion: Value(documentSchemaVersion),
        ),
      );
      return;
    }
    await update(projectAnnotationDocuments).replace(
      existing.copyWith(
        documentJson: documentJson,
        documentSchemaVersion: documentSchemaVersion,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<int> deleteProjectAnnotationDocument({
    required int projectId,
    required String targetType,
    required String targetId,
  }) =>
      (delete(projectAnnotationDocuments)..where(
            (a) =>
                a.projectId.equals(projectId) &
                a.targetType.equals(targetType) &
                a.targetId.equals(targetId),
          ))
          .go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final File file;
    if (AppStorageConfig.isConfigured) {
      file = File(AppStorageConfig.current!.databaseFile);
    } else {
      final defaults = await AppStorageConfig.defaultPaths();
      file = File(defaults.databaseFile);
    }
    await Directory(p.dirname(file.path)).create(recursive: true);
    return NativeDatabase.createInBackground(file);
  });
}

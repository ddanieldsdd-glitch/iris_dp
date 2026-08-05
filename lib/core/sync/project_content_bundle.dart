import 'dart:convert';

import 'package:drift/drift.dart' show Value, OrderingTerm;

import '../database/app_database.dart';
import 'media_entity_keys.dart';

int? bundleInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

int bundleIntOr(dynamic value, int fallback) => bundleInt(value) ?? fallback;

DateTime? bundleDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Resumen cuantitativo del contenido de un proyecto.
class ContentSyncSummary {
  final int sceneCount;
  final int shotCount;
  final int locationSiteCount;
  final int locationSetCount;
  final int shootDocumentCount;
  final int equipmentCount;

  const ContentSyncSummary({
    this.sceneCount = 0,
    this.shotCount = 0,
    this.locationSiteCount = 0,
    this.locationSetCount = 0,
    this.shootDocumentCount = 0,
    this.equipmentCount = 0,
  });

  bool get isEmpty =>
      sceneCount == 0 &&
      shotCount == 0 &&
      locationSiteCount == 0 &&
      locationSetCount == 0 &&
      shootDocumentCount == 0 &&
      equipmentCount == 0;

  @override
  bool operator ==(Object other) =>
      other is ContentSyncSummary &&
      other.sceneCount == sceneCount &&
      other.shotCount == shotCount &&
      other.locationSiteCount == locationSiteCount &&
      other.locationSetCount == locationSetCount &&
      other.shootDocumentCount == shootDocumentCount &&
      other.equipmentCount == equipmentCount;

  @override
  int get hashCode => Object.hash(
        sceneCount,
        shotCount,
        locationSiteCount,
        locationSetCount,
        shootDocumentCount,
        equipmentCount,
      );

  String get label =>
      '$sceneCount escenas · $shotCount planos · $locationSetCount sets · $shootDocumentCount docs';

  factory ContentSyncSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ContentSyncSummary();
    return ContentSyncSummary(
      sceneCount: bundleIntOr(json['sceneCount'], 0),
      shotCount: bundleIntOr(json['shotCount'], 0),
      locationSiteCount: bundleIntOr(json['locationSiteCount'], 0),
      locationSetCount: bundleIntOr(json['locationSetCount'], 0),
      shootDocumentCount: bundleIntOr(json['shootDocumentCount'], 0),
      equipmentCount: bundleIntOr(json['equipmentCount'], 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'sceneCount': sceneCount,
        'shotCount': shotCount,
        'locationSiteCount': locationSiteCount,
        'locationSetCount': locationSetCount,
        'shootDocumentCount': shootDocumentCount,
        'equipmentCount': equipmentCount,
      };
}

/// Exporta e importa el contenido completo de un proyecto como JSON.
class ProjectContentBundle {
  static const bundleVersion = 2;

  static Future<Map<String, dynamic>> export(AppDatabase db, int projectId) async {
    final project = await db.getProject(projectId);
    if (project == null) {
      throw StateError('Proyecto $projectId no encontrado');
    }

    final sites = await (db.select(db.locationSites)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .get();
    final siteKeyById = <int, String>{
      for (final s in sites) s.id: 'site:${s.sortOrder}:${s.name}',
    };

    final siteImages = <Map<String, dynamic>>[];
    for (final site in sites) {
      final imgs = await (db.select(db.siteImages)
            ..where((i) => i.siteId.equals(site.id)))
          .get();
      for (final img in imgs) {
        siteImages.add({
          'siteKey': siteKeyById[site.id],
          'imagePath': img.imagePath,
          'mediaKey': MediaEntityKeys.siteImage(
            siteKey: siteKeyById[site.id]!,
            sortOrder: img.sortOrder,
          ),
          'caption': img.caption,
          'kind': img.kind,
          'timeOfDay': img.timeOfDay,
          'sortOrder': img.sortOrder,
        });
      }
    }

    final sets = await (db.select(db.locationBasePlans)
          ..where((l) => l.projectId.equals(projectId))
          ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
        .get();
    final setKeyById = <int, String>{
      for (final s in sets) s.id: 'set:${s.sortOrder}:${s.locationName}',
    };

    final locationImages = <Map<String, dynamic>>[];
    for (final set in sets) {
      final imgs = await (db.select(db.locationImages)
            ..where((i) => i.locationId.equals(set.id)))
          .get();
      for (final img in imgs) {
        locationImages.add({
          'setKey': setKeyById[set.id],
          'imagePath': img.imagePath,
          'mediaKey': MediaEntityKeys.locationImage(
            setKey: setKeyById[set.id]!,
            sortOrder: img.sortOrder,
          ),
          'caption': img.caption,
          'kind': img.kind,
          'timeOfDay': img.timeOfDay,
          'sortOrder': img.sortOrder,
        });
      }
    }

    final scenes = await (db.select(db.scenes)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .get();
    final sceneKeyById = <int, String>{
      for (final s in scenes) s.id: 'scene:${s.number}',
    };

    final shots = await (db.select(db.shots)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .get();
    final shotKeyById = <int, String>{};

    for (final shot in shots) {
      final scene = scenes.firstWhere((s) => s.id == shot.sceneId);
      shotKeyById[shot.id] = 'shot:${scene.number}:${shot.number}';
    }

    final shotReferences = <Map<String, dynamic>>[];
    for (final shot in shots) {
      final refs = await (db.select(db.shotReferences)
            ..where((r) => r.shotId.equals(shot.id)))
          .get();
      for (final ref in refs) {
        shotReferences.add({
          'shotKey': shotKeyById[shot.id],
          'imagePath': ref.imagePath,
          'mediaKey': MediaEntityKeys.shotReference(
            shotKey: shotKeyById[shot.id]!,
            sortOrder: ref.sortOrder,
          ),
          'source': ref.source,
          'sortOrder': ref.sortOrder,
        });
      }
    }

    final cameraElements = <Map<String, dynamic>>[];
    final cameraPathPoints = <Map<String, dynamic>>[];
    for (final shot in shots) {
      final shotKey = shotKeyById[shot.id]!;
      final elements = await db.getCameraPlanElementsForShot(shot.id);
      for (final el in elements) {
        final elKey = '$shotKey/el:${el.sortOrder}:${el.type}';
        cameraElements.add({
          'shotKey': shotKey,
          'elementKey': elKey,
          'type': el.type,
          'x': el.x,
          'y': el.y,
          'rotation': el.rotation,
          'label': el.label,
          'color': el.color,
          'cameraStabilization': el.cameraStabilization,
          'cameraLens': el.cameraLens,
          'cameraLetter': el.cameraLetter,
          'cameraNumber': el.cameraNumber,
          'lightType': el.lightType,
          'lukaCompatible': el.lukaCompatible,
          'lukaFixtureId': el.lukaFixtureId,
          'externalMappingJson': el.externalMappingJson,
          'sortOrder': el.sortOrder,
        });
        final points = await db.getPathPointsForElement(el.id);
        for (final p in points) {
          cameraPathPoints.add({
            'elementKey': elKey,
            'x': p.x,
            'y': p.y,
            'pointNumber': p.pointNumber,
          });
        }
      }
    }

    final shootDocs = await (db.select(db.shootDocuments)
          ..where((d) => d.projectId.equals(projectId)))
        .get();
    final docKeyById = <int, String>{
      for (final d in shootDocs) d.id: 'doc:${d.id}:${d.name}',
    };

    final shootBlocks = <Map<String, dynamic>>[];
    for (final doc in shootDocs) {
      final blocks = await (db.select(db.shootDocumentBlocks)
            ..where((b) => b.documentId.equals(doc.id))
            ..orderBy([(b) => OrderingTerm.asc(b.sortOrder)]))
          .get();
      for (final b in blocks) {
        shootBlocks.add({
          'documentKey': docKeyById[doc.id],
          'blockType': b.blockType,
          'sortOrder': b.sortOrder,
          'sceneKey':
              b.sceneId != null ? sceneKeyById[b.sceneId!] : null,
          'shotKey': b.shotId != null ? shotKeyById[b.shotId!] : null,
          'scriptExcerpt': b.scriptExcerpt,
          'customLabel': b.customLabel,
          'noteBody': b.noteBody,
          'imagePath': b.imagePath,
          'charactersJson': b.charactersJson,
          'durationSeconds': b.durationSeconds,
          'visibilityJson': b.visibilityJson,
          'contentOverridesJson': b.contentOverridesJson,
        });
      }
    }

    final equipment = await (db.select(db.projectEquipment)
          ..where((e) => e.projectId.equals(projectId)))
        .get();

    final moodGroups = await (db.select(db.moodboardGroups)
          ..where((g) => g.projectId.equals(projectId)))
        .get();
    final groupKeyById = <int, String>{
      for (final g in moodGroups) g.id: 'mbg:${g.sortOrder}:${g.name}',
    };

    final moodImages = await (db.select(db.moodboardImages)
          ..where((m) => m.projectId.equals(projectId)))
        .get();

    final lookBibles = await (db.select(db.lookBibles)
          ..where((l) => l.projectId.equals(projectId)))
        .get();

    final visualBibles = await (db.select(db.visualBibles)
          ..where((v) => v.projectId.equals(projectId)))
        .get();
    final vbKeyById = <int, String>{
      for (final v in visualBibles) v.id: 'vb:${v.id}',
    };

    final vbVersions = <Map<String, dynamic>>[];
    final vbColorBlocks = <Map<String, dynamic>>[];
    final vbLocationRefs = <Map<String, dynamic>>[];
    final bibleSectionGroups = <Map<String, dynamic>>[];
    final bibleSectionDefinitions = <Map<String, dynamic>>[];
    final bibleComments = <Map<String, dynamic>>[];
    for (final vb in visualBibles) {
      final vbKey = vbKeyById[vb.id]!;
      final versions = await (db.select(db.visualBibleVersions)
            ..where((v) => v.bibleId.equals(vb.id)))
          .get();
      for (final ver in versions) {
        vbVersions.add({
          'bibleKey': vbKey,
          ...ver.toJson(),
        });
      }
      final blocks = await (db.select(db.visualBibleColorBlocks)
            ..where((b) => b.bibleId.equals(vb.id)))
          .get();
      for (final b in blocks) {
        vbColorBlocks.add({
          'bibleKey': vbKey,
          ...b.toJson(),
        });
      }
      final locRefs = await (db.select(db.visualBibleLocationRefs)
            ..where((r) => r.bibleId.equals(vb.id)))
          .get();
      for (final r in locRefs) {
        vbLocationRefs.add({
          'bibleKey': vbKey,
          'siteKey': r.locationSiteId != null
              ? siteKeyById[r.locationSiteId!]
              : null,
          'setKey': r.locationBasePlanId != null
              ? setKeyById[r.locationBasePlanId!]
              : null,
          ...r.toJson(),
        });
      }
      final groups = await (db.select(db.bibleSectionGroups)
            ..where((g) => g.bibleId.equals(vb.id)))
          .get();
      for (final g in groups) {
        bibleSectionGroups.add({'bibleKey': vbKey, ...g.toJson()});
      }
      final sections = await (db.select(db.bibleSectionDefinitions)
            ..where((s) => s.bibleId.equals(vb.id)))
          .get();
      for (final s in sections) {
        bibleSectionDefinitions.add({'bibleKey': vbKey, ...s.toJson()});
      }
      final comments = await (db.select(db.bibleComments)
            ..where((c) => c.bibleId.equals(vb.id)))
          .get();
      for (final c in comments) {
        bibleComments.add({'bibleKey': vbKey, ...c.toJson()});
      }
    }

    final annotatedPdfs = await (db.select(db.projectAnnotatedPdfs)
          ..where((p) => p.projectId.equals(projectId)))
        .get();

    final opticsSamples = await (db.select(db.opticsLabSamples)
          ..where((o) => o.projectId.equals(projectId)))
        .get();

    return {
      'version': bundleVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'summary': summarizeFromCounts(
        sceneCount: scenes.length,
        shotCount: shots.length,
        locationSiteCount: sites.length,
        locationSetCount: sets.length,
        shootDocumentCount: shootDocs.length,
        equipmentCount: equipment.length,
      ).toJson(),
      'projectFields': {
        'characterColorsJson': project.characterColorsJson,
        'shootingStartDate': project.shootingStartDate,
        'shootingEndDate': project.shootingEndDate,
        'scriptFileName': project.scriptFileName,
      },
      'locationSites': sites
          .map((s) => {
                'siteKey': siteKeyById[s.id],
                'name': s.name,
                'description': s.description,
                'notes': s.notes,
                'floorPlanJson': s.floorPlanJson,
                'scanPath': s.scanPath,
                'scanSource': s.scanSource,
                'scanMetadataJson': s.scanMetadataJson,
                'sortOrder': s.sortOrder,
              })
          .toList(),
      'siteImages': siteImages,
      'locationBasePlans': sets
          .map((s) => {
                'setKey': setKeyById[s.id],
                'siteKey': s.siteId != null ? siteKeyById[s.siteId!] : null,
                'locationName': s.locationName,
                'description': s.description,
                'imagePath': s.imagePath,
                'color': s.color,
                'notes': s.notes,
                'model3dPath': s.model3dPath,
                'floorPlanJson': s.floorPlanJson,
                'scanPath': s.scanPath,
                'scanSource': s.scanSource,
                'scanMetadataJson': s.scanMetadataJson,
                'sortOrder': s.sortOrder,
              })
          .toList(),
      'locationImages': locationImages,
      'scenes': scenes
          .map((s) => {
                'sceneKey': sceneKeyById[s.id],
                'number': s.number,
                'name': s.name,
                'locationCanonical': s.locationCanonical,
                'locationPureName': s.locationPureName,
                'siteKey': s.locationSiteId != null
                    ? siteKeyById[s.locationSiteId!]
                    : null,
                'setKey':
                    s.locationId != null ? setKeyById[s.locationId!] : null,
                'intExt': s.intExt,
                'dayNight': s.dayNight,
                'locationColor': s.locationColor,
                'charactersJson': s.charactersJson,
                'description': s.description,
                'actionText': s.actionText,
                'sourceStartIndex': s.sourceStartIndex,
                'durationMinutes': s.durationMinutes,
                'autoNumbering': s.autoNumbering,
                'sortOrder': s.sortOrder,
              })
          .toList(),
      'shots': shots.map((shot) {
        final scene = scenes.firstWhere((s) => s.id == shot.sceneId);
        return {
          'shotKey': shotKeyById[shot.id],
          'sceneKey': sceneKeyById[scene.id],
          'number': shot.number,
          'framing': shot.framing,
          'lens': shot.lens,
          'angle': shot.angle,
          'movement': shot.movement,
          'fStop': shot.fStop,
          'action': shot.action,
          'notes': shot.notes,
          'notesHighlight': shot.notesHighlight,
          'referenceImagePath': shot.referenceImagePath,
          'charactersJson': shot.charactersJson,
          'durationSeconds': shot.durationSeconds,
          'scriptAnchorIndex': shot.scriptAnchorIndex,
          'sortOrder': shot.sortOrder,
        };
      }).toList(),
      'shotReferences': shotReferences,
      'cameraPlanElements': cameraElements,
      'cameraPathPoints': cameraPathPoints,
      'shootDocuments': shootDocs
          .map((d) => {
                'documentKey': docKeyById[d.id],
                'name': d.name,
                'description': d.description,
                'defaultVisibilityJson': d.defaultVisibilityJson,
                'layoutPreset': d.layoutPreset,
                'shootDate': d.shootDate,
                'isPrimaryOnSet': d.isPrimaryOnSet,
                'includeCoverInPdf': d.includeCoverInPdf,
              })
          .toList(),
      'shootDocumentBlocks': shootBlocks,
      'projectEquipment': equipment
          .map((e) => {
                'equipmentType': e.equipmentType,
                'equipmentId': e.equipmentId,
                'source': e.source,
                'status': e.status,
                'notes': e.notes,
                'sortOrder': e.sortOrder,
              })
          .toList(),
      'moodboardGroups': moodGroups
          .map((g) => {
                'groupKey': groupKeyById[g.id],
                'category': g.category,
                'name': g.name,
                'sortOrder': g.sortOrder,
              })
          .toList(),
      'moodboardImages': moodImages
          .map((m) => {
                'groupKey': m.groupId != null ? groupKeyById[m.groupId!] : null,
                'bibleId': m.bibleId,
                'imagePath': m.imagePath,
                'mediaKey': MediaEntityKeys.moodboard(
                  groupKey:
                      m.groupId != null ? groupKeyById[m.groupId!] : null,
                  sortOrder: m.sortOrder,
                ),
                'source': m.source,
                'category': m.category,
                'caption': m.caption,
                'filmReference': m.filmReference,
                'linkedSceneId': m.linkedSceneId,
                'linkedLocationName': m.linkedLocationName,
                'setKey': m.linkedLocationBasePlanId != null
                    ? setKeyById[m.linkedLocationBasePlanId!]
                    : null,
                'assignedSections': m.assignedSections,
                'sortOrder': m.sortOrder,
              })
          .toList(),
      'lookBibles': lookBibles.map((l) => l.toJson()).toList(),
      'visualBibles': visualBibles.map((v) => v.toJson()).toList(),
      'visualBibleVersions': vbVersions,
      'visualBibleColorBlocks': vbColorBlocks,
      'visualBibleLocationRefs': vbLocationRefs,
      'bibleSectionGroups': bibleSectionGroups,
      'bibleSectionDefinitions': bibleSectionDefinitions,
      'bibleComments': bibleComments,
      'projectAnnotatedPdfs': annotatedPdfs.map((p) => p.toJson()).toList(),
      'opticsLabSamples': opticsSamples.map((o) => o.toJson()).toList(),
    };
  }

  static ContentSyncSummary summarizeFromCounts({
    required int sceneCount,
    required int shotCount,
    required int locationSiteCount,
    required int locationSetCount,
    required int shootDocumentCount,
    required int equipmentCount,
  }) =>
      ContentSyncSummary(
        sceneCount: sceneCount,
        shotCount: shotCount,
        locationSiteCount: locationSiteCount,
        locationSetCount: locationSetCount,
        shootDocumentCount: shootDocumentCount,
        equipmentCount: equipmentCount,
      );

  static ContentSyncSummary summarize(Map<String, dynamic> bundle) =>
      ContentSyncSummary.fromJson(
        bundle['summary'] as Map<String, dynamic>?,
      );

  static Future<ContentSyncSummary> summarizeLocal(
    AppDatabase db,
    int projectId,
  ) async {
    final scenes = await (db.select(db.scenes)
          ..where((s) => s.projectId.equals(projectId)))
        .get();
    final shots = await (db.select(db.shots)
          ..where((s) => s.projectId.equals(projectId)))
        .get();
    final sites = await (db.select(db.locationSites)
          ..where((s) => s.projectId.equals(projectId)))
        .get();
    final sets = await (db.select(db.locationBasePlans)
          ..where((l) => l.projectId.equals(projectId)))
        .get();
    final docs = await (db.select(db.shootDocuments)
          ..where((d) => d.projectId.equals(projectId)))
        .get();
    final equip = await (db.select(db.projectEquipment)
          ..where((e) => e.projectId.equals(projectId)))
        .get();
    return summarizeFromCounts(
      sceneCount: scenes.length,
      shotCount: shots.length,
      locationSiteCount: sites.length,
      locationSetCount: sets.length,
      shootDocumentCount: docs.length,
      equipmentCount: equip.length,
    );
  }

  static String hashBundle(Map<String, dynamic> bundle) {
    final copy = Map<String, dynamic>.from(bundle);
    for (final key in _hashVolatileTopKeys) {
      copy.remove(key);
    }
    final canonical = jsonEncode(_canonicalize(copy));
    return canonical.hashCode.toRadixString(16);
  }

  /// Campos excluidos del hash (rutas locales, media, metadatos volátiles).
  static const _hashVolatileTopKeys = {
    'exportedAt',
    'version',
    'summary',
    'moodboardImages',
    'siteImages',
    'locationImages',
    'shotReferences',
    'opticsLabSamples',
    'projectAnnotatedPdfs',
  };

  /// Compara hash local con fila de snapshot en nube.
  static bool contentMatchesSnapshot(
    String localHash,
    Map<String, dynamic>? snapshotRow,
  ) {
    if (snapshotRow == null) return false;
    final cloudHash = snapshotRow['content_hash'] as String?;
    if (cloudHash != null && cloudHash == localHash) return true;
    final content = snapshotRow['content'];
    if (content is Map) {
      final fromCloud = hashBundle(Map<String, dynamic>.from(content));
      if (fromCloud == localHash) return true;
    }
    return false;
  }

  static Future<String> computeLocalHash(AppDatabase db, int projectId) async {
    final bundle = await export(db, projectId);
    return hashBundle(bundle);
  }

  static dynamic _canonicalize(dynamic value) {
    if (value is num) {
      if (value is int) return value;
      final rounded = value.roundToDouble();
      if (value == rounded) return value.toInt();
      return value;
    }
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {
        for (final k in keys) k: _canonicalize(value[k]),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }

  static bool hasMeaningfulContent(Map<String, dynamic> bundle) {
    bool hasRows(String key) {
      final value = bundle[key];
      return value is List && value.isNotEmpty;
    }

    return hasRows('scenes') ||
        hasRows('shots') ||
        hasRows('locationSites') ||
        hasRows('locationBasePlans') ||
        hasRows('shootDocuments') ||
        hasRows('visualBibles') ||
        hasRows('lookBibles');
  }

  /// Reemplaza todo el contenido del proyecto (mantiene la fila Projects).
  static Future<void> importBundle(
    AppDatabase db,
    int projectId,
    Map<String, dynamic> bundle,
  ) async {
    if (!hasMeaningfulContent(bundle)) return;

    await db.deleteProjectContentOnly(projectId);

    final projectFields =
        bundle['projectFields'] as Map<String, dynamic>? ?? {};
    final existing = await db.getProject(projectId);
    if (existing != null) {
      await db.updateProject(existing.copyWith(
        characterColorsJson: Value(
          projectFields['characterColorsJson'] as String?,
        ),
        shootingStartDate: Value(
          projectFields['shootingStartDate'] as String?,
        ),
        shootingEndDate: Value(projectFields['shootingEndDate'] as String?),
        scriptFileName: Value(projectFields['scriptFileName'] as String?),
      ));
    }

    final siteKeyToId = <String, int>{};
    for (final row in bundle['locationSites'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = await db.insertSite(LocationSitesCompanion.insert(
        projectId: projectId,
        name: m['name'] as String,
        description: Value(m['description'] as String?),
        notes: Value(m['notes'] as String?),
        floorPlanJson: Value(m['floorPlanJson'] as String?),
        scanPath: Value(m['scanPath'] as String?),
        scanSource: Value(m['scanSource'] as String?),
        scanMetadataJson: Value(m['scanMetadataJson'] as String?),
        sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
      ));
      siteKeyToId[m['siteKey'] as String] = id;
    }

    for (final row in bundle['siteImages'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final siteId = siteKeyToId[m['siteKey'] as String];
      if (siteId == null) continue;
      await db.insertSiteImage(SiteImagesCompanion.insert(
        siteId: siteId,
        imagePath: m['imagePath'] as String,
        caption: Value(m['caption'] as String?),
        kind: Value(m['kind'] as String? ?? 'reference'),
        timeOfDay: Value(m['timeOfDay'] as String?),
        sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
      ));
    }

    final setKeyToId = <String, int>{};
    for (final row in bundle['locationBasePlans'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final siteKey = m['siteKey'] as String?;
      final id = await db.insertLocation(LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteKey != null ? siteKeyToId[siteKey] : null),
        locationName: m['locationName'] as String,
        description: Value(m['description'] as String?),
        imagePath: Value(m['imagePath'] as String?),
        color: Value(m['color'] as String? ?? '#94A3B8'),
        notes: Value(m['notes'] as String?),
        model3dPath: Value(m['model3dPath'] as String?),
        floorPlanJson: Value(m['floorPlanJson'] as String?),
        scanPath: Value(m['scanPath'] as String?),
        scanSource: Value(m['scanSource'] as String?),
        scanMetadataJson: Value(m['scanMetadataJson'] as String?),
        sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
      ));
      setKeyToId[m['setKey'] as String] = id;
    }

    for (final row in bundle['locationImages'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final setId = setKeyToId[m['setKey'] as String];
      if (setId == null) continue;
      await db.insertLocationImage(LocationImagesCompanion.insert(
        locationId: setId,
        imagePath: m['imagePath'] as String,
        caption: Value(m['caption'] as String?),
        kind: Value(m['kind'] as String? ?? 'reference'),
        timeOfDay: Value(m['timeOfDay'] as String?),
        sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
      ));
    }

    final sceneKeyToId = <String, int>{};
    for (final row in bundle['scenes'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final siteKey = m['siteKey'] as String?;
      final setKey = m['setKey'] as String?;
      final id = await db.into(db.scenes).insert(ScenesCompanion.insert(
            projectId: projectId,
            number: bundleIntOr(m['number'], 0),
            name: m['name'] as String,
            locationCanonical: m['locationCanonical'] as String,
            locationPureName: m['locationPureName'] as String,
            intExt: Value(m['intExt'] as String? ?? 'EXT'),
            dayNight: Value(m['dayNight'] as String? ?? 'DÍA'),
            locationColor: Value(m['locationColor'] as String?),
            charactersJson: Value(m['charactersJson'] as String?),
            description: Value(m['description'] as String?),
            actionText: Value(m['actionText'] as String?),
            sourceStartIndex: Value(bundleInt(m['sourceStartIndex'])),
            durationMinutes: Value(bundleIntOr(m['durationMinutes'], 0)),
            autoNumbering: Value(m['autoNumbering'] as bool? ?? true),
            locationSiteId: Value(
              siteKey != null ? siteKeyToId[siteKey] : null,
            ),
            locationId: Value(setKey != null ? setKeyToId[setKey] : null),
            sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
          ));
      sceneKeyToId[m['sceneKey'] as String] = id;
    }

    final shotKeyToId = <String, int>{};
    for (final row in bundle['shots'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final sceneId = sceneKeyToId[m['sceneKey'] as String];
      if (sceneId == null) continue;
      final id = await db.into(db.shots).insert(ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: bundleIntOr(m['number'], 0),
            framing: Value(m['framing'] as String?),
            lens: Value(m['lens'] as String?),
            angle: Value(m['angle'] as String?),
            movement: Value(m['movement'] as String?),
            fStop: Value(m['fStop'] as String?),
            action: Value(m['action'] as String?),
            notes: Value(m['notes'] as String?),
            notesHighlight: Value(m['notesHighlight'] as String?),
            referenceImagePath: Value(m['referenceImagePath'] as String?),
            charactersJson: Value(m['charactersJson'] as String?),
            durationSeconds: Value(bundleInt(m['durationSeconds'])),
            scriptAnchorIndex: Value(bundleInt(m['scriptAnchorIndex'])),
            sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
          ));
      shotKeyToId[m['shotKey'] as String] = id;
    }

    for (final row in bundle['shotReferences'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final shotId = shotKeyToId[m['shotKey'] as String];
      if (shotId == null) continue;
      await db.insertShotReference(ShotReferencesCompanion.insert(
        shotId: shotId,
        imagePath: m['imagePath'] as String,
        source: Value(m['source'] as String? ?? 'manual'),
        sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
      ));
    }

    final elementKeyToId = <String, int>{};
    for (final row in bundle['cameraPlanElements'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final shotId = shotKeyToId[m['shotKey'] as String];
      if (shotId == null) continue;
      final elKey = m['elementKey'] as String;
      final id = await db.insertCameraPlanElement(
        CameraPlanElementsCompanion.insert(
          shotId: shotId,
          type: m['type'] as String,
          x: Value((m['x'] as num?)?.toDouble() ?? 0),
          y: Value((m['y'] as num?)?.toDouble() ?? 0),
          rotation: Value((m['rotation'] as num?)?.toDouble() ?? 0),
          label: Value(m['label'] as String?),
          color: Value(m['color'] as String?),
          cameraStabilization: Value(m['cameraStabilization'] as String?),
          cameraLens: Value(m['cameraLens'] as String?),
          cameraLetter: Value(m['cameraLetter'] as String? ?? 'A'),
          cameraNumber: Value(bundleIntOr(m['cameraNumber'], 1)),
          lightType: Value(m['lightType'] as String?),
          lukaCompatible: Value(m['lukaCompatible'] as bool? ?? false),
          lukaFixtureId: Value(m['lukaFixtureId'] as String?),
          externalMappingJson: Value(m['externalMappingJson'] as String?),
          sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
        ),
      );
      elementKeyToId[elKey] = id;
    }

    for (final row in bundle['cameraPathPoints'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final elId = elementKeyToId[m['elementKey'] as String];
      if (elId == null) continue;
      await db.into(db.cameraPathPoints).insert(
            CameraPathPointsCompanion.insert(
              elementId: elId,
              x: (m['x'] as num).toDouble(),
              y: (m['y'] as num).toDouble(),
              pointNumber: bundleIntOr(
                m['pointNumber'] ?? m['sortOrder'],
                0,
              ),
            ),
          );
    }

    final docKeyToId = <String, int>{};
    for (final row in bundle['shootDocuments'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = await db.insertShootDocument(ShootDocumentsCompanion.insert(
        projectId: projectId,
        name: m['name'] as String,
        description: Value(m['description'] as String?),
        defaultVisibilityJson: Value(m['defaultVisibilityJson'] as String?),
        layoutPreset: Value(m['layoutPreset'] as String? ?? 'freeform'),
        shootDate: Value(m['shootDate'] as String?),
        isPrimaryOnSet: Value(m['isPrimaryOnSet'] as bool? ?? false),
        includeCoverInPdf: Value(m['includeCoverInPdf'] as bool? ?? true),
      ));
      docKeyToId[m['documentKey'] as String] = id;
    }

    for (final row in bundle['shootDocumentBlocks'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final docId = docKeyToId[m['documentKey'] as String];
      if (docId == null) continue;
      await db.insertShootDocumentBlock(ShootDocumentBlocksCompanion.insert(
        documentId: docId,
        blockType: m['blockType'] as String,
        sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
        sceneId: Value(
          m['sceneKey'] != null
              ? sceneKeyToId[m['sceneKey'] as String]
              : null,
        ),
        shotId: Value(
          m['shotKey'] != null ? shotKeyToId[m['shotKey'] as String] : null,
        ),
        scriptExcerpt: Value(m['scriptExcerpt'] as String?),
        customLabel: Value(m['customLabel'] as String?),
        noteBody: Value(m['noteBody'] as String?),
        imagePath: Value(m['imagePath'] as String?),
        charactersJson: Value(m['charactersJson'] as String?),
        durationSeconds: Value(m['durationSeconds'] as int?),
        visibilityJson: Value(m['visibilityJson'] as String?),
        contentOverridesJson: Value(m['contentOverridesJson'] as String?),
      ));
    }

    for (final row in bundle['projectEquipment'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final equipmentId = bundleInt(m['equipmentId']);
      if (equipmentId == null) continue;
      await db.into(db.projectEquipment).insert(ProjectEquipmentCompanion.insert(
            projectId: projectId,
            equipmentType: m['equipmentType'] as String? ?? 'unknown',
            equipmentId: equipmentId,
            source: Value(m['source'] as String? ?? 'rental'),
            status: Value(m['status'] as String? ?? 'available'),
            notes: Value(m['notes'] as String?),
            sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
          ));
    }

    final groupKeyToId = <String, int>{};
    for (final row in bundle['moodboardGroups'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = await db.into(db.moodboardGroups).insert(
            MoodboardGroupsCompanion.insert(
              projectId: projectId,
              category: m['category'] as String,
              name: m['name'] as String,
              sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
            ),
          );
      groupKeyToId[m['groupKey'] as String] = id;
    }

    for (final row in bundle['moodboardImages'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final groupKey = m['groupKey'] as String?;
      final setKey = m['setKey'] as String?;
      await db.into(db.moodboardImages).insert(
            MoodboardImagesCompanion.insert(
              projectId: projectId,
              imagePath: m['imagePath'] as String,
              bibleId: Value(bundleInt(m['bibleId'])),
              source: Value(m['source'] as String? ?? 'manual'),
              category: Value(m['category'] as String?),
              groupId: Value(
                groupKey != null ? groupKeyToId[groupKey] : null,
              ),
              caption: Value(m['caption'] as String?),
              filmReference: Value(m['filmReference'] as String?),
              linkedSceneId: Value(bundleInt(m['linkedSceneId'])),
              linkedLocationName: Value(m['linkedLocationName'] as String?),
              linkedLocationBasePlanId: Value(
                setKey != null ? setKeyToId[setKey] : null,
              ),
              assignedSections: Value(m['assignedSections'] as String?),
              sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
            ),
          );
    }

    for (final row in bundle['lookBibles'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      m.remove('id');
      m.remove('projectId');
      await db.into(db.lookBibles).insert(
            LookBiblesCompanion.insert(
              projectId: projectId,
              visualConcept: Value(m['visualConcept'] as String?),
              colorPalette: Value(m['colorPalette'] as String?),
              lutName: Value(m['lutName'] as String?),
              filmReferences: Value(m['filmReferences'] as String?),
              lightingPhilosophy: Value(m['lightingPhilosophy'] as String?),
              contrastStyle: Value(m['contrastStyle'] as String?),
              actOneNotes: Value(m['actOneNotes'] as String?),
              actTwoNotes: Value(m['actTwoNotes'] as String?),
              actThreeNotes: Value(m['actThreeNotes'] as String?),
              moodboardImages: Value(m['moodboardImages'] as String?),
            ),
          );
    }

    final vbKeyToId = <String, int>{};
    for (final row in bundle['visualBibles'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final oldId = bundleInt(m['id']);
      m.remove('id');
      m.remove('projectId');
      final vb = VisualBible.fromJson({
        ...m,
        'id': 0,
        'projectId': projectId,
        'updatedAt': (bundleDateTime(m['updatedAt']) ?? DateTime.now())
            .toIso8601String(),
      });
      final id = await db.into(db.visualBibles).insert(
            vb.toCompanion(true).copyWith(id: const Value.absent()),
          );
      if (oldId != null) vbKeyToId['vb:$oldId'] = id;
      vbKeyToId['vb:$id'] = id;
    }

    for (final row in bundle['visualBibleVersions'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final bibleId = vbKeyToId[m['bibleKey'] as String];
      if (bibleId == null) continue;
      m.remove('bibleKey');
      m.remove('id');
      m.remove('bibleId');
      await db.into(db.visualBibleVersions).insert(
            VisualBibleVersionsCompanion.insert(
              bibleId: bibleId,
              label: m['label'] as String,
              snapshotJson: m['snapshotJson'] as String,
              changeNote: Value(m['changeNote'] as String?),
            ),
          );
    }

    for (final row in bundle['visualBibleColorBlocks'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final bibleId = vbKeyToId[m['bibleKey'] as String];
      if (bibleId == null) continue;
      m.remove('bibleKey');
      m.remove('id');
      m.remove('bibleId');
      await db.into(db.visualBibleColorBlocks).insert(
            VisualBibleColorBlocksCompanion.insert(
              bibleId: bibleId,
              blockName: m['blockName'] as String,
              dominantColors: m['dominantColors'] as String,
              emotionalIntent: Value(m['emotionalIntent'] as String?),
              accentColors: Value(m['accentColors'] as String?),
              prohibitedColors: Value(m['prohibitedColors'] as String?),
              colorTempKelvin: Value(bundleInt(m['colorTempKelvin'])),
              referenceImages: Value(m['referenceImages'] as String?),
              sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
            ),
          );
    }

    for (final row in bundle['visualBibleLocationRefs'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final bibleId = vbKeyToId[m['bibleKey'] as String];
      if (bibleId == null) continue;
      final siteKey = m['siteKey'] as String?;
      final setKey = m['setKey'] as String?;
      m.remove('bibleKey');
      m.remove('siteKey');
      m.remove('setKey');
      m.remove('id');
      m.remove('bibleId');
      m.remove('locationSiteId');
      m.remove('locationBasePlanId');
      await db.into(db.visualBibleLocationRefs).insert(
            VisualBibleLocationRefsCompanion.insert(
              bibleId: bibleId,
              locationName: m['locationName'] as String,
              locationSiteId: Value(
                siteKey != null ? siteKeyToId[siteKey] : null,
              ),
              locationBasePlanId: Value(
                setKey != null ? setKeyToId[setKey] : null,
              ),
              lightingNote: Value(m['lightingNote'] as String?),
              colorNote: Value(m['colorNote'] as String?),
              stagingNote: Value(m['stagingNote'] as String?),
              referenceImages: Value(m['referenceImages'] as String?),
              linkedShotIds: Value(m['linkedShotIds'] as String?),
              solarOrientation: Value(m['solarOrientation'] as String?),
              availableLightHours: Value(m['availableLightHours'] as String?),
              existingPracticals: Value(m['existingPracticals'] as String?),
              estimatedColorTempKelvin:
                  Value(bundleInt(m['estimatedColorTempKelvin'])),
            ),
          );
    }

    for (final row in bundle['bibleSectionGroups'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final bibleId = vbKeyToId[m['bibleKey'] as String];
      if (bibleId == null) continue;
      m.remove('bibleKey');
      m.remove('bibleId');
      await db.into(db.bibleSectionGroups).insert(
            BibleSectionGroupsCompanion.insert(
              id: m['id'] as String,
              bibleId: bibleId,
              label: m['label'] as String,
              sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
              isBuiltIn: Value(m['isBuiltIn'] as bool? ?? true),
            ),
          );
    }

    for (final row in bundle['bibleSectionDefinitions'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final bibleId = vbKeyToId[m['bibleKey'] as String];
      if (bibleId == null) continue;
      m.remove('bibleKey');
      m.remove('bibleId');
      await db.into(db.bibleSectionDefinitions).insert(
            BibleSectionDefinitionsCompanion.insert(
              id: m['id'] as String,
              bibleId: bibleId,
              groupId: m['groupId'] as String,
              label: m['label'] as String,
              iconKey: Value(m['iconKey'] as String? ?? 'article'),
              sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
              isBuiltIn: Value(m['isBuiltIn'] as bool? ?? true),
              isHidden: Value(m['isHidden'] as bool? ?? false),
              template: Value(m['template'] as String? ?? 'standard'),
              contentJson: Value(m['contentJson'] as String?),
            ),
          );
    }

    for (final row in bundle['bibleComments'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      final bibleId = vbKeyToId[m['bibleKey'] as String];
      if (bibleId == null) continue;
      m.remove('bibleKey');
      m.remove('id');
      m.remove('bibleId');
      await db.into(db.bibleComments).insert(
            BibleCommentsCompanion.insert(
              bibleId: bibleId,
              authorRole: m['authorRole'] as String,
              targetType: m['targetType'] as String,
              targetId: Value(bundleInt(m['targetId'])),
              comment: m['comment'] as String,
            ),
          );
    }

    for (final row in bundle['projectAnnotatedPdfs'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      await db.into(db.projectAnnotatedPdfs).insert(
            ProjectAnnotatedPdfsCompanion.insert(
              projectId: projectId,
              moduleType: m['moduleType'] as String,
              pdfPath: m['pdfPath'] as String,
            ),
          );
    }

    for (final row in bundle['opticsLabSamples'] as List? ?? []) {
      final m = Map<String, dynamic>.from(row as Map);
      await db.into(db.opticsLabSamples).insert(
            OpticsLabSamplesCompanion.insert(
              projectId: projectId,
              imagePath: m['imagePath'] as String,
              sortOrder: Value(bundleIntOr(m['sortOrder'], 0)),
            ),
          );
    }
  }
}

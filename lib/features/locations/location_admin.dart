import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/scene_format.dart';
import '../visual_bible/services/lighting_narrative_cards_service.dart';

/// Lo que usa un set o una localización: para avisar antes de renombrarlo,
/// unirlo o eliminarlo.
class LocationUsage {
  final int scenes;
  final int shots;

  const LocationUsage({required this.scenes, required this.shots});

  bool get inUse => scenes > 0 || shots > 0;

  /// «3 escenas y 12 planos del guion técnico».
  String get summary {
    String n(int count, String one, String many) =>
        '$count ${count == 1 ? one : many}';
    return '${n(scenes, 'escena', 'escenas')} y '
        '${n(shots, 'plano', 'planos')} del guion técnico';
  }
}

/// Renombrar, mover, unir y eliminar localizaciones y sets sin dejar
/// escenas colgando. Lo usan Iluminación y Localización de la biblia.
class LocationAdmin {
  final AppDatabase db;

  const LocationAdmin(this.db);

  Future<List<Scene>> _scenesOfSet(int setId) =>
      (db.select(db.scenes)..where((s) => s.locationId.equals(setId))).get();

  Future<List<Scene>> _scenesOfSite(int siteId) => (db.select(
    db.scenes,
  )..where((s) => s.locationSiteId.equals(siteId))).get();

  Future<LocationUsage> _usage(List<Scene> scenes, {int? setId}) async {
    final sceneIds = {for (final s in scenes) s.id};
    final shots = await db.select(db.shots).get();
    return LocationUsage(
      scenes: scenes.length,
      shots: shots
          .where(
            (s) =>
                sceneIds.contains(s.sceneId) ||
                (setId != null && s.locationBasePlanId == setId),
          )
          .length,
    );
  }

  Future<LocationUsage> usageOfSet(int setId) async =>
      _usage(await _scenesOfSet(setId), setId: setId);

  Future<LocationUsage> usageOfSite(int siteId) async =>
      _usage(await _scenesOfSite(siteId));

  /// Cambia el lugar en el título de las escenas que lo llevaban.
  Future<void> _renameInScenes(
    List<Scene> scenes,
    String oldName,
    String newName,
  ) async {
    final old = oldName.trim().toLowerCase();
    for (final scene in scenes) {
      final place = locationFromCanonical(scene.locationCanonical);
      if (place.trim().toLowerCase() != old &&
          scene.locationPureName.trim().toLowerCase() != old) {
        continue;
      }
      final hadDefaultName =
          scene.name ==
          formatSceneDefaultName(
            intExt: scene.intExt,
            dayNight: scene.dayNight,
            location: place,
          );
      await (db.update(db.scenes)..where((s) => s.id.equals(scene.id))).write(
        ScenesCompanion(
          locationCanonical: Value(
            '${scene.intExt}. $newName - ${scene.dayNight}',
          ),
          locationPureName: Value(newName),
          name: hadDefaultName
              ? Value(
                  formatSceneDefaultName(
                    intExt: scene.intExt,
                    dayNight: scene.dayNight,
                    location: newName,
                  ),
                )
              : const Value.absent(),
        ),
      );
    }
  }

  /// Renombra un set, en sus fichas de luz y en el título de sus escenas.
  Future<void> renameSet(int setId, String name) async {
    final set = await db.getLocationById(setId);
    final clean = name.trim();
    if (set == null || clean.isEmpty || clean == set.locationName) return;
    await db.transaction(() async {
      await _renameInScenes(await _scenesOfSet(setId), set.locationName, clean);
      await (db.update(db.visualBibleNarrativeCards)..where(
            (c) =>
                c.locationBasePlanId.equals(setId) &
                c.title.equals(set.locationName),
          ))
          .write(VisualBibleNarrativeCardsCompanion(title: Value(clean)));
      await (db.update(db.locationBasePlans)..where((l) => l.id.equals(setId)))
          .write(LocationBasePlansCompanion(locationName: Value(clean)));
    });
    await db.touchProjectContent(set.projectId);
  }

  /// Renombra una localización y, con ella, el set que es «la localización
  /// entera» (el que se llama igual).
  Future<void> renameSite(int siteId, String name) async {
    final site = await db.getSiteById(siteId);
    final clean = name.trim();
    if (site == null || clean.isEmpty || clean == site.name) return;
    final sets = await (db.select(
      db.locationBasePlans,
    )..where((l) => l.siteId.equals(siteId))).get();
    await (db.update(db.locationSites)..where((s) => s.id.equals(siteId)))
        .write(LocationSitesCompanion(name: Value(clean)));
    for (final set in sets) {
      if (set.locationName.trim().toLowerCase() ==
          site.name.trim().toLowerCase()) {
        await renameSet(set.id, clean);
      }
    }
    await db.touchProjectContent(site.projectId);
  }

  /// Mete un set suelto dentro de una localización.
  Future<void> moveSetToSite(int setId, int siteId) async {
    final set = await db.getLocationById(setId);
    if (set == null) return;
    await db.transaction(() async {
      await (db.update(db.locationBasePlans)..where((l) => l.id.equals(setId)))
          .write(LocationBasePlansCompanion(siteId: Value(siteId)));
      await (db.update(db.scenes)..where((s) => s.locationId.equals(setId)))
          .write(ScenesCompanion(locationSiteId: Value(siteId)));
    });
    await db.touchProjectContent(set.projectId);
  }

  /// Une [sourceSetId] con [targetSetId]: escenas, planos, esquemas de luz,
  /// imágenes y fichas de la biblia pasan al destino, y el origen se
  /// elimina. Una ficha de luz del origen solo se conserva si el destino no
  /// tenía la suya.
  Future<void> mergeSetInto(int sourceSetId, int targetSetId) async {
    if (sourceSetId == targetSetId) return;
    final source = await db.getLocationById(sourceSetId);
    final target = await db.getLocationById(targetSetId);
    if (source == null || target == null) return;
    final bibles = <int>{};
    await db.transaction(() async {
      final scenes = await _scenesOfSet(sourceSetId);
      await (db.update(
        db.scenes,
      )..where((s) => s.locationId.equals(sourceSetId))).write(
        ScenesCompanion(
          locationId: Value(targetSetId),
          locationSiteId: Value(target.siteId),
        ),
      );
      await _renameInScenes(scenes, source.locationName, target.locationName);
      await (db.update(db.shots)
            ..where((s) => s.locationBasePlanId.equals(sourceSetId)))
          .write(ShotsCompanion(locationBasePlanId: Value(targetSetId)));
      await (db.update(db.lightSetups)
            ..where((s) => s.locationBasePlanId.equals(sourceSetId)))
          .write(LightSetupsCompanion(locationBasePlanId: Value(targetSetId)));
      await (db.update(
        db.lightingSetups,
      )..where((s) => s.locationBasePlanId.equals(sourceSetId))).write(
        LightingSetupsCompanion(locationBasePlanId: Value(targetSetId)),
      );
      await (db.update(db.locationImages)
            ..where((i) => i.locationId.equals(sourceSetId)))
          .write(LocationImagesCompanion(locationId: Value(targetSetId)));
      await (db.update(
        db.visualBibleLocationRefs,
      )..where((r) => r.locationBasePlanId.equals(sourceSetId))).write(
        VisualBibleLocationRefsCompanion(
          locationBasePlanId: Value(targetSetId),
        ),
      );

      // Fichas de luz: pasan al destino; si este ya tenía la suya en esa
      // biblia, el texto del origen se le añade y las dos se funden.
      final cards =
          await (db.select(db.visualBibleNarrativeCards)..where(
                (c) => c.locationBasePlanId.isIn([sourceSetId, targetSetId]),
              ))
              .get();
      for (final card in cards.where(
        (c) => c.locationBasePlanId == sourceSetId,
      )) {
        final twin = cards
            .where(
              (c) =>
                  c.locationBasePlanId == targetSetId &&
                  c.bibleId == card.bibleId &&
                  c.kind == card.kind,
            )
            .firstOrNull;
        final extra = (card.body ?? '').trim();
        if (twin != null && extra.isNotEmpty) {
          final own = (twin.body ?? '').trim();
          await (db.update(
            db.visualBibleNarrativeCards,
          )..where((c) => c.id.equals(twin.id))).write(
            VisualBibleNarrativeCardsCompanion(
              body: Value(own.isEmpty ? extra : '$own\n\n$extra'),
            ),
          );
        }
        await (db.update(
          db.visualBibleNarrativeCards,
        )..where((c) => c.id.equals(card.id))).write(
          VisualBibleNarrativeCardsCompanion(
            locationBasePlanId: Value(targetSetId),
            title: Value(target.locationName),
            body: twin != null ? const Value(null) : const Value.absent(),
          ),
        );
        bibles.add(card.bibleId);
      }
      await (db.delete(
        db.locationBasePlans,
      )..where((l) => l.id.equals(sourceSetId))).go();
    });
    for (final bibleId in bibles) {
      await LightingNarrativeCardsService.mergeDuplicates(db, bibleId);
    }
    await db.touchProjectContent(source.projectId);
  }

  /// Elimina un set que no usa ninguna escena, con sus fichas vacías.
  Future<void> deleteUnusedSet(int setId) async {
    final set = await db.getLocationById(setId);
    if (set == null) return;
    await (db.update(db.shots)
          ..where((s) => s.locationBasePlanId.equals(setId)))
        .write(const ShotsCompanion(locationBasePlanId: Value(null)));
    await (db.update(db.lightingSetups)
          ..where((s) => s.locationBasePlanId.equals(setId)))
        .write(const LightingSetupsCompanion(locationBasePlanId: Value(null)));
    await (db.delete(
      db.visualBibleLocationRefs,
    )..where((r) => r.locationBasePlanId.equals(setId))).go();
    await (db.delete(
      db.visualBibleNarrativeCards,
    )..where((c) => c.locationBasePlanId.equals(setId))).go();
    await db.deleteLocation(setId);
  }
}

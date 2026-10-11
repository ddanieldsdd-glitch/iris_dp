import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/locations/location_admin.dart';
import 'package:iris_dp/features/visual_bible/widgets/lighting/lighting_locations_block.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/narrative_card_kind.dart';

void main() {
  late AppDatabase db;
  late LocationAdmin admin;
  late int projectId;
  late int siteId;
  late int wholeSet;
  late int looseSet;
  late int sceneId;
  late int shotId;
  late int bibleId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    admin = LocationAdmin(db);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
    siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'CALLE RAVAL'),
    );
    wholeSet = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'CALLE RAVAL',
      ),
    );
    // La repetida: un set suelto con el mismo nombre.
    looseSet = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        locationName: 'CALLE RAVAL',
      ),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'EXT. CALLE RAVAL - NOCHE',
        intExt: const Value('EXT'),
        dayNight: const Value('NOCHE'),
        locationCanonical: 'EXT. CALLE RAVAL - NOCHE',
        locationPureName: 'CALLE RAVAL',
        locationId: Value(looseSet),
      ),
    );
    shotId = await db.insertShot(
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
        locationBasePlanId: Value(looseSet),
      ),
    );
    bibleId = (await db.ensureVisualBibleForProject(projectId)).id;
    for (final (set, body) in [
      (wholeSet, 'Sodio y neón'),
      (looseSet, 'Lluvia'),
    ]) {
      await db.insertNarrativeCard(
        VisualBibleNarrativeCardsCompanion.insert(
          bibleId: bibleId,
          sectionId: BibleSectionId.lighting,
          kind: NarrativeCardKind.locationLight,
          title: 'CALLE RAVAL',
          body: Value(body),
          locationBasePlanId: Value(set),
        ),
      );
    }
  });
  tearDown(() => db.close());

  test('un set suelto que se llama como una localización no sale en otra '
      'tarjeta', () async {
    final extra = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        locationName: 'hospital',
      ),
    );
    final groups = LightingSiteGroup.group(
      sites: await db.watchSitesForProject(projectId).first,
      sets: await db.watchLocationsForProject(projectId).first,
      cards: const [],
    );
    expect(groups.map((g) => g.name), ['CALLE RAVAL', 'hospital']);
    expect(groups.first.sets.map((s) => s.id), [wholeSet, looseSet]);
    expect(groups.last.sets.single.id, extra);
  });

  test('el aviso cuenta las escenas y planos que usan el set', () async {
    final usage = await admin.usageOfSet(looseSet);
    expect(usage.inUse, isTrue);
    expect(usage.summary, '1 escena y 1 plano del guion técnico');
    expect((await admin.usageOfSet(wholeSet)).inUse, isFalse);
  });

  test('unir un set repetido lleva escenas, planos y luz al bueno', () async {
    await admin.mergeSetInto(looseSet, wholeSet);

    expect(await db.getLocationById(looseSet), isNull);
    final scene = (await db.getSceneById(sceneId))!;
    expect(scene.locationId, wholeSet);
    expect(scene.locationSiteId, siteId);
    expect((await db.getShotById(shotId))!.locationBasePlanId, wholeSet);
    // Una sola ficha de luz, con los dos textos.
    final cards = await db.select(db.visualBibleNarrativeCards).get();
    expect(cards, hasLength(1));
    expect(cards.single.locationBasePlanId, wholeSet);
    expect(cards.single.body, contains('Sodio y neón'));
    expect(cards.single.body, contains('Lluvia'));
  });

  test('renombrar cambia el título de las escenas que lo llevaban', () async {
    await admin.renameSet(looseSet, 'CALLE HOSPITAL');
    final scene = (await db.getSceneById(sceneId))!;
    expect(scene.locationCanonical, 'EXT. CALLE HOSPITAL - NOCHE');
    expect(scene.locationPureName, 'CALLE HOSPITAL');
    expect(
      (await db.getLocationById(looseSet))!.locationName,
      'CALLE HOSPITAL',
    );

    // La localización arrastra a su set del mismo nombre.
    await admin.renameSite(siteId, 'RAVAL');
    expect((await db.getSiteById(siteId))!.name, 'RAVAL');
    expect((await db.getLocationById(wholeSet))!.locationName, 'RAVAL');
  });

  test(
    'meter un set suelto en una localización, y eliminar uno sin uso',
    () async {
      await admin.moveSetToSite(looseSet, siteId);
      expect((await db.getLocationById(looseSet))!.siteId, siteId);
      expect((await db.getSceneById(sceneId))!.locationSiteId, siteId);

      await admin.deleteUnusedSet(wholeSet);
      expect(await db.getLocationById(wholeSet), isNull);
      final cards = await db.select(db.visualBibleNarrativeCards).get();
      expect(cards.single.locationBasePlanId, looseSet);
    },
  );
}

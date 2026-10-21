import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/exposure.dart';
import 'package:iris_dp/features/camera_plan/light/photometry.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/light_family.dart';
import 'package:iris_dp/features/camera_plan/plan_equipment.dart';
import 'package:iris_dp/shared/equipment/catalog_importer.dart';
import 'package:iris_dp/shared/equipment/catalog_light_retirement.dart';
import 'package:iris_dp/shared/equipment/catalog_models.dart';
import 'package:iris_dp/shared/equipment/light_kind.dart';
import 'package:iris_dp/shared/equipment/light_quick_add.dart';

void main() {
  final lights = parseLightCatalog(
    File('assets/catalog/lights.json').readAsStringSync(),
  );
  CatalogLightEntry light(String id) =>
      lights.singleWhere((l) => l.externalId == id);
  final retired =
      (jsonDecode(File('assets/catalog/retired.json').readAsStringSync())
              as Map)['lights']
          as Map;

  group('vocabulario cerrado', () {
    test('todo tipo del catálogo es «tecnología_formato»', () {
      final codes = {
        for (final t in LightTechnology.values)
          for (final f in LightFormat.values) LightKind(t, f).code,
      };
      for (final l in lights) {
        expect(codes, contains(l.lightType), reason: l.externalId);
      }
    });

    test('los tipos de antes se siguen entendiendo', () {
      expect(LightKind.parse('LED Panel'), LightKind.parse('led_panel'));
      expect(LightKind.parse('LED point-source').format, LightFormat.cob);
      expect(LightKind.parse('LED Flexible Panel').format, LightFormat.flex);
      expect(
        LightKind.parse('fresnel'),
        const LightKind(LightTechnology.tungsten, LightFormat.fresnel),
      );
      expect(LightKind.parse('hmi').technology, LightTechnology.hmi);
      expect(LightKind.parse('balloon').technology, LightTechnology.led);
      expect(LightKind.parse('led_tube').technology, LightTechnology.led);
    });

    test('L7-C, L5-C y el LED 20K son fresnel LED, no tungsteno', () {
      for (final id in ['arri_l7c', 'arri_l5_c', 'mole_led_20k']) {
        expect(light(id).lightType, 'led_fresnel', reason: id);
        expect(
          LightTechInfo.fromCatalogType(light(id).lightType),
          LightTech.led,
        );
        expect(lightGroupForCatalogType(light(id).lightType).id, 'led-fresnel');
      }
      // El LED 20K consume unos 3000 W: no son 20 000 W de LED.
      expect(light('mole_led_20k').powerW, 3000);
      expect(light('aputure_storm_1200').lightType, 'led_cob');
      expect(light('arri_m8').powerW, 800);
      expect(light('mole_5k').lightType, 'tungsten_fresnel');
    });
  });

  group('LUKA', () {
    final manifest =
        jsonDecode(File('assets/luka/manifest.json').readAsStringSync()) as Map;
    final fixtures = {
      for (final f in manifest['fixtures'] as List) (f as Map)['id'],
    };

    test('toda luz compatible apunta a un modelo que existe', () {
      for (final l in lights) {
        if (l.lukaFixtureId != null) {
          expect(fixtures, contains(l.lukaFixtureId), reason: l.externalId);
        }
        if (l.lukaCompatible) {
          expect(l.lukaFixtureId, isNotNull, reason: l.externalId);
        }
      }
    });

    test('ni el L5-C es un L7-C ni el globo un SkyPanel', () {
      expect(light('arri_l5_c').lukaFixtureId, isNull);
      expect(light('arri_softbox_balloon').lukaFixtureId, isNull);
      expect(light('arri_m12').lukaCompatible, isFalse);
      expect(light('arri_m8').lukaCompatible, isFalse);
    });
  });

  group('fotometría', () {
    test('toda fotometría trae su distancia, su haz y una fuente', () {
      final withPhoto = lights.where((l) => l.photometryLux != null).toList();
      expect(withPhoto.length, greaterThanOrEqualTo(6));
      for (final l in withPhoto) {
        expect(l.photometryDistanceM, greaterThan(0), reason: l.externalId);
        expect(l.beamAngleDeg, isNotNull, reason: l.externalId);
        expect(l.provenance?.sourceUrl, isNotNull, reason: l.externalId);
        expect(
          l.provenance!.statusForField('fotometria_lux').label,
          anyOf('CONFIRMADO', 'SECUNDARIO'),
          reason: l.externalId,
        );
      }
    });

    test('un 5K en flood a 3 m y una práctica de 60 W a 1 m: casi siete '
        'stops, desde el catálogo', () {
      Light row(CatalogLightEntry e) => Light(
        id: 1,
        brand: e.brand,
        model: e.model,
        lightType: e.lightType,
        powerW: e.powerW,
        colorTempMin: e.colorTempMin,
        colorTempMax: e.colorTempMax,
        isLukaCompatible: false,
        beamAngleDeg: e.beamAngleDeg,
        photometryLux: e.photometryLux,
        photometryDistanceM: e.photometryDistanceM,
        isCustom: false,
        vintage: false,
      );
      PlanLight plan(String id) {
        final el = PlanEquipment.lightFromCatalog(row(light(id)))
          ..props['intensity'] = 100;
        return PlanLight.of(el)!;
      }

      final fiveK = plan('mole_5k');
      final bulb = plan('practical_bulb_60w');
      expect(fiveK.bare.status, PhotometryStatus.manufacturer);
      expect(bulb.source.isOmni, isTrue);
      final stops = stopsBetweenLux(
        fiveK.source.illuminance(3),
        bulb.source.illuminance(1),
      );
      expect(stops, greaterThan(6.5));
    });

    test('al cerrar el haz de un dato medido, el eje sube con el flujo', () {
      PlanLight at(double spread) => PlanLight.of(
        PlanElement(
          id: 1,
          type: ElementType.light,
          position: Offset.zero,
          lightType: LightType.hmi,
          props: {
            'intensity': 100,
            'spread': spread,
            PlanLight.measuredLuxKey: 1100,
            PlanLight.measuredMetersKey: 10,
            PlanLight.measuredBeamKey: 58,
          },
        ),
      )!;
      expect(at(58).source.illuminance(10), closeTo(1100, 1));
      // ARRI da 11 250 lx a 10 m en spot (15°); el reparto del flujo da
      // el mismo orden.
      final spot = at(15).source.illuminance(10);
      expect(spot, greaterThan(8000));
      expect(spot, lessThan(25000));
    });
  });

  group('duplicados', () {
    test('ninguno sigue en el catálogo y todos van a una ficha que sí', () {
      final ids = lights.map((l) => l.externalId).toSet();
      expect(retired, isNotEmpty);
      for (final MapEntry(:key, :value) in retired.entries) {
        expect(ids, isNot(contains(key)));
        expect(ids, contains(value));
      }
      final names = lights.map((l) => '${l.brand} ${l.model}').toList();
      expect(names.toSet().length, names.length);
    });

    late AppDatabase db;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
    });

    test('retirar uno pasa el equipo y las plantas al que se queda', () async {
      CatalogLightEntry entry(String id) => CatalogLightEntry(
        externalId: id,
        brand: 'ARRI',
        model: id,
        lightType: 'led_panel',
        powerW: 475,
        colorTempMin: 2800,
        colorTempMax: 10000,
      );
      await upsertCatalogLights(db, [entry('queda'), entry('sobra')]);
      final keep = (await db.getLightByExternalId('queda'))!;
      final dup = (await db.getLightByExternalId('sobra'))!;

      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Duplicados'),
      );
      final other = await db.insertProject(
        ProjectsCompanion.insert(name: 'Ya tenía las dos'),
      );
      for (final (p, id) in [
        (projectId, dup.id),
        (other, dup.id),
        (other, keep.id),
      ]) {
        await db.assignEquipmentToProject(
          projectId: p,
          equipmentType: 'light',
          equipmentId: id,
        );
      }
      final sceneId = await db
          .into(db.scenes)
          .insert(
            ScenesCompanion.insert(
              projectId: projectId,
              number: 1,
              name: '1',
              locationCanonical: 'CASA',
              locationPureName: 'Casa',
            ),
          );
      final shotId = await db
          .into(db.shots)
          .insert(
            ShotsCompanion.insert(
              sceneId: sceneId,
              projectId: projectId,
              number: 1,
            ),
          );
      final elementId = await db
          .into(db.cameraPlanElements)
          .insert(
            CameraPlanElementsCompanion.insert(
              shotId: shotId,
              type: 'light',
              externalMappingJson: Value(
                jsonEncode({'catalogLightId': dup.id}),
              ),
            ),
          );
      final setupId = await db.insertLightSetup(
        LightSetupsCompanion.insert(
          projectId: projectId,
          name: 'Noche',
          planJson: Value(
            jsonEncode({
              'elements': [
                {
                  'type': 'light',
                  'externalMapping': {'catalogLightId': dup.id},
                },
                {
                  'type': 'light',
                  'externalMapping': {'catalogLightId': 999},
                },
              ],
            }),
          ),
        ),
      );

      expect(await retireCatalogLights(db, {'sobra': 'queda'}), 1);

      expect(await db.getLightByExternalId('sobra'), isNull);
      final assigned = await db.getProjectEquipment(projectId);
      expect(assigned.single.equipmentId, keep.id);
      // El que ya tenía la buena no la tiene dos veces.
      final both = await db.getProjectEquipment(other);
      expect(both.map((a) => a.equipmentId), [keep.id]);

      final element = await (db.select(
        db.cameraPlanElements,
      )..where((e) => e.id.equals(elementId))).getSingle();
      expect(
        jsonDecode(element.externalMappingJson!)['catalogLightId'],
        keep.id,
      );
      final setup = await (db.select(
        db.lightSetups,
      )..where((s) => s.id.equals(setupId))).getSingle();
      final plan = jsonDecode(setup.planJson!)['elements'] as List;
      expect(plan[0]['externalMapping']['catalogLightId'], keep.id);
      expect(plan[1]['externalMapping']['catalogLightId'], 999);
      // Las plantas cambiadas se marcan para sincronizar.
      final project = await db.getProject(projectId);
      expect(project!.contentSyncUpdatedAt, isNotNull);
    });

    test('una luz propia del usuario no se retira', () async {
      await upsertCatalogLights(db, [
        const CatalogLightEntry(
          externalId: 'queda',
          brand: 'A',
          model: 'B',
          lightType: 'led_panel',
          powerW: 1,
          colorTempMin: 1,
          colorTempMax: 1,
        ),
      ]);
      await db.insertLight(
        LightsCompanion.insert(
          brand: 'Mía',
          model: 'Mía',
          lightType: 'led_panel',
          powerW: 10,
          colorTempMin: 3200,
          colorTempMax: 3200,
          externalId: const Value('sobra'),
          isCustom: const Value(true),
        ),
      );
      expect(await retireCatalogLights(db, {'sobra': 'queda'}), 0);
      expect(await db.getLightByExternalId('sobra'), isNotNull);
    });
  });

  group('alta rápida', () {
    late AppDatabase db;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
    });

    test('el formato da el haz y la tecnología; queda pendiente', () async {
      const draft = LightQuickAddDraft(
        format: LightFormat.tube,
        brand: 'Astera',
        model: 'Titan X2',
        color: LightColorMode.rgb,
        watts: 48,
      );
      expect(draft.problems, isEmpty);
      final (:light, :created) = await LightQuickAdd.add(db, draft);
      expect(created, isTrue);
      expect(light.externalId, 'astera_titan_x2');
      expect(light.lightType, 'led_tube');
      expect(light.beamAngleDeg, 360);
      expect(light.colorTempMin, 2000);
      expect(light.colorTempMax, 10000);
      expect(light.isCustom, isTrue);
      expect(light.dataStatus, 'PENDIENTE');
      expect(LightQuickAdd.isPending(light), isTrue);
      expect(LightQuickAdd.missing(light), contains('ángulo de haz'));

      // En la planta, un tubo alumbra alrededor y con su tamaño.
      final el = PlanEquipment.lightFromCatalog(light)
        ..props['intensity'] = 100;
      final plan = PlanLight.of(el)!;
      expect(plan.source.isOmni, isTrue);
      expect(plan.source.sizeM, LightFormat.tube.sizeM);
      expect(plan.source.status, PhotometryStatus.estimated);

      // Darla otra vez no la duplica.
      expect((await LightQuickAdd.add(db, draft)).created, isFalse);
    });

    test('un fresnel de temperatura fija sale de tungsteno a 3200 K', () {
      const draft = LightQuickAddDraft(
        format: LightFormat.fresnel,
        brand: 'Mole',
        model: 'Baby Junior',
        watts: 2000,
      );
      expect(draft.kind.code, 'tungsten_fresnel');
      expect(draft.cctRange, (3200, 3200));
      expect(
        const LightQuickAddDraft(
          format: LightFormat.panel,
          brand: '',
          model: 'x',
          watts: 0,
        ).problems,
        hasLength(2),
      );
    });

    test(
      'cuando el Excel trae su ficha, la completa y pasa a oficial',
      () async {
        final (:light, created: _) = await LightQuickAdd.add(
          db,
          const LightQuickAddDraft(
            format: LightFormat.cob,
            brand: 'Aputure',
            model: 'STORM 400x',
            color: LightColorMode.bicolor,
            watts: 400,
          ),
        );
        final stats = await upsertCatalogLights(db, [
          CatalogLightEntry(
            externalId: light.externalId!,
            brand: 'Aputure',
            model: 'STORM 400x',
            lightType: 'led_cob',
            powerW: 400,
            colorTempMin: 2500,
            colorTempMax: 10000,
            photometryLux: 5000,
            photometryDistanceM: 3,
          ),
        ]);
        expect(stats.skippedCustom, 0);
        final row = (await db.getLightByExternalId(light.externalId!))!;
        expect(row.isCustom, isFalse);
        expect(LightQuickAdd.isPending(row), isFalse);
        expect(row.colorTempMin, 2500);
        expect(row.photometryLux, 5000);
        // Lo que el Excel no dice se conserva.
        expect(row.beamAngleDeg, LightFormat.cob.beamDeg);
      },
    );

    test('una luz propia que no es de alta rápida no se pisa', () async {
      await db.insertLight(
        LightsCompanion.insert(
          brand: 'Mía',
          model: 'Mía',
          lightType: 'led_panel',
          powerW: 10,
          colorTempMin: 3200,
          colorTempMax: 3200,
          externalId: const Value('mia_mia'),
          isCustom: const Value(true),
        ),
      );
      final stats = await upsertCatalogLights(db, [
        const CatalogLightEntry(
          externalId: 'mia_mia',
          brand: 'Otra',
          model: 'Otra',
          lightType: 'led_panel',
          powerW: 99,
          colorTempMin: 1,
          colorTempMax: 1,
        ),
      ]);
      expect(stats.skippedCustom, 1);
    });
  });

  test('las plantas de antes sin haz en la ficha toman el de su formato', () {
    final el = PlanEquipment.lightFromCatalog(
      const Light(
        id: 1,
        brand: 'Nanlite',
        model: 'PavoTube II 15X',
        lightType: 'LED Tube',
        powerW: 15,
        colorTempMin: 2700,
        colorTempMax: 12000,
        isLukaCompatible: false,
        isCustom: false,
        vintage: false,
      ),
    );
    expect(el.props['spread'], 360);
    expect(el.position, Offset.zero);
  });
}

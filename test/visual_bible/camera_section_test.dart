import 'dart:convert';

import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
// ignore_for_file: cascade_invocations
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/catalog/equipment_facts.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/widgets/sections/camera_sensor_section.dart';
import 'package:iris_dp/shared/visual_bible/bible_equipment.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_text_specs.dart';
import 'package:iris_dp/shared/visual_bible/camera_points.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/snapshot.dart';

void main() {
  test('equipo: estado, alternativa y datos de la ficha van y vuelven', () {
    const item = BibleEquipmentItem(
      role: 'A',
      catalogId: 7,
      name: 'ARRI Alexa 35',
      facts: {'Sensor': '27.99×19.22 mm'},
    );
    expect(item.status, BibleEquipmentStatus.tentative);
    final next = item
        .copyWith(status: BibleEquipmentStatus.definitive)
        .withAlternative(catalogId: 9, name: 'Sony Venice 2')
        .copyWith(altNote: 'Si no entra en presupuesto');
    final back = BibleEquipmentItem.listFrom(
      BibleEquipmentItem.encode([next]),
    ).single;
    expect(back.status, BibleEquipmentStatus.definitive);
    expect(back.altName, 'Sony Venice 2');
    expect(back.altNote, 'Si no entra en presupuesto');
    expect(back.facts['Sensor'], '27.99×19.22 mm');
    // Quitar la alternativa se lleva su nota.
    expect(back.withAlternative().altNote, '');
  });

  test('la ficha del cuerpo se completa con la cámara, sin pisar lo escrito',
      () {
    const value = BibleTextSpecsValue(
      rows: [('Sensor', ''), ('Montura', 'PL'), ('ISO dual', '')],
    );
    final filled = CameraPoints.withFacts(value, {
      'Sensor': '27.99×19.22 mm',
      'Montura': 'LPL',
    });
    expect(filled.rows, [
      ('Sensor', '27.99×19.22 mm'),
      ('Montura', 'PL'),
      ('ISO dual', ''),
    ]);
  });

  for (final width in [900.0, 1500.0]) {
    testWidgets('Cámara a $width px: lo antiguo en los puntos nuevos, sin '
        'ejemplos, y la cámara pasa a definitiva', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await loadSnapshotFonts();
      tester.view.physicalSize = Size(width, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      late VisualBibleData data;
      String? contentJson;
      Future<String?> stored() async {
        final def =
            await (db.select(db.bibleSectionDefinitions)..where(
                  (d) =>
                      d.bibleId.equals(data.id) &
                      d.id.equals(BibleSectionId.camera),
                ))
                .getSingle();
        return def.contentJson;
      }

      await tester.runAsync(() async {
        final projectId = await db.insertProject(
          ProjectsCompanion.insert(name: 'Cámara'),
        );
        final cameraId = await db
            .into(db.cameras)
            .insert(
              CamerasCompanion.insert(
                brand: 'ARRI',
                model: 'Alexa 35',
                sensorWidthMm: 27.99,
                sensorHeightMm: 19.22,
                mountType: const Value('LPL'),
                nativeIso: const Value(800),
                dynamicRangeStops: const Value(17),
              ),
            );
        final bible = await db.ensureVisualBibleForProject(projectId);
        await db.addBuiltinBibleSection(
          bibleId: bible.id,
          sectionId: BibleSectionId.camera,
        );
        data = VisualBibleData.fromRow(bible)
          ..primaryCameraId = cameraId
          ..codec = 'ARRIRAW'
          ..cameraPhilosophy = 'Cámara a la altura de los ojos'
          ..cameraMovements = [
            {'movement': 'Dolly', 'narrative': 'Acompaña sin anticipar'},
          ];
        await (db.update(db.visualBibles)
              ..where((b) => b.id.equals(bible.id)))
            .write(VisualBiblesCompanion(primaryCameraId: Value(cameraId)));
        // Contenido guardado con la pantalla de antes.
        await db.saveBibleSectionFieldValue(
          bible.id,
          BibleSectionId.camera,
          'cameraData',
          jsonEncode({
            'shutterAngle': '172,8°',
            'filters': [
              {'label': 'Difusión', 'value': 'Glimmerglass 1/4'},
            ],
            'ditFlow': 'Silverstack',
          }),
        );
        contentJson = await stored();
        // El catálogo de la app se lee una vez, con tiempo real.
        await EquipmentCatalog.camera(externalId: 'arri_alexa35');
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: CameraSensorSection(
                data: data,
                projectId: data.projectId,
                sectionContentJson: contentJson,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await settle();
      expect(tester.takeException(), isNull);

      // La cámara principal de antes es la A, tentativa, con su ficha.
      expect(find.text('ARRI Alexa 35'), findsOneWidget);
      expect(find.text('TENTATIVA'), findsOneWidget);
      expect(find.textContaining('27.99×19.22 mm'), findsWidgets);

      // Lo escrito antes está en su punto.
      expect(find.text('ARRIRAW'), findsOneWidget);
      expect(find.text('172,8°'), findsOneWidget);
      expect(find.text('Glimmerglass 1/4'), findsOneWidget);
      expect(find.textContaining('Silverstack'), findsOneWidget);
      expect(find.text('Cámara a la altura de los ojos'), findsOneWidget);
      expect(find.text('Dolly'), findsOneWidget);

      // Nada de datos de ejemplo.
      for (final example in [
        'ACES 1.3',
        '-65dB SNR',
        'Codex Compact Drive 2TB',
        'B-Mount 290Wh (x8)',
        '1x LTO-8 (Archivo)',
        'EXT. NIGHT',
      ]) {
        expect(find.textContaining(example), findsNothing, reason: example);
      }

      // Lo técnico sale del catálogo: ficha, modos y matriz.
      expect(find.textContaining('LogC4'), findsWidgets);
      expect(find.text('MODO DE GRABACIÓN · ARRI ALEXA 35'), findsOneWidget);
      expect(find.text('4.6K 3:2 Open Gate'), findsOneWidget);
      expect(find.text('3K 1:1'), findsOneWidget);
      expect(find.text('ARRIRAW/ProRes'), findsWidgets);

      // Elegir un modo que recorta el sensor avisa de lo que supone.
      await tester.tap(find.byTooltip('Elegir modo de grabación'));
      await settle();
      await tester.tap(find.text('4K 16:9').last);
      await settle();
      late String? picked;
      await tester.runAsync(() async => picked = await stored());
      final recording = BibleTextSpecsValue.decode(
        BibleSectionFieldsConfig.parseValues(picked)[CameraPoints.recording],
      );
      expect(CameraPoints.row(recording, CameraPoints.rowMode), '4K 16:9');
      expect(
        CameraPoints.row(recording, CameraPoints.rowResolution),
        '4096 × 2304',
      );
      expect(CameraPoints.row(recording, CameraPoints.rowModeFps), '120 fps');
      // Lo que ya estaba escrito (obturador) no se pierde.
      expect(CameraPoints.row(recording, CameraPoints.rowShutter), '172,8°');

      // Pasa a definitiva con un toque, sin diálogo.
      await tester.tap(find.text('DEFINITIVA'));
      await settle();
      expect(find.byType(AlertDialog), findsNothing);
      late String? after;
      await tester.runAsync(() async => after = await stored());
      final items = BibleEquipmentItem.listFrom(
        BibleSectionFieldsConfig.parseValues(after)[CameraPoints.equipment],
      );
      expect(items.single.status, BibleEquipmentStatus.definitive);
      expect(items.single.role, 'A');
      expect(items.single.facts['Montura'], 'LPL');

      await saveSnapshot(tester, 'camara_${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  }
}

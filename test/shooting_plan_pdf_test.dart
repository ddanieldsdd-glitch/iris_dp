import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/shared/pdf_export/shooting_plan_pdf.dart';

ShootingPlanBlock _block(int n) => ShootingPlanBlock(
  sceneLabel: '6',
  shotNumber: n,
  slug: 'INT/EXT CORTIJO NOCHE',
  exposure: '180°/24fps',
  framing: 'PM',
  lens: '35mm',
  action: 'Una acción bastante larga. ' * 40,
);

ShootingPlanEntry _entry(String label, int blocks) =>
    ShootingPlanEntry(label, [for (var i = 1; i <= blocks; i++) _block(i)]);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    ShootingPlanPdf.debugEntryPages = {};
  });
  tearDown(() => ShootingPlanPdf.debugEntryPages = null);

  test('un plano lleva todas sus imágenes en el PDF', () async {
    Uint8List frame(int shade) => Uint8List.fromList(
      img.encodeJpg(
        img.Image(width: 16, height: 9)
          ..clear(img.ColorRgb8(shade, shade, shade)),
      ),
    );
    final bytes = await ShootingPlanPdf.compose(
      projectName: 'Prueba',
      days: [
        ShootingPlanDay('Orden', [
          ShootingPlanEntry('ESCENA 1 (1)', [
            ShootingPlanBlock(
              sceneLabel: '1',
              shotNumber: 1,
              slug: 'CALLE',
              frames: [frame(10), frame(90), frame(170), frame(250)],
            ),
          ]),
        ]),
      ],
    );
    final raw = latin1.decode(bytes);
    expect(RegExp(r'/Subtype\s*/Image').allMatches(raw).length, 4);
  });

  test('la rejilla de imágenes crece con su número', () {
    expect(ShootingPlanPdf.frameGridColumns(1), 1);
    expect(ShootingPlanPdf.frameGridColumns(2), 1);
    expect(ShootingPlanPdf.frameGridColumns(4), 2);
    expect(ShootingPlanPdf.frameGridColumns(9), 3);
  });

  test('cada entrada del índice apunta a la página donde se pinta', () async {
    final days = [
      ShootingPlanDay('Orden de grabación · Esc 4 y 5', [
        _entry('ESCENA 4 (1-3)', 3),
        _entry('ESCENA 5 (1)', 1),
      ], heading: 'Jornada 1'),
      ShootingPlanDay('Orden de grabación · Esc 6', [
        _entry('ESCENA 6 (1-4)', 4),
        _entry('ESCENA 7 (1)', 1),
      ], heading: 'Jornada 2'),
    ];
    final layout = ShootingPlanLayout.of(days, overviews: true);
    await ShootingPlanPdf.compose(
      projectName: 'Prueba',
      days: days,
      overviews: const [ShootingPlanOverview('Cocina · Noche')],
    );

    final painted = ShootingPlanPdf.debugEntryPages!;
    expect(painted, hasLength(4));
    for (final day in days) {
      for (final entry in day.entries) {
        expect(
          layout.entryPages[entry],
          painted[entry.label],
          reason: entry.label,
        );
      }
    }
    // Índice en la 1; J1 en 2-3; J2 empieza página aparte.
    expect(painted['ESCENA 4 (1-3)'], 2);
    expect(painted['ESCENA 5 (1)'], 3);
    expect(painted['ESCENA 6 (1-4)'], 4);
    expect(painted['ESCENA 7 (1)'], 6);
    expect(layout.overviewPage, 7);
  });

  test('un índice largo desplaza los números', () async {
    final entries = [for (var i = 0; i < 25; i++) _entry('ESCENA $i (1)', 1)];
    final days = [ShootingPlanDay('Orden', entries)];
    final layout = ShootingPlanLayout.of(days, overviews: false);
    expect(layout.indexPages, 2);
    await ShootingPlanPdf.compose(projectName: 'Prueba', days: days);
    expect(ShootingPlanPdf.debugEntryPages!['ESCENA 0 (1)'], 3);
    expect(ShootingPlanPdf.debugEntryPages!['ESCENA 24 (1)'], 15);
  });

  test('sin planos sale un aviso, no un PDF roto', () async {
    final bytes = await ShootingPlanPdf.compose(
      projectName: 'Prueba',
      days: const [],
    );
    expect(bytes, isNotEmpty);
  });
}

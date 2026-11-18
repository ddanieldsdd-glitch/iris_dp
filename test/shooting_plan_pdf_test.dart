import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/features/camera_plan/plan_renderer.dart';
import 'package:iris_dp/features/export_center/export_options.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_timeline.dart';
import 'package:iris_dp/shared/pdf_export/pdf_page_count.dart';
import 'package:iris_dp/shared/pdf_export/shoot_day_brief.dart';
import 'package:iris_dp/shared/pdf_export/shooting_plan_day_sheet.dart';
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

ShootDayBrief _dayBrief({int rows = 6, int stops = 2}) => ShootDayBrief(
  dayId: 1,
  dayName: 'Jornada 1',
  call: '07:30',
  window: '07:30 – 17:00',
  sun: const [('Amanecer', '07:38'), ('Atardecer', '17:35')],
  weatherLine: 'Cubierto · 16–20 °C',
  rows: [
    for (var i = 0; i < rows; i++)
      i.isEven
          ? BriefRow(
              scene: true,
              time: '1$i:00 – 1$i:30',
              title: 'Esc. $i · INT. LOCAL · NOCHE',
              shots: const [BriefShot(number: 1, framing: 'PML')],
            )
          : const BriefRow(
              kind: ShootStripKind.meal,
              time: '14:00 – 14:45',
              title: 'COMIDA',
            ),
  ],
  stops: [
    for (var i = 0; i < stops; i++)
      BriefStop(
        name: 'SITIO $i',
        time: '0$i:00 – 1$i:00',
        minutes: '3 h',
        latitude: 41.3 + i / 10,
        longitude: 2.1,
      ),
  ],
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    ShootingPlanPdf.debugEntryPages = {};
  });
  tearDown(() => ShootingPlanPdf.debugEntryPages = null);

  test('las imágenes del documento se recuerdan y se pueden quitar', () {
    final chosen = const ExportOptions().copyWith(
      planCoverImage: '/a/portada.jpg',
      planBackdropImage: '/a/fondo.jpg',
    );
    final back = ExportOptions.fromJson(chosen.toJson());
    expect(back.planCoverImage, '/a/portada.jpg');
    expect(back.planBackdropImage, '/a/fondo.jpg');
    final cleared = back.copyWith(clearPlanCoverImage: true);
    expect(cleared.planCoverImage, isNull);
    expect(cleared.planBackdropImage, '/a/fondo.jpg');
  });

  test('las partes del índice y la planta grande se recuerdan', () {
    final chosen = const ExportOptions().copyWith(
      planIndexParts: {PlanIndexPart.places},
      planBig: PlanSheetView.light,
    );
    final back = ExportOptions.fromJson(chosen.toJson());
    expect(back.planIndexParts, {PlanIndexPart.places});
    expect(back.planBig, PlanSheetView.light);
    // Lo guardado antes de esto trae todas las partes y la de cámara.
    final old = ExportOptions.fromJson({'planIndex': true});
    expect(old.planIndexParts, PlanIndexPart.values.toSet());
    expect(old.planBig, PlanSheetView.stage);
  });

  test('una jornada: orden, lugares y datos caben en la portada', () async {
    final bytes = await ShootingPlanPdf.compose(
      projectName: 'Prueba',
      days: [
        ShootingPlanDay(
          'Orden',
          [_entry('ESCENA 1 (1)', 1), _entry('ESCENA 2 (1)', 1)],
          heading: 'Jornada 1',
          brief: _dayBrief(),
        ),
      ],
      indexParts: PlanIndexPart.values.toSet(),
    );
    final raw = latin1.decode(bytes);
    // Portada y una página por cada dos planos: sin hojas de más.
    expect(countPdfPages(bytes), 2);
    expect(ShootingPlanPdf.debugEntryPages!['ESCENA 1 (1)'], 2);
    expect(raw, contains('maps.apple.com'));
    expect(raw, contains('waze.com'));
  });

  test('si no cabe, el resumen va en una hoja tras el índice', () async {
    final bytes = await ShootingPlanPdf.compose(
      projectName: 'Prueba',
      days: [
        ShootingPlanDay(
          'Orden',
          [for (var i = 0; i < 6; i++) _entry('ESCENA $i (1)', 1)],
          heading: 'Jornada 1',
          brief: _dayBrief(rows: 40),
        ),
      ],
      indexParts: PlanIndexPart.values.toSet(),
    );
    // Portada con índice, resumen y tres páginas de planos.
    expect(countPdfPages(bytes), 5);
    expect(ShootingPlanPdf.debugEntryPages!['ESCENA 0 (1)'], 3);
  });

  test('sin partes elegidas, el índice es el de siempre', () async {
    final bytes = await ShootingPlanPdf.compose(
      projectName: 'Prueba',
      days: [
        ShootingPlanDay(
          'Orden',
          [_entry('ESCENA 1 (1)', 1)],
          brief: _dayBrief(),
        ),
      ],
    );
    expect(countPdfPages(bytes), 2);
    expect(latin1.decode(bytes), isNot(contains('maps.apple.com')));
  });

  test('varias jornadas: un resumen por jornada', () async {
    final bytes = await ShootingPlanPdf.compose(
      projectName: 'Prueba',
      days: [
        for (var d = 1; d <= 2; d++)
          ShootingPlanDay(
            'Orden',
            [_entry('ESCENA $d (1)', 1)],
            heading: 'Jornada $d',
            brief: _dayBrief(),
          ),
      ],
      indexParts: {PlanIndexPart.order},
    );
    expect(countPdfPages(bytes), 1 + 2 + 2);
    expect(ShootingPlanPdf.debugEntryPages!['ESCENA 1 (1)'], 4);
    expect(ShootingPlanPdf.debugEntryPages!['ESCENA 2 (1)'], 5);
  });

  test('la portada admite una imagen', () async {
    final bytes = await ShootingPlanPdf.compose(
      projectName: 'Prueba',
      days: [
        ShootingPlanDay('Orden', [_entry('ESCENA 1 (1)', 1)]),
      ],
      coverImage: Uint8List.fromList(
        img.encodeJpg(
          img.Image(width: 32, height: 9)..clear(img.ColorRgb8(80, 40, 20)),
        ),
      ),
    );
    expect(bytes, isNotEmpty);
    expect(latin1.decode(bytes), matches(RegExp(r'/Subtype\s*/Image')));
  });

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

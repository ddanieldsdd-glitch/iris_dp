import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/features/shoot_documents/shoot_day_timeline.dart';
import 'package:iris_dp/features/storyboard/storyboard_group_export_options.dart';
import 'package:iris_dp/shared/pdf_export/shoot_day_brief.dart';
import 'package:iris_dp/shared/pdf_export/shoot_day_order_pdf.dart';
import 'package:iris_dp/shared/pdf_export/storyboard_pdf.dart';
import 'package:iris_dp/shared/pdf_export/technical_script_pdf.dart';
import 'package:iris_dp/shared/technical_script_export/technical_script_doc.dart';

Uint8List _jpg() => Uint8List.fromList(
  img.encodeJpg(
    img.Image(width: 64, height: 36)..clear(img.ColorRgb8(90, 90, 90)),
  ),
);

ShootDayBrief _brief({bool located = true}) => ShootDayBrief(
  dayName: 'Jornada 1',
  position: 'día 1 de 5',
  date: 'viernes 13 de noviembre de 2026',
  window: '07:30 – 17:00',
  call: '07:30',
  placeName: 'KEBAB KHALED',
  placeDetail: 'Carrer de Sant Pau, 12, Barcelona',
  latitude: located ? 41.37815 : null,
  longitude: located ? 2.17323 : null,
  map: located ? _jpg() : null,
  cover: _jpg(),
  weatherLine: 'Cubierto · 16–20 °C',
  hours: [
    for (var h = 7; h <= 17; h++)
      BriefHour(hour: h, temperature: 18, code: [0, 2, 3, 61, 71, 95][h % 6]),
  ],
  sun: const [('Amanecer', '07:38'), ('Atardecer', '17:35')],
  rows: [
    const BriefRow(
      kind: ShootStripKind.meal,
      time: '14:00 – 15:00',
      title: 'COMIDA',
    ),
    BriefRow(
      scene: true,
      time: '10:15 – 10:45',
      title: 'Esc. 6 · INT. KEBAB KHALED · NOCHE',
      shots: [
        BriefShot(number: 1, framing: 'PML', image: _jpg()),
        const BriefShot(number: 2, framing: 'PM'),
      ],
    ),
  ],
);

/// Los documentos de la jornada, más visuales: el orden del día con mapa,
/// QR, tiempo por horas y storyboard; la portada del guion técnico; y un
/// storyboard que no deja media hoja vacía.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el orden del día lleva el enlace de Maps y las imágenes', () async {
    final bytes = await ShootDayOrderPdf.compose(
      projectName: 'KEBAB KHALED',
      sheets: [_brief()],
    );
    final text = latin1.decode(bytes);
    expect(text, startsWith('%PDF-'));
    // Los enlaces de Google Maps y Waze van como anotaciones pulsables.
    expect(text, contains('google.com/maps'));
    expect(text, contains('waze.com'));
    expect(
      RegExp(r'/Subtype\s*/Image').allMatches(text).length,
      greaterThan(2),
    );
  });

  test('sin ubicar no hay mapa ni enlaces, y no rompe', () async {
    final bytes = await ShootDayOrderPdf.compose(
      projectName: 'K',
      sheets: [_brief(located: false)],
    );
    expect(latin1.decode(bytes), isNot(contains('google.com/maps')));
  });

  test('el guion técnico de una jornada abre con su portada', () async {
    final doc = TechnicalScriptDoc(
      title: 'GUION TÉCNICO DE RODAJE · K',
      projectName: 'K',
      brief: _brief(),
      columns: scriptDocColumns(hidden: const {}),
      sections: const [
        ScriptDocSection(
          title: '6. INT. KEBAB',
          headerFill: 0xDDDDDD,
          rows: [],
        ),
      ],
    );
    final text = latin1.decode(
      await TechnicalScriptPdfExporter.buildBytes(doc),
    );
    expect(text, contains('google.com/maps'));
    // La copia que se manda a otro formato no pierde la portada.
    expect(doc.copyWith(includeIndex: false).brief, isNotNull);
  });

  test('pocos planos: viñetas más grandes', () {
    const six = StoryboardGridDensity.six;
    expect(StoryboardPdfExporter.gridShape(1, six), (columns: 1, rows: 1));
    expect(StoryboardPdfExporter.gridShape(2, six), (columns: 2, rows: 1));
    expect(StoryboardPdfExporter.gridShape(4, six), (columns: 2, rows: 2));
    expect(StoryboardPdfExporter.gridShape(5, six), (columns: 3, rows: 2));
    expect(StoryboardPdfExporter.gridShape(6, six), (columns: 3, rows: 2));
  });
}

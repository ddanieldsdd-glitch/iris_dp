import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/technical_script/import/docx_technical_script_reader.dart';

/// Word mínimo con una tabla por escena, como los guiones técnicos reales.
Uint8List buildTechnicalScriptDocx({
  required List<(String heading, List<List<Object>> rows)> scenes,
  Map<String, List<int>> media = const {},
  String title = 'GUION TÉCNICO PRUEBA',
}) {
  String p(String text) =>
      '<w:p><w:r><w:t xml:space="preserve">${const HtmlEscape().convert(text)}</w:t></w:r></w:p>';
  String img(String relId) =>
      '<w:p><w:r><w:drawing><wp:inline><a:graphic><a:graphicData><pic:pic>'
      '<pic:blipFill><a:blip r:embed="$relId"/></pic:blipFill>'
      '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>';
  String cell(Object value) {
    if (value is List<String>) {
      return '<w:tc>${value.map(img).join()}${value.isEmpty ? '<w:p/>' : ''}</w:tc>';
    }
    final lines = (value as String).split('\n');
    return '<w:tc>${lines.map(p).join()}</w:tc>';
  }

  const header = [
    'ESC',
    'PLANO',
    'Encuadre',
    'LENTE/ANG/MOV',
    'F',
    'PERS.',
    'ACCIÓN',
    'REFERENCIA',
    'PLANTA',
    'APUNTES',
  ];
  final body = StringBuffer(p(title));
  for (final (heading, rows) in scenes) {
    body.write(p(heading));
    body.write('<w:tbl><w:tr>${header.map(cell).join()}</w:tr>');
    for (final row in rows) {
      body.write('<w:tr>${row.map(cell).join()}</w:tr>');
    }
    body.write('</w:tbl>');
  }
  final document =
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<w:body>$body</w:body></w:document>';
  final rels = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
  );
  for (final name in media.keys) {
    rels.write(
      '<Relationship Id="$name" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$name.png"/>',
    );
  }
  rels.write('</Relationships>');

  final archive = Archive();
  void add(String name, List<int> data) =>
      archive.addFile(ArchiveFile(name, data.length, data));
  add('word/document.xml', utf8.encode(document));
  add('word/_rels/document.xml.rels', utf8.encode(rels.toString()));
  media.forEach((name, data) => add('word/media/$name.png', data));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  group('parseSceneHeading', () {
    test('número, letra, int/ext, lugar y momento', () {
      final h = parseSceneHeading('13A. INT. KEBAB KHALED - NOCHE')!;
      expect(h.number, 13);
      expect(h.suffix, 'A');
      expect(h.intExt, 'INT');
      expect(h.location, 'KEBAB KHALED');
      expect(h.dayNight, 'NOCHE');
    });

    test('lugar con guiones y momento CONTINUO', () {
      final h = parseSceneHeading('14. EXT. CASA - JARDÍN - CONTINUO')!;
      expect(h.suffix, isNull);
      expect(h.location, 'CASA - JARDÍN');
      expect(h.dayNight, 'CONTINUO');
    });

    test('un título no es una cabecera', () {
      expect(
        parseSceneHeading('GUIÓN TÉCNICO KEBAB KHALED - Manu Roma'),
        isNull,
      );
      expect(parseSceneHeading('Dirección: Manu Roma'), isNull);
    });
  });

  test('parseLensLine separa lente, ángulo y movimiento', () {
    final a = parseLensLine('35mm Normal SEGUIMIENTO DORSAL');
    expect(a.lens, '35mm');
    expect(a.angle, 'Normal');
    expect(a.movement, 'SEGUIMIENTO DORSAL');
    final b = parseLensLine('50mm Normal FIJO');
    expect(b.movement, 'FIJO');
    final c = parseLensLine('35MM Normal mano');
    expect(c.lens, '35mm');
    expect(c.movement, 'MANO');
    final d = parseLensLine('85mm');
    expect(d.angle, isNull);
    expect(d.movement, isNull);
  });

  test('splitCharacters', () {
    expect(splitCharacters('ALI, DIEGO'), ['ALI', 'DIEGO']);
    expect(splitCharacters(' ALI, ARIEL, HASSAN y SIMO'), [
      'ALI',
      'ARIEL',
      'HASSAN',
      'SIMO',
    ]);
    expect(splitCharacters(null), isEmpty);
  });

  test('lee escenas, planos e imágenes; la planta repetida es la misma', () {
    final bytes = buildTechnicalScriptDocx(
      media: {
        'rId1': [1, 2, 3],
        'rId2': [4, 5, 6],
        'rId3': [7, 8, 9],
      },
      scenes: [
        (
          '7. EXT. RAMBLA DEL RAVAL - NOCHE',
          [
            [
              '7',
              '1',
              'PA conjunto de ALI y SIMO',
              '35mm',
              '',
              'ALI, SIMO',
              '',
              ['rId1', 'rId2'],
              ['rId3'],
              '',
            ],
            [
              '7',
              '2',
              '2 PMC de ALI',
              '50mm Normal MANO',
              'T2.8',
              'ALI',
              'Ali mira.',
              <String>[],
              ['rId3'],
              'comenzar desenfocado\nplano íntimo',
            ],
          ],
        ),
        (
          '13A. INT. KEBAB KHALED - NOCHE',
          [
            [
              '13A',
              '1',
              'PD rulos',
              '',
              '',
              '',
              '',
              <String>[],
              <String>[],
              '',
            ],
          ],
        ),
      ],
    );

    final script = DocxTechnicalScriptReader.read(bytes);
    expect(script.title, 'GUION TÉCNICO PRUEBA');
    expect(script.scenes, hasLength(2));

    final seven = script.scenes.first;
    expect(seven.number, 7);
    expect(seven.intExt, 'EXT');
    expect(seven.location, 'RAMBLA DEL RAVAL');
    expect(seven.shots, hasLength(2));
    expect(seven.characters, ['ALI', 'SIMO']);

    final first = seven.shots.first;
    expect(first.framing, 'PA conjunto de ALI y SIMO');
    expect(first.lens, '35mm');
    expect(first.references, hasLength(2));
    expect(first.plans.single.hash, seven.shots[1].plans.single.hash);

    final second = seven.shots[1];
    expect(second.number, 2);
    expect(second.fStop, 'T2.8');
    expect(second.movement, 'MANO');
    expect(second.notes, 'comenzar desenfocado\nplano íntimo');
    expect(second.references, isEmpty);

    final thirteen = script.scenes[1];
    expect(thirteen.label, '13A');
    expect(thirteen.shots.single.framing, 'PD rulos');
  });

  test('un Word sin tablas de guion técnico da un error claro', () {
    final bytes = buildTechnicalScriptDocx(scenes: []);
    expect(
      () => DocxTechnicalScriptReader.read(bytes),
      throwsA(isA<FormatException>()),
    );
  });

  final kebab = File(
    '${Platform.environment['HOME']}/Downloads/'
    'GUION TECNICO KEBAB KHALED - Manu Roma (1).docx',
  );
  test(
    'guion real de Kebab Khaled',
    () {
      final script = DocxTechnicalScriptReader.read(kebab.readAsBytesSync());
      final labels = [for (final s in script.scenes) s.label];
      expect(labels, contains('13A'));
      expect(labels, contains('13B'));
      expect(script.scenes, hasLength(16));
      final scene7 = script.scenes.firstWhere((s) => s.label == '7');
      final planHashes = {
        for (final shot in scene7.shots)
          for (final plan in shot.plans) plan.hash,
      };
      expect(planHashes, hasLength(1));
      final s1p1 = script.scenes.first.shots.first;
      expect(s1p1.framing, 'PP ¾ de casco de ALI');
      expect(s1p1.lens, '25mm');
      expect(s1p1.movement, 'FIJO');
      expect(s1p1.notes, 'CAMERA CAR');
      expect(s1p1.references, hasLength(1));
    },
    skip: kebab.existsSync() ? false : 'No está el documento de ejemplo',
  );
}

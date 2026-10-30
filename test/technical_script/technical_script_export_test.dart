import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xml/xml.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/utils/shot_reference_import.dart';
import 'package:iris_dp/features/technical_script/technical_script_export.dart';
import 'package:iris_dp/features/technical_script/technical_script_settings.dart';
import 'package:iris_dp/shared/pdf_export/technical_script_pdf.dart';
import 'package:iris_dp/shared/technical_script_export/technical_script_doc.dart';
import 'package:iris_dp/shared/technical_script_export/technical_script_docx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int projectId;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('iris_export_test');
    projectId = await db.insertProject(
      ProjectsCompanion.insert(
        name: 'Kebab Khaled',
        director: const Value('Manu Roma'),
      ),
    );
    final image = img.Image(width: 320, height: 180);
    img.fill(image, color: img.ColorRgb8(30, 60, 110));
    final imagePath = '${tmp.path}/ref.png';
    File(imagePath).writeAsBytesSync(img.encodePng(image));

    Future<int> scene(int n, String place, String moment) => db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: n,
        name: place,
        locationCanonical: 'EXT. $place - $moment',
        locationPureName: place,
        sortOrder: Value(n),
      ),
    );
    final calle = await scene(1, 'CALLE RAVAL', 'NOCHE');
    await scene(2, 'KEBAB KHALED', 'NOCHE');
    await db.insertShot(
      ShotsCompanion.insert(
        sceneId: calle,
        projectId: projectId,
        number: 1,
        sortOrder: const Value(0),
        framing: const Value('PP ¾ de casco de **ALI**'),
        lens: const Value('50mm'),
        movement: const Value('CAMERA CAR'),
        fStop: const Value('T2.8'),
        action: const Value(
          'ALI (25) conduce *serio* su moto de reparto. El semáforo se '
          'pone en ==ámbar== y aminora. __Rojo__.',
        ),
        notes: const Value('CAMERA CAR'),
        cellStylesJson: const Value('{"notes":"green"}'),
        referenceImagePath: Value(imagePath),
      ),
    );
    await db.insertShot(
      ShotsCompanion.insert(
        sceneId: calle,
        projectId: projectId,
        number: 2,
        sortOrder: const Value(1),
        framing: const Value('PML de DIEGO ¾'),
        action: const Value('DIEGO cierra el cajón de la moto'),
        notesHighlight: const Value('yellow'),
        durationSeconds: const Value(12),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<TechnicalScriptDoc> build([
    TechnicalScriptSettings settings = const TechnicalScriptSettings(),
  ]) async => (await buildNarrativeScriptDoc(db, projectId, settings))!;

  test(
    'el documento sigue el orden narrativo y las columnas de la hoja',
    () async {
      final doc = await build();
      expect(doc.title, 'GUION TÉCNICO KEBAB KHALED');
      expect(doc.subtitle, 'Dirección: Manu Roma');
      expect(doc.sections.map((s) => s.title), [
        '1. EXT. CALLE RAVAL - NOCHE',
        '2. EXT. KEBAB KHALED - NOCHE',
      ]);
      // La duración está oculta por defecto.
      expect(doc.columns.map((c) => c.key), isNot(contains('dur')));
      expect(doc.columns.map((c) => c.label), containsAll(['ESC', 'APUNTES']));

      final first = doc.sections.first.rows.first;
      expect(first.cells['lens'], '50mm\nCAMERA CAR');
      expect(first.image, isNotNull);
      expect(first.fillOf('notes'), isNotNull);
      expect(first.fillOf('action'), isNull);
      // El segundo plano va teñido entero.
      final second = doc.sections.first.rows[1];
      expect(second.fillOf('action'), second.fill);
      expect(second.fill, isNotNull);

      final withDuration = await build(
        const TechnicalScriptSettings(hiddenColumns: {}),
      );
      expect(withDuration.columns.map((c) => c.key), contains('dur'));
      expect(withDuration.sections.first.rows[1].cells['dur'], '12 s');
    },
  );

  test('un plano con varios encuadres lleva todas sus imágenes al PDF y al '
      'Word', () async {
    final shot = (await db.getShotsForProject(projectId)).first;
    final second = img.Image(width: 320, height: 180);
    img.fill(second, color: img.ColorRgb8(120, 40, 40));
    final paths = [shot.referenceImagePath!, '${tmp.path}/ref2.png'];
    File(paths[1]).writeAsBytesSync(img.encodePng(second));
    for (final (i, path) in paths.indexed) {
      await db.insertShotReference(
        ShotReferencesCompanion.insert(
          shotId: shot.id,
          imagePath: path,
          sortOrder: Value(i),
        ),
      );
    }

    final doc = await build();
    expect(doc.sections.first.rows.first.images, hasLength(2));
    final pdf = await TechnicalScriptPdfExporter.buildBytes(doc);
    expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
    final out = Platform.environment['EXPORT_OUT'];
    if (out != null) File('$out/guion_encuadres.pdf').writeAsBytesSync(pdf);
    final archive = ZipDecoder().decodeBytes(
      TechnicalScriptDocxExporter.buildBytes(doc),
    );
    expect(
      archive.files.where((f) => f.name.startsWith('word/media/')),
      hasLength(2),
    );
  });

  test('la planta sale en el PDF y el Word: la dibujada y sus bocetos, y se '
      'va con su columna', () async {
    final shots = await db.getShotsForProject(projectId);
    const strokes =
        '{"strokes":[{"id":"a","tool":"pen","colorArgb":4294901760,'
        '"width":6,"points":[{"x":0.2,"y":0.2},{"x":0.6,"y":0.5},'
        '{"x":0.3,"y":0.7}]}]}';
    Future<void> draw(String type, int id) => db.saveProjectAnnotationDocument(
      projectId: projectId,
      targetType: type,
      targetId: '$id',
      documentJson: strokes,
      documentSchemaVersion: 1,
    );
    // Plano 1: planta dibujada a mano. Plano 2: una imagen y un boceto
    // dibujado en Plantas de cámara y luz.
    await draw('camera_plan_shot', shots[0].id);
    final setupId = await db.insertLightSetup(
      LightSetupsCompanion.insert(projectId: projectId, name: 'Boceto'),
    );
    await draw('camera_plan_light_setup', setupId);
    await db.updateShotFields(
      shots[1].id,
      ShotsCompanion(cameraPlanImagePath: Value(shots[0].referenceImagePath)),
    );
    await addShotPlanSketchSetup(db: db, shot: shots[1], setupId: setupId);

    final doc = await build();
    expect(doc.columns.map((c) => c.key), contains('planta'));
    final rows = doc.sections.first.rows;
    expect(rows[0].planImages, hasLength(1));
    expect(rows[1].planImages, hasLength(2));
    // Un PNG de verdad.
    expect(rows[0].planImages.single.sublist(1, 4), ascii.encode('PNG'));

    final pdf = await TechnicalScriptPdfExporter.buildBytes(doc);
    expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
    final out = Platform.environment['EXPORT_OUT'];
    if (out != null) File('$out/guion_planta.pdf').writeAsBytesSync(pdf);
    final docx = TechnicalScriptDocxExporter.buildBytes(doc);
    if (out != null) File('$out/guion_planta.docx').writeAsBytesSync(docx);
    final media = ZipDecoder()
        .decodeBytes(docx)
        .files
        .where((f) => f.name.startsWith('word/media/'));
    // La referencia del plano 1 y las tres de planta.
    expect(media, hasLength(4));

    // Solo la planta: los bocetos se quedan fuera; y al revés.
    final onlyPlan = await build(
      const TechnicalScriptSettings(planView: ScriptPlanView.plan),
    );
    expect(onlyPlan.sections.first.rows[0].planImages, hasLength(1));
    expect(onlyPlan.sections.first.rows[1].planImages, isEmpty);
    final onlySketch = await build(
      const TechnicalScriptSettings(planView: ScriptPlanView.sketch),
    );
    expect(onlySketch.sections.first.rows[0].planImages, isEmpty);
    expect(onlySketch.sections.first.rows[1].planImages, hasLength(2));
    // La excepción de un plano manda sobre la tabla.
    await db.updateShotFields(
      shots[1].id,
      const ShotsCompanion(cellStylesJson: Value('{"_planView":"both"}')),
    );
    final withException = await build(
      const TechnicalScriptSettings(planView: ScriptPlanView.plan),
    );
    expect(withException.sections.first.rows[1].planImages, hasLength(2));
    expect(withException.sections.first.rows[1].cellFills, isEmpty);

    final hidden = await build(
      const TechnicalScriptSettings(hiddenColumns: {ScriptColumn.planta}),
    );
    expect(hidden.columns.map((c) => c.key), isNot(contains('planta')));
    expect(hidden.sections.first.rows[0].planImages, isEmpty);
  });

  test('el PDF se genera', () async {
    final bytes = await TechnicalScriptPdfExporter.buildBytes(await build());
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(2000));
    final out = Platform.environment['EXPORT_OUT'];
    if (out != null) File('$out/guion.pdf').writeAsBytesSync(bytes);
  });

  test('el Word es un .docx válido, con una tabla por escena, el formato, '
      'los colores y la imagen', () async {
    final bytes = TechnicalScriptDocxExporter.buildBytes(await build());
    final out = Platform.environment['EXPORT_OUT'];
    if (out != null) File('$out/guion.docx').writeAsBytesSync(bytes);

    final zip = ZipDecoder().decodeBytes(bytes);
    final names = zip.files.map((f) => f.name).toSet();
    expect(
      names,
      containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'word/document.xml',
        'word/_rels/document.xml.rels',
        'word/media/referencia1.jpg',
      ]),
    );

    String part(String name) =>
        utf8.decode(zip.files.firstWhere((f) => f.name == name).content);
    // Cada parte es XML bien formado.
    for (final name in names.where((n) => !n.endsWith('.jpg'))) {
      XmlDocument.parse(part(name));
    }
    final document = XmlDocument.parse(part('word/document.xml'));
    expect(document.findAllElements('w:tbl').length, 2);
    expect(
      document.findAllElements('w:pgSz').single.getAttribute('w:orient'),
      'landscape',
    );
    final xml = part('word/document.xml');
    // Sin las marcas del formato, que van como propiedades del texto.
    expect(xml, isNot(contains('**')));
    expect(xml, isNot(contains('==')));
    expect(xml, contains('<w:b/>'));
    expect(xml, contains('<w:i/>'));
    expect(xml, contains('<w:u w:val="single"/>'));
    expect(xml, contains('ALI'));
    expect(xml, contains('ámbar'));
    expect(document.findAllElements('w:drawing').length, 1);
    expect(part('word/_rels/document.xml.rels'), contains('referencia1.jpg'));
  });

  test('el índice lleva cada escena con su página y enlace, en PDF y Word',
      () async {
    final doc = await build();
    expect(doc.sections.first.indexText, 'ESCENA 1. EXT CALLE RAVAL DÍA');

    // El índice ocupa la primera página: las escenas empiezan después.
    final pages = await TechnicalScriptPdfExporter.scenePages(doc);
    expect(pages.keys, [0, 1]);
    expect(pages[0], greaterThanOrEqualTo(2));
    expect(pages[1], greaterThanOrEqualTo(pages[0]!));
    final pdf = latin1.decode(await TechnicalScriptPdfExporter.buildBytes(doc));
    expect(pdf, contains('/Outlines'));
    expect(pdf, contains('esc_1'));
    // Sin índice no hay marcadores.
    final plain = latin1.decode(
      await TechnicalScriptPdfExporter.buildBytes(
        doc.copyWith(includeIndex: false),
      ),
    );
    expect(plain, isNot(contains('esc_0')));

    final fonts = await DocxFontFiles.load('Tinos');
    Archive docx() => ZipDecoder().decodeBytes(
          TechnicalScriptDocxExporter.buildBytes(
            doc.copyWith(fontFamily: 'Tinos'),
            pages: pages,
            fonts: fonts,
          ),
        );
    final zip = docx();
    String part(String name) =>
        utf8.decode(zip.files.firstWhere((f) => f.name == name).content);
    final xml = part('word/document.xml');
    XmlDocument.parse(xml);
    expect(xml, contains('ÍNDICE'));
    expect(xml, contains('<w:hyperlink w:anchor="esc_0"'));
    expect(xml, contains('w:name="esc_1"'));
    expect(xml, contains('PAGEREF esc_1 \\h'));
    expect(xml, contains('<w:t>${pages[0]}</w:t>'));
    expect(xml, isNot(contains('Calibri')));
    // La tipografía de la hoja va en los estilos e incrustada.
    final styles = part('word/styles.xml');
    XmlDocument.parse(styles);
    expect(styles, contains('w:ascii="Tinos"'));
    expect(part('word/fontTable.xml'), contains('w:embedItalic'));
    expect(
      zip.files.where((f) => f.name.endsWith('.odttf')),
      hasLength(4),
    );
    // Word no pregunta por actualizar campos al abrir.
    expect(part('word/settings.xml'), isNot(contains('w:updateFields')));
    // El mismo guion da siempre el mismo .docx.
    final again = docx();
    for (final f in zip.files) {
      expect(
        again.findFile(f.name)?.content,
        f.content,
        reason: f.name,
      );
    }
  });

  test('un asterisco en el título o la escena no pone nada en cursiva',
      () async {
    final doc = TechnicalScriptDoc(
      title: 'GUION *PRUEBA* __X__',
      columns: kScriptDocColumns,
      sections: [
        const ScriptDocSection(
          title: '1. INT. *CASA* - NOCHE',
          headerFill: 0xEEEEEE,
          rows: [],
        ),
      ],
    );
    final xml = utf8.decode(
      ZipDecoder()
          .decodeBytes(TechnicalScriptDocxExporter.buildBytes(doc))
          .files
          .firstWhere((f) => f.name == 'word/document.xml')
          .content,
    );
    expect(xml, contains('GUION *PRUEBA* __X__'));
    expect(xml, contains('*CASA*'));
    expect(xml, isNot(contains('<w:i/>')));
  });
}

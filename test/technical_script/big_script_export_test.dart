import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/technical_script/technical_script_export.dart';
import 'package:iris_dp/features/technical_script/technical_script_settings.dart';
import 'package:iris_dp/shared/pdf_export/technical_script_pdf.dart';
import 'package:iris_dp/shared/technical_script_export/technical_script_docx.dart';

/// Un guion de largometraje (80 escenas, 400 planos con imagen) se exporta
/// en un tiempo razonable, y un plano huérfano no lo rompe.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guion grande a PDF y Word', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tmp = Directory.systemTemp.createTempSync('iris_big');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final image = img.Image(width: 3000, height: 1688);
    img.fill(image, color: img.ColorRgb8(60, 80, 120));
    final path = '${tmp.path}/ref.jpg';
    File(path).writeAsBytesSync(img.encodeJpg(image));

    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Largo'),
    );
    for (var s = 1; s <= 80; s++) {
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: s,
          name: 'LUGAR $s',
          locationCanonical: 'INT. LUGAR $s - DÍA',
          locationPureName: 'LUGAR $s',
          sortOrder: Value(s),
        ),
      );
      for (var n = 1; n <= 5; n++) {
        await db.insertShot(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: n,
            sortOrder: Value(n),
            framing: const Value('PM de **ANA**'),
            action: const Value('ANA cruza el cuadro y se para en la ventana.'),
            referenceImagePath: Value(path),
          ),
        );
      }
    }
    // Un plano cuya escena ya no existe.
    await db.insertShot(
      ShotsCompanion.insert(sceneId: 99999, projectId: projectId, number: 1),
    );

    final watch = Stopwatch()..start();
    final doc = (await buildNarrativeScriptDoc(
      db,
      projectId,
      const TechnicalScriptSettings(),
    ))!;
    final built = watch.elapsedMilliseconds;
    expect(doc.sections, hasLength(80));
    final pdf = await TechnicalScriptPdfExporter.buildBytes(doc);
    final pdfMs = watch.elapsedMilliseconds - built;
    final docx = TechnicalScriptDocxExporter.buildBytes(doc);
    final docxMs = watch.elapsedMilliseconds - built - pdfMs;
    // ignore: avoid_print
    print('⏱ montar $built ms · PDF $pdfMs ms (${pdf.length ~/ 1024} KB) · '
        'Word $docxMs ms (${docx.length ~/ 1024} KB)');
    expect(watch.elapsed, lessThan(const Duration(minutes: 1)));
    // Cada plano lleva su imagen en los dos formatos.
    final media = ZipDecoder()
        .decodeBytes(docx)
        .files
        .where((f) => f.name.startsWith('word/media/'));
    expect(media, hasLength(400));
    expect(doc.sections.first.rows.first.images.single[0], 0xFF);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

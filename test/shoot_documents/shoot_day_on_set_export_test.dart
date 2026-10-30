import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_on_set.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_screen.dart';
import 'package:iris_dp/features/technical_script/technical_script_export.dart';
import 'package:iris_dp/features/technical_script/technical_script_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el PDF de la jornada dice qué planos están hechos o descartados',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Rodaje'),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'COCINA',
        locationCanonical: 'INT. COCINA - NOCHE',
        locationPureName: 'COCINA',
      ),
    );
    final dayId = await db.insertShootDocument(
      ShootDocumentsCompanion.insert(
        projectId: projectId,
        name: 'Jornada 1',
        kind: const Value(kShootDayKind),
      ),
    );
    final marks = [
      const OnSetMark(status: OnSetStatus.done),
      const OnSetMark(status: OnSetStatus.dropped),
      const OnSetMark(),
    ];
    for (final (i, mark) in marks.indexed) {
      final shotId = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: i + 1,
          sortOrder: Value(i),
        ),
      );
      await db.insertShootDocumentBlock(
        ShootDocumentBlocksCompanion.insert(
          documentId: dayId,
          sortOrder: Value(i),
          blockType: 'shot',
          sceneId: Value(sceneId),
          shotId: Value(shotId),
          contentOverridesJson: Value(mark.writeInto(null)),
        ),
      );
    }
    final doc = (await buildShootDayScriptDoc(
      db,
      dayId,
      const TechnicalScriptSettings(),
    ))!;
    final orden = [for (final r in doc.sections.single.rows) r.cells['orden']];
    expect(orden, ['1\n**HECHO**', '2\nDESCART.', '3']);
  });
}

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/visual_bible/v2/bible_v2_policy.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_document.dart';
import 'package:iris_dp/features/visual_bible/v2/persistence/bible_document_store.dart';
import 'package:iris_dp/features/visual_bible/v2/templates/bible_template_apply_service.dart';
import 'package:iris_dp/features/visual_bible/v2/templates/bible_v2_professional_templates.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('proyecto nuevo usa legacy con onboarding pendiente', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Nuevo'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);

    expect(bible.engineVersion, kBibleEngineLegacy);
    expect(bible.structureInitialized, isFalse);
    expect(await db.watchBibleSectionDefinitions(bible.id).first, isEmpty);
  });

  test('aplicar plantilla V2 clona documento con recetas', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Plantilla V2'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);
    final store = BibleDocumentStore(db);
    await store.save(
      BibleDocument.empty(projectId: projectId, bibleId: bible.id),
    );

    final apply = BibleTemplateApplyService(store);
    final applied = await apply.applyPackage(
      package: BibleV2ProfessionalTemplates.minimalist,
      bibleId: bible.id,
      projectId: projectId,
    );

    expect(applied.pages, isNotEmpty);
    expect(applied.pages.first.layoutRecipeId, isNotNull);
  });

  test('legacy existente conserva engineVersion legacy', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Legacy'),
    );
    final bibleId = await db.into(db.visualBibles).insert(
      VisualBiblesCompanion.insert(
        projectId: projectId,
        engineVersion: const Value('legacy'),
        structureInitialized: const Value(true),
      ),
    );
    final bible = await (db.select(db.visualBibles)
          ..where((v) => v.id.equals(bibleId)))
        .getSingle();
    expect(bible.engineVersion, kBibleEngineLegacy);
  });
}

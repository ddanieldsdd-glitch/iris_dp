import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('una Biblia nueva no siembra pantallas automáticamente (onboarding)', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Proyecto vacío'),
    );

    final bible = await db.ensureVisualBibleForProject(projectId);
    final groups = await db.watchBibleSectionGroups(bible.id).first;
    final sections = await db.watchBibleSectionDefinitions(bible.id).first;

    expect(bible.engineVersion, 'legacy');
    expect(bible.structureInitialized, isFalse);
    expect(groups, isEmpty);
    expect(sections, isEmpty);
  });

  test('confirmar Biblia vacía legacy no activa el seed', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Proyecto desde cero'),
    );
    final bibleId = await db.into(db.visualBibles).insert(
      VisualBiblesCompanion.insert(
        projectId: projectId,
        engineVersion: const Value('legacy'),
        structureInitialized: const Value(false),
      ),
    );

    await db.initializeEmptyBible(bibleId);
    final reopened = await db.getVisualBibleForProject(projectId);

    expect(reopened?.structureInitialized, isTrue);
    expect(await db.watchBibleSectionGroups(bibleId).first, isEmpty);
    expect(await db.watchBibleSectionDefinitions(bibleId).first, isEmpty);
  });

  test('la biblioteca puede añadir una sola pantalla', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Proyecto modular'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);

    await db.addBuiltinBibleSection(
      bibleId: bible.id,
      sectionId: BibleSectionId.lighting,
    );

    final groups = await db.watchBibleSectionGroups(bible.id).first;
    final sections = await db.watchBibleSectionDefinitions(bible.id).first;
    final reopened = await db.getVisualBibleForProject(projectId);

    expect(groups, hasLength(1));
    expect(sections, hasLength(1));
    expect(sections.single.id, BibleSectionId.lighting);
    expect(reopened?.structureInitialized, isTrue);
  });

  test('resetear estructura legacy vuelve al onboarding', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Proyecto reset'),
    );
    final bibleId = await db.into(db.visualBibles).insert(
      VisualBiblesCompanion.insert(
        projectId: projectId,
        engineVersion: const Value('legacy'),
        structureInitialized: const Value(true),
      ),
    );
    await db.ensureBibleSectionLayout(bibleId);

    await db.resetBibleStructureToEmpty(bibleId);

    final reopened = await db.getVisualBibleForProject(projectId);
    expect(reopened?.structureInitialized, isFalse);
    expect(await db.watchBibleSectionGroups(bibleId).first, isEmpty);
    expect(await db.watchBibleSectionDefinitions(bibleId).first, isEmpty);
  });

  test('el seed IRIS sigue disponible de forma explícita', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Proyecto plantilla'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);

    await db.ensureBibleSectionLayout(bible.id);

    final sections = await db.watchBibleSectionDefinitions(bible.id).first;
    expect(sections, isNotEmpty);
    expect(sections.map((s) => s.id), contains(BibleSectionId.direction));
    expect(
      (await db.getVisualBibleForProject(projectId))?.structureInitialized,
      isTrue,
    );
  });
}

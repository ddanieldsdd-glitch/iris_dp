import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/shoot_documents/import/shoot_plan_import_service.dart';
import 'package:iris_dp/features/shoot_documents/import/shoot_plan_text_parser.dart';
import 'package:iris_dp/features/shoot_documents/shoot_calendar.dart';
import 'package:iris_dp/features/shoot_documents/shoot_calendar_ics.dart';
import 'package:iris_dp/shared/pdf_export/shoot_day_order_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late int projectId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'K'));
    final scene = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 7,
        name: 'La Rouge',
        locationCanonical: 'EXT. LA ROUGE - NOCHE',
        locationPureName: 'LA ROUGE',
        intExt: const Value('EXT'),
        dayNight: const Value('NOCHE'),
      ),
    );
    for (var n = 1; n <= 2; n++) {
      await db.insertShot(
        ShotsCompanion.insert(sceneId: scene, projectId: projectId, number: n),
      );
    }
    final service = ShootPlanImportService(db);
    await service.apply(
      projectId,
      await service.preview(
        projectId,
        parseShootPlanText(
          'DÍA 1 - 15 NOVIEMBRE (17:00 - 03:00)\n'
          '17:00 Llegada del camión\n'
          '23:00 Escena 7\n'
          '      7.1 PA conjunto (45 min)\n'
          '23:45 7.2 PMC de Ali, mirando (20 min)\n'
          '00:05 CENA (1 hora)\n'
          '03:00 WRAP\n',
          today: DateTime(2026, 11, 10),
        ),
      ),
    );
  });

  tearDown(() => db.close());

  test('la hoja de la jornada lleva el horario entero', () async {
    final sheets = await ShootDayOrderPdf.load(db, projectId);
    final sheet = sheets.single;
    expect(sheet.position, 'día 1 de 1');
    expect(sheet.window, '17:00 – 03:00');
    expect(sheet.rows.map((r) => r.time), [
      '17:00 – 23:00',
      '23:00 – 00:05',
      '00:05 – 01:05',
      '03:00',
    ]);
    final scene = sheet.rows[1];
    expect(scene.title, 'Esc. 7 · EXT. LA ROUGE · NOCHE');
    final shot = scene.shots.last;
    expect(shot.number, 2);
    expect(
      [shot.framing, shot.time].join(' · '),
      allOf(contains('PMC de Ali'), contains('23:45 – 00:05')),
    );
    final bytes = await ShootDayOrderPdf.compose(
      projectName: 'K',
      sheets: sheets,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('el .ics: noche que pasa al día siguiente, texto escapado e ids '
      'estables', () async {
    Future<String> ics() async => buildShootCalendarIcs(
      projectName: 'K',
      now: DateTime.utc(2026, 11, 11, 9),
      entries: buildShootCalendar(
        documents: await db.getShootDocumentsForProject(projectId),
        blocks: await db.getShootDayBlocks(projectId),
        reservations: const [],
        houses: const {},
        sites: const {},
        scenes: {
          for (final s in await db.watchScenesForProject(projectId).first)
            s.id: s,
        },
        shots: {
          for (final s in await db.getShotsForProject(projectId)) s.id: s,
        },
      ),
    );
    final text = await ics();
    expect(text, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(text, contains('DTSTART:20261115T170000\r\nDTEND:20261116T030000'));
    // La cena de las 00:05 es del día 16.
    expect(text, contains('DTSTART:20261116T000500'));
    expect(text, contains('SUMMARY:Esc. 7'));
    expect(text.split('\r\n').every((l) => l.length <= 75), isTrue);
    // Volver a exportar da los mismos identificadores.
    final uids = RegExp(r'UID:(.*)').allMatches(text).map((m) => m[1]);
    final again = RegExp(r'UID:(.*)').allMatches(await ics()).map((m) => m[1]);
    expect(again, uids);
    expect(uids.toSet().length, uids.length);
  });
}

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/shoot_documents/import/shoot_plan_file_reader.dart';
import 'package:iris_dp/features/shoot_documents/import/shoot_plan_import_service.dart';
import 'package:iris_dp/features/shoot_documents/import/shoot_plan_text_parser.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_on_set.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_timeline.dart';
import 'package:iris_dp/features/shoot_documents/shoot_document_block_types.dart';
import 'package:iris_dp/features/shoot_documents/shoot_plan.dart';

ParsedShootPlan _kebab() => parseShootPlanText(
  File(
    'test/fixtures/shoot_plan/kebab_khaled_tentativo.txt',
  ).readAsStringSync(),
  today: DateTime(2026, 11, 10),
);

void main() {
  group('lector del plan escrito a mano', () {
    final plan = _kebab();

    test('saca los cuatro días con fecha y horario', () {
      expect(plan.title, 'PDR - KEBAB KHALED');
      expect(
        [for (final d in plan.days) '${d.number} ${d.date} ${d.from}-${d.to}'],
        [
          '1 2026-11-13 07:30-17:00',
          '2 2026-11-14 15:30-23:40',
          '3 2026-11-15 17:00-03:00',
          '4 2026-11-16 11:00-21:00',
        ],
      );
      expect(plan.days[2].note, 'Rambla del Raval');
    });

    test('planos con hora, duración y apunte; sin la duración en el texto', () {
      final shots = plan.days[0].lines.whereType<ParsedPlanShot>().toList();
      expect(
        [for (final s in shots) '${s.scene}.${s.shot} ${s.from}-${s.to}'],
        [
          '8.1 10:15-10:50',
          '6.1 11:15-11:55',
          '6.2 12:00-12:30',
          '13B.3 13:30-14:15',
          '13B.5 15:10-15:35',
          '13B.6 15:45-16:15',
        ],
      );
      expect(shots.first.text, startsWith('PMC de Ali a PE conjunto - Decir'));
      expect(shots.first.text, contains('escena 13b'));
      expect(shots[1].text, 'P segui de Ali');
    });

    test('franjas con su tipo, y «motor» solo marca la hora', () {
      final strips = plan.days[0].lines.whereType<ParsedPlanStrip>().toList();
      expect(
        [for (final s in strips) '${s.from}-${s.to} ${s.kind.name} ${s.label}'],
        containsAll([
          '07:30-08:30 call Llegada de camión',
          '10:00-10:15 meal Desayuno',
          '10:50-11:15 setup Preparación',
          '12:30-13:30 setup Preparación',
          '14:15-15:00 meal COMIDA',
          '16:15-17:00 wrap Recogida de material',
        ]),
      );
      final day2 = plan.days[1].lines;
      expect(
        day2.whereType<ParsedPlanStrip>().any(
          (s) => s.label.toLowerCase() == 'motor',
        ),
        isFalse,
      );
      final first = day2.whereType<ParsedPlanShot>().first;
      expect('${first.scene}.${first.shot} ${first.from}', '3.1 16:30');
      final call = day2.whereType<ParsedPlanStrip>().elementAt(1);
      expect(call.to, '16:30');
    });

    test('la madrugada sigue en su sitio y las escenas llevan su nota', () {
      final day3 = plan.days[2].lines;
      final last = day3.whereType<ParsedPlanShot>().last;
      expect(
        '${last.scene}.${last.shot} ${last.from}-${last.to}',
        '7.1 00:00-00:45',
      );
      final scene14 = day3.whereType<ParsedPlanScene>().last;
      expect(
        '${scene14.scene} ${scene14.from}-${scene14.to}',
        '14 01:25-02:55',
      );
      final scene6 = plan.days[0].lines.whereType<ParsedPlanScene>().elementAt(
        1,
      );
      expect(scene6.note, contains('HASSAN'));
      final split = plan.days[1].lines.whereType<ParsedPlanStrip>().firstWhere(
        (s) => s.label == 'División de equipo',
      );
      expect(split.note, contains('Equipo B'));
    });

    test('otras maneras de escribir la cabecera y la duración', () {
      final other = parseShootPlanText(
        'Jornada 2 · 03/02 (08.00 a 18.30)\n'
        '08:00 Citación\n'
        '09:00 Escena 4A\n'
        '4A.2 PG (1h 15 min)\n',
        today: DateTime(2026, 12, 20),
      );
      final day = other.days.single;
      expect('${day.date} ${day.from}-${day.to}', '2027-02-03 08:00-18:30');
      final shot = day.lines.whereType<ParsedPlanShot>().single;
      expect(
        '${shot.scene}.${shot.shot} ${shot.from}-${shot.to}',
        '4A.2 09:00-10:15',
      );
      expect(shootPlanDuration('30/40 min de recogida'), 40);
      expect(shootPlanDuration('1 hora'), 60);
    });
  });

  group('lectores de archivo', () {
    test('Excel: horas en columnas y fracción de día', () {
      final book = Excel.createExcel();
      final sheet = book['Sheet1'];
      sheet.appendRow([TextCellValue('DÍA 1 - 13 NOVIEMBRE (7:30 - 17:00)')]);
      sheet.appendRow([
        const TimeCellValue(hour: 7, minute: 30),
        const TimeCellValue(hour: 8, minute: 30),
        TextCellValue('Llegada de camión'),
      ]);
      sheet.appendRow([
        const DoubleCellValue(10.25 / 24),
        TextCellValue('8.1'),
        TextCellValue('PMC de Ali (35 min)'),
      ]);
      final bytes = Uint8List.fromList(book.encode()!);
      final text = readShootPlanFile(('plan.xlsx', bytes));
      final day = parseShootPlanText(
        text,
        today: DateTime(2026, 11, 10),
      ).days.single;
      final strip = day.lines.whereType<ParsedPlanStrip>().first;
      expect('${strip.from}-${strip.to}', '07:30-08:30');
      final shot = day.lines.whereType<ParsedPlanShot>().single;
      expect(
        '${shot.scene}.${shot.shot} ${shot.from}-${shot.to}',
        '8.1 10:15-10:50',
      );
    });

    test('Word: párrafos y filas de tabla en orden', () {
      String p(String t) => '<w:p><w:r><w:t>$t</w:t></w:r></w:p>';
      String cell(String t) => '<w:tc>${p(t)}</w:tc>';
      final xml =
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>'
          '${p('DÍA 1 - 13 NOVIEMBRE (7:30 - 17:00)')}'
          '<w:tbl><w:tr>${cell('7:30 - 8:30')}${cell('Llegada de camión')}</w:tr>'
          '<w:tr>${cell('10:15')}${cell('8.1 PMC de Ali (35 min)')}</w:tr></w:tbl>'
          '</w:body></w:document>';
      final data = utf8.encode(xml);
      final archive = Archive()
        ..addFile(ArchiveFile('word/document.xml', data.length, data));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final text = readShootPlanFile(('plan.docx', bytes));
      final day = parseShootPlanText(
        text,
        today: DateTime(2026, 11, 10),
      ).days.single;
      expect(day.lines.whereType<ParsedPlanStrip>().first.to, '08:30');
      expect(day.lines.whereType<ParsedPlanShot>().single.to, '10:50');
    });

    test('formatos antiguos avisan', () {
      expect(
        () => readShootPlanFile(('plan.doc', Uint8List(0))),
        throwsFormatException,
      );
    });
  });

  group('importar al proyecto', () {
    late AppDatabase db;
    late int projectId;
    final shotIds = <String, int>{};

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'K'));
      shotIds.clear();
      // Las escenas del guion real, con sus planos; la 14 sin planos aquí.
      const counts = {
        '1': 4,
        '2': 1,
        '3': 3,
        '4': 2,
        '5': 3,
        '6': 2,
        '7': 5,
        '8': 1,
        '9': 1,
        '10': 5,
        '11': 5,
        '12': 5,
        '13A': 8,
        '13B': 10,
        '14': 0,
        '15': 2,
      };
      var order = 0;
      for (final e in counts.entries) {
        final m = RegExp(r'^(\d+)([A-Z])?$').firstMatch(e.key)!;
        final sceneId = await db.insertScene(
          ScenesCompanion.insert(
            projectId: projectId,
            number: int.parse(m.group(1)!),
            numberSuffix: Value(m.group(2)),
            name: 'E${e.key}',
            locationCanonical: 'INT. E - NOCHE',
            locationPureName: 'E',
            sortOrder: Value(order++),
          ),
        );
        for (var n = 1; n <= e.value; n++) {
          shotIds['${e.key}.$n'] = await db.insertShot(
            ShotsCompanion.insert(
              sceneId: sceneId,
              projectId: projectId,
              number: n,
              sortOrder: Value(n),
            ),
          );
        }
      }
    });

    tearDown(() => db.close());

    Future<List<ShootDocument>> days() async =>
        sortShootDays(await db.getShootDocumentsForProject(projectId));

    test('crea las jornadas con su orden, horas y apuntes', () async {
      final service = ShootPlanImportService(db);
      final preview = await service.preview(projectId, _kebab());
      expect(preview.days.every((d) => d.existing == null), isTrue);
      // 9.2 no está en este guion; 11.1 sí.
      expect(preview.missingShots, ['9.2']);
      expect(preview.missingScenes, isEmpty);
      await service.apply(projectId, preview);

      final all = await days();
      expect(all.map((d) => d.shootDate), [
        '2026-11-13',
        '2026-11-14',
        '2026-11-15',
        '2026-11-16',
      ]);
      expect(all.first.shootFromTime, '07:30');
      expect(all.first.description, contains('escena 13B'));

      final blocks = await db.getBlocksForShootDocument(all.first.id);
      final shots = {
        for (final s in await db.getShotsForProject(projectId)) s.id: s,
      };
      final entries = buildShootDayEntries(blocks, shots);
      expect(
        entries.map((e) => e is ShootSceneEntry ? 'E' : 'F').join(),
        'FFFEFEFEFEFFEFEFF',
      );
      final scene8 = entries.whereType<ShootSceneEntry>().first;
      final schedule = SceneSchedule.of(scene8.blocks.first);
      expect('${schedule.from}-${schedule.to}', '10:15-10:50');
      expect(schedule.note, 'ALI - SIMO');
      final time = ShotTime.of(scene8.blocks.first);
      expect(time.from, '10:15');
      expect(time.note, contains('cargador'));
      // La escena 6 queda partida por la preparación: dos tramos.
      final scene6 = entries.whereType<ShootSceneEntry>().elementAt(1);
      expect(SceneSchedule.of(scene6.blocks.first).to, '11:55');

      // La 14 no tiene planos: entra como escena, con su hora.
      final day3 = await db.getBlocksForShootDocument(all[2].id);
      final header = day3.lastWhere(
        (b) => b.blockType == ShootBlockType.sceneHeader,
      );
      expect(SceneSchedule.of(header).from, '01:25');
      // El plano que falta queda apuntado en su escena.
      expect(
        day3.any((b) => SceneSchedule.of(b).note.contains('Plano 9.2')),
        isTrue,
      );
    });

    test(
      'sobre jornadas que ya existen: mismas jornadas, marcas a salvo',
      () async {
        final service = ShootPlanImportService(db);
        await service.apply(
          projectId,
          await service.preview(projectId, _kebab()),
        );
        final before = await days();
        final first = await db.getBlocksForShootDocument(before.first.id);
        final done = first.firstWhere((b) => b.shotId == shotIds['6.1']);
        await db.updateShootDocumentBlock(
          done.copyWith(
            contentOverridesJson: Value(
              const OnSetMark(
                status: OnSetStatus.done,
              ).writeInto(done.contentOverridesJson),
            ),
          ),
        );

        final preview = await service.preview(projectId, _kebab());
        expect(
          preview.days.map((d) => d.existing?.id),
          before.map((d) => d.id),
        );
        await service.apply(projectId, preview);

        final after = await days();
        expect(after.map((d) => d.id), before.map((d) => d.id));
        final blocks = await db.getBlocksForShootDocument(after.first.id);
        expect(blocks.length, first.length);
        final again = blocks.firstWhere((b) => b.shotId == shotIds['6.1']);
        expect(OnSetMark.of(again).status, OnSetStatus.done);
        expect(ShotTime.of(again).from, '11:15');
      },
    );
    test(
      'deshacer quita las jornadas nuevas y devuelve las de antes',
      () async {
        final service = ShootPlanImportService(db);
        final existing = await db.insertShootDocument(
          ShootDocumentsCompanion.insert(
            projectId: projectId,
            name: 'Jornada 1',
            kind: const Value(kShootDayKind),
            shootDate: const Value('2026-11-13'),
            shootFromTime: const Value('08:00'),
          ),
        );
        final before = await service.snapshot(projectId);
        await service.apply(
          projectId,
          await service.preview(projectId, _kebab()),
        );
        expect((await days()).length, 4);
        await service.undo(projectId, before);
        final after = await days();
        expect(after.map((d) => d.id), [existing]);
        expect(after.single.shootFromTime, '08:00');
        expect(await db.getBlocksForShootDocument(existing), isEmpty);
      },
    );
  });
}

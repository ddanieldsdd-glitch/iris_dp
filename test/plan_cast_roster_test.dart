import 'dart:convert';
import 'dart:ui' show Color;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/utils/character_colors.dart';
import 'package:iris_dp/core/utils/project_cast_settings.dart';
import 'package:iris_dp/core/utils/scene_color.dart';
import 'package:iris_dp/features/camera_plan/plan_cast.dart';

void main() {
  late AppDatabase db;
  late int projectId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
  });
  tearDown(() => db.close());

  Future<int> scene(int number, List<String> characters) => db
      .into(db.scenes)
      .insert(
        ScenesCompanion.insert(
          projectId: projectId,
          number: number,
          name: 'E$number',
          locationCanonical: 'INT. BAR - DÍA',
          locationPureName: 'BAR',
          charactersJson: Value(jsonEncode(characters)),
        ),
      );

  test('el guion propone sujetos, con su color y por escenas', () async {
    await scene(1, ['ALI', 'DIEGO']);
    await scene(2, ['ALI']);
    final project = (await db.getProject(projectId))!;
    await db.updateProject(
      project.copyWith(
        characterColorsJson: Value(jsonEncode({'DIEGO': '#E63946'})),
      ),
    );

    final roster = await PlanCast.roster(db, projectId);

    expect(roster.members.map((m) => m.name), ['ALI', 'DIEGO']);
    expect(roster.byKey('ALI')!.scriptScenes, 2);
    expect(hexFromColor(roster.byKey('DIEGO')!.color), '#E63946');
    expect(roster.byKey('ALI')!.inPlans, isFalse);
  });

  test('lo quitado no vuelve y lo oculto sale de la paleta', () async {
    await scene(1, ['ALI', 'DIEGO', 'NURIA']);
    await PlanCast.saveSettings(
      db,
      projectId,
      const ProjectCastSettings().withHidden('DIEGO', true).withRemoved('NURIA'),
    );

    final roster = await PlanCast.roster(db, projectId);

    expect(roster.visible.map((m) => m.key), ['ALI']);
    expect(roster.byKey('DIEGO')!.hidden, isTrue);
    expect(roster.byKey('NURIA'), isNull);
    expect(roster.removedNames, {'NURIA': 'NURIA'});
  });

  test('quitar a alguien lo saca de sus grupos', () {
    const group = CastGroup(id: 'g', name: 'Bar', members: ['ALI', 'DIEGO']);
    final out = const ProjectCastSettings(
      groups: [group],
    ).withRemoved('ALI');
    expect(out.groups.single.members, ['DIEGO']);
  });

  test('el guion literario conserva grupos al guardar sus colores', () {
    final raw = encodeCastSettings(
      jsonEncode({'ALI': '#E63946'}),
      const ProjectCastSettings(
        groups: [CastGroup(id: 'g', name: 'Bar', members: ['ALI'])],
      ),
    );

    final saved = encodeCharacterColors(
      {'ALI': '#2A9D8F'},
      manualCharacterLines: const {},
      keepCastFrom: raw,
    );

    expect(decodeCastSettings(saved).groups.single.name, 'Bar');
    expect(decodeCharacterColors(saved), {'ALI': '#2A9D8F'});
  });

  test('cambiar el color de un propuesto llega al guion', () async {
    await scene(1, ['ALI']);
    await PlanCast.recolour(db, projectId, 'ALI', const Color(0xFF2A9D8F));

    final project = (await db.getProject(projectId))!;
    expect(decodeCharacterColors(project.characterColorsJson)['ALI'], isNotNull);
    final roster = await PlanCast.roster(db, projectId);
    expect(hexFromColor(roster.byKey('ALI')!.color), '#2A9D8F');
  });
}

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/auto_sync_scheduler.dart';
import 'package:iris_dp/features/projects/project_my_role.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> project(String name, {String? cloudId}) => db.insertProject(
    ProjectsCompanion.insert(name: name, cloudId: Value(cloudId)),
  );

  test('sin papel, la página de dirección de fotografía', () {
    expect(MyProjectRole.of(null), MyProjectRole.dp);
    expect(MyProjectRole.of('gaffer'), MyProjectRole.gaffer);
    expect(MyProjectRole.of('first_ac'), MyProjectRole.firstAc);
    expect(MyProjectRole.of('viewer'), MyProjectRole.dp);
  });

  test('cada proyecto cae en la página de su papel', () async {
    final a = await project('Corto');
    final b = await project('Largo');
    final c = await project('Anuncio');
    await db.setProjectMyRole(b, 'gaffer');
    await db.setProjectMyRole(c, 'first_ac');
    final all = await db.select(db.projects).get();
    String names(MyProjectRole r) => r.filter(all).map((p) => p.name).join();
    expect(names(MyProjectRole.dp), 'Corto');
    expect(names(MyProjectRole.gaffer), 'Largo');
    expect(names(MyProjectRole.firstAc), 'Anuncio');
    expect(a, isPositive);
  });

  test(
    'cambiar el papel no toca la fecha de edición (no pide subida)',
    () async {
      final id = await project('Largo');
      final before = (await db.getProject(id))!.updatedAt;
      await db.setProjectMyRole(id, 'gaffer');
      final after = (await db.getProject(id))!;
      expect(after.myRole, 'gaffer');
      expect(after.updatedAt, before);
    },
  );

  test('duplicar conserva el papel', () async {
    final id = await project('Largo');
    await db.setProjectMyRole(id, 'gaffer');
    final copy = await db.duplicateProject(id);
    expect((await db.getProject(copy))!.myRole, 'gaffer');
  });

  test('un proyecto invitado toma el papel de la invitación', () async {
    final invited = await project('Invitado', cloudId: 'nube-1');
    final chosen = await project('Elegido', cloudId: 'nube-2');
    final director = await project('Dirección', cloudId: 'nube-3');
    await db.setProjectMyRole(chosen, 'first_ac');
    await fillMyRolesFromMembers(db, {
      'nube-1': 'gaffer',
      'nube-2': 'gaffer',
      'nube-3': 'director',
    });
    expect((await db.getProject(invited))!.myRole, 'gaffer');
    // Lo elegido en este aparato manda.
    expect((await db.getProject(chosen))!.myRole, 'first_ac');
    // Un papel sin página no se apunta: va a la de siempre.
    expect((await db.getProject(director))!.myRole, isNull);
  });
}

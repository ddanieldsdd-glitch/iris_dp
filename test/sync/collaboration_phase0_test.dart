import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/auto_sync_scheduler.dart';
import 'package:iris_dp/core/sync/live_editing.dart';
import 'package:iris_dp/core/sync/live_key_projects.dart';
import 'package:iris_dp/core/sync/realtime_hub.dart';
import 'package:iris_dp/core/sync/server_clock.dart';

/// Fase 0 de colaboración: hora del servidor en los bloqueos, persona y
/// papel en la presencia, canal por proyecto y planta tomada al editar.
void main() {
  tearDown(ServerClock.reset);

  LiveEditing live({Duration idle = const Duration(minutes: 2)}) => LiveEditing(
    installId: 'mac',
    publishEditing: (_, _) {},
    publishTyping: (_, _, _) {},
    idleRelease: idle,
  );

  test('el bloqueo lleva la hora del servidor, no la del equipo', () {
    // Este equipo va 3 minutos atrasado.
    ServerClock.setKnown(const Duration(minutes: 3));
    final l = live()..focusShot('a');
    final drift = l.mySince!.difference(DateTime.now().toUtc());
    expect(drift.inSeconds, inInclusiveRange(179, 181));
    l.dispose();
  });

  test(
    'tocar toma la planta y se suelta sola tras el rato sin tocar',
    () async {
      final l = live(idle: const Duration(milliseconds: 60));
      expect(l.myShotUid, isNull);
      l.touch('set:x');
      expect(l.myShotUid, 'set:x');
      final since = l.mySince;
      // Seguir tocando alarga el plazo sin cambiar desde cuándo se tiene.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      l.touch('set:x');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(l.myShotUid, 'set:x');
      expect(l.mySince, since);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(l.myShotUid, isNull);
      l.dispose();
    },
  );

  test('la presencia dice persona y papel; sin ellos, el equipo', () {
    final named = PeerEditing.fromPayload({
      'installId': 'ipad',
      'device': 'iPad',
      'shotUid': 'a',
      'since': '2026-11-22T12:00:00Z',
      'person': 'Ana',
      'role': 'gaffer',
    })!;
    expect(named.label, 'Ana (gaffer) · iPad');
    // Una versión anterior solo manda el equipo.
    final old = PeerEditing.fromPayload({
      'installId': 'ipad',
      'device': 'iPad',
      'shotUid': 'a',
      'since': '2026-11-22T12:00:00Z',
    })!;
    expect(old.label, 'iPad');
    expect(memberRoleLabel(null), 'propietario');
    expect(memberRoleLabel('director'), 'dirección');
  });

  test('lo que se edita solo lo sabe el canal de su proyecto y el propio', () {
    Map<String, dynamic>? on(String? project) => RealtimeHub.presenceFor(
      installId: 'mac',
      device: 'Mac',
      project: project,
      role: project == null ? null : 'propietario',
      person: 'Daniel',
      editing: {'shotUid': 'a', 'since': '2026-11-22T12:00:00Z'},
      editingProject: 'p1',
      scanBuilder: {'port': 1},
    );
    expect(on(null)!['shotUid'], 'a');
    expect(on(null)!['scanBuilder'], isNotNull);
    expect(on('p1')!['shotUid'], 'a');
    expect(on('p1')!['role'], 'propietario');
    expect(on('p1')!['scanBuilder'], isNull);
    // En otro proyecto se ve que está, no qué edita.
    final other = on('p2')!;
    expect(other['shotUid'], isNull);
    expect(other['person'], 'Daniel');
    // Sin nada que decir, el canal propio no lleva presencia.
    expect(
      RealtimeHub.presenceFor(installId: 'mac', device: 'Mac', project: null),
      isNull,
    );
  });

  test('cada clave en vivo va al proyecto al que pertenece', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Corto de prueba'),
    );
    await (db.update(db.projects)..where((p) => p.id.equals(projectId))).write(
      const ProjectsCompanion(cloudId: Value('nube-1')),
    );
    final scene = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
    final shotId = await db.insertShot(
      ShotsCompanion.insert(sceneId: scene, projectId: projectId, number: 1),
    );
    final shotUid = (await db.getShotById(shotId))!.uid!;
    final sceneUid = (await (db.select(
      db.scenes,
    )..where((s) => s.id.equals(scene))).getSingle()).uid!;

    final keys = LiveKeyProjects(db);
    expect(await keys.cloudIdOf(LiveKey.shot(shotUid)), 'nube-1');
    expect(await keys.cloudIdOf(LiveKey.scene(sceneUid)), 'nube-1');
    expect(
      await keys.cloudIdOf(LiveKey.drawing('storyboard:$shotUid')),
      'nube-1',
    );
    expect(await keys.cloudIdOf('set:no-existe'), isNull);
  });
}

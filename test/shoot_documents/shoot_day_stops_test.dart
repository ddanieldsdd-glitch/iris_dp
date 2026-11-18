import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_stops.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_timeline.dart';

/// Las paradas de la jornada salen del orden de rodaje: escenas seguidas en
/// el mismo sitio y set juntas, con sus tiempos sumados y el traslado.
void main() {
  var nextId = 1;
  setUp(() => nextId = 1);

  ShootDocumentBlock scene(int sceneId, int minutes, {int? stop}) {
    var json = SceneSchedule(minutes: minutes).writeInto(null);
    if (stop != null) json = ShootStopMinutes.writeInto(json, stop);
    return ShootDocumentBlock(
      id: nextId,
      documentId: 1,
      sortOrder: nextId++,
      blockType: 'scene_header',
      sceneId: sceneId,
      contentOverridesJson: json,
    );
  }

  ShootDocumentBlock strip(ShootStrip s) => ShootDocumentBlock(
    id: nextId,
    documentId: 1,
    sortOrder: nextId++,
    blockType: 'schedule',
    contentOverridesJson: s.writeInto(null),
  );

  // Escena → (localización, set).
  const places = <int, ShootPlace>{
    1: (siteId: 10, setId: 100),
    2: (siteId: 10, setId: 100),
    3: (siteId: 10, setId: 101),
    4: (siteId: 20, setId: 200),
    5: (siteId: null, setId: null),
  };

  List<ShootDayStop> stops(List<ShootDocumentBlock> blocks) {
    final entries = buildShootDayEntries(blocks, const {});
    return deriveShootDayStops(
      entries,
      scheduleShootDay(entries, const {}, dayStart: '08:00'),
      placeOf: (e) => places[e.sceneId]!,
      siteOfUid: (uid) => {'casa': 30, 'kebab': 10}[uid],
    );
  }

  test('escenas seguidas en el mismo set van juntas y suman', () {
    final s = stops([
      scene(1, 60),
      strip(const ShootStrip(kind: ShootStripKind.meal, minutes: 45)),
      scene(2, 30),
      scene(3, 20),
    ]);
    expect(s, hasLength(2));
    expect(s[0].sceneIds, [1, 2]);
    // La comida no es tiempo de rodaje de la parada.
    expect(s[0].computedMinutes, 90);
    expect(s[0].start, 8 * 60);
    expect(s[1].setId, 101);
    expect(s[1].siteId, 10);
    expect(s[1].minutes, 20);
  });

  test('el cambio de localización es el traslado de la parada siguiente', () {
    final s = stops([
      scene(1, 60),
      strip(const ShootStrip(kind: ShootStripKind.move, minutes: 40)),
      scene(4, 90),
    ]);
    expect(s.map((x) => x.siteId), [10, 20]);
    expect(s[1].travelMinutes, 40);
    expect(s[1].start, 8 * 60 + 100);
  });

  test('un tiempo fijado manda sobre lo calculado', () {
    final s = stops([scene(1, 60, stop: 150), scene(2, 30)]);
    expect(s.single.computedMinutes, 90);
    expect(s.single.fixedMinutes, 150);
    expect(s.single.minutes, 150);
  });

  test('una parada a mano con su sitio abre parada y acoge lo que sigue', () {
    final s = stops([
      scene(1, 60),
      strip(
        const ShootStrip(
          kind: ShootStripKind.move,
          siteUid: 'casa',
          minutes: 30,
        ),
      ),
      scene(5, 45),
      scene(4, 20),
    ]);
    expect(s.map((x) => x.siteId), [10, 30, 20]);
    expect(s[1].manual, isTrue);
    expect(s[1].travelMinutes, 30);
    // La escena sin sitio se rueda en la parada a mano.
    expect(s[1].sceneIds, [5]);
    expect(s[1].minutes, 45);
  });

  test('una parada a mano en el mismo sitio que la escena siguiente', () {
    final s = stops([
      strip(
        const ShootStrip(
          kind: ShootStripKind.move,
          siteUid: 'kebab',
          minutes: 20,
        ),
      ),
      scene(3, 60),
    ]);
    expect(s.single.siteId, 10);
    expect(s.single.setId, 101);
    expect(s.single.sceneIds, [3]);
  });

  test('una jornada sin escenas no tiene paradas', () {
    expect(
      stops([strip(const ShootStrip(kind: ShootStripKind.meal, minutes: 30))]),
      isEmpty,
    );
  });

  test('el tiempo fijado se guarda y se quita sin tocar lo demás', () {
    final json = const SceneSchedule(minutes: 30).writeInto(null);
    final fixed = ShootStopMinutes.writeInto(json, 90);
    final block = ShootDocumentBlock(
      id: 1,
      documentId: 1,
      sortOrder: 0,
      blockType: 'scene_header',
      contentOverridesJson: fixed,
    );
    expect(ShootStopMinutes.of(block), 90);
    expect(SceneSchedule.of(block).minutes, 30);
    final cleared = ShootStopMinutes.writeInto(fixed, null);
    expect(cleared.contains('stopMinutes'), isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/sync/live_editing.dart';

PeerEditing _peer(String id, String shot, int second, {String device = 'iPad'}) =>
    PeerEditing(
      installId: id,
      device: device,
      shotUid: shot,
      since: DateTime.utc(2026, 10, 18, 12, 0, second),
    );

void main() {
  group('quién tiene el plano', () {
    test('otro equipo lo edita: bloqueado aquí', () {
      final holder = lockHolder(
        'a',
        myInstallId: 'mac',
        peers: [_peer('ipad', 'a', 0)],
      );
      expect(holder?.device, 'iPad');
    });

    test('si los dos lo toman, lo tiene quien lo tomó antes', () {
      final peers = [_peer('ipad', 'a', 5)];
      expect(
        lockHolder(
          'a',
          myInstallId: 'mac',
          myShotUid: 'a',
          mySince: DateTime.utc(2026, 10, 18, 12, 0, 1),
          peers: peers,
        ),
        isNull,
      );
      expect(
        lockHolder(
          'a',
          myInstallId: 'mac',
          myShotUid: 'a',
          mySince: DateTime.utc(2026, 10, 18, 12, 0, 9),
          peers: peers,
        )?.installId,
        'ipad',
      );
    });

    test('a la misma hora decide el id, igual en los dos equipos', () {
      final at = DateTime.utc(2026, 10, 18, 12);
      PeerEditing? holderSeenBy(String me, String other) => lockHolder(
        'a',
        myInstallId: me,
        myShotUid: 'a',
        mySince: at,
        peers: [PeerEditing(installId: other, device: other, shotUid: 'a', since: at)],
      );
      expect(holderSeenBy('aaa', 'bbb'), isNull);
      expect(holderSeenBy('bbb', 'aaa')?.installId, 'aaa');
    });

    test('otro plano no se bloquea', () {
      expect(
        lockHolder('b', myInstallId: 'mac', peers: [_peer('ipad', 'a', 0)]),
        isNull,
      );
    });
  });

  testWidgets('lo escrito se envía como mucho cada 300 ms, y siempre lo último',
      (tester) async {
    final sent = <String>[];
    final t = TypingThrottle(send: sent.add);
    for (var i = 1; i <= 20; i++) {
      t.add('x' * i);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 1));
    // 1 s de escritura: no más de 4 envíos, y el último es el texto final.
    expect(sent.length, lessThanOrEqualTo(5));
    expect(sent.last, 'x' * 20);
  });

  group('estado en vivo', () {
    late List<(String?, DateTime?)> published;
    late List<(String, String, String?)> typed;
    late LiveEditing live;

    setUp(() {
      published = [];
      typed = [];
      live = LiveEditing(
        installId: 'mac',
        publishEditing: (shot, since) => published.add((shot, since)),
        publishTyping: (shot, column, text) => typed.add((shot, column, text)),
      );
    });

    testWidgets('pasar de una celda a otra del mismo plano no lo suelta',
        (tester) async {
      live.focusShot('a');
      live.blurShot('a');
      await tester.pump(const Duration(milliseconds: 100));
      live.focusShot('a');
      await tester.pump(const Duration(seconds: 1));
      expect(published.map((p) => p.$1), ['a']);
      expect(live.myShotUid, 'a');

      // Perder el foco un momento (teclado, menú) no lo suelta…
      live.blurShot('a');
      await tester.pump(const Duration(seconds: 5));
      expect(live.myShotUid, 'a');
      // …pero un rato sin volver, sí.
      await tester.pump(const Duration(seconds: 20));
      expect(published.map((p) => p.$1), ['a', null]);
    });

    testWidgets('pasar a otro plano o salir de la pantalla lo suelta ya',
        (tester) async {
      live.focusShot('a');
      live.blurShot('a');
      live.focusShot('b');
      expect(published.map((p) => p.$1), ['a', 'b']);
      live.leave('b');
      expect(published.map((p) => p.$1), ['a', 'b', null]);
      live.focusShot('c');
      live.releaseAll();
      expect(live.myShotUid, isNull);
      await tester.pump(const Duration(seconds: 30));
      expect(published.map((p) => p.$1), ['a', 'b', null, 'c', null]);
    });

    test('lo que otro empezó antes bloquea aunque aquí se anuncie otra cosa',
        () {
      live.focusShot('shot-1');
      final mine = live.mySince!;
      live.setPeers([
        PeerEditing(
          installId: 'ipad',
          device: 'iPad',
          shotUid: LiveKey.lightSetup('s1'),
          since: mine.subtract(const Duration(seconds: 5)),
        ),
      ]);
      expect(live.holderBefore(LiveKey.lightSetup('s1'), mine)?.device, 'iPad');
      // Si lo tomó después que este equipo, no bloquea aquí.
      live.setPeers([
        PeerEditing(
          installId: 'ipad',
          device: 'iPad',
          shotUid: LiveKey.lightSetup('s1'),
          since: mine.add(const Duration(seconds: 5)),
        ),
      ]);
      expect(live.holderBefore(LiveKey.lightSetup('s1'), mine), isNull);
    });

    test('solo se envía lo que se escribe en el plano que se tiene', () {
      live.typing('a', 'notes', 'hola');
      expect(typed, isEmpty);
      live.focusShot('a');
      live.typing('a', 'notes', 'hola');
      live.typingEnd('a', 'notes');
      expect(typed, [('a', 'notes', 'hola'), ('a', 'notes', null)]);
    });

    test('lo que escribe el otro se ve hasta que termina o deja el plano', () {
      live.setPeers([_peer('ipad', 'a', 0)]);
      live.receiveTyping('a', 'action', 'Ali mira');
      expect(live.holderOf('a')?.device, 'iPad');
      expect(live.typingIn('a', 'action'), 'Ali mira');

      live.receiveTyping('a', 'action', null);
      expect(live.typingIn('a', 'action'), isNull);

      live.receiveTyping('a', 'action', 'otra vez');
      live.setPeers(const []);
      expect(live.typingIn('a', 'action'), isNull);
      expect(live.holderOf('a'), isNull);
    });
  });
}

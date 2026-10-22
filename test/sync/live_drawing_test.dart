import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/sync/live_drawing.dart';
import 'package:iris_dp/core/sync/live_editing.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/live_drawing_link.dart';

AnnotationStroke stroke(String id, int points) => AnnotationStroke(
  id: id,
  tool: AnnotationToolType.pen,
  colorArgb: 0xFF000000,
  width: 3,
  inputKind: AnnotationInputKind.stylus,
  points: [
    for (var i = 0; i < points; i++)
      AnnotationPoint(x: i / 100, y: i / 200, pressure: 0.5),
  ],
);

/// Un equipo: su estado de edición compartida y su folio.
class Device {
  final String id;
  final String name;
  late final LiveEditing live;
  final inbox = StreamController<Map<String, dynamic>>.broadcast();
  final sent = <Map<String, dynamic>>[];
  late Device other;

  Device(this.id, this.name) {
    live = LiveEditing(
      installId: id,
      publishEditing: (key, since) => other.live.setPeers([
        if (key != null)
          PeerEditing(installId: id, device: name, shotUid: key, since: since!),
      ]),
      publishTyping: (_, _, _) {},
    );
  }

  LiveDrawingSession open(String key) => LiveDrawingSession(
    key: key,
    live: live,
    incoming: inbox.stream,
    docInterval: const Duration(milliseconds: 5),
    strokeInterval: const Duration(milliseconds: 5),
    send: (message) {
      sent.add(message);
      // Por el canal real: comprimido y por partes.
      final assembler = DrawingWireAssembler();
      for (final part in DrawingWire.pack(message, size: 200)) {
        final whole = assembler.add(part);
        if (whole != null) other.inbox.add(whole);
      }
    },
  );
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  test('solo viajan enteros los trazos nuevos; el otro rehace el dibujo', () {
    final encoder = DrawingDeltaEncoder();
    final decoder = DrawingDeltaDecoder();
    final a = stroke('a', 40);
    final b = stroke('b', 40);
    final first = encoder.encode(AnnotationDocument(strokes: [a]));
    expect(decoder.apply(first)!.strokes.single.points, hasLength(40));

    final second = encoder.encode(AnnotationDocument(strokes: [a, b]));
    final sentStrokes = (second['doc'] as Map)['strokes'] as List;
    expect(sentStrokes.first, {'ref': 'a'});
    final doc = decoder.apply(second)!;
    expect(doc.strokes.map((s) => s.id), ['a', 'b']);

    // Uno que llega a mitad no tiene «a»: pide el dibujo entero.
    expect(DrawingDeltaDecoder().apply(second), isNull);
  });

  test('un dibujo grande va por partes y se vuelve a juntar', () {
    final message = {
      'key': 'k',
      'kind': 'doc',
      ...DrawingDeltaEncoder().encode(
        AnnotationDocument(
          strokes: [for (var i = 0; i < 30; i++) stroke('s$i', 200)],
        ),
      ),
    };
    final parts = DrawingWire.pack(message, size: 1000);
    expect(parts.length, greaterThan(1));
    final assembler = DrawingWireAssembler();
    Map<String, dynamic>? whole;
    for (final part in parts.reversed) {
      whole = assembler.add(part) ?? whole;
    }
    expect(DrawingDeltaDecoder().apply(whole!)!.strokes, hasLength(30));
  });

  test(
    'el Mac ve en vivo lo que dibuja el iPad y, al soltarlo, dibuja él',
    () async {
      final ipad = Device('ipad', 'iPad');
      final mac = Device('mac', 'Mac');
      ipad.other = mac;
      mac.other = ipad;
      final key = LiveKey.drawing('storyboard:p1');

      final onIpad = ipad.open(key);
      onIpad.claim();
      expect(onIpad.mine.value, isTrue);

      final onMac = mac.open(key);
      expect(onMac.mine.value, isFalse);
      expect(onMac.otherDrawer.value, 'iPad');
      // El Mac no puede tomarlo mientras el iPad dibuja.
      onMac.claim();
      expect(onMac.mine.value, isFalse);

      // Un trazo a medio hacer se ve en el Mac…
      onIpad.publishStroke(stroke('vivo', 12));
      await settle();
      expect(onMac.remoteStroke.value?.points, hasLength(12));

      // …y al levantar el lápiz entra en el dibujo.
      final a = stroke('a', 12);
      onIpad.publish(AnnotationDocument(strokes: [a]));
      onIpad.publishStroke(null);
      await settle();
      expect(onMac.remoteStroke.value, isNull);
      expect(onMac.remoteDocument.value!.strokes.map((s) => s.id), ['a']);

      onIpad.publish(AnnotationDocument(strokes: [a, stroke('b', 5)]));
      await settle();
      expect(onMac.remoteDocument.value!.strokes.map((s) => s.id), ['a', 'b']);

      // El iPad sale del folio: el Mac puede dibujar y el iPad, si vuelve,
      // mira.
      onIpad.dispose();
      await settle();
      expect(onMac.otherDrawer.value, isNull);
      onMac.claim();
      expect(onMac.mine.value, isTrue);
      onMac.publish(
        onMac.remoteDocument.value!.copyWith(
          strokes: [...onMac.remoteDocument.value!.strokes, stroke('c', 3)],
        ),
      );

      final again = ipad.open(key);
      expect(again.mine.value, isFalse);
      expect(again.otherDrawer.value, 'Mac');
      await settle();
      // Al llegar pidió el dibujo entero, aunque no viera los trazos de antes.
      expect(again.remoteDocument.value!.strokes.map((s) => s.id), [
        'a',
        'b',
        'c',
      ]);
      onMac.dispose();
      again.dispose();
      await settle();
    },
  );

  test('al salir del folio vuelve a lo que se editaba antes', () async {
    final ipad = Device('ipad', 'iPad');
    final mac = Device('mac', 'Mac');
    ipad.other = mac;
    mac.other = ipad;
    ipad.live.focusShot('plano-7');
    final session = ipad.open(LiveKey.drawing('storyboard:plano-7'));
    session.claim();
    expect(ipad.live.myShotUid, LiveKey.drawing('storyboard:plano-7'));
    session.dispose();
    await settle();
    expect(ipad.live.myShotUid, 'plano-7');
  });

  test('sin nadie más, el link dice que el folio es de aquí', () {
    final ipad = Device('ipad', 'iPad');
    final mac = Device('mac', 'Mac');
    ipad.other = mac;
    mac.other = ipad;
    final LiveDrawingLink link = ipad.open('k')..claim();
    expect(link.mine.value, isTrue);
    expect(link.otherDrawer.value, isNull);
    link.dispose();
  });
}

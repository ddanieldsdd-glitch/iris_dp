import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/update/app_update_checker.dart';
import 'package:iris_dp/core/update/device_update_host.dart';
import 'package:iris_dp/core/update/device_update_messages.dart';
import 'package:iris_dp/core/update/device_update_request.dart';

void main() {
  group('mensajes', () {
    test('una petición va y vuelve igual', () {
      const r = DeviceUpdateRequest(id: 'a', kind: 'iPad', userId: 'u');
      final back = DeviceUpdateRequest.fromPayload(r.toPayload())!;
      expect(back.id, 'a');
      expect(back.kind, 'iPad');
      expect(back.userId, 'u');
    });

    test('solo se aceptan iPad e iPhone', () {
      expect(
        DeviceUpdateRequest.fromPayload({
          'id': 'a',
          'kind': 'Mac',
          'userId': 'u',
        }),
        isNull,
      );
    });

    test('una fase desconocida no se interpreta', () {
      expect(
        DeviceUpdateStatus.fromPayload({
          'id': 'a',
          'phase': 'rara',
          'message': '',
        }),
        isNull,
      );
    });
  });

  test('el iPad y el iPhone comparan con la versión del Mac', () {
    expect(releasePlatformFor('ios'), 'macos');
    expect(releasePlatformFor('macos'), 'macos');
    expect(releasePlatformFor('windows'), 'windows');
  });

  group('el Mac', () {
    late Directory dir;
    late DeviceUpdateInstallerFiles files;
    late List<DeviceUpdateStatus> sent;
    late int kicks;
    var kickOk = true;

    DeviceUpdateBridge bridge() => DeviceUpdateBridge(
          files: files,
          kickstart: () async {
            kicks++;
            return kickOk;
          },
          currentUserId: () => 'yo',
          sendStatus: (s) async => sent.add(s),
          pollEvery: const Duration(hours: 1),
        );

    File request() => File('${dir.path}/request.json');

    void writeStatus(String id, String phase) => File(
          '${dir.path}/status.json',
        ).writeAsStringSync(
          jsonEncode({'id': id, 'phase': phase, 'message': phase}),
        );

    setUp(() {
      dir = Directory.systemTemp.createTempSync('iris_update');
      addTearDown(() => dir.deleteSync(recursive: true));
      files = DeviceUpdateInstallerFiles(
        dir,
        launchAgent: File('${dir.path}/agente.plist'),
      );
      sent = [];
      kicks = 0;
      kickOk = true;
    });

    test('solo está disponible si el instalador está configurado', () {
      expect(files.configured, isFalse);
      File('${dir.path}/install_ipad.sh').writeAsStringSync('');
      File('${dir.path}/team_id').writeAsStringSync('T');
      File('${dir.path}/agente.plist').writeAsStringSync('');
      expect(files.configured, isTrue);
    });

    test('ignora las peticiones de otro usuario', () async {
      final b = bridge();
      addTearDown(b.dispose);
      await b.handle(
        const DeviceUpdateRequest(id: 'a', kind: 'iPad', userId: 'otro'),
      );
      expect(request().existsSync(), isFalse);
      expect(kicks, 0);
      expect(sent, isEmpty);
    });

    test('deja la petición, lanza la tarea y confirma', () async {
      final b = bridge();
      addTearDown(b.dispose);
      await b.handle(
        const DeviceUpdateRequest(id: 'a', kind: 'iPhone', userId: 'yo'),
      );
      expect(jsonDecode(request().readAsStringSync())['kind'], 'iPhone');
      expect(kicks, 1);
      expect(sent.single.phase, DeviceUpdatePhase.pedido);
    });

    test('con otra petición en cola no la pisa', () async {
      request().writeAsStringSync('{"id":"antes"}');
      final b = bridge();
      addTearDown(b.dispose);
      await b.handle(
        const DeviceUpdateRequest(id: 'a', kind: 'iPad', userId: 'yo'),
      );
      expect(jsonDecode(request().readAsStringSync())['id'], 'antes');
      expect(kicks, 0);
      expect(sent.single.phase, DeviceUpdatePhase.error);
    });

    test('si la tarea no arranca, retira la petición y lo dice', () async {
      kickOk = false;
      final b = bridge();
      addTearDown(b.dispose);
      await b.handle(
        const DeviceUpdateRequest(id: 'a', kind: 'iPad', userId: 'yo'),
      );
      expect(request().existsSync(), isFalse);
      expect(sent.single.phase, DeviceUpdatePhase.error);
    });

    test('reenvía cada fase una vez y solo la de su petición', () async {
      final b = bridge();
      addTearDown(b.dispose);
      await b.handle(
        const DeviceUpdateRequest(id: 'a', kind: 'iPad', userId: 'yo'),
      );
      writeStatus('vieja', 'hecho');
      await b.poll();
      expect(sent, hasLength(1));
      writeStatus('a', 'compilando');
      await b.poll();
      await b.poll();
      expect(sent, hasLength(2));
      writeStatus('a', 'hecho');
      await b.poll();
      expect(sent.last.phase, DeviceUpdatePhase.hecho);
      await b.poll();
      expect(sent, hasLength(3));
    });
  });

  group('el móvil', () {
    DeviceUpdateController controller(
      List<DeviceUpdateRequest> out, {
      Duration ackTimeout = const Duration(seconds: 20),
    }) =>
        DeviceUpdateController(
          kind: 'iPad',
          userId: () => 'yo',
          send: (r) async => out.add(r),
          ackTimeout: ackTimeout,
        );

    test('sin Mac disponible no pide nada', () async {
      final out = <DeviceUpdateRequest>[];
      final c = controller(out);
      addTearDown(c.dispose);
      await c.request();
      expect(out, isEmpty);
      expect(c.busy, isFalse);
    });

    test('sigue las fases de su petición hasta el final', () async {
      final out = <DeviceUpdateRequest>[];
      final c = controller(out)..setHostAvailable(true);
      addTearDown(c.dispose);
      await c.request();
      expect(c.busy, isTrue);
      expect(out.single.kind, 'iPad');

      c.onStatus(
        const DeviceUpdateStatus(
          id: 'ajena',
          phase: DeviceUpdatePhase.hecho,
          message: 'x',
        ),
      );
      expect(c.busy, isTrue);

      c.onStatus(
        DeviceUpdateStatus(
          id: out.single.id,
          phase: DeviceUpdatePhase.aldia,
          message: 'Ya tienes la última versión.',
        ),
      );
      expect(c.busy, isFalse);
      expect(c.message, 'Ya tienes la última versión.');
    });

    test('si el Mac no contesta, deja de esperar y lo dice', () async {
      final c = controller([], ackTimeout: const Duration(milliseconds: 5))
        ..setHostAvailable(true);
      addTearDown(c.dispose);
      await c.request();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(c.busy, isFalse);
      expect(c.phase, DeviceUpdatePhase.error);
    });
  });
}

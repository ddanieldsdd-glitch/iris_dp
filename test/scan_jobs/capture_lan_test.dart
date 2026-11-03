import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/realtime_hub.dart';
import 'package:iris_dp/features/scan_jobs/capture_lan.dart';
import 'package:iris_dp/features/scan_jobs/capture_store.dart';

/// Del iPhone al PC por la red local, con un servidor de verdad en este
/// equipo.
void main() {
  late AppDatabase db;
  late Directory phone;
  late Directory pc;
  late CaptureReceiver receiver;
  late List<String> received;
  late String uid;
  late List<int> bytes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    phone = Directory.systemTemp.createTempSync('iris_lan_phone');
    pc = Directory.systemTemp.createTempSync('iris_lan_pc');
    CaptureStore.debugRoot = phone;
    received = [];
    receiver = CaptureReceiver(
      token: 'secreto',
      root: pc,
      onReceived: (uid) async => received.add(uid),
    );
    await receiver.start(port: 0);

    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'C'),
    );
    await db.insertCapture(
      LocationCapturesCompanion.insert(
        projectId: projectId,
        name: 'Pasillo',
        originInstallId: Value(await InstallId.get()),
      ),
    );
    uid = (await db.watchCapturesForProject(projectId).first).single.uid!;
    bytes = List.generate(300000, (i) => i * 7 % 256);
    (await CaptureStore.zipFor(uid)).writeAsBytesSync(bytes);
  });

  tearDown(() async {
    await receiver.stop();
    await db.close();
    CaptureStore.debugRoot = null;
    phone.deleteSync(recursive: true);
    pc.deleteSync(recursive: true);
  });

  ScanBuilderPeer peer({String token = 'secreto', List<String>? ips}) =>
      ScanBuilderPeer(
        installId: 'pc-1',
        lanIps: ips ?? ['127.0.0.1'],
        port: receiver.port!,
        token: token,
      );

  test('llega entera y queda en el PC', () async {
    final sent = await CaptureSender(db).sendPending([
      peer(ips: ['10.255.255.1', '127.0.0.1']),
    ]);
    expect(sent, 1);
    expect(received, [uid]);
    final file = File('${pc.path}/$uid.iriscapture.zip');
    expect(sha256.convert(file.readAsBytesSync()), sha256.convert(bytes));
    final row = (await db.getCaptureByUid(uid))!;
    expect(row.status, CaptureStatus.onPc);
    expect(row.builderInstallId, 'pc-1');
    expect(await CaptureSender(db).pending(), isEmpty);
  });

  test('con otra clave el PC no contesta y sigue pendiente', () async {
    final sent = await CaptureSender(db).sendPending([peer(token: 'otra')]);
    expect(sent, 0);
    expect(received, isEmpty);
    expect((await db.getCaptureByUid(uid))!.status, CaptureStatus.onPhone);
  });

  test('si no cuadra el tamaño, se borra y se repite', () async {
    final client = HttpClient();
    final req = await client.putUrl(
      Uri.parse(
        'http://127.0.0.1:${receiver.port}/capture/$uid'
        '?token=secreto&size=999&sha256=abc',
      ),
    );
    req.add([1, 2, 3]);
    final res = await req.close();
    await res.drain<void>();
    client.close();
    expect(res.statusCode, HttpStatus.badRequest);
    expect(pc.listSync(), isEmpty);
    expect(received, isEmpty);

    // Una pasada después llega bien.
    expect(await CaptureSender(db).sendPending([peer()]), 1);
  });

  test('una captura de otro equipo no se envía desde aquí', () async {
    await db.updateCapture(
      uid,
      const LocationCapturesCompanion(originInstallId: Value('otro')),
    );
    expect(await CaptureSender(db).sendPending([peer()]), 0);
  });
}

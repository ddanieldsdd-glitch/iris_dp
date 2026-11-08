import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/utils/media_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('iris_media_names_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => docs.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    docs.deleteSync(recursive: true);
  });

  test('referencias del mismo plano escritas a la vez no se pisan', () async {
    final paths = await Future.wait([
      for (var i = 0; i < 40; i++)
        MediaStorage.writeShotReferenceBytes(
          projectId: 1,
          shotId: 1,
          bytes: Uint8List.fromList([i]),
          fileName: 'r$i.png',
        ),
    ]);
    expect(paths.toSet(), hasLength(40));
    for (final (i, path) in paths.indexed) {
      expect(File(path).readAsBytesSync(), [i]);
    }
  });
}

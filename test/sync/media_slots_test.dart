import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/cloud_media_service.dart';
import 'package:iris_dp/core/sync/media_entity_types.dart';
import 'package:iris_dp/core/sync/media_hydrate_service.dart';
import 'package:iris_dp/core/sync/media_slots.dart';
import 'package:iris_dp/core/sync/media_upload_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Nube simulada: guarda lo subido y entrega lo que se le dé para bajar.
class _FakeCloud extends CloudMediaService {
  _FakeCloud({this.assets = const []})
    : super(SupabaseClient('http://127.0.0.1:9', 'clave'));

  final List<Map<String, dynamic>> assets;
  final images = <String>[];
  final files = <String>[];

  CloudUploadResult _ok(String id) => CloudUploadResult(
    publicId: id,
    deliveryUrl: '',
    bytesOriginal: 1,
    bytesStored: 1,
    contentHash: 'h',
  );

  @override
  Future<CloudUploadResult?> uploadFile({
    required String localPath,
    required String publicId,
    required String projectCloudId,
    required String entityType,
    required String entityKey,
    required int sortOrder,
    String? source,
    int? bytesOriginalOverride,
  }) async {
    images.add('$entityType $entityKey');
    return _ok(publicId);
  }

  @override
  Future<CloudUploadResult?> uploadRawFile({
    required String localPath,
    required String projectCloudId,
    required String entityType,
    required String entityKey,
    required int sortOrder,
    required int maxBytes,
    String? source,
  }) async {
    files.add('$entityType $entityKey');
    return _ok(localPath);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProjectAssets(String id) async =>
      assets;

  @override
  Future<String?> downloadToLocal({
    required int localProjectId,
    required String deliveryUrl,
    required String subfolder,
    required String fileName,
  }) async => '/descargas/$subfolder/$fileName';

  @override
  Future<Uint8List> downloadStorageBytes(String storagePath) async =>
      Uint8List.fromList(utf8.encode('{"trazos":[1,2,3]}'));

  @override
  Future<String?> downloadStorageFile({
    required int localProjectId,
    required String storagePath,
    required String subfolder,
    required String fileName,
  }) async => '/descargas/$subfolder/$fileName';
}

void main() {
  late AppDatabase db;
  late int projectId;
  late int sceneId;
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'iris_cloud_workspace_id': 'ws-1'});
    MediaUploadQueue.retryDelay = Duration.zero;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    dir = Directory.systemTemp.createTempSync('iris_slots');
    addTearDown(() => dir.deleteSync(recursive: true));
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'lala', cloudId: const Value('cloud-1')),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'INT. CASA - DÍA',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
  });

  String file(String name) =>
      (File('${dir.path}/$name')..writeAsBytesSync([1, 2, 3])).path;

  Future<String> shotUid({String? storyboard}) async {
    final id = await db
        .into(db.shots)
        .insert(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: 1,
            storyboardImagePath: Value(storyboard),
          ),
        );
    return (await (db.select(
      db.shots,
    )..where((s) => s.id.equals(id))).getSingle()).uid!;
  }

  test(
    'el storyboard, el guion y las pruebas de cámara se ponen en cola',
    () async {
      final uid = await shotUid(storyboard: file('sb.png'));
      final script = file('guion.fdx');
      await (db.update(db.projects)..where((p) => p.id.equals(projectId)))
          .write(ProjectsCompanion(scriptFilePath: Value(script)));
      final bibleId = (await db.ensureVisualBibleForProject(projectId)).id;
      await db
          .into(db.cameraTests)
          .insert(
            CameraTestsCompanion.insert(
              bibleId: bibleId,
              testName: 'Prueba A',
              imagePaths: jsonEncode([file('t1.png'), '/no/existe.png']),
            ),
          );

      final cloud = _FakeCloud();
      final queue = MediaUploadQueue(
        db: db,
        cloud: cloud,
        isEnabled: () => true,
      );
      await queue.scanAndEnqueueProject(projectId);
      await queue.startWorker();

      expect(
        cloud.images,
        contains('${MediaEntityType.shotStoryboard} uid:$uid'),
      );
      expect(cloud.files, ['${MediaEntityType.script} uid:script']);
      // De la lista solo sube la que existe, con su posición.
      expect(
        cloud.images.where((k) => k.startsWith(MediaEntityType.cameraTest)),
        [predicate<String>((k) => k.endsWith('#0'))],
      );
    },
  );

  test('al bajar, cada archivo va a su fila por el uid', () async {
    final uid = await shotUid();
    final hydrate = MediaHydrateService(
      db,
      _FakeCloud(
        assets: [
          {
            'entity_type': MediaEntityType.shotStoryboard,
            'entity_key': mediaSlotKey(uid),
            'delivery_url': 'https://res.cloudinary.com/x/sb',
            'public_id': 'iris/ws/p/shot_storyboard/$uid',
          },
          {
            'entity_type': MediaEntityType.script,
            'entity_key': mediaSlotKey('script'),
            'storage_path': 'projects/cloud-1/script/uid_script/guion.fdx',
            'metadata': {'file_name': 'guion.fdx'},
          },
        ],
      ),
    );

    expect(await hydrate.hydrateProject(projectId, 'cloud-1'), 2);
    final shot = await (db.select(
      db.shots,
    )..where((s) => s.uid.equals(uid))).getSingle();
    expect(
      shot.storyboardImagePath,
      '/descargas/storyboard/${MediaEntityType.shotStoryboard}_$uid.jpg',
    );
    expect(
      (await db.getProject(projectId))!.scriptFilePath,
      '/descargas/script/guion.fdx',
    );
  });

  test('las claves de hueco se leen con su posición', () {
    expect(parseMediaSlotKey('uid:abc'), ('abc', null));
    expect(parseMediaSlotKey('uid:abc#3'), ('abc', 3));
    expect(parseMediaSlotKey('moodboard:x:1'), isNull);
  });

  test('las rutas de un hueco de lista admiten JSON o una ruta suelta', () {
    expect(decodeSlotPaths('/a.png'), ['/a.png']);
    expect(decodeSlotPaths('["/a.png","setup:3"]'), ['/a.png', 'setup:3']);
    expect(decodeSlotPaths(null), isEmpty);
  });

  test('los trazos de un boceto suben con su imagen, como archivo', () async {
    final sb = file('sb.png');
    File('$sb.trazos.json').writeAsStringSync('{"trazos":[]}');
    final uid = await shotUid(storyboard: sb);

    final cloud = _FakeCloud();
    final queue = MediaUploadQueue(db: db, cloud: cloud, isEnabled: () => true);
    await queue.scanAndEnqueueProject(projectId);
    await queue.startWorker();

    expect(
      cloud.images,
      contains('${MediaEntityType.shotStoryboard} uid:$uid'),
    );
    expect(
      cloud.files,
      contains(
        '${MediaEntityType.sketchStrokes} '
        '${MediaEntityType.shotStoryboard}|uid:$uid',
      ),
    );
  });

  test('al bajar, los trazos quedan junto a su imagen', () async {
    final uid = await shotUid();
    final dirPath = Directory.systemTemp.createTempSync('iris_strokes').path;
    final hydrate = MediaHydrateService(
      db,
      _DownloadingCloud(dirPath, [
        {
          'entity_type': MediaEntityType.sketchStrokes,
          'entity_key':
              '${MediaEntityType.shotStoryboard}|${mediaSlotKey(uid)}',
          'storage_path':
              'projects/cloud-1/sketch_strokes/x/sb.png.trazos.json',
          'content_hash': 'b' * 64,
        },
        {
          'entity_type': MediaEntityType.shotStoryboard,
          'entity_key': mediaSlotKey(uid),
          'delivery_url': 'https://res.cloudinary.com/x/sb',
          'public_id': 'iris/ws/p/shot_storyboard/$uid',
          'content_hash': 'a' * 64,
        },
      ]),
    );

    await hydrate.hydrateProject(projectId, 'cloud-1');

    final shot = await (db.select(
      db.shots,
    )..where((s) => s.uid.equals(uid))).getSingle();
    final strokes = File('${shot.storyboardImagePath}.trazos.json');
    expect(strokes.existsSync(), isTrue);
    expect(strokes.readAsStringSync(), '{"trazos":[1,2,3]}');
  });
}

/// Nube que escribe de verdad lo que baja, para que exista junto a la imagen.
class _DownloadingCloud extends _FakeCloud {
  _DownloadingCloud(this.dir, List<Map<String, dynamic>> assets)
    : super(assets: assets);

  final String dir;

  @override
  Future<String?> downloadToLocal({
    required int localProjectId,
    required String deliveryUrl,
    required String subfolder,
    required String fileName,
  }) async => (File('$dir/$fileName')..writeAsBytesSync([1])).path;
}

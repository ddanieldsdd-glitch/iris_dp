import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/media_storage.dart';
import 'media_entity_types.dart';
import 'media_slots.dart';
import 'media_upload_queue.dart';

/// Escaneos 3D puestos en la planta (RealityScan, Polycam, Luma…), F6.12.5.
/// Se guardan en la carpeta del proyecto y viajan como archivo (Supabase
/// Storage, bytes tal cual), igual que las miniaturas de Unreal: la clave es
/// el nombre del archivo, el mismo que guarda `props['file']` del elemento,
/// así que en otro equipo el escaneo baja solo y se encuentra por su nombre.
abstract final class PlanScanStore {
  static const subfolder = 'plan_scans';

  /// La cola que sube lo guardado. La pone `media_sync_binder` al arrancar;
  /// sin nube, solo se guarda aquí.
  static MediaUploadQueue? uploadQueue;

  static final _arrivals = StreamController<String>.broadcast();

  /// Escaneos que acaban de llegar a este equipo: el visor los vuelve a
  /// pedir.
  static Stream<String> get arrivals => _arrivals.stream;

  /// Nombre del archivo, sin carpetas: `<base36>.glb`.
  static bool isKey(String key) =>
      RegExp(r'^[0-9a-z]+\.(glb|gltf|obj|ply)$').hasMatch(key);

  /// Si el archivo cabe en la nube.
  static bool fitsCloud(int bytes) => bytes <= MediaSlot.maxFileBytes;

  /// Dónde va el escaneo [key] del proyecto [projectId] (exista o no).
  static Future<String?> pathFor(int projectId, String key) async {
    final dir = await MediaStorage.projectDirectory(projectId);
    if (dir == null) return null;
    return p.join(dir.path, subfolder, key);
  }

  /// Copia [sourcePath] al proyecto con el nombre [key] y lo pone en cola
  /// para subirlo, si cabe. Devuelve la ruta local.
  static Future<String> save({
    required int projectId,
    required String key,
    required String sourcePath,
  }) async {
    if (!isKey(key)) throw ArgumentError.value(key, 'key', 'Clave no válida');
    final path = await pathFor(projectId, key);
    if (path == null) throw StateError('Almacenamiento no disponible');
    await Directory(p.dirname(path)).create(recursive: true);
    if (p.normalize(sourcePath) != p.normalize(path)) {
      await File(sourcePath).copy(path);
    }
    await enqueue(projectId, key, path);
    _arrivals.add(key);
    return path;
  }

  /// Pone en cola la subida de un escaneo ya guardado en el proyecto.
  static Future<void> enqueue(int projectId, String key, String path) async {
    final queue = uploadQueue;
    if (queue == null) return;
    if (!fitsCloud(await File(path).length())) return;
    await queue.enqueue(
      projectId: projectId,
      entityType: MediaEntityType.planScan,
      entityKey: key,
      localPath: path,
      sortOrder: 0,
    );
    unawaited(queue.startWorker());
  }

  /// La ruta local del escaneo [key] si ya está en este equipo; si no,
  /// `null` (lo baja la sincronización y avisa por [arrivals]).
  static Future<String?> resolve(int projectId, String key) async {
    if (!isKey(key)) return null;
    final path = await pathFor(projectId, key);
    if (path == null || !File(path).existsSync()) return null;
    return path;
  }

  /// Lo llama la descarga de medios al traer un escaneo.
  static void notifyArrived(String key) => _arrivals.add(key);
}

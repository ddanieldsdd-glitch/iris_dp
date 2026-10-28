import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../utils/media_storage.dart';
import 'media_entity_types.dart';
import 'media_upload_queue.dart';

/// Vista de la miniatura de un asset de Unreal.
enum UnrealThumbView {
  /// Cenital ortográfica con transparencia: se dibuja en la planta 2D.
  top('top'),

  /// 3/4 en perspectiva: ficha, biblioteca y cartel del 3D.
  threeQuarter('34');

  const UnrealThumbView(this.suffix);
  final String suffix;
}

/// Miniaturas que renderiza el Unreal del PC para los assets asociados a los
/// elementos (F6.20 B3). Se guardan en la carpeta del proyecto y viajan como
/// archivo (Supabase Storage, bytes tal cual: la cenital necesita su
/// transparencia), así que en el Mac y el iPad bajan solas aunque allí no
/// haya Unreal.
///
/// La clave depende solo de la ruta del asset y de la vista: dos elementos
/// con el mismo asset comparten miniatura. Se guarda en
/// `props['unreal'].thumbTop` / `.thumb34`.
abstract final class UnrealThumbStore {
  static const subfolder = 'unreal_thumbs';

  /// La cola que sube lo guardado. La pone `media_sync_binder` al arrancar;
  /// sin nube, solo se guarda aquí.
  static MediaUploadQueue? uploadQueue;

  static final _arrivals = StreamController<String>.broadcast();

  /// Claves cuya miniatura acaba de llegar a este equipo (guardada aquí o
  /// bajada de la nube): quien la pinta se redibuja.
  static Stream<String> get arrivals => _arrivals.stream;

  /// `<sha1 de la ruta, 20 hex>_top` o `…_34`.
  static String keyFor(String assetPath, UnrealThumbView view) {
    final hash = sha1.convert(utf8.encode(assetPath.trim())).toString();
    return '${hash.substring(0, 20)}_${view.suffix}';
  }

  static bool isKey(String key) =>
      RegExp(r'^[0-9a-f]{20}_(top|34)$').hasMatch(key);

  static String fileName(String key) => '$key.png';

  /// Dónde va la miniatura [key] del proyecto [projectId] (exista o no).
  static Future<String?> pathFor(int projectId, String key) async {
    final dir = await MediaStorage.projectDirectory(projectId);
    if (dir == null) return null;
    return p.join(dir.path, subfolder, fileName(key));
  }

  /// Guarda el PNG que ha renderizado Unreal y lo pone en cola para subirlo.
  /// Devuelve la ruta local.
  static Future<String> save({
    required int projectId,
    required String key,
    required Uint8List pngBytes,
  }) async {
    if (!isKey(key)) throw ArgumentError.value(key, 'key', 'Clave no válida');
    final path = await MediaStorage.writeProjectFileBytes(
      projectId: projectId,
      subfolder: subfolder,
      bytes: pngBytes,
      fileName: fileName(key),
    );
    _arrivals.add(key);
    final queue = uploadQueue;
    if (queue != null) {
      await queue.enqueue(
        projectId: projectId,
        entityType: MediaEntityType.unrealThumb,
        entityKey: key,
        localPath: path,
        sortOrder: 0,
      );
      unawaited(queue.startWorker());
    }
    return path;
  }

  /// La ruta local de la miniatura [key] si ya está en este equipo; si no,
  /// `null` (la baja la sincronización y avisa por [arrivals]).
  static Future<String?> resolve(int projectId, String key) async {
    if (!isKey(key)) return null;
    final path = await pathFor(projectId, key);
    if (path == null || !File(path).existsSync()) return null;
    return path;
  }

  /// Lo llama la descarga de medios al traer una miniatura.
  static void notifyArrived(String key) => _arrivals.add(key);
}

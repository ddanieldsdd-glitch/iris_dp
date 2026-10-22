import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/media_storage.dart';
import 'floor_plan_scope.dart';

/// De dónde salió una imagen de la planta.
abstract final class PlanImageSource {
  static const pasted = 'pegada';
  static const moodboard = 'moodboard';
  static const storyboard = 'storyboard';
  static const file = 'archivo';
}

/// Un comentario sobre una imagen de la planta.
class PlanImageComment {
  /// dp | gaffer | colorist | ac | director | otro
  final String author;
  final String text;
  final DateTime at;

  const PlanImageComment({
    required this.author,
    required this.text,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
    'author': author,
    'text': text,
    'at': at.toIso8601String(),
  };

  static List<PlanImageComment> decode(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      return [
        for (final m in jsonDecode(json) as List)
          PlanImageComment(
            author: (m as Map)['author'] as String? ?? 'dp',
            text: m['text'] as String? ?? '',
            at: DateTime.tryParse(m['at'] as String? ?? '') ?? DateTime(2000),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static String encode(List<PlanImageComment> comments) =>
      jsonEncode([for (final c in comments) c.toJson()]);
}

/// Quién comenta, con su nombre visible.
const kPlanImageAuthors = {
  'dp': 'Dirección de foto',
  'gaffer': 'Gaffer',
  'director': 'Dirección',
  'ac': 'Foquista',
  'colorist': 'Color',
  'otro': 'Otro',
};

/// Rectángulo de una imagen en la planta.
Rect planImageRect(PlanImage image) =>
    Rect.fromLTWH(image.x, image.y, image.w, image.h);

/// ¿Cae [point] (coordenadas de la planta) dentro de la imagen, con su giro?
bool planImageContains(PlanImage image, Offset point) {
  final rect = planImageRect(image);
  if (image.rotation == 0) return rect.contains(point);
  final local = _rotate(point, rect.center, -image.rotation);
  return rect.contains(local);
}

Offset _rotate(Offset p, Offset c, double radians) {
  final d = p - c;
  final cos = math.cos(radians);
  final sin = math.sin(radians);
  return c + Offset(d.dx * cos - d.dy * sin, d.dx * sin + d.dy * cos);
}

/// Escala de una cenital a partir de dos puntos de medida conocida: la
/// imagen se agranda (o encoge) alrededor del primero hasta que la
/// distancia entre los dos mide [meters] en la planta.
Rect calibratePlanImage({
  required Rect rect,
  required Offset from,
  required Offset to,
  required double meters,
  required double metersPerUnit,
}) {
  final distance = (to - from).distance;
  if (distance <= 0 || meters <= 0 || metersPerUnit <= 0) return rect;
  final factor = (meters / metersPerUnit) / distance;
  return Rect.fromLTRB(
    from.dx + (rect.left - from.dx) * factor,
    from.dy + (rect.top - from.dy) * factor,
    from.dx + (rect.right - from.dx) * factor,
    from.dy + (rect.bottom - from.dy) * factor,
  );
}

/// Las imágenes de una planta: guardarlas, moverlas y comentarlas. Toda
/// escritura marca el proyecto como cambiado para la sincronización.
class PlanImageStore {
  final AppDatabase db;

  PlanImageStore(this.db);

  static String targetType(FloorPlanScope scope) => scope.name;

  /// Las imágenes de las capas que se ven (entorno, set, luz y plano), de
  /// abajo arriba.
  Future<List<PlanImage>> forLayers({
    required int projectId,
    int? siteId,
    int? setId,
    int? lightSetupId,
    int? shotId,
  }) async {
    final wanted = {
      if (siteId != null) 'site/$siteId',
      if (setId != null) 'set/$setId',
      if (lightSetupId != null) 'lightSetup/$lightSetupId',
      if (shotId != null) 'shot/$shotId',
    };
    if (wanted.isEmpty) return const [];
    final rows =
        await (db.select(db.planImages)
              ..where((i) => i.projectId.equals(projectId))
              ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
            .get();
    return [
      for (final r in rows)
        if (wanted.contains('${r.targetType}/${r.targetId}')) r,
    ];
  }

  /// Guarda una imagen nueva en la capa [scope]/[targetId], centrada en
  /// [center] y con su lado mayor de [longSide] unidades.
  Future<PlanImage> add({
    required int projectId,
    required FloorPlanScope scope,
    required int targetId,
    required Uint8List bytes,
    required String extension,
    required String source,
    required Offset center,
    double longSide = 360,
    String? caption,
    int? linkedShotId,
  }) async {
    final size = await _imageSize(bytes);
    final aspect = size.height == 0 ? 0.75 : size.height / size.width;
    final w = aspect <= 1 ? longSide : longSide / aspect;
    final h = w * aspect;
    final ext = extension.startsWith('.') ? extension : '.$extension';
    final path = await MediaStorage.writeProjectFileBytes(
      projectId: projectId,
      subfolder: 'plan_images',
      bytes: bytes,
      fileName: 'imagen_${DateTime.now().microsecondsSinceEpoch}$ext',
    );
    final count = (await (db.select(
      db.planImages,
    )..where((i) => i.projectId.equals(projectId))).get()).length;
    final id = await db
        .into(db.planImages)
        .insert(
          PlanImagesCompanion.insert(
            projectId: projectId,
            targetType: targetType(scope),
            targetId: targetId,
            path: Value(path),
            source: Value(source),
            caption: Value(caption),
            x: center.dx - w / 2,
            y: center.dy - h / 2,
            w: w,
            h: h,
            linkedShotId: Value(linkedShotId),
            sortOrder: Value(count),
          ),
        );
    await db.touchProjectContent(projectId);
    return (await get(id))!;
  }

  Future<PlanImage?> get(int id) => (db.select(
    db.planImages,
  )..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<void> save(PlanImage image) async {
    await db.update(db.planImages).replace(image);
    await db.touchProjectContent(image.projectId);
  }

  Future<void> delete(PlanImage image) async {
    await (db.delete(
      db.planImages,
    )..where((i) => i.id.equals(image.id))).go();
    await db.touchProjectContent(image.projectId);
  }

  /// La sube al final de la pila de su capa (se pinta la última).
  Future<PlanImage> bringToFront(PlanImage image) async {
    final top = (await (db.select(
      db.planImages,
    )..where((i) => i.projectId.equals(image.projectId))).get()).fold<int>(
      0,
      (m, i) => math.max(m, i.sortOrder),
    );
    final moved = image.copyWith(sortOrder: top + 1);
    await save(moved);
    return moved;
  }

  Future<PlanImage> addComment(
    PlanImage image, {
    required String author,
    required String text,
  }) async {
    final comments = [
      ...PlanImageComment.decode(image.commentsJson),
      PlanImageComment(author: author, text: text.trim(), at: DateTime.now()),
    ];
    final updated = image.copyWith(
      commentsJson: Value(PlanImageComment.encode(comments)),
    );
    await save(updated);
    return updated;
  }

  Future<PlanImage> removeComment(PlanImage image, int index) async {
    final comments = [...PlanImageComment.decode(image.commentsJson)];
    if (index < 0 || index >= comments.length) return image;
    comments.removeAt(index);
    final updated = image.copyWith(
      commentsJson: Value(
        comments.isEmpty ? null : PlanImageComment.encode(comments),
      ),
    );
    await save(updated);
    return updated;
  }

  static Future<Size> _imageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      return size;
    } catch (_) {
      return const Size(4, 3);
    }
  }
}

/// Las imágenes ya decodificadas, por ruta, para pintarlas en el lienzo.
class PlanImageCache extends ChangeNotifier {
  final Map<String, ui.Image> _images = {};
  final Set<String> _loading = {};

  ui.Image? operator [](String? path) => path == null ? null : _images[path];

  /// Pide las que falten; avisa al tenerlas.
  void ensure(Iterable<PlanImage> images) {
    for (final image in images) {
      final path = image.path;
      if (path == null ||
          _images.containsKey(path) ||
          !_loading.add(path)) {
        continue;
      }
      _load(path);
    }
  }

  Future<void> _load(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      _images[path] = frame.image;
      notifyListeners();
    } catch (_) {
      // Una imagen que no se puede leer se queda sin pintar.
    } finally {
      _loading.remove(path);
    }
  }

  @override
  void dispose() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    super.dispose();
  }
}

/// Lo que el pintor necesita de cada imagen.
class PlanImageDraw {
  final ui.Image? image;
  final Rect rect;
  final double rotation;
  final double opacity;
  final bool above;
  final bool selected;
  final bool hasComments;

  /// Cámara del plano unido: una línea discontinua la une a la imagen.
  final Offset? linkTo;

  const PlanImageDraw({
    required this.image,
    required this.rect,
    this.rotation = 0,
    this.opacity = 1,
    this.above = false,
    this.selected = false,
    this.hasComments = false,
    this.linkTo,
  });
}

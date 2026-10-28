import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../core/sync/unreal_thumb_store.dart';
import '../camera_plan/camera_plan_element_model.dart';
import 'unreal_link.dart';

/// Miniaturas de los assets de Unreal (F6.20 B3): las pide al Unreal del PC,
/// las guarda en el proyecto (y la sincronización las sube) y las carga para
/// dibujarlas en la planta, la ficha y el 3D.
class UnrealThumbs extends ChangeNotifier {
  UnrealThumbs._() {
    UnrealThumbStore.arrivals.listen(_arrived);
  }

  static final instance = UnrealThumbs._();

  final _images = <String, ui.Image>{};
  final _files = <String, String>{};
  final _loading = <String>{};

  /// Claves que no estaban en este equipo: se reintentan al llegar.
  final _missing = <String>{};

  /// Renderiza en Unreal las dos miniaturas de [ref], las guarda en el
  /// proyecto [projectId] y devuelve el asset con sus claves.
  static Future<UnrealAssetRef> render(
    UnrealLink link,
    int projectId,
    UnrealAssetRef ref,
  ) async {
    final shot = await link.assetPreview(ref.path);
    final top = UnrealThumbStore.keyFor(ref.path, UnrealThumbView.top);
    final three = UnrealThumbStore.keyFor(
      ref.path,
      UnrealThumbView.threeQuarter,
    );
    await UnrealThumbStore.save(
      projectId: projectId,
      key: top,
      pngBytes: shot.top,
    );
    await UnrealThumbStore.save(
      projectId: projectId,
      key: three,
      pngBytes: shot.threeQuarter,
    );
    return ref.copyWith(
      thumbTop: top,
      thumb34: three,
      topSpanCm: shot.topSpanCm,
    );
  }

  /// La imagen de [key], si ya está cargada. Si no, la empieza a cargar y
  /// avisa cuando la tenga.
  ui.Image? image(int projectId, String? key) {
    if (key == null) return null;
    final ready = _images[key];
    if (ready != null) return ready;
    _load(projectId, key);
    return null;
  }

  /// La ruta local de [key], si ya está en este equipo.
  String? file(int projectId, String? key) {
    if (key == null) return null;
    final ready = _files[key];
    if (ready != null) return ready;
    _load(projectId, key);
    return null;
  }

  /// Lo que hace falta para la vista de assets de una planta: carga las
  /// cenitales de sus elementos.
  void warm(int projectId, Iterable<PlanElement> elements) {
    for (final el in elements) {
      image(projectId, UnrealAssetRef.of(el)?.thumbTop);
    }
  }

  Future<void> _load(int projectId, String key) async {
    if (_loading.contains(key) || _missing.contains(key)) return;
    _loading.add(key);
    try {
      final path = await UnrealThumbStore.resolve(projectId, key);
      if (path == null) {
        _missing.add(key);
        return;
      }
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _images[key]?.dispose();
      _images[key] = frame.image;
      _files[key] = path;
      notifyListeners();
    } catch (e) {
      debugPrint('[unreal] miniatura $key: $e');
    } finally {
      _loading.remove(key);
    }
  }

  void _arrived(String key) {
    // Ha llegado (o se ha vuelto a renderizar): se carga de nuevo.
    _missing.remove(key);
    _images.remove(key)?.dispose();
    _files.remove(key);
    notifyListeners();
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../annotation_brush_catalog.dart';
import '../annotation_document.dart';
import '../annotation_textures.dart';
import 'procreate_brush_import.dart';

/// Pinceles propios de este dispositivo: los importados de Procreate y las
/// variantes guardadas en el estudio de pincel. No viajan con el proyecto:
/// en otro dispositivo, un trazo hecho con ellos se pinta con su familia.
class CustomBrushStore {
  CustomBrushStore({Future<Directory> Function()? root})
    : _root = root ?? _defaultRoot;

  static final CustomBrushStore instance = CustomBrushStore();

  final Future<Directory> Function() _root;
  Future<void>? _loading;

  static Future<Directory> _defaultRoot() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'pinceles'),
  );

  /// Base de los pinceles importados: punta propia, sin humedad.
  static const _importBase = BrushSpec(
    id: 'custom.base',
    name: 'Importado',
    category: BrushCategory.custom,
    family: AnnotationToolType.pencil,
    tip: BrushTip.hardRound,
    defaultWidth: 14,
    spacing: 0.1,
    flow: 0.7,
    pressureSize: 0.4,
    pressureOpacity: 0.4,
  );

  /// Carga una vez los pinceles guardados y los registra en el catálogo.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final Directory dir;
    try {
      dir = await _root();
      if (!dir.existsSync()) return;
    } catch (_) {
      return;
    }
    for (final entry in dir.listSync().whereType<Directory>()) {
      try {
        await _loadOne(entry);
      } catch (_) {
        // Un pincel roto no impide cargar los demás.
      }
    }
  }

  Future<BrushSpec?> _loadOne(Directory folder) async {
    final meta = File(p.join(folder.path, 'brush.json'));
    if (!meta.existsSync()) return null;
    final json = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
    final params = {
      for (final e in (json['params'] as Map? ?? const {}).entries)
        if (e.value is num) '${e.key}': (e.value as num).toDouble(),
    };
    final base = BrushCatalog.byId(json['base'] as String?) ?? _importBase;
    final shape = File(p.join(folder.path, 'shape.png'));
    final grain = File(p.join(folder.path, 'grain.png'));
    final spec = base.derive(
      id: json['id'] as String,
      name: json['name'] as String?,
      category: BrushCategory.custom,
      params: params,
      tipImage: shape.existsSync() ? await _decode(shape) : null,
      grainImage: grain.existsSync() ? await _decode(grain) : null,
      defaultColor: (json['color'] as num?)?.toInt(),
    );
    BrushCatalog.register(spec);
    return spec;
  }

  static Future<ui.Image> _decode(File file) async {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  static String _newId() => 'custom.${DateTime.now().microsecondsSinceEpoch}';

  /// Importa un `.brush` o `.brushset`. Devuelve los pinceles añadidos.
  Future<List<BrushSpec>> importProcreate(
    Uint8List bytes, {
    String? fileName,
  }) async {
    await ensureLoaded();
    final parsed = ProcreateBrushImport.parse(bytes, fileName: fileName);
    final root = await _root();
    final added = <BrushSpec>[];
    for (final brush in parsed) {
      final id = _newId();
      final folder = Directory(p.join(root.path, id.replaceAll('.', '_')));
      folder.createSync(recursive: true);
      File(p.join(folder.path, 'shape.png')).writeAsBytesSync(brush.shapePng);
      final grain = brush.grainPng;
      if (grain != null) {
        File(p.join(folder.path, 'grain.png')).writeAsBytesSync(grain);
      }
      File(p.join(folder.path, 'brush.json')).writeAsStringSync(
        jsonEncode({
          'id': id,
          'name': brush.name,
          'source': 'procreate',
          'params': brush.params,
        }),
      );
      final spec = await _loadOne(folder);
      if (spec != null) added.add(spec);
    }
    return added;
  }

  /// Guarda una variante de [base] con otros ajustes (estudio de pincel).
  Future<BrushSpec?> saveVariant(
    BrushSpec base, {
    required String name,
    required Map<String, double> params,
    int? color,
  }) async {
    await ensureLoaded();
    final root = await _root();
    final id = _newId();
    final folder = Directory(p.join(root.path, id.replaceAll('.', '_')));
    folder.createSync(recursive: true);
    // Una variante de un importado lleva su punta y su grano.
    final custom = base.category == BrushCategory.custom;
    final source = custom ? _folderOf(root, base.id) : null;
    for (final file in ['shape.png', 'grain.png']) {
      final from = source == null ? null : File(p.join(source.path, file));
      if (from != null && from.existsSync()) {
        from.copySync(p.join(folder.path, file));
      }
    }
    File(p.join(folder.path, 'brush.json')).writeAsStringSync(
      jsonEncode({
        'id': id,
        'name': name,
        'source': 'variant',
        // Un importado no tiene base en el catálogo: se parte de la genérica.
        if (!custom) 'base': base.id,
        'params': {...base.params, ...params},
        'color': ?color,
      }),
    );
    return _loadOne(folder);
  }

  Directory? _folderOf(Directory root, String id) {
    final dir = Directory(p.join(root.path, id.replaceAll('.', '_')));
    return dir.existsSync() ? dir : null;
  }

  Future<void> delete(String id) async {
    final root = await _root();
    final dir = _folderOf(root, id);
    if (dir != null) dir.deleteSync(recursive: true);
    BrushCatalog.unregister(id);
  }

  /// Solo para pruebas: olvida lo cargado.
  void resetForTest() => _loading = null;
}

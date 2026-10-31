import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../camera_plan/camera_plan_constants.dart';
import '../camera_plan/camera_plan_element_model.dart';
import '../camera_plan/light/light_scene.dart';
import 'unreal_asset_ref.dart';

/// Un asset de la biblioteca: el asset (con sus miniaturas), si es favorito,
/// cuándo se usó y en qué proyecto están sus miniaturas.
class UnrealLibraryEntry {
  final UnrealAssetRef ref;
  final bool favorite;
  final DateTime lastUsed;

  /// Proyecto donde se guardaron sus miniaturas ([UnrealThumbStore] las
  /// guarda por proyecto).
  final int? thumbProjectId;

  const UnrealLibraryEntry({
    required this.ref,
    this.favorite = false,
    required this.lastUsed,
    this.thumbProjectId,
  });

  Map<String, dynamic> toJson() => {
    'ref': ref.toJson(),
    if (favorite) 'favorite': true,
    'lastUsed': lastUsed.toUtc().toIso8601String(),
    'thumbProjectId': ?thumbProjectId,
  };

  static UnrealLibraryEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final ref = UnrealAssetRef.fromJson(raw['ref']);
    if (ref == null) return null;
    return UnrealLibraryEntry(
      ref: ref,
      favorite: raw['favorite'] == true,
      lastUsed:
          DateTime.tryParse(raw['lastUsed'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      thumbProjectId: (raw['thumbProjectId'] as num?)?.toInt(),
    );
  }

  UnrealLibraryEntry copyWith({
    UnrealAssetRef? ref,
    bool? favorite,
    DateTime? lastUsed,
    int? thumbProjectId,
  }) => UnrealLibraryEntry(
    ref: ref ?? this.ref,
    favorite: favorite ?? this.favorite,
    lastUsed: lastUsed ?? this.lastUsed,
    thumbProjectId: thumbProjectId ?? this.thumbProjectId,
  );
}

/// La biblioteca de assets de Unreal (F6.20 B5): todo asset usado o
/// encontrado, con su miniatura, origen y medidas. Se busca sin Unreal, y
/// viaja con los ajustes del usuario (`user_settings`), así que se ve en el
/// Mac y el iPad.
class UnrealLibrary extends ChangeNotifier {
  UnrealLibrary();

  static final instance = UnrealLibrary();

  static const prefsKey = 'iris_unreal_library';

  final _byPath = <String, UnrealLibraryEntry>{};

  /// Lo quitado, con la fecha: viaja con la biblioteca para que otro equipo
  /// no lo vuelva a traer (salvo que alguien lo use después).
  final _removed = <String, DateTime>{};
  bool _loaded = false;

  /// Favoritos primero; luego lo último usado.
  List<UnrealLibraryEntry> get entries {
    final list = _byPath.values.toList()
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return b.lastUsed.compareTo(a.lastUsed);
      });
    return list;
  }

  UnrealLibraryEntry? entryOf(String path) => _byPath[path];

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    importJson(prefs.getString(prefsKey), notify: false);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, encode());
  }

  String encode() => jsonEncode({
    'entries': [for (final e in entries) e.toJson()],
    'removed': {
      for (final MapEntry(:key, :value) in _removed.entries)
        key: value.toUtc().toIso8601String(),
    },
  });

  /// Junta lo que llega (de otro equipo) con lo de aquí: por ruta, se queda
  /// lo último usado, favorito si lo es en alguno, y las miniaturas que
  /// haya.
  void importJson(String? json, {bool notify = true}) {
    if (json == null || json.isEmpty) return;
    final Object? raw;
    try {
      raw = jsonDecode(json);
    } catch (_) {
      return;
    }
    // Antes era solo la lista; ahora {entries, removed}.
    final items = raw is List
        ? raw
        : raw is Map
        ? (raw['entries'] as List? ?? const [])
        : const [];
    if (raw is Map && raw['removed'] is Map) {
      for (final MapEntry(:key, :value) in (raw['removed'] as Map).entries) {
        final at = DateTime.tryParse('$value');
        if (at == null) continue;
        final mine = _removed['$key'];
        if (mine == null || at.isAfter(mine)) _removed['$key'] = at;
      }
    }
    for (final item in items) {
      final e = UnrealLibraryEntry.fromJson(item);
      if (e != null) _merge(e);
    }
    // Lo quitado no vuelve, salvo que se haya usado después de quitarlo.
    _byPath.removeWhere((path, e) {
      final at = _removed[path];
      return at != null && !e.lastUsed.isAfter(at);
    });
    if (notify) notifyListeners();
  }

  void _merge(UnrealLibraryEntry incoming) {
    final mine = _byPath[incoming.ref.path];
    if (mine == null) {
      _byPath[incoming.ref.path] = incoming;
      return;
    }
    final newer = incoming.lastUsed.isAfter(mine.lastUsed) ? incoming : mine;
    final other = identical(newer, incoming) ? mine : incoming;
    _byPath[incoming.ref.path] = newer.copyWith(
      favorite: mine.favorite || incoming.favorite,
      ref: newer.ref.thumb34 != null
          ? newer.ref
          : newer.ref.copyWith(
              thumbTop: other.ref.thumbTop,
              thumb34: other.ref.thumb34,
              topSpanCm: other.ref.topSpanCm,
            ),
      thumbProjectId: newer.thumbProjectId ?? other.thumbProjectId,
    );
  }

  /// Un asset que se acaba de usar (asignado a un elemento o con
  /// miniaturas nuevas).
  Future<void> remember(UnrealAssetRef ref, {int? projectId}) async {
    await load();
    final old = _byPath[ref.path];
    // Usarlo de nuevo lo devuelve a la biblioteca.
    _removed.remove(ref.path);
    final hasThumbs = ref.thumb34 != null;
    _byPath[ref.path] = UnrealLibraryEntry(
      ref: hasThumbs || old == null
          ? ref
          : ref.copyWith(
              thumbTop: old.ref.thumbTop,
              thumb34: old.ref.thumb34,
              topSpanCm: old.ref.topSpanCm,
            ),
      favorite: old?.favorite ?? false,
      lastUsed: DateTime.now().toUtc(),
      thumbProjectId: hasThumbs ? projectId : old?.thumbProjectId ?? projectId,
    );
    await _save();
  }

  /// Lo encontrado en Unreal: entra sin pisar lo que ya había.
  Future<int> addFound(Iterable<UnrealAssetRef> found) async {
    await load();
    var added = 0;
    for (final ref in found) {
      // Lo que se quitó a propósito no vuelve con una búsqueda.
      if (_byPath.containsKey(ref.path) || _removed.containsKey(ref.path)) {
        continue;
      }
      _byPath[ref.path] = UnrealLibraryEntry(
        ref: ref,
        lastUsed: DateTime.fromMillisecondsSinceEpoch(0),
      );
      added++;
    }
    if (added > 0) await _save();
    return added;
  }

  Future<void> toggleFavorite(String path) async {
    final e = _byPath[path];
    if (e == null) return;
    _byPath[path] = e.copyWith(favorite: !e.favorite);
    await _save();
  }

  Future<void> remove(String path) async {
    if (_byPath.remove(path) == null) return;
    _removed[path] = DateTime.now().toUtc();
    await _save();
  }

  /// Lo que contiene todas las palabras de [query] (nombre, ruta, origen o
  /// clase), sin Unreal.
  List<UnrealLibraryEntry> search(String query, {bool favoritesOnly = false}) {
    final words = query.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    return [
      for (final e in entries)
        if (!favoritesOnly || e.favorite)
          if (words.every(
            [
              e.ref.name,
              e.ref.path,
              e.ref.source.label,
              e.ref.kind.name,
            ].join(' ').toLowerCase().contains,
          ))
            e,
    ];
  }

  @visibleForTesting
  void clearForTest() {
    _byPath.clear();
    _removed.clear();
    _loaded = true;
  }

  /// El elemento de la planta que hace de [ref] al ponerlo desde la
  /// biblioteca: un actor si es un personaje; si no, una pieza de atrezzo
  /// del tipo que dice su nombre (sofá, silla, mesa…), con sus medidas.
  static PlanElement elementFor(UnrealAssetRef ref, {Offset at = Offset.zero}) {
    final name = prettyName(ref.name);
    if (ref.kind == UnrealAssetKind.skeletal ||
        ref.kind == UnrealAssetKind.metahuman) {
      final el = PlanElement(
        id: 0,
        type: ElementType.actor,
        position: at,
        label: name.toUpperCase(),
      );
      UnrealAssetRef.set(el, ref);
      return el;
    }
    final type = propTypeFor(ref.name);
    final el = PlanElement(
      id: 0,
      type: ElementType.prop,
      position: at,
      label: type.dbValue,
    )..customName = name;
    final s = ref.sizeCm;
    if (s != null && s.every((v) => v > 0)) {
      el.props[LightScene.sizeKey] = math.max(s[0], s[1]).roundToDouble() / 100;
      el.props[LightScene.heightKey] = s[2].roundToDouble() / 100;
    }
    UnrealAssetRef.set(el, ref);
    return el;
  }

  /// `SM_Sofa_Velvet_01` → `Sofa Velvet 01`.
  static String prettyName(String name) => name
      .replaceFirst(RegExp(r'^(SM|SK|BP|S|M|T)_', caseSensitive: false), '')
      .replaceAll('_', ' ')
      .trim();

  /// El tipo de atrezzo que dice el nombre del asset.
  static PropType propTypeFor(String name) {
    final n = name.toLowerCase();
    bool has(List<String> words) => words.any(n.contains);
    if (has(['sofa', 'couch', 'settee', 'sillon', 'sofá'])) {
      return PropType.sofa;
    }
    if (has(['chair', 'stool', 'silla', 'taburete', 'bench'])) {
      return PropType.chair;
    }
    if (has(['table', 'desk', 'mesa', 'counter'])) return PropType.table;
    if (has(['bed', 'cama', 'mattress'])) return PropType.bed;
    if (has(['car', 'vehicle', 'truck', 'van', 'bus', 'coche', 'moto'])) {
      return PropType.vehicle;
    }
    if (has(['tree', 'pine', 'oak', 'palm', 'arbol', 'árbol', 'bush'])) {
      return PropType.tree;
    }
    if (has(['rock', 'stone', 'boulder', 'roca', 'piedra'])) {
      return PropType.rock;
    }
    return PropType.rectangle;
  }
}

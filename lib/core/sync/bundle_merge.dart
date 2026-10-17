import 'dart:convert';

/// De qué lado venía una edición.
enum MergeSide { local, cloud }

/// Lo que la mezcla descartó: el mismo dato cambió en los dos lados (o en
/// uno se borró y en el otro se editó) y ganó la edición más reciente.
class MergeDiscard {
  /// Nombre de la colección (`scenes`, `shots`…) o del bloque (`biblia`…).
  final String collection;
  final String? uid;
  final String? label;

  /// `null`: se decidió el elemento o el bloque entero.
  final String? field;
  final Object? kept;
  final Object? discarded;

  /// `null`: se fue en cascada con su padre, borrado en el otro lado.
  final MergeSide? discardedSide;

  const MergeDiscard({
    required this.collection,
    this.uid,
    this.label,
    this.field,
    this.kept,
    this.discarded,
    this.discardedSide,
  });
}

class BundleMergeResult {
  final Map<String, dynamic> merged;
  final List<MergeDiscard> discards;

  const BundleMergeResult(this.merged, this.discards);
}

/// Mezcla a tres bandas del contenido de un proyecto: la base (lo último en
/// que coincidieron este equipo y la nube), lo de aquí y lo de la nube.
///
/// - Escenas, planos, referencias, localizaciones, sets, esquemas de luz y
///   sus imágenes se mezclan elemento a elemento por uid, y campo a campo.
/// - El resto va en bloques que se enlazan por ids locales entre sí (biblia,
///   documentos de rodaje, plantas, equipo, dibujos…): gana el lado que
///   cambió; si cambiaron los dos, el más reciente.
/// - Si el mismo campo cambió en los dos lados gana [newer] y lo otro queda
///   en [BundleMergeResult.discards].
///
/// Las referencias entre colecciones viajan por claves que dependen de
/// números y nombres (`scene:3`, `shot:3:2`…): antes de mezclar se pasan a
/// uid y después se vuelven a poner con las claves del resultado, para que
/// renumerar en un lado no deje colgado lo añadido en el otro.
abstract final class BundleMerge {
  static const elementCollections = [
    'locationSites',
    'siteImages',
    'locationBasePlans',
    'lightSetups',
    'locationImages',
    'scenes',
    'shots',
    'shotReferences',
  ];

  /// La clave propia de cada colección a la que otras apuntan.
  static const selfKeys = {
    'locationSites': 'siteKey',
    'locationBasePlans': 'setKey',
    'lightSetups': 'lightSetupKey',
    'scenes': 'sceneKey',
    'shots': 'shotKey',
  };

  /// Campo de referencia → colección a la que apunta.
  static const refParents = {
    'siteKey': 'locationSites',
    'locationSiteKey': 'locationSites',
    'setKey': 'locationBasePlans',
    'shotSetKey': 'locationBasePlans',
    'locationSetKey': 'locationBasePlans',
    'lightSetupKey': 'lightSetups',
    'planSetupKey': 'lightSetups',
    'sceneKey': 'scenes',
    'shotKey': 'shots',
  };

  static const _routeRefs = ['siteKey', 'setKey', 'lightSetupKey'];

  static const _annotationTargets = {
    'camera_plan_site': 'locationSites',
    'camera_plan_set': 'locationBasePlans',
    'camera_plan_shot': 'shots',
    'camera_plan_light_setup': 'lightSetups',
  };

  /// Sin esta referencia el elemento no tiene adónde volver: si su padre se
  /// borró en el otro lado, se va con él.
  static const _requiredRefs = {
    'shots': 'sceneKey',
    'shotReferences': 'shotKey',
    'siteImages': 'siteKey',
    'locationImages': 'setKey',
  };

  /// Bloques que se deciden enteros. Lo que no esté aquí ni en
  /// [elementCollections] (colecciones futuras) va en un bloque propio.
  static const blocks = {
    'biblia': [
      'moodboardGroups',
      'moodboardImages',
      'lookBibles',
      'visualBibles',
      'visualBibleVersions',
      'visualBibleColorBlocks',
      'visualBibleLocationRefs',
      'bibleSectionGroups',
      'bibleSectionDefinitions',
      'bibleComments',
      'exposureBlocks',
      'lightingSetups',
      'cameraTests',
      'visualBibleDocuments',
      'visualBibleNarrativeCards',
      'bibleSectionEvidence',
    ],
    'documentos de rodaje': ['shootDocuments', 'shootDocumentBlocks'],
    'plantas de cámara': ['cameraPlanElements', 'cameraPathPoints'],
    'equipo': ['projectEquipment'],
    'dibujos': ['projectAnnotatedPdfs', 'projectAnnotationDocuments'],
    'laboratorio óptico': ['opticsLabSamples'],
  };

  /// Campos del proyecto que van con un bloque (el catálogo del moodboard
  /// enlaza imágenes de la biblia).
  static const _blockProjectFields = {'moodboardCatalogJson': 'biblia'};

  static const _metaKeys = {'version', 'exportedAt', 'summary'};

  static const _linkPrefix = '@uid:';

  /// [baseLocal] es lo que este equipo exportó en la última sincronización y
  /// [baseCloud] lo que tenía la nube entonces: el mismo contenido, pero cada
  /// uno con los ids locales de su equipo (biblia, stills, dibujos…). Cada
  /// lado se compara con su base para saber qué cambió.
  static BundleMergeResult merge({
    required Map<String, dynamic> baseLocal,
    required Map<String, dynamic> baseCloud,
    required Map<String, dynamic> local,
    required Map<String, dynamic> cloud,
    required MergeSide newer,
  }) {
    final bl = _link(baseLocal);
    final bc = _link(baseCloud);
    final l = _link(local);
    final c = _link(cloud);
    final discards = <MergeDiscard>[];
    final out = <String, dynamic>{
      for (final k in _metaKeys)
        if (local.containsKey(k)) k: _copy(local[k]),
    };

    final allKeys = {...bl.keys, ...bc.keys, ...l.keys, ...c.keys}
      ..removeAll(_metaKeys);
    final listKeys = {
      for (final k in allKeys)
        if (l[k] is List || c[k] is List || bl[k] is List || bc[k] is List) k,
    };

    // Elemento a elemento, si todos sus elementos tienen uid.
    final elementWise = <String>{
      for (final k in elementCollections)
        if (listKeys.contains(k) &&
            [bl, bc, l, c].every((x) => _allHaveUid(x[k])))
          k,
    };
    for (final k in elementWise) {
      out[k] = _mergeElements(k, bl[k], bc[k], l[k], c[k], newer, discards);
    }

    // Bloques: los conocidos y una colección suelta por cada desconocida.
    final grouped = <String, List<String>>{
      for (final e in blocks.entries)
        e.key: [
          for (final k in e.value)
            if (listKeys.contains(k)) k,
        ],
    };
    for (final k in listKeys) {
      if (elementWise.contains(k)) continue;
      if (blocks.values.any((v) => v.contains(k))) continue;
      grouped[k] = [k];
    }
    final pfBl = _map(bl['projectFields']);
    final pfBc = _map(bc['projectFields']);
    final pfL = _map(l['projectFields']);
    final pfC = _map(c['projectFields']);
    final pfOut = <String, dynamic>{};
    for (final e in grouped.entries) {
      final fields = [
        for (final f in _blockProjectFields.entries)
          if (f.value == e.key) f.key,
      ];
      if (e.value.isEmpty && fields.isEmpty) continue;
      Map<String, dynamic> blob(
        Map<String, dynamic> side,
        Map<String, dynamic> pf,
      ) => {
        for (final k in e.value) k: side[k] ?? <dynamic>[],
        for (final f in fields)
          if (pf.containsKey(f)) 'projectFields.$f': pf[f],
      };
      final chosen = _pickBlock(
        e.key,
        blob(bl, pfBl),
        blob(bc, pfBc),
        blob(l, pfL),
        blob(c, pfC),
        newer,
        discards,
      );
      for (final k in e.value) {
        out[k] = chosen[k];
      }
      for (final f in fields) {
        if (chosen.containsKey('projectFields.$f')) {
          pfOut[f] = chosen['projectFields.$f'];
        }
      }
    }

    // Campos del proyecto: uno a uno.
    Map<String, dynamic> only(Map<String, dynamic> pf) => {
      for (final e in pf.entries)
        if (!_blockProjectFields.containsKey(e.key)) e.key: e.value,
    };
    pfOut.addAll(
      _mergeFields(
        'proyecto',
        null,
        'Proyecto',
        only(pfBl),
        only(pfBc),
        only(pfL),
        only(pfC),
        newer,
        discards,
      ),
    );
    out['projectFields'] = pfOut;

    // Otras claves sueltas que no son listas: como un bloque cada una.
    for (final k in allKeys) {
      if (listKeys.contains(k) || k == 'projectFields') continue;
      final chosen = _pickBlock(
        k,
        {k: bl[k]},
        {k: bc[k]},
        {k: l[k]},
        {k: c[k]},
        newer,
        discards,
      );
      if (chosen[k] != null) out[k] = chosen[k];
    }

    _unlink(out, [bl, bc], discards);
    return BundleMergeResult(out, discards);
  }

  // ---------------------------------------------------------------------
  // Elementos

  static List<Map<String, dynamic>> _mergeElements(
    String collection,
    Object? baseLocalList,
    Object? baseCloudList,
    Object? localList,
    Object? cloudList,
    MergeSide newer,
    List<MergeDiscard> discards,
  ) {
    final blBy = _byUid(baseLocalList);
    final bcBy = _byUid(baseCloudList);
    final lBy = _byUid(localList);
    final cBy = _byUid(cloudList);
    // El orden de aquí, y detrás lo nuevo de la nube.
    final order = [
      ...lBy.keys,
      for (final u in cBy.keys)
        if (!lBy.containsKey(u)) u,
    ];
    final out = <Map<String, dynamic>>[];
    for (final uid in order) {
      final blRec = blBy[uid] ?? bcBy[uid];
      final bcRec = bcBy[uid] ?? blBy[uid];
      final lRec = lBy[uid];
      final cRec = cBy[uid];
      if (blRec == null || bcRec == null) {
        // Añadido en un lado (o, raro, en los dos con el mismo uid).
        if (lRec != null && cRec != null) {
          out.add(_mergeFields(
            collection,
            uid,
            _label(collection, lRec),
            const {},
            const {},
            lRec,
            cRec,
            newer,
            discards,
          ));
        } else {
          out.add(lRec ?? cRec!);
        }
        continue;
      }
      if (lRec == null || cRec == null) {
        // Borrado en un lado. Si el otro no lo tocó, se borra; si lo editó,
        // gana lo más reciente.
        final keptSide = lRec != null ? MergeSide.local : MergeSide.cloud;
        final kept = lRec ?? cRec!;
        if (_same(kept, keptSide == MergeSide.local ? blRec : bcRec)) continue;
        if (newer == keptSide) {
          out.add(kept);
          discards.add(MergeDiscard(
            collection: collection,
            uid: uid,
            label: _label(collection, kept),
            kept: kept,
            discarded: null,
            discardedSide: _other(keptSide),
          ));
        } else {
          discards.add(MergeDiscard(
            collection: collection,
            uid: uid,
            label: _label(collection, kept),
            kept: null,
            discarded: kept,
            discardedSide: keptSide,
          ));
        }
        continue;
      }
      out.add(_mergeFields(
        collection,
        uid,
        _label(collection, lRec),
        blRec,
        bcRec,
        lRec,
        cRec,
        newer,
        discards,
      ));
    }
    return out;
  }

  static Map<String, dynamic> _mergeFields(
    String collection,
    String? uid,
    String? label,
    Map<String, dynamic> bl,
    Map<String, dynamic> bc,
    Map<String, dynamic> l,
    Map<String, dynamic> c,
    MergeSide newer,
    List<MergeDiscard> discards,
  ) {
    final out = <String, dynamic>{};
    final hasLocal = l.isNotEmpty;
    for (final k in {...l.keys, ...c.keys}) {
      final MergeSide from;
      if (_isPathKey(k)) {
        // Las rutas son de cada equipo (y no cuentan en la huella): la de
        // aquí; los archivos nuevos de la nube los baja el hidratado.
        from = hasLocal && l.containsKey(k) ? MergeSide.local : MergeSide.cloud;
      } else {
        final vl = l[k], vc = c[k];
        final changedHere = !_eq(vl, bl[k]);
        final changedThere = !_eq(vc, bc[k]);
        if (changedThere && !changedHere) {
          from = MergeSide.cloud;
        } else if (!changedThere || _eq(vl, vc)) {
          from = l.containsKey(k) || !c.containsKey(k)
              ? MergeSide.local
              : MergeSide.cloud;
        } else {
          from = newer;
          discards.add(MergeDiscard(
            collection: collection,
            uid: uid,
            label: label,
            field: k,
            kept: newer == MergeSide.local ? vl : vc,
            discarded: newer == MergeSide.local ? vc : vl,
            discardedSide: _other(newer),
          ));
        }
      }
      final src = from == MergeSide.local ? l : c;
      if (src.containsKey(k)) out[k] = _copy(src[k]);
    }
    return out;
  }

  // ---------------------------------------------------------------------
  // Bloques

  static Map<String, dynamic> _pickBlock(
    String name,
    Map<String, dynamic> bl,
    Map<String, dynamic> bc,
    Map<String, dynamic> l,
    Map<String, dynamic> c,
    MergeSide newer,
    List<MergeDiscard> discards,
  ) {
    final changedHere = _canon(_comparable(l)) != _canon(_comparable(bl));
    final changedThere = _canon(_comparable(c)) != _canon(_comparable(bc));
    if (!changedThere) return l;
    if (!changedHere) return c;
    discards.add(MergeDiscard(
      collection: name,
      label: name,
      kept: newer == MergeSide.local ? l : c,
      discarded: newer == MergeSide.local ? c : l,
      discardedSide: _other(newer),
    ));
    return newer == MergeSide.local ? l : c;
  }

  // ---------------------------------------------------------------------
  // Referencias: claves → uid y vuelta

  static Map<String, dynamic> _link(Map<String, dynamic> bundle) {
    final b = _copy(bundle) as Map<String, dynamic>;
    final keyToUid = <String, Map<String, String>>{};
    for (final e in selfKeys.entries) {
      final map = keyToUid[e.key] = {};
      for (final rec in _records(b[e.key])) {
        final key = rec[e.value];
        final uid = rec['uid'];
        if (key is String && uid is String) map[key] = uid;
      }
    }
    Object? link(String parent, Object? v) {
      if (v is! String) return v;
      final uid = keyToUid[parent]?[v];
      return uid == null ? v : '$_linkPrefix$uid';
    }

    for (final entry in b.entries) {
      final collection = entry.key;
      for (final rec in _records(entry.value)) {
        for (final ref in refParents.entries) {
          if (selfKeys[collection] == ref.key) continue;
          if (rec.containsKey(ref.key)) {
            rec[ref.key] = link(ref.value, rec[ref.key]);
          }
        }
        final route = rec['route'];
        if (route is List) {
          for (final leg in route.whereType<Map>()) {
            for (final f in _routeRefs) {
              if (leg.containsKey(f)) leg[f] = link(refParents[f]!, leg[f]);
            }
          }
        }
        if (collection == 'projectAnnotationDocuments') {
          final parent = _annotationTargets[rec['targetType']];
          if (parent != null) rec['targetKey'] = link(parent, rec['targetKey']);
        }
      }
    }
    return b;
  }

  static void _unlink(
    Map<String, dynamic> out,
    List<Map<String, dynamic>> bases,
    List<MergeDiscard> discards,
  ) {
    String? linkedUid(Object? v) =>
        v is String && v.startsWith(_linkPrefix)
            ? v.substring(_linkPrefix.length)
            : null;

    // Lo que se queda sin padre (borrado en el otro lado) se va con él; en
    // cascada: un plano que se va se lleva sus referencias.
    var changed = true;
    while (changed) {
      changed = false;
      final present = {
        for (final p in selfKeys.keys)
          p: {for (final r in _records(out[p])) r['uid']},
      };
      bool dangles(String parent, Object? v) {
        final uid = linkedUid(v);
        return uid != null && !present[parent]!.contains(uid);
      }

      for (final e in _requiredRefs.entries) {
        final list = out[e.key];
        if (list is! List) continue;
        final parent = refParents[e.value]!;
        final before = list.length;
        list.removeWhere((r) {
          if (r is! Map || !dangles(parent, r[e.value])) return false;
          // Si no se había tocado desde la base, es un borrado normal.
          final rec = Map<String, dynamic>.from(r);
          final untouched = bases.any((base) {
            final before = _byUid(base[e.key])[r['uid']];
            return before != null && _same(before, rec);
          });
          // Lo que se anotó al mezclarlo (p. ej. «se queda») ya no vale.
          discards.removeWhere(
            (d) => d.collection == e.key && d.uid == r['uid'],
          );
          if (!untouched) {
            discards.add(MergeDiscard(
              collection: e.key,
              uid: r['uid'] as String?,
              label: _label(e.key, rec),
              discarded: r,
            ));
          }
          return true;
        });
        if (list.length != before) changed = true;
      }
      final docs = out['projectAnnotationDocuments'];
      if (docs is List) {
        docs.removeWhere((d) {
          if (d is! Map) return false;
          final parent = _annotationTargets[d['targetType']];
          return parent != null && dangles(parent, d['targetKey']);
        });
      }
    }

    // Claves propias únicas: dos elementos nuevos de lados distintos pueden
    // coincidir (p. ej. el plano 3/4 añadido en los dos).
    final uidToKey = <String, Map<String, String>>{};
    for (final e in selfKeys.entries) {
      final seen = <String>{};
      final map = uidToKey[e.key] = {};
      for (final rec in _records(out[e.key])) {
        var key = rec[e.value];
        if (key is! String) continue;
        if (seen.contains(key)) {
          var n = 2;
          while (seen.contains('$key~$n')) {
            n++;
          }
          key = '$key~$n';
          rec[e.value] = key;
        }
        seen.add(key);
        final uid = rec['uid'];
        if (uid is String) map[uid] = key;
      }
    }

    Object? unlink(String parent, Object? v) {
      final uid = linkedUid(v);
      if (uid == null) return v;
      return uidToKey[parent]?[uid];
    }

    for (final entry in out.entries) {
      final collection = entry.key;
      for (final rec in _records(entry.value)) {
        for (final ref in refParents.entries) {
          if (selfKeys[collection] == ref.key) continue;
          if (rec.containsKey(ref.key)) {
            rec[ref.key] = unlink(ref.value, rec[ref.key]);
          }
        }
        final route = rec['route'];
        if (route is List) {
          for (final leg in route.whereType<Map>()) {
            for (final f in _routeRefs) {
              if (leg.containsKey(f)) leg[f] = unlink(refParents[f]!, leg[f]);
            }
          }
        }
        if (collection == 'projectAnnotationDocuments') {
          final parent = _annotationTargets[rec['targetType']];
          if (parent != null) {
            rec['targetKey'] = unlink(parent, rec['targetKey']);
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------
  // Utilidades

  static Iterable<Map<String, dynamic>> _records(Object? list) sync* {
    if (list is! List) return;
    for (final r in list) {
      if (r is Map<String, dynamic>) yield r;
    }
  }

  static bool _allHaveUid(Object? list) {
    if (list == null) return true;
    if (list is! List) return false;
    final seen = <String>{};
    for (final r in list) {
      if (r is! Map) return false;
      final uid = r['uid'];
      if (uid is! String || uid.isEmpty || !seen.add(uid)) return false;
    }
    return true;
  }

  static Map<String, Map<String, dynamic>> _byUid(Object? list) => {
    for (final r in _records(list)) r['uid'] as String: r,
  };

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static MergeSide _other(MergeSide s) =>
      s == MergeSide.local ? MergeSide.cloud : MergeSide.local;

  static bool _isPathKey(String k) => k.endsWith('Path') || k.endsWith('Paths');

  /// Para comparar, como la huella: sin rutas, que son de cada equipo.
  static Object? _comparable(Object? v) {
    if (v is Map) {
      return {
        for (final e in v.entries)
          if (!(e.key is String && _isPathKey(e.key as String)))
            e.key: _comparable(e.value),
      };
    }
    if (v is List) return [for (final e in v) _comparable(e)];
    return v;
  }

  static bool _same(Map<String, dynamic> a, Map<String, dynamic> b) =>
      _canon(_comparable(a)) == _canon(_comparable(b));

  static bool _eq(Object? a, Object? b) => _canon(a) == _canon(b);

  static String _canon(Object? v) => jsonEncode(_sorted(v));

  static Object? _sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return {for (final k in keys) k: _sorted(v[k])};
    }
    if (v is List) return [for (final e in v) _sorted(e)];
    return v;
  }

  static Object? _copy(Object? v) {
    if (v is Map) {
      return <String, dynamic>{
        for (final e in v.entries) '${e.key}': _copy(e.value),
      };
    }
    if (v is List) return [for (final e in v) _copy(e)];
    return v;
  }

  /// Cómo se llama el elemento en el historial.
  static String? _label(String collection, Map<String, dynamic> rec) {
    String? key(String field) {
      final v = rec[field];
      return v is String && !v.startsWith(_linkPrefix) ? v : null;
    }

    switch (collection) {
      case 'scenes':
        final name = rec['name'];
        return 'Escena ${rec['number']}${name is String ? ' · $name' : ''}';
      case 'shots':
        final parts = key('shotKey')?.split(':');
        return parts != null && parts.length >= 3
            ? 'Plano ${parts[1]}/${parts[2]}'
            : 'Plano ${rec['number']}';
      case 'shotReferences':
        return 'Referencia de plano';
      case 'locationSites':
        return 'Localización ${rec['name'] ?? ''}'.trim();
      case 'locationBasePlans':
        return 'Set ${rec['locationName'] ?? ''}'.trim();
      case 'lightSetups':
        return 'Esquema de luz ${rec['name'] ?? ''}'.trim();
      case 'siteImages':
      case 'locationImages':
        return 'Imagen de localización';
    }
    return rec['name'] as String? ?? rec['uid'] as String?;
  }
}

import 'dart:convert';

import 'bundle_merge.dart';
import 'project_content_bundle.dart';

/// Una cosa del proyecto que cambió entre dos paquetes: un plano, una
/// escena, un set… o un bloque entero (la biblia, el equipo).
class ContentChange {
  const ContentChange({
    required this.collection,
    required this.uid,
    required this.action,
    this.label,
    this.fields = const [],
  });

  /// `shots`, `scenes`… o el nombre del bloque (`biblia`, `equipo`…).
  final String collection;

  /// El uid del elemento, o el nombre del bloque.
  final String uid;
  final String? label;

  /// `added`, `edited` o `removed` (como en `project_activity`, 021).
  final String action;

  /// Qué partes cambiaron, en palabras («planta», «óptica»…).
  final List<String> fields;

  Map<String, dynamic> toRow() => {
    'collection': collection,
    'uid': uid,
    'label': label,
    'action': action,
    'fields': fields,
  };

  @override
  String toString() => '$action $collection $uid $fields';
}

/// Qué cambió de [base] a [current]: lo que anota la autoría al subir.
///
/// Escenas, planos, sets, localizaciones y esquemas de luz se comparan por
/// uid y campo a campo. La planta de cámara no tiene uid por elemento: se
/// atribuye al plano al que pertenece. El resto (biblia, equipo, dibujos…)
/// se anota por bloque.
abstract final class BundleChanges {
  /// Colecciones que se comparan elemento a elemento.
  static const _elementCollections = [
    'scenes',
    'shots',
    'locationSites',
    'locationBasePlans',
    'setGroups',
    'lightSetups',
    'shootDocuments',
    'rentalReservations',
  ];

  /// Colecciones hijas que cuentan como un campo de su padre.
  static const _childCollections = {
    'shotReferences': ('shots', 'shotKey', 'referencias'),
    'siteImages': ('locationSites', 'siteKey', 'imágenes'),
    'locationImages': ('locationBasePlans', 'setKey', 'imágenes'),
    'shootDocumentBlocks': ('shootDocuments', 'documentKey', 'contenido'),
  };

  /// Campos que no dicen nada a quien lee la actividad.
  static const _ignored = {
    'uid',
    'sortOrder',
    'mediaKey',
    'shotKey',
    'sceneKey',
    'siteKey',
    'setKey',
    'documentKey',
    'scriptAnchorIndex',
    'scriptTextHash',
    'sourceStartIndex',
    'scriptHeadingKey',
  };

  static const _fieldNames = {
    'name': 'nombre',
    'number': 'número',
    'numberSuffix': 'número',
    'description': 'descripción',
    'notes': 'notas',
    'notesHighlight': 'notas',
    'lens': 'óptica',
    'fStop': 'diafragma',
    'fps': 'fps',
    'shutterAngle': 'obturación',
    'framing': 'encuadre',
    'angle': 'ángulo',
    'movement': 'movimiento',
    'durationSeconds': 'duración',
    'durationMinutes': 'duración',
    'storyboardImagePath': 'storyboard',
    'referenceImagePath': 'referencias',
    'primaryReferenceUid': 'referencias',
    'cameraPlanImagePath': 'planta',
    'planViewJson': 'planta',
    'lightOverridesJson': 'luces del plano',
    'lightSetupKey': 'esquema de luz',
    'shotSetKey': 'set',
    'shootOrder': 'orden de rodaje',
    'actionText': 'acción',
    'intExt': 'cabecera',
    'dayNight': 'cabecera',
    'charactersJson': 'personajes',
    'route': 'ruta',
    'coverImage': 'imagen',
    'locationColor': 'color',
  };

  static List<ContentChange> between(
    Map<String, dynamic> base,
    Map<String, dynamic> current,
  ) {
    final changes = <String, ContentChange>{};
    String id(String collection, String uid) => '$collection/$uid';

    void add(ContentChange c) {
      final key = id(c.collection, c.uid);
      final prev = changes[key];
      if (prev == null) {
        changes[key] = c;
        return;
      }
      // Un añadido o borrado manda sobre una edición; los campos se juntan.
      changes[key] = ContentChange(
        collection: c.collection,
        uid: c.uid,
        label: prev.label ?? c.label,
        action: prev.action == 'edited' ? c.action : prev.action,
        fields: {...prev.fields, ...c.fields}.toList(),
      );
    }

    // Elementos con uid.
    for (final collection in _elementCollections) {
      final before = _byUid(base[collection]);
      final after = _byUid(current[collection]);
      if (before == null || after == null) continue;
      for (final entry in after.entries) {
        final old = before[entry.key];
        final label = _label(collection, entry.value);
        if (old == null) {
          add(
            ContentChange(
              collection: collection,
              uid: entry.key,
              label: label,
              action: 'added',
            ),
          );
          continue;
        }
        final fields = _changedFields(old, entry.value);
        if (fields.isNotEmpty) {
          add(
            ContentChange(
              collection: collection,
              uid: entry.key,
              label: label,
              action: 'edited',
              fields: fields,
            ),
          );
        }
      }
      for (final entry in before.entries) {
        if (after.containsKey(entry.key)) continue;
        add(
          ContentChange(
            collection: collection,
            uid: entry.key,
            label: _label(collection, entry.value),
            action: 'removed',
          ),
        );
      }
    }

    // Hijas: un cambio en ellas es un cambio de su padre.
    for (final MapEntry(key: child, value: spec) in _childCollections.entries) {
      final (parent, refKey, field) = spec;
      final parentUids = {
        ..._keyToUid(base[parent], BundleMerge.selfKeys[parent]),
        ..._keyToUid(current[parent], BundleMerge.selfKeys[parent]),
      };
      final before = _groupBy(base[child], refKey);
      final after = _groupBy(current[child], refKey);
      for (final key in {...before.keys, ...after.keys}) {
        if (before[key] == after[key]) continue;
        final uid = parentUids[key];
        if (uid == null) continue;
        if (_isNewOrGone(changes, parent, uid)) continue;
        add(
          ContentChange(
            collection: parent,
            uid: uid,
            label: _labelOf(base, current, parent, uid),
            action: 'edited',
            fields: [field],
          ),
        );
      }
    }

    // La planta de cámara, por plano.
    final shotUids = {
      ..._keyToUid(base['shots'], 'shotKey'),
      ..._keyToUid(current['shots'], 'shotKey'),
    };
    final planBefore = _planByShot(base);
    final planAfter = _planByShot(current);
    for (final shotKey in {...planBefore.keys, ...planAfter.keys}) {
      if (planBefore[shotKey] == planAfter[shotKey]) continue;
      final uid = shotUids[shotKey];
      if (uid == null || _isNewOrGone(changes, 'shots', uid)) continue;
      add(
        ContentChange(
          collection: 'shots',
          uid: uid,
          label: _labelOf(base, current, 'shots', uid),
          action: 'edited',
          fields: const ['planta'],
        ),
      );
    }

    // Bloques sin uid por elemento.
    for (final MapEntry(key: block, value: collections)
        in BundleMerge.blocks.entries) {
      if (block == 'plantas de cámara' || block == 'documentos de rodaje') {
        continue;
      }
      final a = _canon([for (final c in collections) base[c]]);
      final b = _canon([for (final c in collections) current[c]]);
      if (a != b) {
        add(
          ContentChange(
            collection: block,
            uid: block,
            label: block[0].toUpperCase() + block.substring(1),
            action: 'edited',
          ),
        );
      }
    }

    return changes.values.toList();
  }

  static bool _isNewOrGone(
    Map<String, ContentChange> changes,
    String collection,
    String uid,
  ) {
    final c = changes['$collection/$uid'];
    return c != null && c.action != 'edited';
  }

  static List<String> _changedFields(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final out = <String>{};
    for (final key in {...a.keys, ...b.keys}) {
      if (_ignored.contains(key)) continue;
      if (_canon(a[key]) == _canon(b[key])) continue;
      final name = _fieldNames[key];
      if (name != null) {
        out.add(name);
      } else if (ProjectContentBundle.isPathKey(key)) {
        out.add('imagen');
      } else {
        out.add('otros datos');
      }
    }
    return out.toList();
  }

  static Map<String, Map<String, dynamic>>? _byUid(Object? list) {
    if (list is! List) return null;
    final out = <String, Map<String, dynamic>>{};
    for (final r in list) {
      if (r is! Map) continue;
      final uid = r['uid'];
      // Sin uid no se puede seguir: esa colección no se compara.
      if (uid is! String || uid.isEmpty) return null;
      out[uid] = Map<String, dynamic>.from(r);
    }
    return out;
  }

  static Map<String, String> _keyToUid(Object? list, String? keyField) {
    if (list is! List || keyField == null) return const {};
    return {
      for (final r in list)
        if (r is Map && r[keyField] is String && r['uid'] is String)
          r[keyField] as String: r['uid'] as String,
    };
  }

  /// Lo de cada padre, en un texto comparable (sin importar el orden).
  static Map<String, String> _groupBy(Object? list, String refKey) {
    final groups = <String, List<String>>{};
    if (list is List) {
      for (final r in list) {
        if (r is! Map) continue;
        final key = r[refKey];
        if (key is! String) continue;
        groups.putIfAbsent(key, () => []).add(_canon(r));
      }
    }
    return {for (final e in groups.entries) e.key: (e.value..sort()).join('|')};
  }

  static Map<String, String> _planByShot(Map<String, dynamic> bundle) {
    final points = <String, List<String>>{};
    for (final p in bundle['cameraPathPoints'] as List? ?? const []) {
      if (p is Map && p['elementKey'] is String) {
        points.putIfAbsent(p['elementKey'] as String, () => []).add(_canon(p));
      }
    }
    final groups = <String, List<String>>{};
    for (final e in bundle['cameraPlanElements'] as List? ?? const []) {
      if (e is! Map || e['shotKey'] is! String) continue;
      final pts = (points[e['elementKey']] ?? const <String>[]).toList()
        ..sort();
      groups
          .putIfAbsent(e['shotKey'] as String, () => [])
          .add('${_canon(e)}${pts.join()}');
    }
    return {for (final e in groups.entries) e.key: (e.value..sort()).join('|')};
  }

  static String? _labelOf(
    Map<String, dynamic> base,
    Map<String, dynamic> current,
    String collection,
    String uid,
  ) {
    for (final bundle in [current, base]) {
      final rec = _byUid(bundle[collection])?[uid];
      if (rec != null) return _label(collection, rec);
    }
    return null;
  }

  static String? _label(String collection, Map<String, dynamic> rec) {
    String? key(String field) {
      final v = rec[field];
      return v is String ? v : null;
    }

    switch (collection) {
      case 'scenes':
        final name = rec['name'];
        return 'Escena ${rec['number']}${rec['numberSuffix'] ?? ''}'
            '${name is String && name.isNotEmpty ? ' · $name' : ''}';
      case 'shots':
        final parts = key('shotKey')?.split(':');
        return parts != null && parts.length >= 3
            ? 'Plano ${parts[1]}/${parts[2]}'
            : 'Plano ${rec['number']}';
      case 'locationSites':
        return 'Localización ${rec['name'] ?? ''}'.trim();
      case 'locationBasePlans':
        return 'Set ${rec['locationName'] ?? rec['name'] ?? ''}'.trim();
      case 'setGroups':
        return 'Grupo de sets ${rec['name'] ?? ''}'.trim();
      case 'lightSetups':
        return 'Esquema de luz ${rec['name'] ?? ''}'.trim();
      case 'shootDocuments':
        return '${rec['name'] ?? 'Jornada'}';
      case 'rentalReservations':
        return 'Reserva ${rec['name'] ?? rec['houseName'] ?? ''}'.trim();
    }
    return rec['name'] as String?;
  }

  static String _canon(Object? v) => jsonEncode(_sorted(v));

  static Object? _sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return {for (final k in keys) k: _sorted(v[k])};
    }
    if (v is List) return [for (final e in v) _sorted(e)];
    return v;
  }
}

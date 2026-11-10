import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../cloud/cloud_runtime_config.dart';
import '../utils/error_log.dart';

/// Un esquema de luz guardado en la biblioteca.
class PlanLibraryScheme {
  final String name;
  final String planJson;
  final String? category;

  const PlanLibraryScheme({
    required this.name,
    required this.planJson,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'planJson': planJson,
    'category': ?category,
  };

  static PlanLibraryScheme fromJson(Map raw) => PlanLibraryScheme(
    name: raw['name'] as String,
    planJson: raw['planJson'] as String,
    category: raw['category'] as String?,
  );
}

/// Una entrada de la biblioteca: un esquema de luz suelto o un set entero,
/// con su planta y sus esquemas. No pertenece a ningún proyecto.
class PlanLibraryEntry {
  final String uid;
  final String name;
  final DateTime updatedAt;

  /// Lápida: borrada, y se recuerda para que otro equipo no la resucite.
  final bool deleted;

  /// La planta del set. Nula en un esquema suelto.
  final String? setPlanJson;
  final List<PlanLibraryScheme> schemes;

  const PlanLibraryEntry({
    required this.uid,
    required this.name,
    required this.updatedAt,
    this.deleted = false,
    this.setPlanJson,
    this.schemes = const [],
  });

  bool get isSet => setPlanJson != null;

  PlanLibraryEntry renamed(String next, DateTime at) => PlanLibraryEntry(
    uid: uid,
    name: next,
    updatedAt: at,
    setPlanJson: setPlanJson,
    schemes: schemes,
  );

  /// Lo que viaja a la nube, además de `uid`, fecha y lápida.
  Map<String, dynamic> payload() => {
    'name': name,
    'setPlanJson': ?setPlanJson,
    'schemes': [for (final s in schemes) s.toJson()],
  };

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deleted': deleted,
    ...payload(),
  };

  static PlanLibraryEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final uid = raw['uid'], at = DateTime.tryParse('${raw['updatedAt']}');
    if (uid is! String || at == null) return null;
    return PlanLibraryEntry(
      uid: uid,
      name: raw['name'] as String? ?? 'Sin nombre',
      updatedAt: at.toUtc(),
      deleted: raw['deleted'] == true,
      setPlanJson: raw['setPlanJson'] as String?,
      schemes: [
        for (final s in (raw['schemes'] as List? ?? const []))
          if (s is Map) PlanLibraryScheme.fromJson(s),
      ],
    );
  }
}

/// Qué hacer para que este equipo y la nube queden iguales: en cada entrada
/// gana la edición más reciente, también si es un borrado.
@visibleForTesting
({List<PlanLibraryEntry> toStore, List<PlanLibraryEntry> toUpload})
planLibraryMerge(List<PlanLibraryEntry> local, List<PlanLibraryEntry> remote) {
  final here = {for (final e in local) e.uid: e};
  final there = {for (final e in remote) e.uid: e};
  final toStore = <PlanLibraryEntry>[];
  final toUpload = <PlanLibraryEntry>[];
  for (final uid in {...here.keys, ...there.keys}) {
    final a = here[uid], b = there[uid];
    if (b == null || (a != null && a.updatedAt.isAfter(b.updatedAt))) {
      toUpload.add(a!);
    } else if (a == null || b.updatedAt.isAfter(a.updatedAt)) {
      toStore.add(b);
    }
  }
  return (toStore: toStore, toUpload: toUpload);
}

/// La biblioteca en este equipo: un archivo JSON por entrada, fuera de
/// cualquier proyecto. Con la nube activa y la migración 015, se copia entre
/// los equipos del usuario.
///
/// Los archivos son pequeños y se leen de golpe y sin esperas.
class PlanLibraryStore {
  final Directory dir;

  PlanLibraryStore(this.dir);

  static PlanLibraryStore? _local;

  /// Para las pruebas.
  @visibleForTesting
  static set local(PlanLibraryStore? store) => _local = store;

  /// La de este equipo, o `null` si aquí no hay carpeta de datos.
  static Future<PlanLibraryStore?> open() async {
    if (_local != null) return _local;
    try {
      final base = await getApplicationSupportDirectory();
      return _local = PlanLibraryStore(
        Directory(p.join(base.path, 'biblioteca_sets')),
      );
    } on MissingPluginException {
      return null;
    }
  }

  File _file(String uid) => File(p.join(dir.path, '$uid.json'));

  /// Todas, lápidas incluidas.
  List<PlanLibraryEntry> all() {
    if (!dir.existsSync()) return const [];
    final out = <PlanLibraryEntry>[];
    for (final f in dir.listSync().whereType<File>()) {
      if (p.extension(f.path) != '.json') continue;
      try {
        final entry = PlanLibraryEntry.fromJson(
          jsonDecode(f.readAsStringSync()),
        );
        if (entry != null) out.add(entry);
      } on FormatException catch (e, s) {
        // Una entrada rota no tira toda la biblioteca.
        ErrorLog.record(e, s, context: 'Biblioteca: ${p.basename(f.path)}');
      }
    }
    return out;
  }

  /// Las que se pueden usar, por nombre.
  List<PlanLibraryEntry> list() =>
      all().where((e) => !e.deleted).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  void store(PlanLibraryEntry entry) {
    dir.createSync(recursive: true);
    final target = _file(entry.uid);
    final partial = File('${target.path}.parcial');
    partial.writeAsStringSync(jsonEncode(entry.toJson()), flush: true);
    partial.renameSync(target.path);
  }

  /// Guarda una entrada nueva.
  PlanLibraryEntry add({
    required String name,
    String? setPlanJson,
    required List<PlanLibraryScheme> schemes,
  }) {
    final entry = PlanLibraryEntry(
      uid: const Uuid().v4(),
      name: name,
      updatedAt: DateTime.now().toUtc(),
      setPlanJson: setPlanJson,
      schemes: schemes,
    );
    store(entry);
    return entry;
  }

  void rename(PlanLibraryEntry entry, String name) =>
      store(entry.renamed(name, DateTime.now().toUtc()));

  void remove(PlanLibraryEntry entry) => store(
    PlanLibraryEntry(
      uid: entry.uid,
      name: entry.name,
      updatedAt: DateTime.now().toUtc(),
      deleted: true,
    ),
  );

  /// Iguala este equipo con la nube. Nunca lanza: sin red, sin sesión o sin
  /// la migración 015, la biblioteca sigue siendo la de este equipo.
  Future<void> sync() async {
    if (!CloudRuntimeConfig.isActive) return;
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final rows = await client
          .from('plan_library')
          .select('uid, updated_at, deleted, payload');
      final remote = <PlanLibraryEntry>[
        for (final r in rows)
          ?PlanLibraryEntry.fromJson({
            ...?(r['payload'] as Map?),
            'uid': r['uid'],
            'updatedAt': r['updated_at'],
            'deleted': r['deleted'],
          }),
      ];
      final plan = planLibraryMerge(all(), remote);
      plan.toStore.forEach(store);
      if (plan.toUpload.isEmpty) return;
      await client.from('plan_library').upsert([
        for (final e in plan.toUpload)
          {
            'user_id': user.id,
            'uid': e.uid,
            'updated_at': e.updatedAt.toIso8601String(),
            'deleted': e.deleted,
            'payload': e.deleted ? null : e.payload(),
          },
      ], onConflict: 'user_id,uid');
    } on PostgrestException catch (e, s) {
      // La tabla todavía no existe: falta ejecutar la migración 015.
      if (e.code == 'PGRST205' || e.code == '42P01') return;
      await ErrorLog.recordUnlessOffline(e, s, context: 'Biblioteca de sets');
    } on Exception catch (e, s) {
      await ErrorLog.recordUnlessOffline(e, s, context: 'Biblioteca de sets');
    }
  }
}

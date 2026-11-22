import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/project_role.dart';
import '../utils/error_log.dart';
import 'bundle_changes.dart';
import 'device_label.dart';

/// Un cambio anotado en la nube (021): quién, cuándo y qué.
class ActivityEntry {
  const ActivityEntry({
    required this.at,
    required this.userId,
    required this.collection,
    required this.action,
    this.name,
    this.role,
    this.device,
    this.uid,
    this.label,
    this.fields = const [],
  });

  final DateTime at;
  final String userId;
  final String? name;

  /// Papel en el proyecto; nulo: el dueño.
  final String? role;
  final String? device;
  final String collection;
  final String? uid;
  final String? label;
  final String action;
  final List<String> fields;

  /// «Ana (gaffer)».
  String get who =>
      '${name?.trim().isNotEmpty == true ? name!.trim() : 'Alguien'} '
      '(${ProjectRole.shortLabel(role)})';

  /// «cambió la planta y la óptica de», «añadió», «borró».
  String get verb => switch (action) {
    'added' => 'añadió',
    'removed' => 'borró',
    _ =>
      fields.isEmpty
          ? 'cambió'
          : 'cambió ${_join(fields.map(_withArticle).toList())} de',
  };

  /// «Ana (gaffer) cambió la planta de Plano 6/1».
  String get sentence => '$who $verb ${label ?? collection}';

  static String _withArticle(String f) => switch (f) {
    'referencias' || 'imágenes' || 'notas' || 'luces del plano' => 'las $f',
    'personajes' || 'otros datos' => 'los $f',
    'óptica' ||
    'planta' ||
    'descripción' ||
    'duración' ||
    'acción' ||
    'cabecera' ||
    'ruta' ||
    'imagen' ||
    'obturación' => 'la $f',
    _ => 'el $f',
  };

  static String _join(List<String> parts) {
    if (parts.length <= 1) return parts.join();
    return '${parts.sublist(0, parts.length - 1).join(', ')} y ${parts.last}';
  }

  factory ActivityEntry.fromRow(Map<String, dynamic> r) => ActivityEntry(
    at: DateTime.parse(r['at'] as String).toLocal(),
    userId: r['user_id'] as String,
    name: r['name'] as String?,
    role: r['role'] as String?,
    device: r['device'] as String?,
    collection: r['collection'] as String,
    uid: r['uid'] as String?,
    label: r['label'] as String?,
    action: r['action'] as String,
    fields: [for (final f in (r['fields'] as List? ?? const [])) '$f'],
  );
}

/// Anota y lee la autoría de un proyecto compartido (021). Sin la 021, no
/// anota nada y no hay lista: la sincronización sigue igual.
class ProjectActivityService {
  ProjectActivityService(this._client);

  final SupabaseClient _client;

  /// Tope por subida: lo de una sola subida grande (importar un guion) no
  /// llena la lista.
  static const maxRowsPerUpload = 80;

  /// Sin la 021 en la nube se deja de intentar hasta reiniciar.
  static bool _unavailable = false;

  static bool _missing(PostgrestException e) =>
      e.code == 'PGRST205' ||
      e.code == 'PGRST202' ||
      e.code == '42P01' ||
      e.message.contains('project_activity');

  /// Tras subir: anota [changes]. Nunca lanza.
  Future<void> record(
    String projectCloudId,
    List<ContentChange> changes,
  ) async {
    if (_unavailable || changes.isEmpty) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    var list = changes;
    if (list.length > maxRowsPerUpload) {
      list = [
        ...list.take(maxRowsPerUpload - 1),
        ContentChange(
          collection: 'project',
          uid: 'project',
          label: 'y ${changes.length - maxRowsPerUpload + 1} cosas más',
          action: 'edited',
        ),
      ];
    }
    final device = deviceLabel();
    try {
      await _client.from('project_activity').insert([
        for (final c in list)
          {
            ...c.toRow(),
            'project_id': projectCloudId,
            'user_id': userId,
            'device': device.length > 80 ? device.substring(0, 80) : device,
          },
      ]);
    } on PostgrestException catch (e, st) {
      if (_missing(e)) {
        _unavailable = true;
        return;
      }
      await ErrorLog.recordUnlessOffline(e, st, context: 'Anotar la autoría');
    } catch (e, st) {
      await ErrorLog.recordUnlessOffline(e, st, context: 'Anotar la autoría');
    }
  }

  /// Lo último que pasó en el proyecto, lo más reciente primero.
  Future<List<ActivityEntry>> recent(
    String projectCloudId, {
    int limit = 200,
    DateTime? before,
  }) async {
    final rows = await _client.rpc(
      'iris_project_activity',
      params: {
        'p_project': projectCloudId,
        'p_limit': limit,
        'p_before': before?.toUtc().toIso8601String(),
      },
    );
    return [
      for (final r in rows as List)
        ActivityEntry.fromRow(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// El último cambio de cada cosa, por `colección/uid`.
  Future<Map<String, ActivityEntry>> lastChanges(String projectCloudId) async {
    final rows = await _client.rpc(
      'iris_last_changes',
      params: {'p_project': projectCloudId},
    );
    return {
      for (final r in rows as List)
        '${r['collection']}/${r['uid']}': ActivityEntry.fromRow(
          Map<String, dynamic>.from(r as Map),
        ),
    };
  }

  static bool isMissing(Object e) => e is PostgrestException && _missing(e);
}

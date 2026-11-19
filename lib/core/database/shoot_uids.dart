import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

/// Identidad de las jornadas y sus bloques (schemaVersion 64).
///
/// Las filas que ya existían se rellenan con un uid que sale de su
/// contenido, no al azar: el Mac, el iPad y el iPhone tenían las mismas
/// jornadas por la nube, y así les ponen los mismos uid sin hablar entre
/// ellos. Las nuevas llevan uno al azar ([newEntityUid]).
abstract final class ShootUids {
  static String _hash(String text) {
    final hex = sha1.convert(utf8.encode(text)).toString().substring(0, 32);
    // Con forma de UUID, para que se lea como los demás.
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// Documento: tipo, nombre, fecha y, si se repiten, cuál de ellos.
  static String document({
    required String kind,
    required String name,
    String? shootDate,
    int ordinal = 0,
  }) => _hash('doc|$kind|${name.trim()}|${shootDate ?? ''}|$ordinal');

  /// Bloque: su documento, su orden y, si se repite el orden, cuál de ellos.
  static String block({
    required String documentUid,
    required int sortOrder,
    int ordinal = 0,
  }) => _hash('block|$documentUid|$sortOrder|$ordinal');

  /// Pone uid a las jornadas y bloques que no lo tienen. Idempotente.
  static Future<void> backfill(DatabaseConnectionUser db) async {
    final docs = await db
        .customSelect(
          'SELECT id, project_id, uid, kind, name, shoot_date FROM shoot_documents '
          'ORDER BY project_id, id',
        )
        .get();
    final seen = <String, int>{};
    final docUid = <int, String>{};
    for (final row in docs) {
      final id = row.read<int>('id');
      final kind = row.read<String?>('kind') ?? 'freeform';
      final name = row.read<String>('name');
      final date = row.read<String?>('shoot_date');
      // El orden se cuenta dentro del proyecto: los ids de proyecto
      // cambian de un equipo a otro, pero no el orden de sus jornadas.
      final key =
          '${row.read<int>('project_id')}|$kind|${name.trim()}|${date ?? ''}';
      final ordinal = seen[key] = (seen[key] ?? -1) + 1;
      var uid = row.read<String?>('uid');
      if (uid == null || uid.isEmpty) {
        uid = document(
          kind: kind,
          name: name,
          shootDate: date,
          ordinal: ordinal,
        );
        await db.customStatement(
          'UPDATE shoot_documents SET uid = ? WHERE id = ?',
          [uid, id],
        );
      }
      docUid[id] = uid;
    }
    final blocks = await db
        .customSelect(
          'SELECT id, uid, document_id, sort_order FROM shoot_document_blocks '
          'ORDER BY document_id, sort_order, id',
        )
        .get();
    final seenBlock = <String, int>{};
    for (final row in blocks) {
      final uid = row.read<String?>('uid');
      if (uid != null && uid.isNotEmpty) continue;
      final parent = docUid[row.read<int>('document_id')];
      // Un bloque sin documento no viaja: se queda sin uid.
      if (parent == null) continue;
      final sortOrder = row.read<int>('sort_order');
      final key = '$parent|$sortOrder';
      final ordinal = seenBlock[key] = (seenBlock[key] ?? -1) + 1;
      await db.customStatement(
        'UPDATE shoot_document_blocks SET uid = ? WHERE id = ?',
        [
          block(documentUid: parent, sortOrder: sortOrder, ordinal: ordinal),
          row.read<int>('id'),
        ],
      );
    }
  }
}

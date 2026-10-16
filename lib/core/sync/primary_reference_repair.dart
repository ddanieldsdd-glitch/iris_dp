import 'dart:io';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// La principal de un plano es una de sus referencias. En equipos que la
/// bajaron como imagen aparte (antes de este arreglo) salía dos veces: si es
/// el mismo archivo que una referencia, pasa a apuntar a esa referencia.
Future<int> repairDuplicatePrimaryReferences(
  AppDatabase db,
  int projectId,
) async {
  final rows = await db
      .customSelect(
        'SELECT s.id, s.reference_image_path AS primary_path, '
        'r.image_path AS ref_path FROM shots s '
        'JOIN shot_references r ON r.shot_id = s.id '
        'WHERE s.project_id = ? AND s.reference_image_path IS NOT NULL '
        'AND NOT EXISTS (SELECT 1 FROM shot_references x '
        'WHERE x.shot_id = s.id AND x.image_path = s.reference_image_path)',
        variables: [Variable.withInt(projectId)],
      )
      .get();
  var repaired = 0;
  final done = <int>{};
  for (final row in rows) {
    final shotId = row.read<int>('id');
    if (done.contains(shotId)) continue;
    final primary = File(row.read<String>('primary_path'));
    final reference = File(row.read<String>('ref_path'));
    if (!primary.existsSync() || !reference.existsSync()) continue;
    if (primary.lengthSync() != reference.lengthSync()) continue;
    if (!_sameBytes(primary, reference)) continue;
    await (db.update(db.shots)..where((s) => s.id.equals(shotId))).write(
      ShotsCompanion(referenceImagePath: Value(reference.path)),
    );
    done.add(shotId);
    repaired++;
  }
  return repaired;
}

bool _sameBytes(File a, File b) {
  final x = a.readAsBytesSync();
  final y = b.readAsBytesSync();
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  return true;
}

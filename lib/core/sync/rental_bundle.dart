import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Las reservas de material en el bundle del proyecto. Viajan solo si hay
/// filas, para no cambiar la huella de los proyectos que no las usan, y se
/// aplican fila a fila por uid: una lista ausente no borra nada.
abstract final class RentalBundle {
  static Map<String, dynamic> _clean(Map<String, dynamic> json) => {
    for (final e in json.entries)
      if (e.key != 'id' && e.key != 'projectId' && e.value != null)
        e.key: e.value,
  };

  static Future<Map<String, dynamic>> export(
    AppDatabase db,
    int projectId,
  ) async {
    final houses =
        await (db.select(db.rentalHouses)
              ..where((r) => r.projectId.equals(projectId))
              ..orderBy([(r) => OrderingTerm.asc(r.uid)]))
            .get();
    final reservations =
        await (db.select(db.rentalReservations)
              ..where((r) => r.projectId.equals(projectId))
              ..orderBy([(r) => OrderingTerm.asc(r.uid)]))
            .get();
    final items =
        await (db.select(db.rentalItems)
              ..where((r) => r.projectId.equals(projectId))
              ..orderBy([(r) => OrderingTerm.asc(r.uid)]))
            .get();
    return {
      if (houses.isNotEmpty)
        'rentalHouses': [for (final r in houses) _clean(r.toJson())],
      if (reservations.isNotEmpty)
        'rentalReservations': [
          for (final r in reservations) _clean(r.toJson()),
        ],
      if (items.isNotEmpty)
        'rentalItems': [for (final r in items) _clean(r.toJson())],
    };
  }

  static Iterable<Map<String, dynamic>> _rows(Object? list) sync* {
    if (list is! List) return;
    for (final r in list) {
      if (r is Map && r['uid'] is String) yield Map<String, dynamic>.from(r);
    }
  }

  static Future<void> import(
    AppDatabase db,
    int projectId,
    Map<String, dynamic> bundle,
  ) async {
    for (final m in _rows(bundle['rentalHouses'])) {
      final existing =
          await (db.select(db.rentalHouses)..where(
                (r) => r.projectId.equals(projectId) & r.uid.equals(m['uid']),
              ))
              .getSingleOrNull();
      final row = RentalHouse.fromJson({
        ...m,
        'id': existing?.id ?? 0,
        'projectId': projectId,
      });
      if (existing != null) {
        await db.update(db.rentalHouses).replace(row);
      } else {
        await db
            .into(db.rentalHouses)
            .insert(row.toCompanion(true).copyWith(id: const Value.absent()));
      }
    }
    for (final m in _rows(bundle['rentalReservations'])) {
      final existing =
          await (db.select(db.rentalReservations)..where(
                (r) => r.projectId.equals(projectId) & r.uid.equals(m['uid']),
              ))
              .getSingleOrNull();
      final row = RentalReservation.fromJson({
        ...m,
        'id': existing?.id ?? 0,
        'projectId': projectId,
      });
      if (existing != null) {
        await db.update(db.rentalReservations).replace(row);
      } else {
        await db
            .into(db.rentalReservations)
            .insert(row.toCompanion(true).copyWith(id: const Value.absent()));
      }
    }
    for (final m in _rows(bundle['rentalItems'])) {
      final existing =
          await (db.select(db.rentalItems)..where(
                (r) => r.projectId.equals(projectId) & r.uid.equals(m['uid']),
              ))
              .getSingleOrNull();
      final row = RentalItem.fromJson({
        ...m,
        'id': existing?.id ?? 0,
        'projectId': projectId,
      });
      if (existing != null) {
        await db.update(db.rentalItems).replace(row);
      } else {
        await db
            .into(db.rentalItems)
            .insert(row.toCompanion(true).copyWith(id: const Value.absent()));
      }
    }
  }
}

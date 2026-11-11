import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';

/// Reservas de material. Se borra con [RentalReservations.deletedAt]: una
/// fila no puede desaparecer sin que los demás aparatos se enteren.
extension RentalQueries on AppDatabase {
  Stream<List<RentalHouse>> watchRentalHouses(int projectId) =>
      (select(rentalHouses)
            ..where((r) => r.projectId.equals(projectId) & r.deletedAt.isNull())
            ..orderBy([
              (r) => OrderingTerm.asc(r.sortOrder),
              (r) => OrderingTerm.asc(r.name),
            ]))
          .watch();

  Stream<List<RentalReservation>> watchRentalReservations(int projectId) =>
      (select(rentalReservations)
            ..where((r) => r.projectId.equals(projectId) & r.deletedAt.isNull())
            ..orderBy([
              (r) => OrderingTerm.asc(r.pickupAt),
              (r) => OrderingTerm.asc(r.title),
            ]))
          .watch();

  Future<List<RentalReservation>> getRentalReservations(int projectId) =>
      watchRentalReservations(projectId).first;

  /// Las reservas pendientes de todos los proyectos, para los recordatorios.
  Future<List<RentalReservation>> getAllActiveRentalReservations() =>
      (select(rentalReservations)..where((r) => r.deletedAt.isNull())).get();

  Stream<List<RentalItem>> watchRentalItems(
    int projectId,
    String reservationUid,
  ) =>
      (select(rentalItems)
            ..where(
              (r) =>
                  r.projectId.equals(projectId) &
                  r.reservationUid.equals(reservationUid) &
                  r.deletedAt.isNull(),
            )
            ..orderBy([(r) => OrderingTerm.asc(r.sortOrder)]))
          .watch();

  Future<List<RentalItem>> getRentalItemsIncludingDeleted(
    int projectId,
    String reservationUid,
  ) =>
      (select(rentalItems)..where(
            (r) =>
                r.projectId.equals(projectId) &
                r.reservationUid.equals(reservationUid),
          ))
          .get();

  Future<RentalReservation?> getRentalReservationByUid(
    int projectId,
    String uid,
  ) =>
      (select(rentalReservations)
            ..where((r) => r.projectId.equals(projectId) & r.uid.equals(uid)))
          .getSingleOrNull();

  Future<void> setReservationPickedUp(
    RentalReservation r, {
    required String? at,
    required String? device,
  }) async {
    await (update(rentalReservations)..where((x) => x.id.equals(r.id))).write(
      RentalReservationsCompanion(
        pickedUpAt: Value(at),
        pickedUpDevice: Value(device),
      ),
    );
    await touchProjectContent(r.projectId);
  }

  Future<void> setReservationReturned(
    RentalReservation r, {
    required String? at,
    required String? device,
  }) async {
    await (update(rentalReservations)..where((x) => x.id.equals(r.id))).write(
      RentalReservationsCompanion(
        returnedAt: Value(at),
        returnedDevice: Value(device),
      ),
    );
    await touchProjectContent(r.projectId);
  }

  Future<void> setRentalItemChecked(
    RentalItem item, {
    required bool returning,
    required String? at,
  }) async {
    await (update(rentalItems)..where((x) => x.id.equals(item.id))).write(
      returning
          ? RentalItemsCompanion(returnCheckedAt: Value(at))
          : RentalItemsCompanion(pickupCheckedAt: Value(at)),
    );
    await touchProjectContent(item.projectId);
  }

  Future<void> softDeleteRentalReservation(
    RentalReservation r,
    String at,
  ) async {
    await transaction(() async {
      await (update(rentalReservations)..where((x) => x.id.equals(r.id))).write(
        RentalReservationsCompanion(deletedAt: Value(at)),
      );
      await (update(rentalItems)..where(
            (x) =>
                x.projectId.equals(r.projectId) &
                x.reservationUid.equals(r.uid),
          ))
          .write(RentalItemsCompanion(deletedAt: Value(at)));
    });
    await touchProjectContent(r.projectId);
  }

  /// Las líneas añadidas a mano empiezan así: reimportar la lista no las
  /// toca.
  static const manualItemPrefix = 'manual-';

  /// Nombre, fechas («2026-11-13T09:00») y notas de la reserva.
  Future<void> updateRentalReservationInfo(
    RentalReservation r, {
    required String title,
    required String? pickupAt,
    required String? returnAt,
    required String? notes,
  }) async {
    await (update(rentalReservations)..where((x) => x.id.equals(r.id))).write(
      RentalReservationsCompanion(
        title: Value(title.trim().isEmpty ? r.title : title.trim()),
        pickupAt: Value(pickupAt),
        returnAt: Value(returnAt),
        notes: Value(
          notes == null || notes.trim().isEmpty ? null : notes.trim(),
        ),
      ),
    );
    await touchProjectContent(r.projectId);
  }

  Future<void> addManualRentalItem(
    RentalReservation r, {
    required String name,
    double? quantity,
    String? note,
  }) async {
    final last =
        await (select(rentalItems)
              ..where(
                (x) =>
                    x.projectId.equals(r.projectId) &
                    x.reservationUid.equals(r.uid),
              )
              ..orderBy([(x) => OrderingTerm.desc(x.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    await into(rentalItems).insert(
      RentalItemsCompanion.insert(
        uid: '$manualItemPrefix${const Uuid().v4()}',
        projectId: r.projectId,
        reservationUid: r.uid,
        name: name.trim(),
        quantity: Value(quantity),
        note: Value(note == null || note.trim().isEmpty ? null : note.trim()),
        section: const Value('Añadido a mano'),
        sortOrder: Value((last?.sortOrder ?? 0) + 1),
      ),
    );
    await touchProjectContent(r.projectId);
  }

  Future<void> updateRentalItemText(
    RentalItem item, {
    required String name,
    double? quantity,
    String? note,
  }) async {
    await (update(rentalItems)..where((x) => x.id.equals(item.id))).write(
      RentalItemsCompanion(
        name: Value(name.trim().isEmpty ? item.name : name.trim()),
        quantity: Value(quantity),
        note: Value(note == null || note.trim().isEmpty ? null : note.trim()),
      ),
    );
    await touchProjectContent(item.projectId);
  }

  Future<void> softDeleteRentalItem(RentalItem item, String at) async {
    await (update(rentalItems)..where((x) => x.id.equals(item.id))).write(
      RentalItemsCompanion(deletedAt: Value(at)),
    );
    await touchProjectContent(item.projectId);
  }
}

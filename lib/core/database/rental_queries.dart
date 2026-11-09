import 'package:drift/drift.dart';

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
}

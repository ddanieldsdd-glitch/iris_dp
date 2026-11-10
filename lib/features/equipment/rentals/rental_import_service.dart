import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/rental_queries.dart';
import 'rental_import_models.dart';

String _sha(String text) => sha1.convert(utf8.encode(text)).toString();

String _normalize(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Identidades que salen del contenido: importar el mismo PDF en dos
/// aparatos da las mismas filas, y la mezcla las une en vez de duplicarlas.
String rentalHouseUid(String name) => _sha('house|${_normalize(name)}');

String rentalReservationUid(String? number) => number == null || number.isEmpty
    ? const Uuid().v4()
    : _sha('reservation|${_normalize(number)}');

class FlatRentalItem {
  final String uid;
  final String? parentUid;
  final ParsedRentalItem item;
  final int sortOrder;

  const FlatRentalItem(this.uid, this.parentUid, this.item, this.sortOrder);
}

/// Lo que va a pasar al guardar una lista.
class RentalImportPreview {
  final ParsedReservation parsed;
  final String reservationUid;
  final RentalReservation? existing;
  final List<FlatRentalItem> items;
  final List<String> added;
  final List<String> changed;
  final List<String> removed;

  const RentalImportPreview({
    required this.parsed,
    required this.reservationUid,
    required this.existing,
    required this.items,
    required this.added,
    required this.changed,
    required this.removed,
  });

  bool get isUpdate => existing != null;
}

class RentalImportService {
  final AppDatabase _db;

  RentalImportService(this._db);

  static List<FlatRentalItem> flatten(
    String reservationUid,
    List<ParsedRentalItem> items,
  ) {
    final out = <FlatRentalItem>[];
    final seen = <String, int>{};
    String uidFor(ParsedRentalItem i, String? parentName) {
      final key = [
        i.section ?? '',
        parentName ?? '',
        i.groupLabel ?? '',
        _normalize(i.name),
      ].join('|');
      final ordinal = seen[key] = (seen[key] ?? 0) + 1;
      return _sha('$reservationUid|$key|$ordinal');
    }

    var order = 0;
    for (final item in items) {
      final uid = uidFor(item, null);
      out.add(FlatRentalItem(uid, null, item, order++));
      for (final child in item.children) {
        out.add(FlatRentalItem(uidFor(child, item.name), uid, child, order++));
      }
    }
    return out;
  }

  Future<RentalImportPreview> preview(
    int projectId,
    ParsedReservation parsed,
  ) async {
    final uid = rentalReservationUid(parsed.number);
    final existing = await _db.getRentalReservationByUid(projectId, uid);
    final items = flatten(uid, parsed.items);
    final active = existing == null || existing.deletedAt != null
        ? const <RentalItem>[]
        : [
            for (final r in await _db.getRentalItemsIncludingDeleted(
              projectId,
              uid,
            ))
              if (r.deletedAt == null) r,
          ];
    final byUid = {for (final r in active) r.uid: r};
    final parsedUids = {for (final i in items) i.uid};
    return RentalImportPreview(
      parsed: parsed,
      reservationUid: uid,
      existing: existing?.deletedAt == null ? existing : null,
      items: items,
      added: [
        for (final i in items)
          if (active.isNotEmpty && !byUid.containsKey(i.uid)) i.item.name,
      ],
      changed: [
        for (final i in items)
          if (byUid[i.uid] case final old?)
            if (old.quantity != i.item.quantity ||
                old.serial != i.item.serial ||
                old.note != i.item.note)
              i.item.name,
      ],
      removed: [
        for (final r in active)
          if (!parsedUids.contains(r.uid)) r.name,
      ],
    );
  }

  /// Guarda la lista. Conserva lo que se haya marcado (recogido, comprobado)
  /// aunque se reimporte. Devuelve el uid de la reserva.
  Future<String> apply({
    required int projectId,
    required RentalImportPreview preview,
    required String title,
    required String houseName,
    String? contact,
    String? sourceFileName,
    DateTime? now,
  }) async {
    final parsed = preview.parsed;
    final at = (now ?? DateTime.now()).toUtc().toIso8601String();
    final uid = preview.reservationUid;
    final trimmedHouse = houseName.trim();
    final houseUid = trimmedHouse.isEmpty ? null : rentalHouseUid(trimmedHouse);

    await _db.transaction(() async {
      if (houseUid != null) {
        final house =
            await (_db.select(_db.rentalHouses)..where(
                  (r) => r.projectId.equals(projectId) & r.uid.equals(houseUid),
                ))
                .getSingleOrNull();
        if (house == null) {
          await _db
              .into(_db.rentalHouses)
              .insert(
                RentalHousesCompanion.insert(
                  uid: houseUid,
                  projectId: projectId,
                  name: trimmedHouse,
                  contact: Value(contact),
                ),
              );
        } else if (house.deletedAt != null ||
            (house.contact == null && contact != null)) {
          await (_db.update(
            _db.rentalHouses,
          )..where((r) => r.id.equals(house.id))).write(
            RentalHousesCompanion(
              deletedAt: const Value(null),
              contact: Value(house.contact ?? contact),
            ),
          );
        }
      }

      final fields = RentalReservationsCompanion(
        houseUid: Value(houseUid),
        number: Value(parsed.number),
        externalId: Value(parsed.externalId),
        sourceStatus: Value(parsed.sourceStatus),
        title: Value(title.trim()),
        responsible: Value(parsed.responsible),
        pickupAt: Value(parsed.pickupAt),
        returnAt: Value(parsed.returnAt),
        sourceFileName: Value(sourceFileName),
        deletedAt: const Value(null),
      );
      final existing = await _db.getRentalReservationByUid(projectId, uid);
      if (existing == null) {
        await _db
            .into(_db.rentalReservations)
            .insert(
              fields.copyWith(uid: Value(uid), projectId: Value(projectId)),
            );
      } else {
        await (_db.update(
          _db.rentalReservations,
        )..where((r) => r.id.equals(existing.id))).write(fields);
      }

      final current = await _db.getRentalItemsIncludingDeleted(projectId, uid);
      final byUid = {for (final r in current) r.uid: r};
      final parsedUids = <String>{};
      for (final f in preview.items) {
        parsedUids.add(f.uid);
        final i = f.item;
        final row = RentalItemsCompanion(
          parentUid: Value(f.parentUid),
          kind: Value(i.kind),
          section: Value(i.section),
          groupLabel: Value(i.groupLabel),
          name: Value(i.name),
          quantity: Value(i.quantity),
          quantityCertain: Value(i.quantityCertain),
          serial: Value(i.serial),
          note: Value(i.note),
          rawText: Value(i.rawText),
          removedFromSourceAt: const Value(null),
          sortOrder: Value(f.sortOrder),
          deletedAt: const Value(null),
        );
        final old = byUid[f.uid];
        if (old == null) {
          await _db
              .into(_db.rentalItems)
              .insert(
                row.copyWith(
                  uid: Value(f.uid),
                  projectId: Value(projectId),
                  reservationUid: Value(uid),
                ),
              );
        } else {
          await (_db.update(
            _db.rentalItems,
          )..where((r) => r.id.equals(old.id))).write(row);
        }
      }
      for (final old in current) {
        if (parsedUids.contains(old.uid) || old.deletedAt != null) continue;
        final checked =
            old.pickupCheckedAt != null || old.returnCheckedAt != null;
        await (_db.update(
          _db.rentalItems,
        )..where((r) => r.id.equals(old.id))).write(
          checked
              ? RentalItemsCompanion(removedFromSourceAt: Value(at))
              : RentalItemsCompanion(deletedAt: Value(at)),
        );
      }
    });
    await _db.touchProjectContent(projectId);
    return uid;
  }
}

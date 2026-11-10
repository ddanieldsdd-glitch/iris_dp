import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/shoot_documents/shoot_agenda.dart';

void main() {
  test('junta jornadas, recogidas y devoluciones por fecha y hora', () {
    final agenda = buildShootAgenda(
      documents: const [],
      reservations: const [
        RentalReservation(
          id: 1,
          uid: 'a',
          projectId: 1,
          houseUid: 'h',
          title: 'Cámara',
          pickupAt: '2026-11-12T10:00',
          returnAt: '2026-11-08T14:00',
          pickedUpAt: 'x',
          sortOrder: 0,
        ),
      ],
      houses: const {
        'h': RentalHouse(
          id: 1,
          uid: 'h',
          projectId: 1,
          name: 'ESCAC',
          sortOrder: 0,
        ),
      },
      sites: const {},
      now: DateTime(2026, 11, 9),
    );
    expect(agenda.keys, ['2026-11-12']);
    final entry = agenda['2026-11-12']!.single;
    expect(entry.kind, ShootAgendaKind.pickup);
    expect(entry.detail, '10:00 · ESCAC');
    expect(entry.done, isTrue);
  });
}

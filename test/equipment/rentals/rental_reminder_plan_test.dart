import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/notifications/rental_reminder_plan.dart';

RentalReservation reservation({
  String uid = 'a',
  String? pickedUpAt,
  String? returnedAt,
  String? deletedAt,
}) => RentalReservation(
  id: 1,
  uid: uid,
  projectId: 1,
  houseUid: 'h',
  title: 'Cámara',
  pickupAt: '2026-11-12T10:00',
  returnAt: '2026-11-18T14:00',
  pickedUpAt: pickedUpAt,
  returnedAt: returnedAt,
  deletedAt: deletedAt,
  sortOrder: 0,
);

const house = RentalHouse(
  id: 1,
  uid: 'h',
  projectId: 1,
  name: 'ESCAC',
  sortOrder: 0,
);

void main() {
  final now = DateTime(2026, 11, 9, 12);
  const settings = RentalReminderSettings();
  final houses = {'h': house};

  test('víspera a las 20:00 y 90 minutos antes, de recoger y devolver', () {
    final list = RentalReminderPlan.upcoming(
      [reservation()],
      houses,
      settings,
      now,
    );
    expect(list.map((r) => r.at), [
      DateTime(2026, 11, 11, 20),
      DateTime(2026, 11, 12, 8, 30),
      DateTime(2026, 11, 17, 20),
      DateTime(2026, 11, 18, 12, 30),
    ]);
    expect(list.first.title, 'Mañana hay que recoger material');
    expect(list.first.body, contains('ESCAC'));
    expect(list.last.title, 'Hoy hay que devolver material');
  });

  test('lo recogido deja de avisar de la recogida', () {
    final list = RentalReminderPlan.upcoming(
      [reservation(pickedUpAt: 'x')],
      houses,
      settings,
      now,
    );
    expect(list.every((r) => r.title.contains('devolver')), isTrue);
  });

  test('sin avisos si se devolvió, se quitó o están apagados', () {
    expect(
      RentalReminderPlan.upcoming(
        [reservation(pickedUpAt: 'x', returnedAt: 'y')],
        houses,
        settings,
        now,
      ),
      isEmpty,
    );
    expect(
      RentalReminderPlan.upcoming(
        [reservation(deletedAt: 'x')],
        houses,
        settings,
        now,
      ),
      isEmpty,
    );
    expect(
      RentalReminderPlan.upcoming(
        [reservation()],
        houses,
        const RentalReminderSettings(enabled: false),
        now,
      ),
      isEmpty,
    );
  });

  test('los ids son estables y no se pasa del límite', () {
    final a = RentalReminderPlan.upcoming(
      [reservation()],
      houses,
      settings,
      now,
    );
    final b = RentalReminderPlan.upcoming(
      [reservation()],
      houses,
      settings,
      now,
    );
    expect(a.map((r) => r.id), b.map((r) => r.id));
    expect(a.map((r) => r.id).toSet(), hasLength(4));
    final many = [for (var i = 0; i < 40; i++) reservation(uid: 'u$i')];
    expect(
      RentalReminderPlan.upcoming(many, houses, settings, now).length,
      RentalReminderPlan.maxScheduled,
    );
  });

  test('al abrir IRIS se enseña solo lo que ya toca', () {
    final eve = DateTime(2026, 11, 11, 21);
    final due = RentalReminderPlan.dueNow(
      [reservation()],
      houses,
      settings,
      eve,
    );
    expect(due.single.title, 'Mañana hay que recoger material');
    final after = DateTime(2026, 11, 12, 11);
    expect(
      RentalReminderPlan.dueNow(
        [reservation()],
        houses,
        settings,
        after,
      ).where((r) => r.title.contains('recoger')),
      isEmpty,
    );
  });
}

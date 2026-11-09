import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../features/equipment/rentals/rental_format.dart';
import '../database/app_database.dart';

/// Un recordatorio de recogida o devolución.
class RentalReminder {
  final int id;
  final String key;
  final String title;
  final String body;
  final DateTime at;

  /// Cuándo es la recogida o devolución en sí.
  final DateTime eventAt;

  const RentalReminder({
    required this.id,
    required this.key,
    required this.title,
    required this.body,
    required this.at,
    required this.eventAt,
  });
}

class RentalReminderSettings {
  final bool enabled;

  /// A qué hora de la víspera avisa.
  final int eveHour;
  final int minutesBefore;

  const RentalReminderSettings({
    this.enabled = true,
    this.eveHour = 20,
    this.minutesBefore = 90,
  });
}

/// Los recordatorios que deberían existir ahora mismo. Con los mismos datos
/// da siempre los mismos ids, así que se pueden reponer sin duplicar.
abstract final class RentalReminderPlan {
  /// iOS no deja programar más de 64: se quedan los más próximos.
  static const maxScheduled = 60;

  static int _id(String key) => int.parse(
    sha1.convert(utf8.encode(key)).toString().substring(0, 7),
    radix: 16,
  );

  static List<RentalReminder> _all(
    Iterable<RentalReservation> reservations,
    Map<String, RentalHouse> houses,
    RentalReminderSettings settings,
  ) {
    if (!settings.enabled) return const [];
    final out = <RentalReminder>[];
    void add(RentalReservation r, String kind, String verb, String? when) {
      final at = when == null ? null : DateTime.tryParse(when);
      if (at == null) return;
      final house = houses[r.houseUid]?.name;
      final place = house == null ? r.title : '${r.title} · $house';
      final moment = formatRentalMoment(when);
      void one(String slot, DateTime fire, String heading) {
        final key = '${r.projectId}|${r.uid}|$kind|$slot';
        out.add(
          RentalReminder(
            id: _id(key),
            key: key,
            title: heading,
            body: '$place · $moment',
            at: fire,
            eventAt: at,
          ),
        );
      }

      final eve = DateTime(at.year, at.month, at.day - 1, settings.eveHour);
      one('eve', eve, 'Mañana hay que $verb material');
      one(
        'soon',
        at.subtract(Duration(minutes: settings.minutesBefore)),
        'Hoy hay que $verb material',
      );
    }

    for (final r in reservations) {
      if (r.deletedAt != null) continue;
      if (r.pickedUpAt == null) add(r, 'pickup', 'recoger', r.pickupAt);
      if (r.returnedAt == null) add(r, 'return', 'devolver', r.returnAt);
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// Los que quedan por sonar.
  static List<RentalReminder> upcoming(
    Iterable<RentalReservation> reservations,
    Map<String, RentalHouse> houses,
    RentalReminderSettings settings,
    DateTime now,
  ) => _all(
    reservations,
    houses,
    settings,
  ).where((r) => r.at.isAfter(now)).take(maxScheduled).toList();

  /// Los que ya tocaban y cuyo momento aún no ha pasado: se enseñan al abrir
  /// IRIS donde no se pueden programar avisos del sistema.
  static List<RentalReminder> dueNow(
    Iterable<RentalReservation> reservations,
    Map<String, RentalHouse> houses,
    RentalReminderSettings settings,
    DateTime now,
  ) {
    final latest = <String, RentalReminder>{};
    for (final r in _all(reservations, houses, settings)) {
      if (r.at.isAfter(now) || !r.eventAt.isAfter(now)) continue;
      latest[r.body + r.title.split(' ').take(5).join(' ')] = r;
    }
    return latest.values.toList();
  }
}

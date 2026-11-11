import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/access/app_access.dart';
import 'package:iris_dp/core/access/app_access_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 11, 11, 12);

  AccessCheck check({
    AccessStatus status = AccessStatus.active,
    bool admin = false,
    bool maintenance = false,
    int minBuild = 0,
    DateTime? checkedAt,
    int? limit,
    int? used,
  }) => AccessCheck(
    userId: 'u1',
    status: status,
    isAdmin: admin,
    checkedAt: checkedAt ?? now,
    maintenance: maintenance,
    minBuild: minBuild,
    storageLimitBytes: limit,
    usedBytes: used,
  );

  AccessVerdict decide(AccessCheck? c, {bool fresh = true, int build = 50}) =>
      decideAccess(last: c, fresh: fresh, localBuild: build, now: now);

  group('decideAccess', () {
    test('cuenta activa entra', () {
      expect(decide(check()), AccessVerdict.open);
    });

    test('pendiente y cerrada no entran', () {
      expect(decide(check(status: AccessStatus.pending)), AccessVerdict.pending);
      expect(
        decide(check(status: AccessStatus.suspended)),
        AccessVerdict.suspended,
      );
    });

    test('mantenimiento cierra al invitado pero no al administrador', () {
      expect(decide(check(maintenance: true)), AccessVerdict.maintenance);
      expect(decide(check(maintenance: true, admin: true)), AccessVerdict.open);
    });

    test('el administrador con la cuenta cerrada tampoco entra', () {
      expect(
        decide(check(admin: true, status: AccessStatus.suspended)),
        AccessVerdict.suspended,
      );
    });

    test('versión por debajo de la mínima', () {
      expect(decide(check(minBuild: 51)), AccessVerdict.outdated);
      expect(decide(check(minBuild: 50)), AccessVerdict.open);
    });

    test('sin conexión vale 7 días desde la última comprobación', () {
      final sixDays = check(checkedAt: now.subtract(const Duration(days: 6)));
      final eightDays = check(checkedAt: now.subtract(const Duration(days: 8)));
      expect(decide(sixDays, fresh: false), AccessVerdict.open);
      expect(decide(eightDays, fresh: false), AccessVerdict.offlineExpired);
    });

    test('un reloj que va hacia atrás no alarga el margen', () {
      final future = check(checkedAt: now.add(const Duration(hours: 1)));
      expect(decide(future, fresh: false), AccessVerdict.offlineExpired);
    });

    test('el administrador entra sin conexión aunque pase el margen', () {
      final old = check(
        admin: true,
        checkedAt: now.subtract(const Duration(days: 30)),
      );
      expect(decide(old, fresh: false), AccessVerdict.open);
    });

    test('sin ninguna comprobación no se entra', () {
      expect(decide(null, fresh: false), AccessVerdict.offlineExpired);
    });
  });

  group('AccessCheck', () {
    test('lee la respuesta del servidor', () {
      final c = AccessCheck.fromServer(
        {
          'status': 'suspended',
          'role': 'guest',
          'message': '  Hasta el lunes  ',
          'maintenance': false,
          'maintenance_message': '',
          'min_build': 40,
          'storage_limit_bytes': 1000,
          'used_bytes': 1200,
        },
        userId: 'u1',
        checkedAt: now,
      );
      expect(c.status, AccessStatus.suspended);
      expect(c.isAdmin, isFalse);
      expect(c.message, 'Hasta el lunes');
      expect(c.maintenanceMessage, isNull);
      expect(c.minBuild, 40);
      expect(c.overQuota, isTrue);
    });

    test('sin tope nunca está por encima', () {
      expect(check(used: 999999).overQuota, isFalse);
    });

    test('la caché es de una sola cuenta', () async {
      SharedPreferences.setMockInitialValues({});
      await AccessCheckCache.save(check(admin: true));
      final same = await AccessCheckCache.load('u1');
      expect(same?.isAdmin, isTrue);
      expect(same?.checkedAt, now);
      expect(await AccessCheckCache.load('otra'), isNull);
    });
  });
}

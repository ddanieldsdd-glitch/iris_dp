import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/access/app_access.dart';
import 'package:iris_dp/core/access/app_invite.dart';
import 'package:iris_dp/core/cloud/project_role.dart';

void main() {
  group('código', () {
    test('se escribe como sea y se lee igual', () {
      expect(normalizeInviteCode('k7m2-qx9p 4c'), 'K7M2QX9P4C');
      expect(normalizeInviteCode(' K7M2QX9P4C '), 'K7M2QX9P4C');
      expect(
        normalizeInviteCode('$kInvitePageUrl#c=K7M2-QX9P-4C&de=Ana&p=Corto'),
        'K7M2QX9P4C',
      );
    });

    test('rechaza lo que no es un código', () {
      expect(normalizeInviteCode(''), isNull);
      expect(normalizeInviteCode('K7M2-QX9P'), isNull);
      // 0, O, 1 e I no se usan: se confunden.
      expect(normalizeInviteCode('K7M2-QX9P-40'), isNull);
      expect(normalizeInviteCode('K7M2-QX9P-4I'), isNull);
    });

    test('se presenta en tres grupos', () {
      expect(formatInviteCode('K7M2QX9P4C'), 'K7M2-QX9P-4C');
    });
  });

  test('el enlace lleva los datos tras #, no en la consulta', () {
    final link = inviteLink(
      code: 'K7M2QX9P4C',
      from: 'Ana',
      project: 'Corto de prueba',
      role: ProjectRole.gaffer,
    );
    expect(link.toString(), startsWith(kInvitePageUrl));
    expect(link.query, isEmpty);
    final params = Uri.splitQueryString(link.fragment);
    expect(params['c'], 'K7M2-QX9P-4C');
    expect(params['de'], 'Ana');
    expect(params['p'], 'Corto de prueba');
    expect(params['r'], 'Gaffer');
  });

  test('el mensaje dice quién, a qué y el código', () {
    final text = inviteMessage(
      code: 'K7M2QX9P4C',
      from: 'Ana',
      project: 'Corto de prueba',
      role: ProjectRole.firstAc,
    );
    expect(text, startsWith('Ana te invita al proyecto «Corto de prueba»'));
    expect(text, contains('como 1.º ayudante de cámara'));
    expect(text, contains('K7M2-QX9P-4C'));
    expect(
      inviteMessage(code: 'K7M2QX9P4C'),
      startsWith('Te invitan a probar IRIS'),
    );
  });

  test('cada error del servidor tiene su explicación', () {
    for (final code in [
      'UNKNOWN',
      'EXPIRED',
      'USED',
      'REVOKED',
      'OTHER_EMAIL',
      'SIGNIN',
    ]) {
      expect(
        inviteErrorText(Exception('IRIS_INVITE_$code')),
        isNot(contains('No se pudo completar')),
        reason: code,
      );
    }
    expect(inviteErrorText(Exception('red')), contains('No se pudo'));
  });

  test('invitación abierta, usada, caducada o retirada', () {
    final now = DateTime.utc(2026, 11, 22);
    AppInvite make({int uses = 0, DateTime? expires, DateTime? revoked}) =>
        AppInvite(
          id: 'x',
          code: 'K7M2QX9P4C',
          grantsAccess: true,
          maxUses: 1,
          uses: uses,
          expiresAt: expires ?? now.add(const Duration(days: 3)),
          revokedAt: revoked,
        );
    expect(make().isOpen(now), isTrue);
    expect(make(uses: 1).isOpen(now), isFalse);
    expect(make(expires: now).isOpen(now), isFalse);
    expect(make(revoked: now).isOpen(now), isFalse);
  });

  test('resultado de usar una invitación', () {
    final r = InviteRedemption.fromServer({
      'redeemed': 1,
      'access': true,
      'projects': ['p1'],
    });
    expect(r.redeemed, 1);
    expect(r.access, isTrue);
    expect(r.projects, ['p1']);
    expect(InviteRedemption.fromServer(null).redeemed, 0);
  });

  group('plan caducado', () {
    final now = DateTime.utc(2026, 11, 22, 12);

    test('cierra la app y se guarda en la caché', () {
      final check = AccessCheck.fromServer(
        {
          'status': 'expired',
          'role': 'guest',
          'plan': 'trial',
          'plan_expires_at': '2026-11-21T00:00:00Z',
        },
        userId: 'u',
        checkedAt: now,
      );
      expect(check.status, AccessStatus.expired);
      expect(check.plan, 'trial');
      expect(
        decideAccess(last: check, fresh: true, localBuild: 1, now: now),
        AccessVerdict.expired,
      );
      final cached = AccessCheck.fromCache(check.toJson())!;
      expect(cached.status, AccessStatus.expired);
      expect(cached.planExpiresAt, DateTime.utc(2026, 11, 21));
    });

    test('una nube sin la 020 sigue funcionando', () {
      final check = AccessCheck.fromServer(
        {'status': 'active', 'role': 'guest'},
        userId: 'u',
        checkedAt: now,
      );
      expect(check.plan, isNull);
      expect(
        decideAccess(last: check, fresh: true, localBuild: 1, now: now),
        AccessVerdict.open,
      );
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/core/cloud/cloud_usage_service.dart';
import 'package:iris_dp/core/cloud/profile_service.dart';
import 'package:iris_dp/core/cloud/user_profile.dart';

import 'fake_profile_backend.dart';

Uint8List _png(int w, int h) =>
    Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));

void main() {
  const uid = 'u-1';
  late FakeProfileBackend backend;
  late MemoryProfileCache cacheA;
  late ProfileService deviceA;

  setUp(() {
    backend = FakeProfileBackend();
    cacheA = MemoryProfileCache();
    deviceA = ProfileService(backend, cacheA);
  });

  group('ProfileService', () {
    test('crea el perfil si falta, con el nombre de respaldo', () async {
      final snap = await deviceA.refresh(
        userId: uid,
        email: 'daniel@iris.test',
        fallbackName: 'Daniel',
      );
      expect(snap.profile.displayName, 'Daniel');
      expect(snap.profile.email, 'daniel@iris.test');
      expect(backend.profiles[uid]?.displayName, 'Daniel');
      expect(cacheA.profiles[uid]?.displayName, 'Daniel');
    });

    test('guarda nombre y foto, y otro dispositivo los recibe', () async {
      var snap = await deviceA.refresh(userId: uid, fallbackName: 'Daniel');
      snap = await deviceA.saveName(snap, '  Daniel Díaz ');
      snap = await deviceA.setAvatar(snap, _png(800, 600));

      expect(snap.profile.displayName, 'Daniel Díaz');
      expect(snap.profile.hasAvatar, isTrue);
      final stored = img.decodeJpg(snap.avatarBytes!)!;
      expect(stored.width, ProfileService.avatarSize);
      expect(stored.height, ProfileService.avatarSize);

      // Segundo dispositivo, caché vacía.
      final cacheB = MemoryProfileCache();
      final deviceB = ProfileService(backend, cacheB);
      final onB = await deviceB.refresh(userId: uid);
      expect(onB.profile.displayName, 'Daniel Díaz');
      expect(onB.avatarBytes, snap.avatarBytes);
      expect(cacheB.avatars[uid], isNotNull);

      // Sin cambios no vuelve a descargar la foto.
      final before = backend.downloads;
      await deviceB.refresh(userId: uid);
      expect(backend.downloads, before);

      // Foto nueva en A → B la baja al refrescar.
      await deviceA.setAvatar(snap, _png(300, 300));
      final updated = await deviceB.refresh(userId: uid);
      expect(img.decodeJpg(updated.avatarBytes!)!.width, 300);
    });

    test('quitar la foto la borra de la nube y de la caché', () async {
      var snap = await deviceA.refresh(userId: uid, fallbackName: 'D');
      snap = await deviceA.setAvatar(snap, _png(64, 64));
      snap = await deviceA.removeAvatar(snap);
      expect(snap.profile.hasAvatar, isFalse);
      expect(snap.avatarBytes, isNull);
      expect(backend.profiles[uid]?.avatarUrl, isNull);
      expect(backend.files, isEmpty);
      expect(cacheA.avatars[uid], isNull);
    });

    test('sin conexión devuelve la caché', () async {
      var snap = await deviceA.refresh(userId: uid, fallbackName: 'Daniel');
      snap = await deviceA.setAvatar(snap, _png(64, 64));
      backend.offline = true;
      final offline = await deviceA.refresh(userId: uid, email: 'd@x.test');
      expect(offline.profile.displayName, 'Daniel');
      expect(offline.profile.email, 'd@x.test');
      expect(offline.avatarBytes, isNotNull);
    });

    test('sin conexión ni caché lanza el error', () async {
      backend.offline = true;
      expect(deviceA.refresh(userId: uid), throwsException);
    });

    test('una imagen ilegible no se sube', () async {
      final snap = await deviceA.refresh(userId: uid, fallbackName: 'D');
      await expectLater(
        deviceA.setAvatar(snap, Uint8List.fromList([1, 2, 3])),
        throwsA(isA<FormatException>()),
      );
      expect(backend.uploads, 0);
    });
  });

  group('UserProfile', () {
    test('iniciales', () {
      expect(initialsFor('Daniel Díaz'), 'DD');
      expect(initialsFor('daniel'), 'D');
      expect(initialsFor('ana maría  lópez'), 'AL');
      expect(initialsFor('dani.diaz'), 'DD');
      expect(initialsFor('  '), '?');
    });

    test('sin nombre usa el email', () {
      const p = UserProfile(id: 'x', displayName: '', email: 'eva@iris.test');
      expect(p.label, 'eva');
      expect(p.initials, 'E');
    });

    test('roles', () {
      expect(roleLabel('owner'), 'DP');
      expect(roleLabel('dp'), 'DP');
      expect(roleLabel('director'), 'Director');
      expect(roleLabel(null), 'Sin rol');
    });
  });

  group('Espacio en la nube', () {
    test('lee la respuesta de iris_storage_usage', () {
      final u = CloudUsage.fromJson({
        'database_bytes': 12345678,
        'storage_bytes': '2048',
        'storage_buckets': {'project-media': 1024, 'avatars': 1024},
        'cloudinary_bytes': 5.0e9,
        'cloudinary_assets': 42,
        'measured_at': '2026-10-19T10:00:00Z',
      });
      expect(u.databaseBytes, 12345678);
      expect(u.storageBytes, 2048);
      expect(u.storageBuckets['avatars'], 1024);
      expect(u.cloudinaryBytes, 5000000000);
      expect(u.cloudinaryAssets, 42);
      expect(u.measuredAt, isNotNull);
    });

    test('formatea bytes', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1536), '1,5 KB');
      expect(formatBytes(500 * 1024 * 1024), '500 MB');
      expect(formatBytes(25 * 1024 * 1024 * 1024), '25 GB');
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:iris_dp/core/cloud/profile_service.dart';
import 'package:iris_dp/core/cloud/user_profile.dart';

/// Supabase falso: perfiles en memoria y fotos por URL.
class FakeProfileBackend implements ProfileBackend {
  final profiles = <String, UserProfile>{};
  final files = <String, Uint8List>{};
  final members = <UserProfile>[];
  bool offline = false;
  int uploads = 0;
  int downloads = 0;

  void _check() {
    if (offline) throw Exception('sin conexión');
  }

  @override
  Future<UserProfile?> fetch(String userId) async {
    _check();
    return profiles[userId];
  }

  @override
  Future<void> upsert(UserProfile profile) async {
    _check();
    profiles[profile.id] = UserProfile(
      id: profile.id,
      displayName: profile.displayName,
      avatarUrl: profile.avatarUrl,
      role: profiles[profile.id]?.role ?? 'dp',
    );
  }

  @override
  Future<String> uploadAvatar(String userId, Uint8List jpeg) async {
    _check();
    uploads++;
    final url = 'https://test/avatars/$userId/avatar.jpg?v=$uploads';
    files[url] = jpeg;
    return url;
  }

  @override
  Future<void> deleteAvatar(String userId) async {
    _check();
    files.removeWhere((url, _) => url.contains('/$userId/'));
  }

  @override
  Future<List<UserProfile>> workspaceMembers(String workspaceId) async {
    _check();
    return members;
  }

  @override
  Future<Uint8List?> download(String url) async {
    _check();
    downloads++;
    return files[url];
  }
}

/// Caché en memoria (por dispositivo).
class MemoryProfileCache implements ProfileCache {
  final profiles = <String, UserProfile>{};
  final avatars = <String, Uint8List>{};

  @override
  Future<UserProfile?> read(String userId) async => profiles[userId];

  @override
  Future<void> write(UserProfile profile) async =>
      profiles[profile.id] = profile;

  @override
  Future<Uint8List?> readAvatar(String userId) async => avatars[userId];

  @override
  Future<void> writeAvatar(String userId, Uint8List? bytes) async {
    if (bytes == null) {
      avatars.remove(userId);
    } else {
      avatars[userId] = bytes;
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_profile.dart';

/// Perfil con la foto ya descargada (para verla sin conexión).
class ProfileSnapshot {
  const ProfileSnapshot(this.profile, [this.avatarBytes]);

  final UserProfile profile;
  final Uint8List? avatarBytes;
}

/// Acceso remoto a perfiles (Supabase en la app, falso en tests).
abstract class ProfileBackend {
  Future<UserProfile?> fetch(String userId);

  /// Crea o actualiza la fila del usuario (nombre y foto).
  Future<void> upsert(UserProfile profile);

  /// Sube la foto ya normalizada y devuelve su URL pública.
  Future<String> uploadAvatar(String userId, Uint8List jpeg);

  Future<void> deleteAvatar(String userId);

  Future<List<UserProfile>> workspaceMembers(String workspaceId);

  Future<Uint8List?> download(String url);
}

/// Copia local del perfil propio y su foto.
abstract class ProfileCache {
  Future<UserProfile?> read(String userId);
  Future<void> write(UserProfile profile);
  Future<Uint8List?> readAvatar(String userId);
  Future<void> writeAvatar(String userId, Uint8List? bytes);
}

/// Perfil del usuario con sesión: Supabase manda; la caché sirve sin red.
class ProfileService {
  ProfileService(this._backend, this._cache);

  final ProfileBackend _backend;
  final ProfileCache _cache;

  /// Lado de la foto guardada (cuadrada).
  static const avatarSize = 512;

  Future<ProfileSnapshot?> cached(String userId) async {
    final profile = await _cache.read(userId);
    if (profile == null) return null;
    return ProfileSnapshot(profile, await _cache.readAvatar(userId));
  }

  /// Trae el perfil de la nube y actualiza la caché. Si no hay fila (cuentas
  /// antiguas), la crea con [fallbackName]. Sin red, devuelve la caché.
  Future<ProfileSnapshot> refresh({
    required String userId,
    String? email,
    String fallbackName = '',
  }) async {
    final previous = await _cache.read(userId);
    UserProfile? remote;
    try {
      remote = await _backend.fetch(userId);
      if (remote == null) {
        remote = UserProfile(id: userId, displayName: fallbackName);
        await _backend.upsert(remote);
      }
    } catch (_) {
      if (previous != null) {
        return ProfileSnapshot(
          previous.copyWith(email: email),
          await _cache.readAvatar(userId),
        );
      }
      rethrow;
    }

    final profile = remote.copyWith(email: email);
    var bytes = await _cache.readAvatar(userId);
    if (!profile.hasAvatar) {
      bytes = null;
      await _cache.writeAvatar(userId, null);
    } else if (bytes == null || previous?.avatarUrl != profile.avatarUrl) {
      // Otra foto (cambiada desde otro dispositivo): se descarga una vez.
      try {
        final fresh = await _backend.download(profile.avatarUrl!);
        if (fresh != null) {
          bytes = fresh;
          await _cache.writeAvatar(userId, fresh);
        }
      } catch (_) {
        // Sin foto local: se pinta desde la URL o con iniciales.
      }
    }
    await _cache.write(profile);
    return ProfileSnapshot(profile, bytes);
  }

  Future<ProfileSnapshot> saveName(ProfileSnapshot current, String name) async {
    final updated = current.profile.copyWith(displayName: name.trim());
    await _backend.upsert(updated);
    await _cache.write(updated);
    return ProfileSnapshot(updated, current.avatarBytes);
  }

  /// Recorta en cuadrado, reduce a [avatarSize] y sube como JPEG.
  Future<ProfileSnapshot> setAvatar(
    ProfileSnapshot current,
    Uint8List raw,
  ) async {
    final jpeg = await compute(normalizeAvatar, raw);
    final url = await _backend.uploadAvatar(current.profile.id, jpeg);
    final updated = current.profile.copyWith(avatarUrl: url);
    await _backend.upsert(updated);
    await _cache.writeAvatar(updated.id, jpeg);
    await _cache.write(updated);
    return ProfileSnapshot(updated, jpeg);
  }

  Future<ProfileSnapshot> removeAvatar(ProfileSnapshot current) async {
    final updated = current.profile.copyWith(clearAvatar: true);
    await _backend.upsert(updated);
    try {
      await _backend.deleteAvatar(updated.id);
    } catch (_) {
      // El archivo huérfano no molesta: el perfil ya no lo apunta.
    }
    await _cache.writeAvatar(updated.id, null);
    await _cache.write(updated);
    return ProfileSnapshot(updated);
  }

  Future<List<UserProfile>> workspaceMembers(String workspaceId) =>
      _backend.workspaceMembers(workspaceId);
}

/// Imagen cualquiera → JPEG cuadrado de [ProfileService.avatarSize] px.
Uint8List normalizeAvatar(Uint8List raw) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(raw);
  } catch (_) {
    // Bytes que no son imagen: algunos decodificadores lanzan en vez de null.
  }
  if (decoded == null) {
    throw const FormatException('No se pudo leer la imagen');
  }
  final oriented = img.bakeOrientation(decoded);
  final side = oriented.width < oriented.height
      ? oriented.width
      : oriented.height;
  final size = side < ProfileService.avatarSize
      ? side
      : ProfileService.avatarSize;
  final square = img.copyResizeCropSquare(oriented, size: size);
  return Uint8List.fromList(img.encodeJpg(square, quality: 85));
}

/// Perfiles en Supabase (`profiles` + bucket `avatars`, migración 012).
class SupabaseProfileBackend implements ProfileBackend {
  SupabaseProfileBackend(this._client, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _http;

  static const bucket = 'avatars';

  static String avatarPath(String userId) => '$userId/avatar.jpg';

  @override
  Future<UserProfile?> fetch(String userId) async {
    final row = await _client
        .from('profiles')
        .select('id, display_name, avatar_url, role')
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : UserProfile.fromJson(row);
  }

  @override
  Future<void> upsert(UserProfile profile) async {
    await _client.from('profiles').upsert({
      'id': profile.id,
      'display_name': profile.displayName,
      'avatar_url': profile.avatarUrl,
    });
  }

  @override
  Future<String> uploadAvatar(String userId, Uint8List jpeg) async {
    final path = avatarPath(userId);
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          jpeg,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
            cacheControl: '3600',
          ),
        );
    final url = _client.storage.from(bucket).getPublicUrl(path);
    // Misma ruta, otra foto: el parámetro evita que se vea la anterior.
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> deleteAvatar(String userId) async {
    await _client.storage.from(bucket).remove([avatarPath(userId)]);
  }

  @override
  Future<List<UserProfile>> workspaceMembers(String workspaceId) async {
    final rows =
        await _client.rpc(
              'workspace_member_profiles',
              params: {'ws': workspaceId},
            )
            as List<dynamic>;
    return rows
        .map((r) => UserProfile.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<Uint8List?> download(String url) async {
    final res = await _http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;
    return res.bodyBytes;
  }
}

/// Caché en preferencias (datos) y en Application Support (foto).
class LocalProfileCache implements ProfileCache {
  static String _key(String userId) => 'iris_profile_cache_$userId';

  Future<File> _avatarFile(String userId) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/profile/avatar_$userId.jpg');
  }

  @override
  Future<UserProfile?> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(profile.id), jsonEncode(profile.toJson()));
  }

  @override
  Future<Uint8List?> readAvatar(String userId) async {
    final file = await _avatarFile(userId);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> writeAvatar(String userId, Uint8List? bytes) async {
    final file = await _avatarFile(userId);
    if (bytes == null) {
      if (file.existsSync()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }
}

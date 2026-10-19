import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud_providers.dart';
import 'cloud_session.dart';
import 'profile_service.dart';
import 'user_profile.dart';

/// Cuenta con sesión iniciada (lo mínimo que necesita el perfil).
class SignedInAccount {
  const SignedInAccount({required this.id, this.email, this.metadataName});

  final String id;
  final String? email;

  /// `display_name` guardado al registrarse.
  final String? metadataName;

  String get fallbackName => metadataName?.trim().isNotEmpty == true
      ? metadataName!.trim()
      : (email?.split('@').first ?? '');
}

/// Se recalcula al iniciar o cerrar sesión.
final signedInAccountProvider = Provider<SignedInAccount?>((ref) {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  final user = client?.auth.currentUser;
  if (user == null) return null;
  return SignedInAccount(
    id: user.id,
    email: user.email,
    metadataName: user.userMetadata?['display_name'] as String?,
  );
});

final profileServiceProvider = Provider<ProfileService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return ProfileService(SupabaseProfileBackend(client), LocalProfileCache());
});

/// Nombre del workspace activo (para el menú de cuenta).
final cloudWorkspaceNameProvider = FutureProvider<String?>((ref) {
  ref.watch(signedInAccountProvider);
  return CloudSessionStore.workspaceName();
});

/// Perfil propio: primero la caché (al instante) y luego la nube.
final currentProfileProvider =
    AsyncNotifierProvider<CurrentProfileNotifier, ProfileSnapshot?>(
      CurrentProfileNotifier.new,
    );

class CurrentProfileNotifier extends AsyncNotifier<ProfileSnapshot?> {
  ProfileService? get _service => ref.read(profileServiceProvider);
  SignedInAccount? get _account => ref.read(signedInAccountProvider);

  @override
  Future<ProfileSnapshot?> build() async {
    final account = ref.watch(signedInAccountProvider);
    final service = ref.watch(profileServiceProvider);
    if (account == null || service == null) return null;

    final cached = await service.cached(account.id);
    if (cached != null) {
      unawaited(Future(refresh));
      return ProfileSnapshot(
        cached.profile.copyWith(email: account.email),
        cached.avatarBytes,
      );
    }
    try {
      return await _fetch(service, account);
    } catch (_) {
      // Sin red y sin caché: el avatar sale con iniciales del email.
      return ProfileSnapshot(
        UserProfile(
          id: account.id,
          displayName: account.fallbackName,
          email: account.email,
        ),
      );
    }
  }

  Future<ProfileSnapshot> _fetch(
    ProfileService service,
    SignedInAccount account,
  ) {
    return service.refresh(
      userId: account.id,
      email: account.email,
      fallbackName: account.fallbackName,
    );
  }

  /// Vuelve a leer de la nube (otro dispositivo pudo cambiar nombre o foto).
  Future<void> refresh() async {
    final service = _service;
    final account = _account;
    if (service == null || account == null) return;
    try {
      final fresh = await _fetch(service, account);
      if (_account?.id == account.id) state = AsyncData(fresh);
    } catch (_) {
      // Se queda lo que hay.
    }
  }

  Future<void> saveName(String name) => _update((s, c) => s.saveName(c, name));

  Future<void> setAvatar(Uint8List raw) =>
      _update((s, c) => s.setAvatar(c, raw));

  Future<void> removeAvatar() => _update((s, c) => s.removeAvatar(c));

  Future<void> _update(
    Future<ProfileSnapshot> Function(ProfileService, ProfileSnapshot) op,
  ) async {
    final service = _service;
    final current = state.valueOrNull;
    if (service == null || current == null) return;
    state = AsyncData(await op(service, current));
    ref.invalidate(workspaceMembersProvider);
  }
}

/// Personas del workspace activo con su perfil.
final workspaceMembersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final account = ref.watch(signedInAccountProvider);
  final service = ref.watch(profileServiceProvider);
  if (account == null || service == null) return const [];
  final workspaceId = await CloudSessionStore.workspaceId();
  if (workspaceId == null) return const [];
  return service.workspaceMembers(workspaceId);
});

/// Cierra la sesión de Supabase (los datos locales se quedan).
Future<void> signOutCloud(WidgetRef ref) async {
  final client = ref.read(supabaseClientProvider);
  await client?.auth.signOut();
  ref.invalidate(signedInAccountProvider);
  ref.invalidate(currentUserProvider);
}
